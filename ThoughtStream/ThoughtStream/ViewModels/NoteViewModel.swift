import Foundation
import CoreData
import SwiftUI

class NoteViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false

    func deleteNote(_ note: Note, context: NSManagedObjectContext) {
        context.delete(note)

        do {
            try context.save()
        } catch {
            print("Error deleting note: \(error)")
        }
    }

    func updateNote(_ note: Note, content: String, context: NSManagedObjectContext) {
        note.content = content
        note.updatedAt = Date()

        do {
            try context.save()
        } catch {
            print("Error updating note: \(error)")
        }
    }
}
