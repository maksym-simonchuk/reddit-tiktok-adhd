import AVKit
import SwiftUI

/// Полное превью ролика: видео зацикленно играет, под ним — метаданные, сохранение
/// в «Фото», шаринг и описание, которое можно забрать в буфер одной кнопкой.
struct ReelDetailView: View {

    let reel: Reel

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?
    @State private var isSaving = false
    @State private var isMuted = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.spacing * 2) {
                    VideoPlayer(player: player)
                        .frame(height: proxy.size.height * 0.62)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                        .overlay(alignment: .topTrailing) { playbackControls }

                    metadata
                    actions
                    description
                }
                .padding(Theme.spacing * 2)
            }
        }
        .background(Theme.background)
        .navigationTitle(Formatting.duration(reel.duration))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: reel.url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share video")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if reel.post != nil {
                        Button("Regenerate", systemImage: "arrow.clockwise") {
                            model.regenerate(reel)
                            dismiss()
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        model.delete(reel)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            // Зацикливаем: ролик короткий, и пересматривать его приходится подряд.
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: reel.url))
            player.play()
        }
        .onDisappear { player.pause() }
    }

    private var playbackControls: some View {
        HStack(spacing: Theme.spacing) {
            Button {
                isMuted.toggle()
                player.isMuted = isMuted
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(Theme.body(14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45), in: .circle)
            }
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            Button {
                player.seek(to: .zero)
                player.play()
            } label: {
                Image(systemName: "gobackward")
                    .font(Theme.body(14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45), in: .circle)
            }
            .accessibilityLabel("Restart")
        }
        .padding(Theme.spacing)
    }

    /// Что именно уедет на платформу: длительность, кадр и вес файла.
    private var metadata: some View {
        HStack(spacing: Theme.spacing * 2) {
            Label(Formatting.duration(reel.duration), systemImage: "timer")
            Label("1080×1920", systemImage: "aspectratio")
            Label(Formatting.fileSize(fileSize), systemImage: "internaldrive")
            Spacer()
        }
        .font(Theme.numeric(13))
        .foregroundStyle(Theme.secondaryText)
    }

    private var fileSize: Int64 {
        Int64((try? reel.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }

    private var actions: some View {
        HStack(spacing: Theme.spacing * 1.5) {
            Button {
                isSaving = true
                Task {
                    await model.saveToPhotos(reel)
                    isSaving = false
                }
            } label: {
                Label(isSaving ? "Saving" : "Save to Photos", systemImage: "square.and.arrow.down")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.minimumHitTarget)
                    .background(Theme.accent, in: .capsule)
            }
            .disabled(isSaving)

            Button {
                model.copyDescription(reel)
            } label: {
                Label("Description", systemImage: "doc.on.doc")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.minimumHitTarget)
                    .background(Theme.panel, in: .capsule)
                    .overlay { Capsule().strokeBorder(Theme.separator, lineWidth: 1) }
            }
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: Theme.spacing * 1.5) {
            Text(reel.description.title)
                .font(Theme.title(18))
                .foregroundStyle(Theme.primaryText)

            Text(reel.description.body)
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText)

            Text(reel.description.tags.map { "#" + $0 }.joined(separator: "  "))
                .font(Theme.body(14))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing * 2)
        .panel()
    }
}
