import SwiftUI

struct ContentView: View {
    var body: some View {
        NoteFeedView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
