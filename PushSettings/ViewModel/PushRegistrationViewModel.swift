import Foundation
import SwiftUICore
import Combine

final class PushRegistrationViewModel: ObservableObject {
    
    // MARK: - Published state for the View
    
    /// Whether the user is effectively registered (drives the toggle).
    @Published private(set) var isRegistered: Bool = false
    
    /// Whether we are currently loading (initial fetch or register/deregister).
    @Published var isLoading: Bool = false
    
    /// Info message for things like `.anotherDevice`.
    @Published var infoMessage: String? = nil
    
    /// Error message when something fails.
    @Published var errorMessage: String? = nil
    
    var toggleLabelText: String {
            isRegistered
            ? "Disable push notifications"
            : "Enable push notifications"
        }

    // MARK: - Dependencies
    
    private let sessionUC: SessionUC
    private let pushAuthenticationUC: PushAuthenticationUC
    private let vendorUC: VendorUC
    private let notificationService: NotificationService
    private let uuid: String
    private var cachedSession: String?
    
    /// An object that represents an active subscription. The Set<AnyCancellable> is just "all the active subscriptions we want to keep alive".
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(sessionUC: SessionUC,
        pushAuthenticationUC: PushAuthenticationUC,
        vendorUC: VendorUC,
        notificationService: NotificationService,
        uuid: String) {
        
        self.sessionUC = sessionUC
        self.pushAuthenticationUC = pushAuthenticationUC
        self.vendorUC = vendorUC
        self.notificationService = notificationService
        self.uuid = uuid
    }
    
    // MARK: - Public API for View
    
    func onAppear() {
        loadCurrentRegistrationState()
    }
    
    /// Binding target for the Toggle. We don't let the toggle write directly to `isRegistered`;
    /// instead we interpret the user's intent and run the correct flow.
    func userSetToggle(to newValue: Bool) {
        guard !isLoading else {
            return
        }
        
        /// If the value didn't change, nothing to do.
        guard newValue != isRegistered else {
            return
        }
        
        if newValue {
            startRegistrationFlow()
        } else {
            startDeregistrationFlow()
        }
    }
    
    // MARK: - Initial state loading

    /**
     This method, loadCurrentRegistrationState(), is a private function on the ViewModel that takes no parameters and returns nothing (Void) instead, it works entirely through side effects on the ViewModel’s state.
     When we call it, it marks the screen as loading (isLoading = true), clears any previous error/info messages, and then kicks off an asynchronous Combine pipeline. That pipeline starts by calling sessionUC.fetchSession(), which returns a publisher that will eventually emit a String session or an error. After the session is fetched, it waits an extra 3 seconds using .delay (to satisfy the requirement), then uses flatMap to call pushUC.getRegistrationStatus(session:) and attach the session to that result. Next, it flatMaps again to call vendorUC.checkRegistrationStatusPublisher(uuid:), combining everything into a single tuple (session, pushStatus, vendorStatus). The .receive(on: DispatchQueue.main) ensures that the values and completion are delivered on the main thread, so updating @Published properties is UI-safe. And finally, .sink subscribes to this whole publisher chain: in the completion closure it stops the loading state and sets an error if needed, and in receiveValue it caches the session and computes whether the user is effectively registered by calling applyCombinedStatus. In short it is an async method in behaviour (it returns immediately and finishes later), but it uses Combine publishers rather than async/await, and its "result" is reflected in the ViewModel’s observable properties, not in a return value.
     */
    private func loadCurrentRegistrationState() {
        
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        /// 1. Fetch session
        sessionUC.fetchSession()
        
        /// 2. Add 3 second delay AFTER fetch completes
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
        
        /// 3. For the obtained session, query push status
            .flatMap { [pushAuthenticationUC] session in
                
                // Keep the session for later registration calls
                return pushAuthenticationUC.getRegistrationStatus(session: session)
                    .map { (session, $0) } // attach session to result
            }
        
        /// 4. Combine with vendor status in parallel
            .flatMap { [vendorUC, uuid] (session, pushStatus) in
                vendorUC.checkRegistrationStatusPublisher(uuid: uuid)
                    .map { vendorStatus in
                        return (session, pushStatus, vendorStatus)
                    }
            }
        
        /// 5. Ensure UI updates happen on main thread
            .receive(on: DispatchQueue.main)
        
        /// 6. Subscribe
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch completion {
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load status: \(error.localizedDescription)"
                    
                case .finished:
                    break
                }
            } receiveValue: { [weak self] session, pushStatus, vendorStatus in
                guard let self = self else { return }
                
                self.cachedSession = session
                
                self.applyCombinedStatus(pushStatus: pushStatus,
                                         vendorStatus: vendorStatus)
            }
            .store(in: &cancellables)
    }
    
    internal func applyCombinedStatus(pushStatus: RegistrationStatus,
                                     vendorStatus: RegistrationStatus) {
        
        switch (pushStatus, vendorStatus) {
        /// 1) Special case: push says "anotherDevice" – vendor doesn’t matter
        case (.anotherDevice, _):
            isRegistered = false
            infoMessage = "Registered on another device."

        /// 2) Both say "register" = effectively registered
        case (.register, .register):
            isRegistered = true
            infoMessage = nil

        /// 3) Everything else = treated as unregistered
        default:
            isRegistered = false
            infoMessage = nil
        }
    }
    
    // MARK: - Registration / De-registration flows
    
    private func startDeregistrationFlow() {
        isLoading = true
        errorMessage = nil
        
        /// Call both de-register use cases in parallel
        Publishers.Zip(
            pushAuthenticationUC.deRegister(with: uuid),
            vendorUC.deRegisterUser(with: uuid)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self = self else { return }
            
            self.isLoading = false
            
            switch completion {
                
            case .failure(let error):
                self.errorMessage = "De-registration failed: \(error.localizedDescription)"
                
            case .finished:
                break
            }
        } receiveValue: { [weak self] pushSuccess, vendorSuccess in
            guard let self = self else { return }
            
            if pushSuccess && vendorSuccess {
                self.isRegistered = false
            } else {
                self.errorMessage = "De-registration did not complete successfully."
            }
        }
        .store(in: &cancellables)
    }
    
    private func startRegistrationFlow() {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        /// 1. Ask for notification permission & token
        notificationService.requestPermissionAndToken()
       
        /// 2. Get a session (again with a delay)
            .flatMap { [sessionUC] token in
                sessionUC.fetchSession()
                    .delay(for: .seconds(3), scheduler: DispatchQueue.main)
                    .map { session in (token, session) }
            }
        
        /// 3. Once we have token + session, call both register endpoints
            .flatMap { [pushAuthenticationUC, vendorUC, uuid] (token, session) in
                Publishers.Zip(
                    pushAuthenticationUC.register(with: uuid, session: session, token: token),
                    vendorUC.registerUser(with: uuid)
                )
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false

                switch completion {
                case .failure(let error):
                    self.errorMessage = "Registration failed: \(error.localizedDescription)"
                    
                case .finished:
                    break
                }
            } receiveValue: { [weak self] pushSuccess, vendorSuccess in
                guard let self = self else { return }
                
                if pushSuccess && vendorSuccess {
                    self.isRegistered = true
                } else {
                    self.errorMessage = "Registration did not complete successfully."
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Convenience binding for the View
    
    /// a computed property that creates a Binding<Bool>.
    var toggleBinding: Binding<Bool> {
        Binding(
            get: {
                self.isRegistered
            },
            set: { [weak self] newValue in
                self?.userSetToggle(to: newValue)
            }
        )
    }
}
