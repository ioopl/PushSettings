import SwiftUI
import Combine

struct ContentView: View {
    
    @StateObject private var viewModel = PushRegistrationViewModel(
            sessionUC: SessionUCImplementation(),
            pushUC: PushAuthenticationUCImplementation(),
            vendorUC: VendorUCImplementation(),
            notificationService: NotificationServiceImplementation(),
            uuid: "device-uuid-123")
    
    var body: some View {
        PushRegistrationScreen(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
