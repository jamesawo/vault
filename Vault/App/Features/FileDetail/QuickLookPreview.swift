import AVKit
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

struct QuickLookPreview: View {
    let item: VaultItem
    let url: URL
    let playbackPosition: Double
    let onPlaybackPositionChange: (Double) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VaultItemPreviewContent(
                item: item,
                url: url,
                playbackPosition: playbackPosition,
                onPlaybackPositionChange: onPlaybackPositionChange
            )
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
        }
    }
}

struct VaultItemPreviewContent: View {
    let item: VaultItem
    let url: URL
    let playbackPosition: Double
    let onPlaybackPositionChange: (Double) -> Void

    private var isVideo: Bool {
        let fileExtension = url.pathExtension.isEmpty ? URL(fileURLWithPath: item.displayName).pathExtension : url.pathExtension
        guard let type = UTType(filenameExtension: fileExtension) else {
            return false
        }

        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    var body: some View {
        Group {
            if isVideo {
                VaultVideoPlayerView(
                    url: url,
                    initialPlaybackPosition: playbackPosition,
                    onPlaybackPositionChange: onPlaybackPositionChange
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                QuickLookPreviewContent(url: url)
            }
        }
    }
}

private struct VaultVideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    let initialPlaybackPosition: Double
    let onPlaybackPositionChange: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaybackPositionChange: onPlaybackPositionChange)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = context.coordinator.controller
        controller.player = context.coordinator.player
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        context.coordinator.configure(url: url, initialPlaybackPosition: initialPlaybackPosition)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onPlaybackPositionChange = onPlaybackPositionChange
        context.coordinator.configure(url: url, initialPlaybackPosition: initialPlaybackPosition)
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.capturePlaybackPosition()
        coordinator.cleanup()
    }

    final class Coordinator: NSObject {
        let controller = AVPlayerViewController()
        let player = AVPlayer()

        var onPlaybackPositionChange: (Double) -> Void

        private var currentURL: URL?
        private var timeObserver: Any?
        private var playbackEndObserver: NSObjectProtocol?

        init(onPlaybackPositionChange: @escaping (Double) -> Void) {
            self.onPlaybackPositionChange = onPlaybackPositionChange
        }

        func configure(url: URL, initialPlaybackPosition: Double) {
            guard currentURL != url else {
                return
            }

            currentURL = url

            removePlaybackEndObserver()

            let playerItem = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: playerItem)
            observePlaybackEnd(for: playerItem)
            seek(to: initialPlaybackPosition)
            ensureTimeObserver()
        }

        func cleanup() {
            player.pause()

            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }

            removePlaybackEndObserver()
        }

        func capturePlaybackPosition() {
            let currentTime = player.currentTime().seconds

            guard currentTime.isFinite else {
                return
            }

            onPlaybackPositionChange(currentTime)
        }

        private func seek(to seconds: Double) {
            let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        private func ensureTimeObserver() {
            guard timeObserver == nil else {
                return
            }

            let interval = CMTime(seconds: 1, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                let seconds = time.seconds

                guard let self, seconds.isFinite else {
                    return
                }

                self.onPlaybackPositionChange(seconds)
            }
        }

        private func observePlaybackEnd(for item: AVPlayerItem) {
            playbackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.onPlaybackPositionChange(0)
            }
        }

        private func removePlaybackEndObserver() {
            if let playbackEndObserver {
                NotificationCenter.default.removeObserver(playbackEndObserver)
                self.playbackEndObserver = nil
            }
        }
    }
}
