import SwiftUI

struct CollectionsScreen: View {
    var body: some View {
        ContentUnavailableView(
            "Collections",
            systemImage: "folder",
            description: Text("Collections feature scaffold")
        )
        .navigationTitle("Collections")
    }
}

#Preview {
    NavigationStack {
        CollectionsScreen()
    }
}
