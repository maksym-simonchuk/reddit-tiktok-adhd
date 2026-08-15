import AVKit
import SwiftUI

/// Полное превью ролика: видео зацикленно играет, под ним — сохранение в «Фото»
/// и описание, которое можно забрать в буфер одной кнопкой.
struct ReelDetailView: View {

    let reel: Reel

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?
    @State private var isSaving = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.spacing * 2) {
                    VideoPlayer(player: player)
                        .frame(height: proxy.size.height * 0.62)
                        .clipShape(.rect(cornerRadius: Theme.cornerRadius))

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
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    model.delete(reel)
                    dismiss()
                }
                .tint(Theme.danger)
            }
        }
        .onAppear {
            // Зацикливаем: ролик короткий, и пересматривать его приходится подряд.
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: reel.url))
            player.play()
        }
        .onDisappear { player.pause() }
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
                Label(isSaving ? "Сохраняю" : "В галерею", systemImage: "square.and.arrow.down")
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
                Label("Описание", systemImage: "doc.on.doc")
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
