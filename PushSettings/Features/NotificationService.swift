import SwiftUI
import Combine
import UserNotifications

// MARK: - Helper protocol to abstract notification permission + token

protocol NotificationService {
    
    /// Asks for permission if needed and returns a push token.
    func requestPermissionAndToken() -> AnyPublisher<String, Error>
}
