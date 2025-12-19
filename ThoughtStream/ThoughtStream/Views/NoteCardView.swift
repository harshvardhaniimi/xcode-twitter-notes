import SwiftUI
import AVFoundation

struct NoteCardView: View {
    @ObservedObject var note: Note

    private var sortedAttachments: [Attachment] {
        guard let attachments = note.attachments as? Set<Attachment> else { return [] }
        return attachments.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }

    private var imageAttachments: [Attachment] {
        sortedAttachments.filter { $0.type == "image" }
    }

    private var pdfAttachments: [Attachment] {
        sortedAttachments.filter { $0.type == "pdf" }
    }

    private var linkAttachments: [Attachment] {
        sortedAttachments.filter { $0.type == "link" }
    }

    private var audioAttachments: [Attachment] {
        sortedAttachments.filter { $0.type == "audio" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with avatar and timestamp
            HStack(alignment: .top, spacing: 12) {
                // User avatar (using a generic icon since it's personal notes)
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("My Thought")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(timeAgo(from: note.createdAt ?? Date()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Note content
                    if let content = note.content, !content.isEmpty {
                        Text(content)
                            .font(.body)
                            .lineLimit(10)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Attachments section
                    if !imageAttachments.isEmpty {
                        ImageAttachmentsGrid(attachments: imageAttachments)
                            .padding(.top, 8)
                    }

                    if !audioAttachments.isEmpty {
                        AudioAttachmentsView(attachments: audioAttachments)
                            .padding(.top, 8)
                    }

                    if !pdfAttachments.isEmpty {
                        PDFAttachmentsView(attachments: pdfAttachments)
                            .padding(.top, 8)
                    }

                    if !linkAttachments.isEmpty {
                        LinkAttachmentsView(attachments: linkAttachments)
                            .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ImageAttachmentsGrid: View {
    let attachments: [Attachment]

    var body: some View {
        let columns = attachments.count == 1 ? 1 : 2
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)

        LazyVGrid(columns: gridItems, spacing: 4) {
            ForEach(attachments, id: \.id) { attachment in
                if let data = attachment.data, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: attachments.count == 1 ? 200 : 120)
                        .frame(maxHeight: attachments.count == 1 ? 300 : 150)
                        .clipped()
                        .cornerRadius(12)
                }
            }
        }
    }
}

struct AudioAttachmentsView: View {
    let attachments: [Attachment]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(attachments, id: \.id) { attachment in
                AudioPlayerCard(attachment: attachment)
            }
        }
    }
}

struct AudioPlayerCard: View {
    let attachment: Attachment
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Note")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let transcription = attachment.extractedText, !transcription.isEmpty {
                    Text(transcription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Audio Recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Waveform indicator
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.opacity(isPlaying ? 1 : 0.3))
                        .frame(width: 3, height: CGFloat.random(in: 8...20))
                        .animation(isPlaying ? .easeInOut(duration: 0.3).repeatForever() : .default, value: isPlaying)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onDisappear {
            audioPlayer?.stop()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            guard let data = attachment.data else { return }

            do {
                // Configure audio session to play through speaker (not earpiece)
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)

                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.delegate = AudioPlayerDelegate { [self] in
                    isPlaying = false
                }
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Failed to play audio: \(error)")
            }
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

struct PDFAttachmentsView: View {
    let attachments: [Attachment]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(attachments, id: \.id) { attachment in
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName ?? "PDF Document")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text("PDF Document")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

struct LinkAttachmentsView: View {
    let attachments: [Attachment]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(attachments, id: \.id) { attachment in
                if let urlString = attachment.linkURL {
                    LinkPreviewCard(urlString: urlString)
                }
            }
        }
    }
}

struct LinkPreviewCard: View {
    let urlString: String

    private var displayURL: String {
        if let url = URL(string: urlString),
           let host = url.host {
            return host
        }
        return urlString
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayURL)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(urlString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "This is a sample thought that shows how notes will appear in the feed. It can contain multiple lines and will be displayed nicely."
    note.createdAt = Date()

    return NoteCardView(note: note)
        .previewLayout(.sizeThatFits)
}
