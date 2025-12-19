import SwiftUI
import CoreData

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case notes = "Notes"
    case images = "Images"
    case pdfs = "PDFs"
    case links = "Links"
    case audio = "Audio"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .notes: return "note.text"
        case .images: return "photo"
        case .pdfs: return "doc.fill"
        case .links: return "link"
        case .audio: return "waveform"
        }
    }
}

struct NoteFeedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = NoteViewModel()
    @State private var searchText = ""
    @State private var showingCreateNote = false
    @State private var selectedNote: Note?
    @State private var selectedFilter: SearchFilter = .all
    @State private var isSearching = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>

    var filteredNotes: [Note] {
        var results = Array(notes)

        // First apply type filter
        if selectedFilter != .all {
            results = results.filter { note in
                guard let attachments = note.attachments as? Set<Attachment> else {
                    // If no attachments and filter is notes, include notes with content
                    return selectedFilter == .notes && (note.content?.isEmpty == false)
                }

                switch selectedFilter {
                case .all:
                    return true
                case .notes:
                    // Notes with text content (even if they have attachments)
                    return note.content?.isEmpty == false
                case .images:
                    return attachments.contains { $0.type == "image" }
                case .pdfs:
                    return attachments.contains { $0.type == "pdf" }
                case .links:
                    return attachments.contains { $0.type == "link" }
                case .audio:
                    return attachments.contains { $0.type == "audio" }
                }
            }
        }

        // Then apply text search
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            results = results.filter { note in
                // Search in note content
                if let content = note.content?.lowercased(), content.contains(searchLower) {
                    return true
                }

                // Search in extracted text (OCR from images, speech from audio)
                if let extractedText = note.extractedText?.lowercased(), extractedText.contains(searchLower) {
                    return true
                }

                // Search in attachments
                if let attachments = note.attachments as? Set<Attachment> {
                    for attachment in attachments {
                        // Search in attachment extracted text (OCR/transcription)
                        if let extractedText = attachment.extractedText?.lowercased(), extractedText.contains(searchLower) {
                            return true
                        }
                        // Search in link URLs
                        if let linkURL = attachment.linkURL?.lowercased(), linkURL.contains(searchLower) {
                            return true
                        }
                        // Search in file names
                        if let fileName = attachment.fileName?.lowercased(), fileName.contains(searchLower) {
                            return true
                        }
                    }
                }

                return false
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search filter tags - only show when search is active
                    if isSearching || !searchText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SearchFilter.allCases, id: \.self) { filter in
                                    FilterChip(
                                        filter: filter,
                                        isSelected: selectedFilter == filter,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedFilter = filter
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .background(Color(.systemBackground))

                        Divider()
                    }

                    if filteredNotes.isEmpty {
                        Spacer()
                        EmptyStateView(searchText: searchText, filter: selectedFilter)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredNotes, id: \.id) { note in
                                    NoteCardView(note: note)
                                        .onTapGesture {
                                            selectedNote = note
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteNote(note)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }

                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingCreateNote = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Your Thoughts")
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search notes, images, audio...")
            .onChange(of: isSearching) { oldValue, newValue in
                if !newValue {
                    // Reset filter when search is dismissed
                    selectedFilter = .all
                }
            }
            .sheet(isPresented: $showingCreateNote) {
                CreateNoteView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func deleteNote(_ note: Note) {
        withAnimation {
            viewContext.delete(note)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting note: \(error)")
            }
        }
    }
}

struct FilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct EmptyStateView: View {
    let searchText: String
    var filter: SearchFilter = .all

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var emptyStateIcon: String {
        if !searchText.isEmpty || filter != .all {
            return "magnifyingglass"
        }
        return "note.text"
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results found"
        }
        if filter != .all {
            return "No \(filter.rawValue.lowercased()) yet"
        }
        return "No thoughts yet"
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try a different search term or filter"
        }
        if filter != .all {
            return "Add some \(filter.rawValue.lowercased()) to see them here"
        }
        return "Tap the + button to capture your first thought"
    }
}

#Preview {
    NoteFeedView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
