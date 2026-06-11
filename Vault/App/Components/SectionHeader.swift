import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
