import UIKit
import Combine

enum RegistrationStatus {
    case register
    case unregister
    case anotherDevice
}

/// PushAuthentication backend (via PushAuthentication Use Case)
protocol PushAuthenticationUC {
    func getRegistrationStatus(session: String) -> AnyPublisher<RegistrationStatus, Error>
    func register(with uuid: String, session: String, token: String) -> AnyPublisher<Bool, Error>
    func deRegister(with uuid: String) -> AnyPublisher<Bool, Error>
}

/// Session Use case
protocol SessionUC {
    func fetchSession() -> AnyPublisher<String, Error>
}

/// Vendor backend (via Vendor Use Case)
protocol VendorUC {
    func checkRegistrationStatusPublisher(uuid: String) -> AnyPublisher<RegistrationStatus, Error>
    func registerUser(with uuid: String) -> AnyPublisher<Bool, Error>
    func deRegisterUser(with uuid: String) -> AnyPublisher<Bool, Error>
}
