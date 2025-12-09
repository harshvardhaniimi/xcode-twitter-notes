# ThoughtStream

An offline, Twitter-like note-taking app for iOS where you can capture your thoughts, PDFs, links, images, and more - all organized beautifully.

## Features

- **Twitter-like Feed**: All your notes displayed in a familiar, scrollable feed
- **Rich Content Support**:
  - Text notes
  - Images (with OCR text extraction for searchability)
  - PDF documents (with text extraction)
  - Links with preview cards
- **Powerful Search**:
  - Keyword search across all content
  - OCR-powered search within images
  - Search through PDF text content
  - Search through link URLs
- **Completely Offline**: All data stored locally using Core Data
- **Native iOS**: Built with SwiftUI for the best iOS experience

## Screenshots

The app features:
- A main feed view showing all your thoughts chronologically
- A floating action button (bottom-right) to create new notes
- A search bar at the top to find content quickly
- Detail views for viewing and editing notes
- Full-screen image viewer with zoom support
- PDF preview using QuickLook

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone this repository
2. Open `ThoughtStream/ThoughtStream.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run (Cmd + R)

## Project Structure

```
ThoughtStream/
├── ThoughtStream.xcodeproj/
└── ThoughtStream/
    ├── ThoughtStreamApp.swift      # App entry point
    ├── ContentView.swift           # Root view
    ├── Views/
    │   ├── NoteFeedView.swift      # Main feed with search
    │   ├── NoteCardView.swift      # Individual note cards
    │   ├── CreateNoteView.swift    # Create new notes
    │   └── NoteDetailView.swift    # View/edit notes
    ├── ViewModels/
    │   └── NoteViewModel.swift     # Note operations
    ├── Services/
    │   ├── PersistenceController.swift  # Core Data setup
    │   └── OCRService.swift        # Text extraction (Vision/PDFKit)
    ├── Assets.xcassets/            # App icons and colors
    └── ThoughtStream.xcdatamodeld/ # Core Data model
```

## Data Model

### Note
- `id`: UUID
- `content`: String (note text)
- `extractedText`: String (combined OCR text for search)
- `createdAt`: Date
- `updatedAt`: Date
- `attachments`: [Attachment] (relationship)

### Attachment
- `id`: UUID
- `type`: String ("image", "pdf", "link")
- `data`: Binary (image/PDF data)
- `fileName`: String
- `linkURL`: String
- `extractedText`: String (OCR text)
- `createdAt`: Date

## Privacy

This app stores all data locally on your device. No data is sent to external servers. The app requires photo library access only when you choose to attach images to your notes.

## License

MIT License
