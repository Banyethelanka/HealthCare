import Foundation

struct FamilyMember: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var avatarSystemName: String
    var tintHex: String
}

struct HealthFile: Identifiable, Codable, Hashable {
    var id = UUID()
    var originalName: String
    var storedName: String
    var category: VisitAttachmentCategory
    var examName: String
    var uploadedAt = Date()

    var localURL: URL {
        FileLibrary.documentsDirectory.appendingPathComponent(storedName)
    }
}

struct CheckupReport: Identifiable, Codable, Hashable {
    var id = UUID()
    var memberID: UUID
    var hospital: String
    var checkupDate: Date
    var file: HealthFile
    var createdAt = Date()
}

struct VisitRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var memberID: UUID
    var visitDate: Date
    var hospital: String
    var department: String
    var registrationType: RegistrationType
    var doctor: String
    var reason: String
    var attachments: [HealthFile] = []
    var createdAt = Date()
}

enum RegistrationType: String, Codable, CaseIterable, Identifiable {
    case expert = "专家号"
    case normal = "普通号"

    var id: String { rawValue }
}

enum VisitAttachmentCategory: String, Codable, CaseIterable, Identifiable {
    case medicalRecord = "病例"
    case inspectionReport = "报告"
    case imaging = "影像"
    case checkupReport = "体检报告"
    case other = "其他"

    var id: String { rawValue }
}

struct CheckupParseResult: Codable {
    var hospital: String
    var checkupDate: Date
}

struct VisitFileParseResult: Codable {
    var category: VisitAttachmentCategory
    var examName: String
}

extension Date {
    static func appDate(_ value: String) -> Date {
        let formatter = DateFormatter.appDayFormatter
        return formatter.date(from: value) ?? Date()
    }
}

extension DateFormatter {
    static let appDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月"
        return formatter
    }()
}
