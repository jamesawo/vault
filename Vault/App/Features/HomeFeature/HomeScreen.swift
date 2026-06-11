import SwiftUI

struct HomeScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink(value: AppRoute.collections) {
                    Label("Collections", systemImage: "folder")
                }

                NavigationLink(value: AppRoute.search) {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink(value: AppRoute.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            } header: {
                SectionHeader(title: "Features")
            }
        }
        .navigationTitle("Vault")
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
}
