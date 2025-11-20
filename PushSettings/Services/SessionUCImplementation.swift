import Foundation
import Combine

final class SessionUCImplementation: SessionUC {
    
    func fetchSession() -> AnyPublisher<String, Error> {
        Just("mock-session-1234")
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1),
                   scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
