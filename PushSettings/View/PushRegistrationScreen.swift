import SwiftUI

struct PushRegistrationScreen: View {
    
    @StateObject var viewModel: PushRegistrationViewModel
    
    private var toggleLabelText: String {
        viewModel.isRegistered
        ? "Disable push notifications"
        : "Enable push notifications"
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Push Registration")
                .font(.title)
                .bold()
            
            if viewModel.isLoading {
                ProgressView("Loading.")
            }
            
            Toggle(isOn: viewModel.toggleBinding) {
                Text(viewModel.toggleLabelText)
            }
            .disabled(viewModel.isLoading)
            .padding()
            .accessibilityIdentifier("pushNotificationToggle")
            
            if let info = viewModel.infoMessage {
                Text(info)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
    }
}
