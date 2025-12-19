import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct CreateNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteContent = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPDFs: [PDFData] = []
    @State private var links: [String] = []
    @State private var audioRecordings: [AudioData] = []
    @State private var newLinkText = ""
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    @State private var showingLinkInput = false
    @State private var isProcessingOCR = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    @State private var photosPickerItems: [PhotosPickerItem] = []

    struct PDFData: Identifiable {
        let id = UUID()
        let data: Data
        let fileName: String
    }

    struct AudioData: Identifiable {
        let id = UUID()
        let data: Data
        let duration: TimeInterval
        let fileName: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Text input
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                )

                            TextField("What's on your mind?", text: $noteContent, axis: .vertical)
                                .font(.body)
                                .lineLimit(1...20)
                                .autocorrectionDisabled(false)
                                .textInputAutocapitalization(.sentences)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Selected images preview
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedImages.indices, id: \.self) { index in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[index])
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipped()
                                                .cornerRadius(12)

                                            Button(action: {
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Audio recordings preview
                        if !audioRecordings.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(audioRecordings) { audio in
                                    HStack {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.purple)
                                        Text(formatDuration(audio.duration))
                                            .font(.subheadline)
                                        Spacer()
                                        Button(action: {
                                            audioRecordings.removeAll { $0.id == audio.id }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Recording indicator
                        if isRecording {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                Text("Recording: \(formatDuration(recordingDuration))")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Spacer()
                                Button("Stop") {
                                    stopRecording()
                                }
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }

                        // Selected PDFs preview
                        if !selectedPDFs.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(selectedPDFs) { pdf in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(.red)
                                        Text(pdf.fileName)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: {
                                            selectedPDFs.removeAll { $0.id == pdf.id }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Links preview
                        if !links.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(links.indices, id: \.self) { index in
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.blue)
                                        Text(links[index])
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: {
                                            links.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Link input field
                        if showingLinkInput {
                            HStack {
                                TextField("Enter URL", text: $newLinkText)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .keyboardType(.URL)

                                Button("Add") {
                                    addLink()
                                }
                                .disabled(newLinkText.isEmpty)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Divider()

                // Bottom toolbar
                HStack(spacing: 20) {
                    // Photo picker
                    PhotosPicker(selection: $photosPickerItems,
                                 maxSelectionCount: 4,
                                 matching: .images) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .onChange(of: photosPickerItems) { oldValue, newValue in
                        Task {
                            await loadImages(from: newValue)
                        }
                    }

                    // PDF picker
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Image(systemName: "doc.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    // Link button
                    Button(action: {
                        showingLinkInput.toggle()
                    }) {
                        Image(systemName: "link")
                            .font(.title3)
                            .foregroundColor(showingLinkInput ? .blue : .blue.opacity(0.7))
                    }

                    // Audio recording button
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundColor(isRecording ? .red : .blue)
                    }

                    Spacer()

                    if isProcessingOCR {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle("New Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                    .disabled(noteContent.isEmpty && selectedImages.isEmpty && selectedPDFs.isEmpty && links.isEmpty && audioRecordings.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                handlePDFSelection(result)
            }
        }
        .onDisappear {
            // Clean up recording if view is dismissed
            if isRecording {
                audioRecorder?.stop()
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            recordingURL = audioFilename
            isRecording = true
            recordingDuration = 0

            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingDuration += 1
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        if let url = recordingURL, let data = try? Data(contentsOf: url) {
            let audio = AudioData(data: data, duration: recordingDuration, fileName: url.lastPathComponent)
            audioRecordings.append(audio)
        }

        recordingURL = nil
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        selectedImages = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImages.append(image)
                }
            }
        }
    }

    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? Data(contentsOf: url) {
                    let pdf = PDFData(data: data, fileName: url.lastPathComponent)
                    selectedPDFs.append(pdf)
                }
            }
        case .failure(let error):
            print("Error selecting PDF: \(error)")
        }
    }

    private func addLink() {
        var urlString = newLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.isEmpty {
            // Add https:// if no scheme is present
            if !urlString.contains("://") {
                urlString = "https://\(urlString)"
            }
            links.append(urlString)
            newLinkText = ""
        }
    }

    private func saveNote() {
        isProcessingOCR = true

        Task {
            let note = Note(context: viewContext)
            note.id = UUID()
            note.content = noteContent
            note.createdAt = Date()
            note.updatedAt = Date()

            var allExtractedText: [String] = []

            // Save images and perform OCR
            for image in selectedImages {
                let attachment = Attachment(context: viewContext)
                attachment.id = UUID()
                attachment.type = "image"
                attachment.data = image.jpegData(compressionQuality: 0.8)
                attachment.createdAt = Date()
                attachment.note = note

                // Perform OCR on the image
                if let extractedText = await OCRService.shared.extractText(from: image) {
                    attachment.extractedText = extractedText
                    allExtractedText.append(extractedText)
                }
            }

            // Save PDFs
            for pdf in selectedPDFs {
                let attachment = Attachment(context: viewContext)
                attachment.id = UUID()
                attachment.type = "pdf"
                attachment.data = pdf.data
                attachment.fileName = pdf.fileName
                attachment.createdAt = Date()
                attachment.note = note

                // Extract text from PDF
                if let extractedText = OCRService.shared.extractText(from: pdf.data) {
                    attachment.extractedText = extractedText
                    allExtractedText.append(extractedText)
                }
            }

            // Save links
            for link in links {
                let attachment = Attachment(context: viewContext)
                attachment.id = UUID()
                attachment.type = "link"
                attachment.linkURL = link
                attachment.createdAt = Date()
                attachment.note = note
            }

            // Save audio recordings with speech-to-text
            for audio in audioRecordings {
                let attachment = Attachment(context: viewContext)
                attachment.id = UUID()
                attachment.type = "audio"
                attachment.data = audio.data
                attachment.fileName = audio.fileName
                attachment.createdAt = Date()
                attachment.note = note

                // Perform speech-to-text on audio
                if let transcription = await SpeechService.shared.transcribe(audioData: audio.data) {
                    attachment.extractedText = transcription
                    allExtractedText.append(transcription)
                }
            }

            // Store all extracted text in the note for easier searching
            note.extractedText = allExtractedText.joined(separator: " ")

            do {
                try viewContext.save()
                await MainActor.run {
                    isProcessingOCR = false
                    dismiss()
                }
            } catch {
                print("Error saving note: \(error)")
                await MainActor.run {
                    isProcessingOCR = false
                }
            }
        }
    }
}

#Preview {
    CreateNoteView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
