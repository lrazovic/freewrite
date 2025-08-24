import AppKit
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class EntryManager: ObservableObject {
    @Published var entries: [HumanEntry] = []
    @Published var selectedEntryId: UUID? = nil
    @Published var text: String = ""

    private var debounceTimer: Timer?
    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    init() {
        let directory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Freewrite")

        // Create Freewrite directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                print("Successfully created Freewrite directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        self.documentsDirectory = directory
        loadExistingEntries()
    }

    func saveEntry(entry: HumanEntry) {
        Task.detached {
            await self.saveEntryAsync(entry: entry)
        }
    }

    func debouncedSave(entry: HumanEntry) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: false
        ) { _ in
            Task.detached {
                await self.saveEntryAsync(entry: entry)
            }
        }
    }

    func saveEntryAsync(entry: HumanEntry) async {
        let textToSave = await MainActor.run { text }

        do {
            // Perform file I/O on background thread
            try textToSave.write(
                to: entry.fileURL,
                atomically: true,
                encoding: .utf8
            )
            print("Successfully saved entry: \(entry.filename)")

            // Generate preview on background thread
            let preview =
                textToSave
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated =
                preview.isEmpty
                ? ""
                : (preview.count > 30
                    ? String(preview.prefix(30)) + "..." : preview)

            // Update UI on main thread
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entry.id })
                {
                    entries[index].previewText = truncated
                }
            }
        } catch {
            print("Error saving entry: \(error)")
        }
    }

    func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }

    func loadExistingEntries() {
        print("Looking for entries in: \(documentsDirectory.path)")

        do {
            // Load file metadata including modification dates
            let resourceKeys: [URLResourceKey] = [
                .contentModificationDateKey, .fileSizeKey,
            ]
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: resourceKeys
            )
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            print("Found \(mdFiles.count) .md files")

            // Process each file (metadata only)
            let entriesWithDates = mdFiles.compactMap {
                fileURL -> (entry: HumanEntry, date: Date)? in
                let filename = fileURL.lastPathComponent
                print("Processing metadata for: \(filename)")

                // Extract UUID and date from filename - pattern [uuid]-[yyyy-MM-dd-HH-mm-ss].md
                guard
                    let uuidMatch = filename.range(
                        of: #"\[(.*?)\]"#,
                        options: .regularExpression
                    ),
                    let dateMatch = filename.range(
                        of: #"\[(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})\]"#,
                        options: .regularExpression
                    ),
                    let uuid = UUID(
                        uuidString: String(
                            filename[uuidMatch].dropFirst().dropLast()
                        )
                    )
                else {
                    print(
                        "Failed to extract UUID or date from filename: \(filename)"
                    )
                    return nil
                }

                // Get modification date from file system
                do {
                    let resourceValues = try fileURL.resourceValues(
                        forKeys: Set(resourceKeys)
                    )
                    let modificationDate =
                        resourceValues.contentModificationDate ?? Date()

                    // Parse the date string for display
                    let dateString = String(
                        filename[dateMatch].dropFirst().dropLast()
                    )
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

                    guard let fileDate = dateFormatter.date(from: dateString)
                    else {
                        print("Failed to parse date from filename: \(filename)")
                        return nil
                    }

                    // Format display date
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)

                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            fileURL: fileURL,
                            modificationDate: modificationDate,
                            previewText: nil  // Will be loaded lazily
                        ),
                        date: fileDate
                    )
                } catch {
                    print("Error getting file metadata: \(error)")
                    return nil
                }
            }

            // Sort by modification date (most recent first)
            self.entries =
                entriesWithDates
                .sorted {
                    $0.entry.modificationDate > $1.entry.modificationDate
                }
                .map { $0.entry }

            print(
                "Successfully loaded metadata for \(self.entries.count) entries"
            )

            // Handle entry selection logic
            handleInitialEntrySelection()

        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }

    private func handleInitialEntrySelection() {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        // Check if there's a recent entry from today
        let todayEntry = self.entries.first { entry in
            let entryDayStart = calendar.startOfDay(for: entry.modificationDate)
            return calendar.isDate(entryDayStart, inSameDayAs: todayStart)
        }

        if self.entries.isEmpty {
            // First time user - create entry with welcome message
            print("First time user, creating welcome entry")
            createNewEntry()
        } else if let todayEntry = todayEntry {
            // Select today's entry
            self.selectedEntryId = todayEntry.id
            loadEntry(entry: todayEntry)
        } else {
            // No entry for today - create new entry
            print("No entry for today, creating new entry")
            createNewEntry()
        }
    }

    func loadEntry(entry: HumanEntry) {
        do {
            if fileManager.fileExists(atPath: entry.fileURL.path) {
                self.text = try String(
                    contentsOf: entry.fileURL,
                    encoding: .utf8
                )
                print("Successfully loaded entry: \(entry.filename)")
            }
        } catch {
            print("Error loading entry: \(error)")
        }
    }

    func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        self.entries.insert(newEntry, at: 0)  // Add to the beginning
        self.selectedEntryId = newEntry.id

        // If this is the first entry (entries was empty before adding this one)
        if self.entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(
                forResource: "default",
                withExtension: "md"
            ),
                let defaultMessage = try? String(
                    contentsOf: defaultMessageURL,
                    encoding: .utf8
                )
            {
                self.text = defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
        } else {
            // Regular new entry starts empty
            self.text = ""
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }

    func deleteEntry(entry: HumanEntry) {
        // Delete the file from the filesystem
        do {
            try fileManager.removeItem(at: entry.fileURL)
            print("Successfully deleted file: \(entry.filename)")

            // Remove the entry from the entries array
            if let index = self.entries.firstIndex(where: {
                $0.id == entry.id
            }) {
                self.entries.remove(at: index)

                // If the deleted entry was selected, select the first entry or create a new one
                if self.selectedEntryId == entry.id {
                    if let firstEntry = self.entries.first {
                        self.selectedEntryId = firstEntry.id
                        loadEntry(entry: firstEntry)
                    } else {
                        createNewEntry()
                    }
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }

    func loadPreviewText(for entry: HumanEntry) {
        // Don't load if already loading or loaded
        guard entry.previewText == nil && !entry.isPreviewLoading else {
            return
        }

        // Mark as loading
        if let index = self.entries.firstIndex(where: {
            $0.id == entry.id
        }) {
            self.entries[index].isPreviewLoading = true
        }

        // Load preview asynchronously
        Task.detached {
            do {
                let content = try String(
                    contentsOf: entry.fileURL,
                    encoding: .utf8
                )
                let preview =
                    content
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let truncated =
                    preview.isEmpty
                    ? ""
                    : (preview.count > 30
                        ? String(preview.prefix(30)) + "..." : preview)

                await MainActor.run {
                    // Find and update the entry in the entries array
                    if let index = self.entries.firstIndex(where: {
                        $0.id == entry.id
                    }) {
                        self.entries[index].previewText = truncated
                        self.entries[index].isPreviewLoading = false
                    }
                }
            } catch {
                print("Error loading preview text: \(error)")
                await MainActor.run {
                    if let index = self.entries.firstIndex(where: {
                        $0.id == entry.id
                    }) {
                        self.entries[index].previewText =
                            "Error loading preview"
                        self.entries[index].isPreviewLoading = false
                    }
                }
            }
        }
    }

    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String)
        -> String
    {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }

        // Split content into words, ignoring newlines and removing punctuation
        let words =
            trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(
                    in: CharacterSet(charactersIn: ",.!?;:'()[]{}<>")
                )
                .lowercased()
            }
            .filter { !$0.isEmpty }

        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }

        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }

        // Fallback to date if no words found
        return "Entry \(date)"
    }

    func exportEntryAsPDF(entry: HumanEntry, appearance: AppearanceSettings) {
        // First make sure the current entry is saved
        if self.selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }

        // Get entry content
        do {
            // Read the content of the entry
            let entryContent = try String(
                contentsOf: entry.fileURL,
                encoding: .utf8
            )

            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename =
                extractTitleFromContent(entryContent, date: entry.date) + ".pdf"

            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible

            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(
                    text: entryContent,
                    appearance: appearance
                ) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }

    private func createPDFFromText(text: String, appearance: AppearanceSettings)
        -> Data?
    {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0  // 11 x 72
        let margin: CGFloat = 72.0  // 1-inch margins

        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )

        // Create PDF data container
        let pdfData = NSMutableData()

        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        let font =
            NSFont(name: appearance.selectedFont, size: appearance.fontSize)
            ?? .systemFont(ofSize: appearance.fontSize)
        let defaultLineHeight = font.ascender - font.descender + font.leading
        paragraphStyle.lineSpacing =
            (appearance.fontSize * 1.5) - defaultLineHeight

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                red: 0.20,
                green: 0.20,
                blue: 0.20,
                alpha: 1.0
            ),
            .paragraphStyle: paragraphStyle,
        ]

        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create the attributed string with formatting
        let attributedString = NSAttributedString(
            string: trimmedText,
            attributes: textAttributes
        )

        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(
            attributedString
        )

        // Create a PDF context with the data consumer
        guard
            let pdfContext = CGContext(
                consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                mediaBox: nil,
                nil
            )
        else {
            print("Failed to create PDF context")
            return nil
        }

        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0

        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)

        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)

            // Fill the page with white background
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(
                CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            )

            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter,
                currentRange,
                framePath,
                nil
            )

            // Draw the text frame
            CTFrameDraw(frame, pdfContext)

            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)

            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length

            // Finish the page
            pdfContext.endPage()
            pageIndex += 1

            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }

        // Finalize the PDF document
        pdfContext.closePDF()

        return pdfData as Data
    }
}
