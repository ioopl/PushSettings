import XCTest
import Combine
@testable import PushSettings

// MARK: - ViewModel Tests

@MainActor
final class PushRegistrationViewModelTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Helper to build a fresh VM with configurable mocks
    private func makeViewModel(
        pushStatus: RegistrationStatus = .unregister,
        vendorStatus: RegistrationStatus = .unregister,
        notificationShouldSucceed: Bool = true,
        pushRegisterShouldSucceed: Bool = true,
        pushDeRegisterShouldSucceed: Bool = true,
        vendorRegisterShouldSucceed: Bool = true,
        vendorDeRegisterShouldSucceed: Bool = true) -> (vm: PushRegistrationViewModel,
                                                        pushUC: TestPushAuthenticationUC,
                                                        vendorUC: TestVendorUC,
                                                        notificationService: TestNotificationService) {
            
        let sessionUC = ImmediateSessionUC()
        
        let pushUC = TestPushAuthenticationUC()
        pushUC.registrationStatus = pushStatus
        pushUC.registerShouldSucceed = pushRegisterShouldSucceed
        pushUC.deRegisterShouldSucceed = pushDeRegisterShouldSucceed
        
        let vendorUC = TestVendorUC()
        vendorUC.registrationStatus = vendorStatus
        vendorUC.registerShouldSucceed = vendorRegisterShouldSucceed
        vendorUC.deRegisterShouldSucceed = vendorDeRegisterShouldSucceed
        
        let notificationService = TestNotificationService()
        notificationService.shouldSucceed = notificationShouldSucceed
        
        let vm = PushRegistrationViewModel(
            sessionUC: sessionUC,
            pushAuthenticationUC: pushUC,
            vendorUC: vendorUC,
            notificationService: notificationService,
            uuid: "test-uuid")
        
        return (vm, pushUC, vendorUC, notificationService)
    }
    
    /**
     The toggles state depends on the following logic:
     The user is **registered** Only
     if
     ***`PushAuthenticationUC.getRegistrationStatus(session:)` returns `.register`
     `and`
     `VendorUC.checkRegistrationStatusPublisher(uuid:)` returns `.register`.
     */
    
    func testInitialState_bothSystemsRegistered_setsIsRegisteredTrue() {
        
        let (vm, _, _, _) = makeViewModel(pushStatus: .register,
                                          vendorStatus: .register)
        
        let exp = expectation(description: "becomes registered")
        
        vm.$isRegistered
            .dropFirst() /// initial false
            .sink { value in
                if value == true {
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        vm.onAppear()
        
        /// 3 seconds internal delay in ViewModel; give a bit extra
        waitForExpectations(timeout: 4.0)
        
        XCTAssertTrue(vm.isRegistered)
        XCTAssertNil(vm.infoMessage)
        XCTAssertNil(vm.errorMessage)
    }
    
    func testInitialState_anotherDevice_setsUnregisteredAndShowsMessage() {
        
        let (vm, _, _, _) = makeViewModel(pushStatus: .anotherDevice,
                                          vendorStatus: .register   // does not matter in this case
        )
        
        let exp = expectation(description: "infoMessage set for anotherDevice")
        
        vm.$infoMessage
            .compactMap { $0 }
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        vm.onAppear()
        
        waitForExpectations(timeout: 4.0)
        
        XCTAssertFalse(vm.isRegistered)
        XCTAssertEqual(vm.infoMessage, "Registered on another device.")
    }
    
    func testToggleOn_triggersRegistrationAndSetsRegisteredOnSuccess() {
        
        let (vm, pushUC, vendorUC, _) = makeViewModel(pushStatus: .unregister,
                                                      vendorStatus: .unregister,
                                                      notificationShouldSucceed: true,
                                                      pushRegisterShouldSucceed: true,
                                                      vendorRegisterShouldSucceed: true)
        
        let exp = expectation(description: "becomes registered after toggle on")
        
        vm.$isRegistered
            .dropFirst()
            .sink { value in
                if value == true {
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        /// No need to call onAppear for this test, we start from unregistered
        vm.updateToggle(to: true)
        
        waitForExpectations(timeout: 4.0)
        
        XCTAssertTrue(vm.isRegistered)
        XCTAssertTrue(pushUC.registerCalled)
        XCTAssertTrue(vendorUC.registerCalled)
        XCTAssertNil(vm.errorMessage)
    }
    
    func testToggleOn_failsWhenNotificationPermissionDenied() {
        
        let (viewModel, pushUC, vendorUC, notificationService) = makeViewModel(pushStatus: .unregister,
                                                                               vendorStatus: .unregister,
                                                                               notificationShouldSucceed: false)
        
        XCTAssertFalse(notificationService.shouldSucceed)
        
        let exp = expectation(description: "errorMessage set when permission denied")
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.updateToggle(to: true)
        
        waitForExpectations(timeout: 2.0)
        
        XCTAssertFalse(viewModel.isRegistered)
        XCTAssertFalse(pushUC.registerCalled)
        XCTAssertFalse(vendorUC.registerCalled)
    }
    
    func testToggleOff_triggersDeregistration() {
        
        /// Start with both systems registered
        let (viewModel, pushUC, vendorUC, _) = makeViewModel(pushStatus: .register,
                                                             vendorStatus: .register)
        
        let becameRegistered = expectation(description: "initially becomes registered")
        
        viewModel.$isRegistered
            .dropFirst()
            .sink { value in
                if value == true {
                    becameRegistered.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.onAppear()
        wait(for: [becameRegistered], timeout: 4.0)
        XCTAssertTrue(viewModel.isRegistered)
        
        /// Test toggling off
        let becameUnregistered = expectation(description: "becomes unregistered after toggle off")
        
        viewModel.$isRegistered
            .dropFirst()
            .sink { value in
                if value == false {
                    becameUnregistered.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.updateToggle(to: false)
        
        wait(for: [becameUnregistered], timeout: 2.0)
        
        XCTAssertFalse(viewModel.isRegistered)
        XCTAssertTrue(pushUC.deRegisterCalled)
        XCTAssertTrue(vendorUC.deRegisterCalled)
    }
    
        // MARK: - applyCombinedStatus() tests

        func testApplyCombinedStatus_anotherDevice_overridesVendor() {
            /// Given a fresh VM
            let (viewModel, _, _, _) = makeViewModel()

            /// When pushStatus is .anotherDevice and vendor is .register
            viewModel.applyCombinedStatus(pushStatus: .anotherDevice, vendorStatus: .register)

            /// Then we should be unregistered with the special message
            XCTAssertFalse(viewModel.isRegistered)
            XCTAssertEqual(viewModel.infoMessage, "Registered on another device.")

            /// And even if vendor says .unregister, result is the same
            viewModel.applyCombinedStatus(pushStatus: .anotherDevice, vendorStatus: .unregister)

            XCTAssertFalse(viewModel.isRegistered)
            XCTAssertEqual(viewModel.infoMessage, "Registered on another device.")
        }

    /**
     Given the raw statuses .register + .register, the combined state is “registered”.
     */
    func testApplyCombinedStatus_bothRegister_setsRegisteredTrue() {
        let (viewModel, _, _, _) = makeViewModel()
        
        viewModel.applyCombinedStatus(pushStatus: .register, vendorStatus: .register)
        
        XCTAssertTrue(viewModel.isRegistered)
        XCTAssertNil(viewModel.infoMessage)
    }
    
    /**
     If one returns `.register` and the other `.unregister`, the combined state should be **unregister**.
     */
    func testApplyCombinedStatus_mixedOrUnregister_combinations_setRegisteredFalse() {
        let (viewModel, _, _, _) = makeViewModel()
        
        /// All combinations that are NOT (.register, .register) and not (.anotherDevice, _)
        let cases: [(RegistrationStatus, RegistrationStatus)] = [
            (.register, .unregister),
            (.unregister, .register),
            (.unregister, .unregister)
        ]
        
        for (pushStatus, vendorStatus) in cases {
            viewModel.applyCombinedStatus(pushStatus: pushStatus, vendorStatus: vendorStatus)
            
            XCTAssertFalse(viewModel.isRegistered, "Expected isRegistered = false for (\(pushStatus), \(vendorStatus))")
            XCTAssertNil(viewModel.infoMessage, "Expected no infoMessage for (\(pushStatus), \(vendorStatus))")
        }
    }

    /**
     If `PushAuthenticationUC.getRegistrationStatus(session:)` returns `.anotherDevice`,
       the state should be **unregister**, and an appropriate **message** should be shown
       (e.g. Registered on another device)
     */
    @MainActor
    func testInitialState_pushAnotherDevice_setsUnregisteredAndShowsMessage() {
        /// Given: a View Model where PushAuthenticationUC returns .anotherDevice
        /// pushStatus and vendorStatus are just the raw statuses from two backends.
        
        let (viewModel, pushUC, vendorUC, _) = makeViewModel(pushStatus: .anotherDevice,
                                                             vendorStatus: .register /// vendor result shouldn't really matter in this case
        )
        
        XCTAssertEqual(pushUC.registrationStatus, .anotherDevice)
        XCTAssertEqual(vendorUC.registrationStatus, .register)
        
        /// We expect: isRegistered becomes false, and infoMessage is set
        let infoExpectation = expectation(description: "infoMessage set for anotherDevice")
        
        viewModel.$infoMessage
            .compactMap { $0 } /// ignore nils
            .sink { _ in
                infoExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        /// When: the screen appears (triggers loadCurrentRegistrationState)
        viewModel.onAppear()
        
        /// ViewModel has an internal delay (3s) so we give it a bit more
        waitForExpectations(timeout: 4.0)
        
        /// Then: state is unregistered + message shown
        XCTAssertFalse(viewModel.isRegistered)
        XCTAssertEqual(viewModel.infoMessage, "Registered on another device.")
        XCTAssertNil(viewModel.errorMessage)
    }

    /**
        Push Notifiction Toggle Text Scenarios
     */
    @MainActor
    func testToggleLabelReflectsRegistrationState() {
        /// Given: a fresh ViewModel (default isRegistered should be false)
        let (vm, _, _, _) = makeViewModel()

        /// Initially unregistered → label should say "Enable..."
        XCTAssertFalse(vm.isRegistered)
        XCTAssertEqual(vm.toggleLabelText, "You will receive alerts and updates notifications")

        /// When: we make the combined status registered
        vm.applyCombinedStatus(pushStatus: .register, vendorStatus: .register)

        /// Then: state and label should both reflect "registered"
        XCTAssertTrue(vm.isRegistered)
        XCTAssertEqual(vm.toggleLabelText, "You will not receive any notifications")
    }
    
    /**
     A unit test for the binding.
     Test that the binding’s get reflects isRegistered,
     that setting the binding actually calls into the registration logic.
     */
    @MainActor
    func testToggleBindingReflectsAndControlsIsRegistered() {
        /// Given: a View Model starting unregistered, with fast-success mocks
        let (viewModel, _, _, _) = makeViewModel(pushStatus: .unregister,
                                                 vendorStatus: .unregister,
                                                 notificationShouldSucceed: true,
                                                 pushRegisterShouldSucceed: true,
                                                 vendorRegisterShouldSucceed: true)
        
        let binding = viewModel.toggleBinding
        
        /// 1) Getter should reflect current isRegistered
        XCTAssertFalse(viewModel.isRegistered)
        XCTAssertEqual(binding.wrappedValue, false, "Binding getter should mirror isRegistered")
        
        /// 2) When we set the binding to true, it should go through userSetToggle
        let becameRegistered = expectation(description: "VM becomes registered via binding")
        
        viewModel.$isRegistered
            .dropFirst()
            .sink { value in
                if value == true {
                    becameRegistered.fulfill()
                }
            }
            .store(in: &cancellables)
        
        /// This uses the Binding's setter and calls userSetToggle(to: true)
        binding.wrappedValue = true
        
        wait(for: [becameRegistered], timeout: 4.0)
        
        /// 3) After async flow, isRegistered AND binding getter should both be true
        XCTAssertTrue(viewModel.isRegistered)
        XCTAssertEqual(binding.wrappedValue, true)
    }
}
