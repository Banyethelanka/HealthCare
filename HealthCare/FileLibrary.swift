import Foundation

enum FileLibrary {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func importFile(from sourceURL: URL, category: VisitAttachmentCategory, examName: String = "") throws -> HealthFile {
        let securityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = sourceURL.pathExtension
        let storedName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let destination = documentsDirectory.appendingPathComponent(storedName)

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        return HealthFile(
            originalName: sourceURL.deletingPathExtension().lastPathComponent,
            storedName: storedName,
            category: category,
            examName: examName
        )
    }
}
