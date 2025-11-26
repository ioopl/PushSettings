import Combine
import Foundation

/// Fake notification service – in real App we will use APNS token
enum MockNotificationError: Error {
    case denied
}

final class NotificationServiceImplementation: NotificationService {
    var shouldAllow: Bool = true
    
    func requestPermissionAndToken() -> AnyPublisher<String, Error> {
        if shouldAllow {
            return Just("mock-push-token-xyz")
                .setFailureType(to: Error.self)
                .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: MockNotificationError.denied)
                .eraseToAnyPublisher()
        }
    }
}
