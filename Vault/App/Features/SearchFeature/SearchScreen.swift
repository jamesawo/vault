import SwiftUI

struct SearchScreen: View {
    var body: some View {
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Search feature scaffold")
        )
        .navigationTitle("Search")
    }
}

#Preview {
    NavigationStack {
        SearchScreen()
    }
}
