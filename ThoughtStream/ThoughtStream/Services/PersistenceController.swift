import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // App Group identifier - must match the one in entitlements
    static let appGroupIdentifier = "group.com.thoughtstream.app"

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ThoughtStream")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group shared container for data sharing with extensions
            if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PersistenceController.appGroupIdentifier) {
                let storeURL = appGroupURL.appendingPathComponent("ThoughtStream.sqlite")
                let description = NSPersistentStoreDescription(url: storeURL)
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [description]
            }
        }

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // Preview helper
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample notes for preview
        for i in 0..<5 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.content = "Sample thought #\(i + 1). This is a preview note to show how the app looks."
            newNote.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            newNote.updatedAt = newNote.createdAt
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()
}
