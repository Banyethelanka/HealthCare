import Foundation

@MainActor
final class HealthStore: ObservableObject {
    @Published var members: [FamilyMember] = []
    @Published var selectedMemberID: UUID?
    @Published var checkups: [CheckupReport] = []
    @Published var visits: [VisitRecord] = []

    private let saveURL = FileLibrary.documentsDirectory.appendingPathComponent("health-data.json")

    init() {
        load()
        if members.isEmpty {
            seedSampleData()
        }
    }

    var selectedMember: FamilyMember? {
        members.first { $0.id == selectedMemberID } ?? members.first
    }

    var selectedCheckups: [CheckupReport] {
        checkups
            .filter { $0.memberID == selectedMember?.id }
            .sorted { $0.checkupDate > $1.checkupDate }
    }

    var selectedVisits: [VisitRecord] {
        visits
            .filter { $0.memberID == selectedMember?.id }
            .sorted { $0.visitDate > $1.visitDate }
    }

    var hospitalOptions: [String] {
        uniqueOptions(from: visits.map(\.hospital))
    }

    var departmentOptions: [String] {
        uniqueOptions(from: visits.map(\.department))
    }

    func addMember(name: String) {
        // 随机颜色
        let colors = ["#6C5CE7", "#A9D6F5", "#D7E6FF", "#50C878", "#FF6B6B", "#1ABC9C"]
        let randomColor = colors.randomElement() ?? "#6C5CE7"
        let member = FamilyMember(name: name, avatarSystemName: "person.crop.circle.fill", tintHex: randomColor)
        members.append(member)
        selectedMemberID = member.id
        save()
    }

    func deleteMember(_ memberID: UUID) {
        members.removeAll { $0.id == memberID }
        checkups.removeAll { $0.memberID == memberID }
        visits.removeAll { $0.memberID == memberID }

        if selectedMemberID == memberID {
            selectedMemberID = members.first?.id
        }

        save()
    }

    func addCheckup(file: HealthFile) async {
        guard let memberID = selectedMember?.id else { return }
        let parsed = await AIParsingService.shared.parseCheckup(file: file)
        checkups.append(CheckupReport(memberID: memberID, hospital: parsed.hospital, checkupDate: parsed.checkupDate, file: file))
        save()
    }

    func updateCheckup(_ report: CheckupReport) {
        guard let index = checkups.firstIndex(where: { $0.id == report.id }) else { return }
        checkups[index] = report
        save()
    }

    func addVisit(_ visit: VisitRecord) {
        visits.append(visit)
        save()
    }

    func updateVisit(_ visit: VisitRecord) {
        guard let index = visits.firstIndex(where: { $0.id == visit.id }) else { return }
        visits[index] = visit
        save()
    }

    func addAttachment(to visitID: UUID, file: HealthFile, preferredCategory: VisitAttachmentCategory? = nil) async {
        guard let index = visits.firstIndex(where: { $0.id == visitID }) else { return }
        let parsed = await AIParsingService.shared.parseVisitAttachment(file: file)
        var updated = file
        updated.category = preferredCategory ?? parsed.category
        updated.examName = parsed.examName
        visits[index].attachments.append(updated)
        save()
    }

    func save() {
        let snapshot = HealthSnapshot(members: members, selectedMemberID: selectedMemberID, checkups: checkups, visits: visits)
        guard let data = try? JSONEncoder.appEncoder.encode(snapshot) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let snapshot = try? JSONDecoder.appDecoder.decode(HealthSnapshot.self, from: data)
        else { return }

        members = snapshot.members
        selectedMemberID = snapshot.selectedMemberID ?? snapshot.members.first?.id
        checkups = snapshot.checkups
        visits = snapshot.visits
    }

    private func seedSampleData() {
        writeSamplePDF(named: "sample-checkup.pdf", title: "体检报告示例")
        writeSamplePDF(named: "sample-visit.pdf", title: "门诊病历示例")
        writeSamplePDF(named: "sample-eeg.pdf", title: "常规脑电图报告示例")

        let liXi = FamilyMember(name: "李*汐", avatarSystemName: "person.crop.circle.fill", tintHex: "#625BFF")
        let liuXia = FamilyMember(name: "刘*霞", avatarSystemName: "person.crop.circle.fill", tintHex: "#A9D6F5")
        let liMin = FamilyMember(name: "李*民", avatarSystemName: "person.crop.circle.fill", tintHex: "#D7E6FF")

        members = [liXi, liuXia, liMin]
        selectedMemberID = liXi.id

        let checkupFile = HealthFile(
            originalName: "体检报告-光谷医院-2026.01.09.pdf",
            storedName: "sample-checkup.pdf",
            category: .checkupReport,
            examName: "体检报告"
        )
        checkups = [
            CheckupReport(memberID: liXi.id, hospital: "光谷医院", checkupDate: .appDate("2026.01.09"), file: checkupFile)
        ]

        visits = [
            VisitRecord(
                memberID: liXi.id,
                visitDate: .appDate("2026.04.22"),
                hospital: "华中科技大学同济医学院附属同济医院",
                department: "神经内科",
                registrationType: .expert,
                doctor: "晕厥初诊检查随访",
                reason: "头晕、短暂晕厥复查",
                attachments: [
                    HealthFile(originalName: "门诊病历.pdf", storedName: "sample-visit.pdf", category: .medicalRecord, examName: "门诊病历"),
                    HealthFile(originalName: "常规脑电图报告.pdf", storedName: "sample-eeg.pdf", category: .inspectionReport, examName: "常规脑电图/脑地形图")
                ]
            )
        ]

        save()
    }

    private func writeSamplePDF(named fileName: String, title: String) {
        let url = FileLibrary.documentsDirectory.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        let pdf = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 420] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
        endobj
        4 0 obj
        << /Length 64 >>
        stream
        BT /F1 18 Tf 40 330 Td (\(title)) Tj 0 -34 Td (HealthCare Demo File) Tj ET
        endstream
        endobj
        5 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000241 00000 n
        0000000355 00000 n
        trailer
        << /Root 1 0 R /Size 6 >>
        startxref
        425
        %%EOF
        """
        try? Data(pdf.utf8).write(to: url, options: .atomic)
    }

    private func uniqueOptions(from values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
    
    // 删除医院选项（从所有就诊记录中移除该医院，如果该医院存在）
        func deleteHospitalOption(_ hospital: String) {
            // 从所有就诊记录中移除该医院
            for index in visits.indices {
                if visits[index].hospital == hospital {
                    visits[index].hospital = ""
                }
            }
            save()
        }

        // 删除科室选项（从所有就诊记录中移除该科室，如果该科室存在）
        func deleteDepartmentOption(_ department: String) {
            // 从所有就诊记录中移除该科室
            for index in visits.indices {
                if visits[index].department == department {
                    visits[index].department = ""
                }
            }
            save()
        }
}

private struct HealthSnapshot: Codable {
    var members: [FamilyMember]
    var selectedMemberID: UUID?
    var checkups: [CheckupReport]
    var visits: [VisitRecord]
}

private extension JSONEncoder {
    static var appEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
