import SwiftUI
import CoreData

struct NoteFeedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = NoteViewModel()
    @State private var searchText = ""
    @State private var showingCreateNote = false
    @State private var selectedNote: Note?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>

    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { note in
                let searchLower = searchText.lowercased()

                // Search in note content
                if let content = note.content?.lowercased(), content.contains(searchLower) {
                    return true
                }

                // Search in extracted text (OCR from images)
                if let extractedText = note.extractedText?.lowercased(), extractedText.contains(searchLower) {
                    return true
                }

                // Search in attachments
                if let attachments = note.attachments as? Set<Attachment> {
                    for attachment in attachments {
                        // Search in attachment extracted text (OCR)
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
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if filteredNotes.isEmpty {
                    EmptyStateView(searchText: searchText)
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
            .navigationTitle("ThoughtStream")
            .searchable(text: $searchText, prompt: "Search notes, images, links...")
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

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "No thoughts yet" : "No results found")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ? "Tap the + button to capture your first thought" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    NoteFeedView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
