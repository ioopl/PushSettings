import Foundation
import Combine

final class PushAuthenticationUCImplementation: PushAuthenticationUC {
    
    var registrationStatus: RegistrationStatus = .unregister
    var shouldSucceed: Bool = true
    
    func getRegistrationStatus(session: String) -> AnyPublisher<RegistrationStatus, Error> {
        /// Just(registrationStatus): A publisher that emits "registrationStatus" once then completes successfully, never fails.
        /// .setFailureType(to: Error.self): Changes the generic failure type from Never to Error. "Treating it as if it could fail with Error, even though it never does."
        /// .eraseToAnyPublisher(): Wraps that concrete publisher into AnyPublisher<RegistrationStatus, Error>, to match the protocol and hide the exact type.
        Just(registrationStatus)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func register(with uuid: String, session: String, token: String) -> AnyPublisher<Bool, Error> {
        Just(shouldSucceed)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func deRegister(with uuid: String) -> AnyPublisher<Bool, Error> {
        Just(shouldSucceed)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
