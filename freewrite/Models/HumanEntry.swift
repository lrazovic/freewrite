
import Foundation

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    let fileURL: URL
    let modificationDate: Date
    var previewText: String?  // nil means not loaded yet
    var isPreviewLoading: Bool = false

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Freewrite")
        let filename = "[\(id)]-[\(dateString)].md"

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: filename,
            fileURL: documentsDirectory.appendingPathComponent(filename),
            modificationDate: now,
            previewText: nil
        )
    }
}
