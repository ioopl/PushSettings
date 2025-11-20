import Foundation
import Combine

final class VendorUCImplementation: VendorUC {
    var registrationStatus: RegistrationStatus = .unregister
    var shouldSucceed: Bool = true
    
    func checkRegistrationStatusPublisher(uuid: String) -> AnyPublisher<RegistrationStatus, Error> {
        Just(registrationStatus)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func registerUser(with uuid: String) -> AnyPublisher<Bool, Error> {
        Just(shouldSucceed)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func deRegisterUser(with uuid: String) -> AnyPublisher<Bool, Error> {
        Just(shouldSucceed)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
