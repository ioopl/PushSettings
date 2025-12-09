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

/**
 There are two layers:
 ***1. The value type → String***
    This is the actual data you care about (token, JSON, etc.)
    Just like Bool, Int, etc. → normal Swift types.
 
 ***2. The publisher type → AnyPublisher<Output, Failure> (or Just<String>, Published<String>.Publisher, etc.)***
 
 This is the kind of thing that emits values over time.
    It’s not the String itself. It’s the pipe that carries Strings.
 So:
    String = what comes out.
    Publisher = how it comes out (one value vs many, immediate vs async, never fails vs can fail, etc.).
 
 When we say:
    “Don’t worry about the exact publisher type”
    we don’t mean “don’t worry about String vs Int”.
 We mean:
    “ Don’t worry if the publisher is a Just<String>, a Future<String, Error>, a PassthroughSubject<String, Error>, or some crazy nested Publishers.Map<Publishers.Decode<...>>.”
 */
