import SwiftUI
import Combine

struct ContentView: View {
    
    @StateObject private var viewModel = PushRegistrationViewModel(
            sessionUC: SessionUCImplementation(),
            pushAuthenticationUC: PushAuthenticationUCImplementation(),
            vendorUC: VendorUCImplementation(),
            notificationService: NotificationServiceImplementation(),
            uuid: "device-uuid-123")
    
    var body: some View {
        PushRegistrationViewController(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
