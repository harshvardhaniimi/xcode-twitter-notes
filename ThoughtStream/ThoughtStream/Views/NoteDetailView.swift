import SwiftUI
import QuickLook

struct NoteDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var note: Note

    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var selectedImageData: Data?
    @State private var showingImageViewer = false
    @State private var previewURL: URL?
    @State private var showingDeleteConfirmation = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Thought")
                                .font(.headline)

                            Text(formattedDate(note.createdAt ?? Date()))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Content
                    if isEditing {
                        TextField("Your thought...", text: $editedContent, axis: .vertical)
                            .font(.body)
                            .padding(.horizontal, 16)
                    } else {
                        if let content = note.content, !content.isEmpty {
                            Text(content)
                                .font(.body)
                                .padding(.horizontal, 16)
                        }
                    }

                    // Images
                    if !imageAttachments.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(imageAttachments, id: \.id) { attachment in
                                if let data = attachment.data, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(12)
                                        .onTapGesture {
                                            selectedImageData = data
                                            showingImageViewer = true
                                        }

                                    // Show extracted text if available
                                    if let extractedText = attachment.extractedText, !extractedText.isEmpty {
                                        DisclosureGroup("Extracted Text") {
                                            Text(extractedText)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // PDFs
                    if !pdfAttachments.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(pdfAttachments, id: \.id) { attachment in
                                Button(action: {
                                    openPDF(attachment)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.fill")
                                            .font(.title)
                                            .foregroundColor(.red)
                                            .frame(width: 50, height: 50)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(10)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(attachment.fileName ?? "PDF Document")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)

                                            Text("Tap to view")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                }

                                // Show extracted text if available
                                if let extractedText = attachment.extractedText, !extractedText.isEmpty {
                                    DisclosureGroup("Extracted Text") {
                                        Text(extractedText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Links
                    if !linkAttachments.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(linkAttachments, id: \.id) { attachment in
                                if let urlString = attachment.linkURL {
                                    Button(action: {
                                        if let url = URL(string: urlString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "link")
                                                .font(.title)
                                                .foregroundColor(.blue)
                                                .frame(width: 50, height: 50)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(10)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(URL(string: urlString)?.host ?? urlString)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)

                                                Text(urlString)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Image(systemName: "arrow.up.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if isEditing {
                            saveChanges()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            editedContent = note.content ?? ""
                            isEditing.toggle()
                        }) {
                            Label(isEditing ? "Cancel Edit" : "Edit", systemImage: isEditing ? "xmark" : "pencil")
                        }

                        if isEditing {
                            Button(action: saveChanges) {
                                Label("Save", systemImage: "checkmark")
                            }
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Thought?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteNote()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showingImageViewer) {
                if let data = selectedImageData, let image = UIImage(data: data) {
                    ImageViewerView(image: image)
                }
            }
            .quickLookPreview($previewURL)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saveChanges() {
        note.content = editedContent
        note.updatedAt = Date()

        do {
            try viewContext.save()
            isEditing = false
        } catch {
            print("Error saving changes: \(error)")
        }
    }

    private func deleteNote() {
        viewContext.delete(note)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting note: \(error)")
        }
    }

    private func openPDF(_ attachment: Attachment) {
        guard let data = attachment.data else { return }

        // Create a temporary file to preview
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = attachment.fileName ?? "document.pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            previewURL = fileURL
        } catch {
            print("Error writing PDF: \(error)")
        }
    }
}

struct ImageViewerView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, min(value, 4.0))
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale > 1.0 ? 1.0 : 2.0
                            }
                        }
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "This is a detailed thought that I want to save for later. It contains important information about my ideas and projects."
    note.createdAt = Date()

    return NoteDetailView(note: note)
        .environment(\.managedObjectContext, context)
}
