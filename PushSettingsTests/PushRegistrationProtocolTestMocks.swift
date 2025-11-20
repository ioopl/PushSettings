import XCTest
import Combine
@testable import PushSettings

// MARK: - Test Mocks
 
final class ImmediateSessionUC: SessionUC {
    func fetchSession() -> AnyPublisher<String, Error> {
        Just("test-session-123")
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

private enum TestError: Error {
    case permissionDenied
}

final class TestNotificationService: NotificationService {
    
    var shouldSucceed: Bool = true
    var tokenToReturn: String = "test-token"
    
    func requestPermissionAndToken() -> AnyPublisher<String, Error> {
        if shouldSucceed {
            return Just(tokenToReturn)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: TestError.permissionDenied)
                .eraseToAnyPublisher()
        }
    }
}

final class TestPushAuthenticationUC: PushAuthenticationUC {
    var registrationStatus: RegistrationStatus = .unregister
    var registerShouldSucceed: Bool = true
    var deRegisterShouldSucceed: Bool = true
    
    private(set) var registerCalled = false
    private(set) var deRegisterCalled = false
    
    func getRegistrationStatus(session: String) -> AnyPublisher<RegistrationStatus, Error> {
        Just(registrationStatus)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func register(with uuid: String, session: String, token: String) -> AnyPublisher<Bool, Error> {
        registerCalled = true
        return Just(registerShouldSucceed)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deRegister(with uuid: String) -> AnyPublisher<Bool, Error> {
        deRegisterCalled = true
        return Just(deRegisterShouldSucceed)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

final class TestVendorUC: VendorUC {
    
    var registrationStatus: RegistrationStatus = .unregister
    var registerShouldSucceed: Bool = true
    var deRegisterShouldSucceed: Bool = true
    
    private(set) var registerCalled = false
    private(set) var deRegisterCalled = false
    
    func checkRegistrationStatusPublisher(uuid: String) -> AnyPublisher<RegistrationStatus, Error> {
        Just(registrationStatus)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func registerUser(with uuid: String) -> AnyPublisher<Bool, Error> {
        registerCalled = true
        return Just(registerShouldSucceed)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deRegisterUser(with uuid: String) -> AnyPublisher<Bool, Error> {
        deRegisterCalled = true
        return Just(deRegisterShouldSucceed)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
