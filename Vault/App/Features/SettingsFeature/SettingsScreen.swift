import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "gearshape",
            description: Text("Settings feature scaffold")
        )
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
