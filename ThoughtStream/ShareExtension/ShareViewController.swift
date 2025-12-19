import UIKit
import Social
import UniformTypeIdentifiers
import CoreData
import CloudKit

class ShareViewController: UIViewController {
    private var sharedItems: [SharedItem] = []
    private var addedURLs: Set<String> = [] // Track URLs to prevent duplicates
    private let textView = UITextView()
    private let stackView = UIStackView()
    private let previewStackView = UIStackView()
    private var viewContext: NSManagedObjectContext?

    struct SharedItem {
        enum ItemType {
            case text(String)
            case url(URL)
            case image(UIImage)
            case data(Data, String) // data and filename
        }
        let type: ItemType
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCoreData()
        processSharedItems()
    }

    private func setupCoreData() {
        // Set up Core Data with App Group for shared container and CloudKit sync
        let container = NSPersistentCloudKitContainer(name: "ThoughtStream")

        // Use App Group shared container
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.thoughtstream.app") {
            let storeURL = appGroupURL.appendingPathComponent("ThoughtStream.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)

            // Enable CloudKit sync
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.thoughtstream.app"
            )
            description.cloudKitContainerOptions = cloudKitOptions

            // Enable history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext = container.viewContext
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Navigation bar
        let navBar = UINavigationBar(frame: .zero)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        let navItem = UINavigationItem(title: "Add to ThoughtStream")
        navItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navItem.rightBarButtonItem = UIBarButtonItem(title: "Post", style: .done, target: self, action: #selector(postTapped))

        navBar.setItems([navItem], animated: false)
        view.addSubview(navBar)

        // Main stack view
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        // Text view for notes
        textView.font = .systemFont(ofSize: 16)
        textView.placeholder = "Add a note..."
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(textView)

        // Preview stack for shared content
        previewStackView.axis = .vertical
        previewStackView.spacing = 8
        previewStackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(previewStackView)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        let group = DispatchGroup()

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                        if let url = item as? URL {
                            let urlString = url.absoluteString
                            DispatchQueue.main.async {
                                // Only add if we haven't seen this URL before
                                if self?.addedURLs.contains(urlString) == false {
                                    self?.addedURLs.insert(urlString)
                                    self?.sharedItems.append(SharedItem(type: .url(url)))
                                    self?.addURLPreview(url)
                                }
                            }
                        }
                        group.leave()
                    }
                }
                // Handle plain text
                else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                        if let text = item as? String {
                            DispatchQueue.main.async {
                                // Check if this text is a URL that we've already captured
                                if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                                   (url.scheme == "http" || url.scheme == "https"),
                                   self?.addedURLs.contains(url.absoluteString) == true {
                                    // Skip - this URL was already added
                                } else {
                                    self?.sharedItems.append(SharedItem(type: .text(text)))
                                    self?.textView.text = text
                                }
                            }
                        }
                        group.leave()
                    }
                }
                // Handle images
                else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                        var image: UIImage?
                        if let imageData = item as? Data {
                            image = UIImage(data: imageData)
                        } else if let imageURL = item as? URL {
                            if let data = try? Data(contentsOf: imageURL) {
                                image = UIImage(data: data)
                            }
                        } else if let uiImage = item as? UIImage {
                            image = uiImage
                        }

                        if let image = image {
                            DispatchQueue.main.async {
                                self?.sharedItems.append(SharedItem(type: .image(image)))
                                self?.addImagePreview(image)
                            }
                        }
                        group.leave()
                    }
                }
                // Handle PDFs
                else if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] item, _ in
                        if let url = item as? URL, let data = try? Data(contentsOf: url) {
                            DispatchQueue.main.async {
                                self?.sharedItems.append(SharedItem(type: .data(data, url.lastPathComponent)))
                                self?.addPDFPreview(url.lastPathComponent)
                            }
                        }
                        group.leave()
                    }
                }
            }
        }
    }

    private func addURLPreview(_ url: URL) {
        let label = UILabel()
        label.text = "🔗 \(url.absoluteString)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        previewStackView.addArrangedSubview(label)
    }

    private func addImagePreview(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        previewStackView.addArrangedSubview(imageView)
    }

    private func addPDFPreview(_ filename: String) {
        let label = UILabel()
        label.text = "📄 \(filename)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        previewStackView.addArrangedSubview(label)
    }

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func postTapped() {
        guard let context = viewContext else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
        note.setValue(UUID(), forKey: "id")
        note.setValue(textView.text, forKey: "content")
        note.setValue(Date(), forKey: "createdAt")
        note.setValue(Date(), forKey: "updatedAt")

        // Add attachments
        for item in sharedItems {
            switch item.type {
            case .text(let text):
                // Text goes into note content, not as an attachment
                if textView.text.isEmpty {
                    note.setValue(text, forKey: "content")
                }
            case .url(let url):
                let attachment = NSEntityDescription.insertNewObject(forEntityName: "Attachment", into: context)
                attachment.setValue(UUID(), forKey: "id")
                attachment.setValue(Date(), forKey: "createdAt")
                attachment.setValue(note, forKey: "note")
                attachment.setValue("link", forKey: "type")
                attachment.setValue(url.absoluteString, forKey: "linkURL")
            case .image(let image):
                let attachment = NSEntityDescription.insertNewObject(forEntityName: "Attachment", into: context)
                attachment.setValue(UUID(), forKey: "id")
                attachment.setValue(Date(), forKey: "createdAt")
                attachment.setValue(note, forKey: "note")
                attachment.setValue("image", forKey: "type")
                attachment.setValue(image.jpegData(compressionQuality: 0.8), forKey: "data")
            case .data(let data, let filename):
                let attachment = NSEntityDescription.insertNewObject(forEntityName: "Attachment", into: context)
                attachment.setValue(UUID(), forKey: "id")
                attachment.setValue(Date(), forKey: "createdAt")
                attachment.setValue(note, forKey: "note")
                attachment.setValue("pdf", forKey: "type")
                attachment.setValue(data, forKey: "data")
                attachment.setValue(filename, forKey: "fileName")
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to save: \(error)")
        }

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// UITextView placeholder extension
extension UITextView {
    var placeholder: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.placeholder) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.placeholder, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setupPlaceholder()
        }
    }

    private struct AssociatedKeys {
        static var placeholder = "placeholder"
        static var placeholderLabel = "placeholderLabel"
    }

    private var placeholderLabel: UILabel? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.placeholderLabel) as? UILabel
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.placeholderLabel, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func setupPlaceholder() {
        if placeholderLabel == nil {
            let label = UILabel()
            label.textColor = .placeholderText
            label.font = font
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: topAnchor, constant: textContainerInset.top),
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainerInset.left + 4),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -textContainerInset.right)
            ])

            placeholderLabel = label

            NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: self)
        }

        placeholderLabel?.text = placeholder
        placeholderLabel?.isHidden = !text.isEmpty
    }

    @objc private func textDidChange() {
        placeholderLabel?.isHidden = !text.isEmpty
    }
}
