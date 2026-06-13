import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

struct VaultFileThumbnailView: View {
    let item: VaultItem
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackThumbnail
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: item.id) {
            await loadThumbnail()
        }
    }

    private var fallbackThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            Image(systemName: fallbackSystemImageName)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var fallbackSystemImageName: String {
        let fileExtension = URL(fileURLWithPath: item.displayName).pathExtension
        if let type = UTType(filenameExtension: fileExtension) {
            if type.conforms(to: .image) {
                return "photo"
            }

            if type.conforms(to: .movie) || type.conforms(to: .video) {
                return "video"
            }

            if type.conforms(to: .pdf) {
                return "doc.richtext"
            }
        }

        return "doc"
    }

    private func loadThumbnail() async {
        do {
            let fileDetailService = try FileDetailService()
            let fileURL = try fileDetailService.preparedDocument(for: item).url
            let scale = await MainActor.run { UIScreen.main.scale }
            let request = QLThumbnailGenerator.Request(
                fileAt: fileURL,
                size: CGSize(width: size * scale, height: size * scale),
                scale: scale,
                representationTypes: .thumbnail
            )

            let thumbnail = try await generateThumbnail(for: request)
            await MainActor.run {
                image = thumbnail
            }
        } catch {
            await MainActor.run {
                image = nil
            }
        }
    }

    private func generateThumbnail(for request: QLThumbnailGenerator.Request) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let representation else {
                    continuation.resume(throwing: ThumbnailError.unavailable)
                    return
                }

                continuation.resume(returning: representation.uiImage)
            }
        }
    }

    private enum ThumbnailError: Error {
        case unavailable
    }
}
