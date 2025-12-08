import SwiftUI

struct PushRegistrationViewController: View {
    
    @StateObject var viewModel: PushRegistrationViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Push Registration")
                .font(.title)
                .bold()
            
            /// Reusable toggle row
            ToggleView(
                title: viewModel.title,
                enabledLabel: viewModel.toggleLabelText,
                disabledLabel: viewModel.toggleLabelText,
                isOn: $viewModel.isRegistered,
                isLoading: $viewModel.isLoading) { newToggleState in
                    viewModel.updateToggle(to: newToggleState)
                }
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
