import Foundation
import SwiftUICore
import Combine

final class PushRegistrationViewModel: ObservableObject {
    
    // MARK: - Published state (Publisher for the View)
    
    @Published var isRegistered: Bool = false
    
    @Published var isLoading: Bool = false
    
    @Published var infoMessage: String? = nil
    
    @Published var errorMessage: String? = nil
    
    var toggleLabelText: String {
        isRegistered
        ? "You will not receive any notifications"
        : "You will receive alerts and updates notifications"
    }
    
    var title = "Push Notifications"

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
    
    /// Called by the UI when user toggles
    /// Binding target for the Toggle. We don't let the toggle write directly to `isRegistered`; instead we interpret the user's intent and run the correct flow.
       func updateToggle(to newValue: Bool) {
           guard !isLoading else {
               return
           }
           
           /// If the value didn't change, nothing to do.
           guard newValue != isRegistered else {
               return
           }
           
           errorMessage = nil
           infoMessage = nil
           
           if newValue {
               startRegistrationFlow()
           } else {
               startDeregistrationFlow()
           }
       }
    
    // MARK: - Initial state loading

    /**
    Summary
     When loadCurrentRegistrationState() runs, it does this:
     1. Show loading, clear messages.
     2. Fetch session + wait 3 seconds.
     3. Ask push backend: “what’s this session’s registration status?”
     4. Ask vendor backend: “what’s this UUID’s registration status?”
     5. Combine both answers + apply your business rules:
        — both .register → toggle ON
        — .anotherDevice → toggle OFF + message
        — anything else → toggle OFF
     6. Update UI state on the main thread, handle errors, stop spinner.
     */
    /**
     loadCurrentRegistrationState() is called (from onAppear) to answer:
        “Given both backends, is this user currently registered or not, and do I need to show a special message?”
     It uses:
        — sessionUC to get a session string
        — pushAuthenticationUC to get push registration status
        — vendorUC to get vendor registration status
        — then sets ViewModel’s isRegistered / infoMessage.
     */
    /**
     This method, loadCurrentRegistrationState(), is a private function on the ViewModel that takes no parameters and returns nothing (Void) instead, it works entirely through side effects on the ViewModel’s state.
     When we call it, it marks the screen as loading (isLoading = true), clears any previous error/info messages, and then kicks off an asynchronous Combine pipeline. That pipeline starts by calling sessionUC.fetchSession(), which returns a publisher that will eventually emit a String session or an error. After the session is fetched, it waits an extra 3 seconds using .delay (to satisfy the requirement), then uses flatMap to call pushUC.getRegistrationStatus(session:) and attach the session to that result. Next, it flatMaps again to call vendorUC.checkRegistrationStatusPublisher(uuid:), combining everything into a single tuple (session, pushStatus, vendorStatus). The .receive(on: DispatchQueue.main) ensures that the values and completion are delivered on the main thread, so updating @Published properties is UI-safe. And finally, .sink subscribes to this whole publisher chain: in the completion closure it stops the loading state and sets an error if needed, and in receiveValue it caches the session and computes whether the user is effectively registered by calling applyCombinedStatus. In short it is an async method in behaviour (it returns immediately and finishes later), but it uses Combine publishers rather than async/await, and its "result" is reflected in the ViewModel’s observable properties, not in a return value.
     */
    private func loadCurrentRegistrationState() {

        /// show spinner / disable toggle
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        /// Step 1. Fetch session. Start the Combine pipeline
        /// sessionUC to get a session string
        /// sessionUC.fetchSession() returns an **AnyPublisher<String, Error>**. This publisher will emit a session: **String** (or **fail**)
        /// We haven’t subscribed yet, but we’re building a chain. Lets call it **Publisher A**
        
        sessionUC.fetchSession()
        
        /// Step 2. Add 3 second delay AFTER fetch completes. Enforce the 3-second delay requirement.
        /// then pass the session value downstream. So now the stream still emits session: **String**, just 3 seconds later.
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
        
        /// Step 3. For the obtained session, query push status, i.e. use pushAuthenticationUC to get push registration status
        /// This .flatMap {} is chained onto the delayed session publisher i.e. sessionUC.fetchSession
        /// pushAuthenticationUC.getRegistrationStatus(session: session) which returns an **AnyPublisher<RegistrationStatus, Error>**. Lets call it **Publisher B**
        /// pushStatus: RegistrationStatus (e.g. .register, .unregister, .anotherDevice)

            .flatMap { [pushAuthenticationUC] session in
                
                /// Keep the session for later registration calls
                /// $0 is the **pushStatus** from Publisher B.
                /// We package them as (session, pushStatus).

                return pushAuthenticationUC.getRegistrationStatus(session: session)
                    .map { (session, $0) } // attach session to result
            }
        
        /// Step 4. Combine with vendor status in parallel
        /// So after this flatMap, the pipeline now emits: (session: String, pushStatus: RegistrationStatus)
        /// That’s our combined result of Steps 1–3.

            .flatMap { [vendorUC, uuid] (session, pushStatus) in
                
                /// Step 5. Ask the vendor backend for its status and combine the results
                /// Inside vendorUC.checkRegistrationStatusPublisher(uuid: uuid): which returns AnyPublisher<RegistrationStatus, Error>. Lets call it **Publisher C**
                
                vendorUC.checkRegistrationStatusPublisher(uuid: uuid)
                    .map { vendorStatus in
                        /// So after this step, your pipeline now emits: (session: String, pushStatus: RegistrationStatus, vendorStatus: RegistrationStatus)
                        return (session, pushStatus, vendorStatus)
                    }
            }
        
        /// Step 6. Ensure UI updates happen on main thread
        /// “From this point on, send values and completions on the main queue.”
            .receive(on: DispatchQueue.main)
        
        /// Step 7. Subscribe
        /// Attach a subscriber (sink) and handle the result

        /// receiveValue closure. This gets the triple we built earlier: (session: String, pushStatus: RegistrationStatus, vendorStatus: RegistrationStatus)
        /// 
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false

                /// This is where the pipeline actually runs.
                /// completion closure, Runs once when the publisher: either finishes normally (.finished), or fails with an error (.failure).
                switch completion {
                    
                case .failure(let error):
                    /// If there was an error anywhere in the chain (session fetch, push status, vendor status):
                    self.errorMessage = "Failed to load status: \(error.localizedDescription)"
                    
                case .finished:
                    /// If it finished successfully: Do nothing special here—success handling is in receiveValue:
                    break
                }
            } receiveValue: { [weak self] session, pushStatus, vendorStatus in
                guard let self = self else { return }
                
                /// Cache the session string for later registration calls (so we don’t have to fetch it again immediately)
                self.cachedSession = session
                
                /// Delegate the business rule of “How do we interpret these two statuses?” to a separate method.
                self.applyCombinedStatus(pushStatus: pushStatus,
                                         vendorStatus: vendorStatus)
            }
            .store(in: &cancellables)
    }
    
    internal func applyCombinedStatus(pushStatus: RegistrationStatus,
                                     vendorStatus: RegistrationStatus) {
        
        switch (pushStatus, vendorStatus) {
        /// 1) Special case: push says "anotherDevice" – vendor doesn’t matter, ignore vendor completely, Mark the user as not registered
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
  
    // MARK: - Registration flow
    
    /**
     Summary
     1. Mark UI as loading, clear old messages.
     2. Ask the OS for notification permission + token.
     3. Once you have the token, fetch a session and wait 3 seconds.
     4. Once you have both token + session, call:
        — Push backend register API,
        — Vendor backend register API,
        — in parallel, and wait for both.
     5. Back on the main thread:
        — Stop loading.
        — If any error occurred → show “Registration failed: …”.
        — If both calls returned true → mark isRegistered = true.
        — If either returned false → show “Registration did not complete successfully.”
     All of that logic is encoded as a single Combine “pipe”.
     */
    private func startRegistrationFlow() {
        
        /// “We’re busy” set isLoading = true (show spinner, disable toggle). So the user sees a clean “working…” state
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        /// Step 1. Ask for notification permission & token
        /// Calls NotificationService abstraction
        /// requestPermissionAndToken() returns an AnyPublisher<String, Error>:
        /// notificationService.requestPermissionAndToken() → returns a **publisher of token String**

        notificationService.requestPermissionAndToken()
       
        /// This line starts a Combine pipeline: from here on, all the operators chain off this specific publisher (i.e. notificationService.requestPermissionAndToken)
        /// So basically this block is chained to the previous publisher i.e. notificationService.requestPermissionAndToken which we recall returns: AnyPublisher<String, Error>
        /// That’s our first publisher in the chain. Say we call it PublisherA: “token stream”
        /// Each step sees the output of the previous one.
        /**
         PublisherA
           .flatMap { ... }
           .flatMap { ... }
           .map { ... }
           .sink { ... }
         */

        /// Step 2. Get a session (with a delay)
        /// NOTE: sessionUC is not created here. It’s a dependency of the ViewModel, captured into the closure.
        /// sessionUC is a stored property on the ViewModel. 
        /// sessionUC is injected from outside (unit tests give a mock, real app gives a real implementation).
        /// It conforms to SessionUC and has a method: func fetchSession() -> AnyPublisher<String, Error>
        /// .flatMap { [sessionUC] token in — This is a **closure capture list**:
        /// Recap: A **Capture List** in Swift is a way to define how values from the surrounding context are captured by a closure. It allows us to capture values by value using [mode] syntax, and can also be used to define custom names for the captured variables.
        /// **Why Does This Happen?** Captured Values: When we capture a value in a closure, Swift creates a snapshot of that value at the time the closure is created. See Google docs for details on this topic

        /// and **token** is just a String value being piped through Combine.
        /// We’re just saying: “For every **token** the previous publisher emits, use my existing **sessionUC** dependency to fetch a session.”
        /// token is the argument passed into the closure — from the previous publisher which is notificationService.requestPermissionAndToken()

        /// **sessionUC.fetchSession():** Uses the captured sessionUC dependency from the ViewModel and Starts a new publisher that will emit a **session: String**
        
        /// **.map { session in (token, session) }:** Combines the outer data coming from the first step i.e. **token** and inner **session** into a tuple. Now the pipeline emits (token: String, session: String).
        /// We’re essentially combining dependency + incoming value to produce a new **publisher**
        
        /// flatMap takes that **token**, runs a new async publisher (fetchSession), then flattens it so downstream sees (token, session).

            .flatMap { [sessionUC] token in
                sessionUC.fetchSession()
                    .delay(for: .seconds(3), scheduler: DispatchQueue.main)
                    .map { session in (token, session) }
            }
        
        /// So after first flatMap, our pipeline is now a Publisher that **emits (token, session)** or an **error**
        /// Step 3. Once we have (token + session) call both register endpoints / call two backends.
        
        /// Publishers.Zip(A, B):
        /// Runs both publishers in parallel.
        /// Waits for one value from each.
        /// Emits a tuple (aValue, bValue) → here: (Bool, Bool).
        /// If either fails, the whole zip fails with that error.
        /// pushAuthenticationUC.register(...): Returns AnyPublisher<Bool, Error> — did PushAuth registration succeed? Yes/No
        /// vendorUC.registerUser(with: uuid): Returns AnyPublisher<Bool, Error> — did Vendor registration succeed? Yes/No
    

            .flatMap { [pushAuthenticationUC, vendorUC, uuid] (token, session) in
                Publishers.Zip(
                    pushAuthenticationUC.register(with: uuid, session: session, token: token),
                    vendorUC.registerUser(with: uuid)
                )
            }
        /// .receive(on: DispatchQueue.main) tells Combine: “From this point on, deliver values and completions on the main thread.” IMP because we are about to update @Published properties used by the UI/ SwiftUI
            .receive(on: DispatchQueue.main)

        /// sink — This is where we **subscribe** – we attach a **Subscriber (sink)** to the pipeline:

        /// receiveValue closure runs whenever the pipeline emits a value. This runs when Publishers.Zip emits (Bool, Bool)
        /// receiveValue: closure is our “business rule”: Registration is only considered successful if both backends report success (true, true)

            .sink { [weak self] completion in
                guard let self = self else { return }
                
                self.isLoading = false

                switch completion {
                    /// If it failed: Set errorMessage so the UI can show an error.
                case .failure(let error):
                    self.errorMessage = "Registration failed: \(error.localizedDescription)"
                    /// If it finished normally: Do nothing here — success handling is all done in receiveValue:
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

    // MARK: - De-registration flow
    
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
    
    // MARK: - Convenience binding for the View
    
    /// a computed property that creates a Binding<Bool>
    var toggleBinding: Binding<Bool> {
        Binding(
            get: {
                self.isRegistered
            },
            set: { [weak self] newValue in
                self?.updateToggle(to: newValue)
            }
        )
    }
}
