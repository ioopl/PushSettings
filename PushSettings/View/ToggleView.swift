import SwiftUI

/// A reusable, plug-and-play toggle row with an inline loader.
/// - User provide:
///   - title
///   - labels for enabled / disabled states
///   - bindings for isOn + isLoading
///   - onToggle closure to perform async work.
struct ToggleView: View {
    let title: String
    let enabledLabel: String
    let disabledLabel: String
    
    /// External state: parent owns these.
    @Binding var isOn: Bool
    @Binding var isLoading: Bool
    
    /// Called when user flips the toggle.
    /// we set:
    /// - set isLoading = true
    /// - call backend / async work
    /// - update isOn depending on success
    /// - set isLoading = false
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true) // good for Dynamic Type
                
                Text(isOn ? enabledLabel : disabledLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 12)
            
            // Trailing area: Toggle + Loader stacked so layout NEVER jumps.
            ZStack {
                // The actual toggle
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        // Block user interaction while loading
                        guard !isLoading else { return }
                        onToggle(newValue)
                    })
                )
                .labelsHidden()
                .opacity(isLoading ? 0 : 1)
                .accessibilityHidden(isLoading) // when loading, spinner will take over
                
                // Loader that lives "inside" the toggle area
                ProgressView()
                    .opacity(isLoading ? 1 : 0)
                    .accessibilityLabel(Text("Updating"))
            }
            // Keep a consistent tap target and width so the row never shifts,
            // but still respects Dynamic Type vertically.
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.vertical, 8)
        // Make the whole row tappable if you like:
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLoading else { return }
            onToggle(!isOn)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isLoading ? "Updating" : (isOn ? enabledLabel : disabledLabel)))
    }
}
