import SwiftUI
import Combine
import UserNotifications

// MARK: - Helper protocol to abstract notification permission + token

protocol NotificationService {
    /// Asks for permission if needed and returns a push token.
    func requestPermissionAndToken() -> AnyPublisher<String, Error>
}

/// AnyPublisher is a type-erased publisher.
/// We use it when we don’t care (or don’t want to expose) how the values are produced – only what type they are and whether they can fail.

///     There are two layers:

///     1. The value type → String
///     This is the actual data you care about (token, JSON, etc.) Just like Bool, Int, etc. → normal Swift types.

///     2. The publisher type → AnyPublisher<Output, Failure> (or Just<String>, Published<String>.Publisher, etc.)
///     This is the kind of thing that emits values over time. It’s not the String itself. It’s the pipe that carries Strings.
