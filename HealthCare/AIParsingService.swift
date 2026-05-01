import Foundation

final class AIParsingService {
    static let shared = AIParsingService()

    var endpoint: URL?
    var apiKey: String?

    private init() {}

    func parseCheckup(file: HealthFile) async -> CheckupParseResult {
        if let endpoint, let apiKey, !apiKey.isEmpty {
            if let result = try? await request(
                endpoint: endpoint,
                apiKey: apiKey,
                task: "parse_checkup",
                file: file,
                responseType: CheckupWireResult.self
            ) {
                return CheckupParseResult(
                    hospital: result.hospital,
                    checkupDate: DateFormatter.appDayFormatter.date(from: result.date) ?? Date()
                )
            }
        }

        return mockCheckupResult(from: file.originalName)
    }

    func parseVisitAttachment(file: HealthFile) async -> VisitFileParseResult {
        if let endpoint, let apiKey, !apiKey.isEmpty {
            if let result = try? await request(
                endpoint: endpoint,
                apiKey: apiKey,
                task: "parse_visit_attachment",
                file: file,
                responseType: VisitWireResult.self
            ) {
                return VisitFileParseResult(
                    category: VisitAttachmentCategory(rawValue: result.category) ?? .other,
                    examName: result.examName
                )
            }
        }

        return mockVisitResult(from: file.originalName)
    }

    private func request<T: Decodable>(
        endpoint: URL,
        apiKey: String,
        task: String,
        file: HealthFile,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try Data(contentsOf: file.localURL)
        let payload = AIRequestPayload(
            task: task,
            fileName: file.originalName,
            mimeHint: file.localURL.pathExtension,
            base64: data.base64EncodedString()
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    private func mockCheckupResult(from name: String) -> CheckupParseResult {
        CheckupParseResult(
            hospital: hospitalGuess(from: name),
            checkupDate: dateGuess(from: name) ?? Date()
        )
    }

    private func mockVisitResult(from name: String) -> VisitFileParseResult {
        let lower = name.lowercased()
        if lower.contains("ct") || lower.contains("mri") || lower.contains("影像") || lower.contains("片") {
            return VisitFileParseResult(category: .imaging, examName: examNameGuess(from: name, fallback: "影像资料"))
        }
        if lower.contains("报告") || lower.contains("检查") || lower.contains("检验") || lower.contains("超声") {
            return VisitFileParseResult(category: .inspectionReport, examName: examNameGuess(from: name, fallback: "检查报告"))
        }
        if lower.contains("病历") || lower.contains("病例") || lower.contains("门诊") {
            return VisitFileParseResult(category: .medicalRecord, examName: examNameGuess(from: name, fallback: "门诊病历"))
        }
        return VisitFileParseResult(category: .other, examName: examNameGuess(from: name, fallback: "就诊资料"))
    }

    private func hospitalGuess(from name: String) -> String {
        if name.contains("同济") { return "华中科技大学同济医学院附属同济医院" }
        if name.contains("协和") { return "协和医院" }
        if name.contains("光谷") { return "光谷医院" }
        if name.contains("中心") { return "市中心医院" }
        return "待确认医院"
    }

    private func dateGuess(from name: String) -> Date? {
        let patterns = [
            #"20\d{2}[.-]\d{1,2}[.-]\d{1,2}"#,
            #"20\d{6}"#
        ]

        for pattern in patterns {
            if let range = name.range(of: pattern, options: .regularExpression) {
                let raw = String(name[range])
                let normalized: String
                if raw.count == 8, raw.allSatisfy(\.isNumber) {
                    let year = raw.prefix(4)
                    let month = raw.dropFirst(4).prefix(2)
                    let day = raw.suffix(2)
                    normalized = "\(year).\(month).\(day)"
                } else {
                    normalized = raw.replacingOccurrences(of: "-", with: ".")
                }
                return DateFormatter.appDayFormatter.date(from: normalized)
            }
        }
        return nil
    }

    private func examNameGuess(from name: String, fallback: String) -> String {
        let base = (name as NSString).deletingPathExtension
        return base.isEmpty ? fallback : base
    }
}

private struct AIRequestPayload: Encodable {
    var task: String
    var fileName: String
    var mimeHint: String
    var base64: String
}

private struct CheckupWireResult: Decodable {
    var hospital: String
    var date: String
}

private struct VisitWireResult: Decodable {
    var category: String
    var examName: String
}
