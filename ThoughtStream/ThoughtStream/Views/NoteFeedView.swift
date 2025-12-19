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

// MARK: - Date Filter

struct DateFilter: Equatable, Identifiable {
    let id = UUID()
    let displayText: String
    let year: Int?
    let month: Int?

    func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)

        if let year = year, let month = month {
            return components.year == year && components.month == month
        } else if let year = year {
            return components.year == year
        } else if let month = month {
            return components.month == month
        }
        return true
    }
}

class DateFilterParser {
    static let shared = DateFilterParser()

    private let monthNames: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]

    private let monthDisplayNames: [Int: String] = [
        1: "January", 2: "February", 3: "March", 4: "April",
        5: "May", 6: "June", 7: "July", 8: "August",
        9: "September", 10: "October", 11: "November", 12: "December"
    ]

    /// Parse search text and extract date filters
    /// Returns tuple of (remaining search text, detected date filters)
    func parse(_ searchText: String) -> (String, [DateFilter]) {
        var filters: [DateFilter] = []
        var remainingText = searchText
        let words = searchText.lowercased().components(separatedBy: .whitespaces)

        var i = 0
        while i < words.count {
            let word = words[i]

            // Check for year (4 digits between 1900-2100)
            if let year = Int(word), year >= 1900 && year <= 2100 {
                // Check if previous word was a month
                if i > 0, let month = monthNames[words[i-1]] {
                    // Month + Year combo (e.g., "June 2024")
                    let displayText = "\(monthDisplayNames[month]!) \(year)"
                    filters.append(DateFilter(displayText: displayText, year: year, month: month))
                    remainingText = removeWord(words[i-1], from: remainingText)
                    remainingText = removeWord(word, from: remainingText)
                }
                // Check if next word is a month
                else if i + 1 < words.count, let month = monthNames[words[i+1]] {
                    // Year + Month combo (e.g., "2024 June")
                    let displayText = "\(monthDisplayNames[month]!) \(year)"
                    filters.append(DateFilter(displayText: displayText, year: year, month: month))
                    remainingText = removeWord(word, from: remainingText)
                    remainingText = removeWord(words[i+1], from: remainingText)
                    i += 1 // Skip next word
                } else {
                    // Just year
                    filters.append(DateFilter(displayText: String(year), year: year, month: nil))
                    remainingText = removeWord(word, from: remainingText)
                }
            }
            // Check for month name alone
            else if let month = monthNames[word] {
                // Check if next word is a year
                if i + 1 < words.count, let year = Int(words[i+1]), year >= 1900 && year <= 2100 {
                    // Already handled above, skip
                    i += 1
                }
                // Check if previous word was a year (already handled above)
                else if i > 0, let year = Int(words[i-1]), year >= 1900 && year <= 2100 {
                    // Already handled above
                } else {
                    // Just month (applies to any year)
                    filters.append(DateFilter(displayText: monthDisplayNames[month]!, year: nil, month: month))
                    remainingText = removeWord(word, from: remainingText)
                }
            }

            i += 1
        }

        // Remove duplicate filters
        var seen = Set<String>()
        filters = filters.filter { filter in
            let key = "\(filter.year ?? 0)-\(filter.month ?? 0)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return (remainingText.trimmingCharacters(in: .whitespaces), filters)
    }

    private func removeWord(_ word: String, from text: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        return text
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
    @State private var activeDateFilters: [DateFilter] = []

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>

    private var parsedSearch: (text: String, dateFilters: [DateFilter]) {
        DateFilterParser.shared.parse(searchText)
    }

    private var detectedDateFilters: [DateFilter] {
        parsedSearch.dateFilters
    }

    private var remainingSearchText: String {
        parsedSearch.text
    }

    var filteredNotes: [Note] {
        var results = Array(notes)

        // Apply date filters
        if !activeDateFilters.isEmpty {
            results = results.filter { note in
                guard let createdAt = note.createdAt else { return false }
                return activeDateFilters.allSatisfy { $0.matches(date: createdAt) }
            }
        }

        // Apply type filter
        if selectedFilter != .all {
            results = results.filter { note in
                guard let attachments = note.attachments as? Set<Attachment> else {
                    return selectedFilter == .notes && (note.content?.isEmpty == false)
                }

                switch selectedFilter {
                case .all:
                    return true
                case .notes:
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

        // Apply text search (excluding date terms that became filters)
        let textToSearch = activeDateFilters.isEmpty ? searchText : remainingSearchText
        if !textToSearch.isEmpty {
            let searchLower = textToSearch.lowercased()
            results = results.filter { note in
                if let content = note.content?.lowercased(), content.contains(searchLower) {
                    return true
                }
                if let extractedText = note.extractedText?.lowercased(), extractedText.contains(searchLower) {
                    return true
                }
                if let attachments = note.attachments as? Set<Attachment> {
                    for attachment in attachments {
                        if let extractedText = attachment.extractedText?.lowercased(), extractedText.contains(searchLower) {
                            return true
                        }
                        if let linkURL = attachment.linkURL?.lowercased(), linkURL.contains(searchLower) {
                            return true
                        }
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
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter section - show when searching
                    if isSearching || !searchText.isEmpty {
                        VStack(spacing: 8) {
                            // Date filter chips (detected from search)
                            if !detectedDateFilters.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(detectedDateFilters) { dateFilter in
                                            DateFilterChip(
                                                dateFilter: dateFilter,
                                                isActive: activeDateFilters.contains(where: { $0.displayText == dateFilter.displayText }),
                                                onTap: {
                                                    toggleDateFilter(dateFilter)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                }
                            }

                            // Active date filters (already selected)
                            if !activeDateFilters.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(activeDateFilters) { dateFilter in
                                            ActiveDateFilterChip(
                                                dateFilter: dateFilter,
                                                onRemove: {
                                                    removeActiveDateFilter(dateFilter)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Type filter chips
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
                        }
                        .background(Color(.systemBackground))

                        Divider()
                    }

                    if filteredNotes.isEmpty {
                        Spacer()
                        EmptyStateView(
                            searchText: searchText,
                            filter: selectedFilter,
                            dateFilters: activeDateFilters
                        )
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
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search notes, dates (June 2024)...")
            .onChange(of: isSearching) { oldValue, newValue in
                if !newValue {
                    selectedFilter = .all
                    activeDateFilters = []
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

    private func toggleDateFilter(_ dateFilter: DateFilter) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = activeDateFilters.firstIndex(where: { $0.displayText == dateFilter.displayText }) {
                activeDateFilters.remove(at: index)
            } else {
                activeDateFilters.append(dateFilter)
            }
        }
    }

    private func removeActiveDateFilter(_ dateFilter: DateFilter) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeDateFilters.removeAll { $0.displayText == dateFilter.displayText }
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

// MARK: - Filter Chips

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

struct DateFilterChip: View {
    let dateFilter: DateFilter
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(dateFilter.displayText)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.orange : Color.orange.opacity(0.15))
            .foregroundColor(isActive ? .white : .orange)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange, lineWidth: isActive ? 0 : 1)
            )
        }
    }
}

struct ActiveDateFilterChip: View {
    let dateFilter: DateFilter
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption)
            Text(dateFilter.displayText)
                .font(.subheadline)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange)
        .foregroundColor(.white)
        .cornerRadius(16)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let searchText: String
    var filter: SearchFilter = .all
    var dateFilters: [DateFilter] = []

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
        if !searchText.isEmpty || filter != .all || !dateFilters.isEmpty {
            return "magnifyingglass"
        }
        return "note.text"
    }

    private var emptyStateTitle: String {
        if !dateFilters.isEmpty {
            let dateText = dateFilters.map { $0.displayText }.joined(separator: ", ")
            return "No thoughts from \(dateText)"
        }
        if !searchText.isEmpty {
            return "No results found"
        }
        if filter != .all {
            return "No \(filter.rawValue.lowercased()) yet"
        }
        return "No thoughts yet"
    }

    private var emptyStateMessage: String {
        if !dateFilters.isEmpty {
            return "Try a different date or remove the date filter"
        }
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
