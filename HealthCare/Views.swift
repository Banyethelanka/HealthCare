import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @State private var selectedTab: AppTab = .checkups

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CheckupListView()
            }
            .tabItem { Label("体检报告", systemImage: "doc.text.magnifyingglass") }
            .tag(AppTab.checkups)

            NavigationStack {
                VisitListView()
            }
            .tabItem { Label("就诊记录", systemImage: "cross.case.fill") }
            .tag(AppTab.visits)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(.accentColor) // 使用系统原色
    }
}

private enum AppTab {
    case checkups
    case visits
    case profile
}
// MARK: - 体检报告列表
struct CheckupListView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var importing = false
    @State private var isParsing = false

    var body: some View {
        AppScreen {
            ScrollView {
                ContentColumn {
                    VStack(spacing: 18) {
                        HeaderView(title: "健康档案")
                        MemberPicker()
                        TopActionRow(buttonTitle: isParsing ? "解析中" : "上传体检报告", systemImage: "square.and.arrow.up") {
                            importing = true
                        }
                        if store.selectedCheckups.isEmpty {
                            EmptyStateView(title: "还没有体检报告", message: "上传 PDF 或图片")
                        } else {
                            MonthGroupedCheckups(reports: store.selectedCheckups)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarHidden(true)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            Task {
                guard let url = try? result.get().first else { return }
                isParsing = true
                defer { isParsing = false }
                if let file = try? FileLibrary.importFile(from: url, category: .checkupReport, examName: "体检报告") {
                    await store.addCheckup(file: file)
                }
            }
        }
    }
}
// MARK: - 就诊记录列表
struct VisitListView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var showingNewVisit = false

    var body: some View {
        AppScreen {
            ScrollView {
                ContentColumn {
                    VStack(spacing: 18) {
                        HeaderView(title: "健康档案")
                        MemberPicker() // 已移除加号，仅选择
                        HStack {
                            TopActionRow(buttonTitle: "新增就诊记录", systemImage: "plus") {
                                showingNewVisit = true
                            }
                            Spacer()
                        }
                        if store.selectedVisits.isEmpty {
                            EmptyStateView(title: "还没有就诊记录", message: "手动填写就诊信息后，可继续上传病历、报告和影像资料。")
                        } else {
                            MonthGroupedVisits(visits: store.selectedVisits)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewVisit) {
            NavigationStack {
                VisitEditorView(mode: .create)
            }
        }
    }
}
// MARK: - 我的页
struct ProfileView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var endpointText = ""
    @State private var apiKey = ""
    @State private var newMemberName = ""

    var body: some View {
        AppScreen {
            ScrollView {
                ContentColumn {
                    VStack(spacing: 18) {
                        HeaderView(title: "我的")
                        SettingsGroup(title: "家庭成员管理") {
                            VStack(spacing: 0) {
                                ForEach(store.members, id: \.id) { member in
                                    HStack(spacing: 12) {
                                        Button {
                                            store.selectedMemberID = member.id
                                            store.save()
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: member.avatarSystemName)
                                                    .font(.body)
                                                    .foregroundStyle(Color.accentColor)
                                                Text(member.name)
                                                    .foregroundStyle(Color.primary)
                                                Spacer()
                                                if store.selectedMemberID == member.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Color.accentColor)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        Button(role: .destructive) {
                                            store.deleteMember(member.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.red)
                                                .frame(width: 30, height: 30)
                                                .background(Color.red.opacity(0.1), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if member.id != store.members.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }

                        SettingsGroup(title: "新增成员") {
                            HStack(spacing: 12) {
                                TextField("输入成员姓名", text: $newMemberName)
                                    .textFieldStyle(.plain)
                                Button("添加") {
                                    let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    store.addMember(name: trimmed)
                                    newMemberName = ""
                                }
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        SettingsGroup(title: "AI 解析接口") {
                            VStack(alignment: .leading, spacing: 0) {
                                SettingsFieldRow(title: "接口地址") {
                                    TextField("https://api.example.com/parse", text: $endpointText)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.URL)
                                        .multilineTextAlignment(.trailing)
                                }
                                Divider()
                                SettingsFieldRow(title: "API Key") {
                                    SecureField("输入 API Key", text: $apiKey)
                                        .multilineTextAlignment(.trailing)
                                }
                                Divider()
                                Button {
                                    AIParsingService.shared.endpoint = URL(string: endpointText)
                                    AIParsingService.shared.apiKey = apiKey
                                } label: {
                                    HStack {
                                        Text("保存配置")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                        }

                        Text("接口返回体检 { hospital, date }；就诊资料 { category, examName }。未配置时使用本地模拟解析。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarHidden(true)
        .onAppear {
            endpointText = AIParsingService.shared.endpoint?.absoluteString ?? ""
            apiKey = AIParsingService.shared.apiKey ?? ""
        }
    }
}
// MARK: - 体检详情页
struct CheckupDetailView: View {
    @EnvironmentObject private var store: HealthStore
    @Environment(\.dismiss) private var dismiss
    @State var report: CheckupReport
    @State private var previewURL: URL?

    var body: some View {
        Form {
            Section("体检信息") {
                TextField("体检医院", text: $report.hospital)
                DatePicker("体检日期", selection: $report.checkupDate, displayedComponents: .date)
            }
            Section("原始文件") {
                FileRow(file: report.file) {
                    previewURL = report.file.localURL
                }
                ShareLink(item: report.file.localURL) {
                    Label("保存或导出原文件", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("体检详情")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.updateCheckup(report)
                    dismiss()
                }
            }
        }
        .sheet(item: $previewURL) { url in
            QuickLookPreview(url: url)
        }
    }
}

// MARK: - 就诊详情页
struct VisitDetailView: View {
    @EnvironmentObject private var store: HealthStore
    @Environment(\.dismiss) private var dismiss
    @State var visit: VisitRecord
    @State private var importing = false
    @State private var previewURL: URL?
    @State private var parsing = false
    @State private var uploadCategory: VisitAttachmentCategory?
    @State private var showingHospitalInput = false
    @State private var showingDepartmentInput = false
    @State private var draftHospital = ""
    @State private var draftDepartment = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // 就诊信息卡片
                DetailInfoCard(title: "就诊信息") {
                    VStack(spacing: 14) {
                        InlineValueRow(title: "就诊日期") {
                            DatePicker("", selection: $visit.visitDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        // 医院：单选 + 加号新增
                        InlineSingleSelectRow(
                            title: "就诊医院",
                            value: $visit.hospital,
                            options: store.hospitalOptions,
                            placeholder: "请选择"
                        ) {
                            draftHospital = ""
                            showingHospitalInput = true
                        }
                        
                        // 科室：单选 + 加号新增
                        InlineSingleSelectRow(
                            title: "科室",
                            value: $visit.department,
                            options: store.departmentOptions,
                            placeholder: "请选择"
                        ) {
                            draftDepartment = ""
                            showingDepartmentInput = true
                        }
                        
                        InlinePickerRow(title: "挂号类型", selection: $visit.registrationType, options: RegistrationType.allCases)
                        InlineTextFieldRow(title: "医生", text: $visit.doctor, placeholder: "输入医生")
                        InlineTextFieldRow(title: "就诊原因", text: $visit.reason, placeholder: "输入就诊原因", axis: .vertical)
                    }
                } trailingBottom: {
                    Color.clear.frame(height: 0)
                }

                // 每个资料分类右上角独立上传按钮
                ForEach(VisitAttachmentCategory.allCases.filter { $0 != .checkupReport }, id: \.self) { category in
                    AttachmentGroupCard(
                        title: category.rawValue,
                        files: visit.attachments.filter { $0.category == category },
                        parsing: parsing,
                        onUpload: {
                            uploadCategory = category
                            importing = true
                        },
                        onPreview: { file in
                            previewURL = file.localURL
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("就诊详情")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.updateVisit(visit)
                    dismiss()
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            Task {
                parsing = true
                defer { parsing = false }
                guard let urls = try? result.get() else { return }
                for url in urls {
                    if let file = try? FileLibrary.importFile(from: url, category: .other) {
                        await store.addAttachment(to: visit.id, file: file, preferredCategory: uploadCategory)
                    }
                }
                if let fresh = store.visits.first(where: { $0.id == visit.id }) {
                    visit = fresh
                }
            }
        }
        .alert("新增医院", isPresented: $showingHospitalInput) {
            TextField("输入医院名称", text: $draftHospital)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let trimmed = draftHospital.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    visit.hospital = trimmed
                }
            }
        }
        .alert("新增科室", isPresented: $showingDepartmentInput) {
            TextField("输入科室名称", text: $draftDepartment)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let trimmed = draftDepartment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    visit.department = trimmed
                }
            }
        }
        .sheet(item: $previewURL) { url in
            QuickLookPreview(url: url)
        }
    }
}
// MARK: - 就诊详情页信息编辑
struct VisitEditorView: View {
    enum Mode {
        case create
    }

    @EnvironmentObject private var store: HealthStore
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State private var visitDate = Date()
    @State private var hospital = ""
    @State private var department = ""
    @State private var registrationType: RegistrationType = .expert
    @State private var doctor = ""
    @State private var reason = ""
    @State private var showingHospitalInput = false
    @State private var showingDepartmentInput = false
    @State private var draftHospital = ""
    @State private var draftDepartment = ""

    var body: some View {
        Form {
            Section("就诊信息") {
                DatePicker("就诊时间", selection: $visitDate, displayedComponents: .date)
                PickerSelectionField(title: "就诊医院", value: $hospital, options: store.hospitalOptions, placeholder: "选择医院") {
                    draftHospital = hospital
                    showingHospitalInput = true
                }
                PickerSelectionField(title: "科室", value: $department, options: store.departmentOptions, placeholder: "选择科室") {
                    draftDepartment = department
                    showingDepartmentInput = true
                }
                Picker("挂号类型", selection: $registrationType) {
                    ForEach(RegistrationType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                TextField("医生", text: $doctor)
                TextField("就诊原因", text: $reason, axis: .vertical)
            }
        }
        .navigationTitle("新增就诊")
        .alert("新增医院", isPresented: $showingHospitalInput) {
            TextField("输入医院名称", text: $draftHospital)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let trimmed = draftHospital.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    hospital = trimmed
                }
            }
        }
        .alert("新增科室", isPresented: $showingDepartmentInput) {
            TextField("输入科室名称", text: $draftDepartment)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let trimmed = draftDepartment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    department = trimmed
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard let memberID = store.selectedMember?.id else { return }
                    let visit = VisitRecord(
                        memberID: memberID,
                        visitDate: visitDate,
                        hospital: hospital,
                        department: department,
                        registrationType: registrationType,
                        doctor: doctor,
                        reason: reason
                    )
                    store.addVisit(visit)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 公共组件
private struct HeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .padding(.top, 6)
    }
}

// // MARK: - 成员选择器
private struct MemberPicker: View {
    @EnvironmentObject private var store: HealthStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.members, id: \.id) { member in
                    Button {
                        store.selectedMemberID = member.id
                        store.save()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: member.avatarSystemName)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(store.selectedMemberID == member.id ? .white : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(memberBackground(member))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func memberBackground(_ member: FamilyMember) -> some View {
        if store.selectedMemberID == member.id {
            Capsule().fill(Color.accentColor)
        } else {
            Capsule().fill(Color(.tertiarySystemBackground))
        }
    }
}

private struct TopActionRow: View {
    let buttonTitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            GlassActionButton(title: buttonTitle, systemImage: systemImage, action: action)
        }
    }
}

// 半透明毛玻璃按钮
private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// 日期高亮样式
private struct AccentDateLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 4, height: 22)
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DetailInfoCard<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let trailingBottom: Footer

    init(title: String, @ViewBuilder content: () -> Content, @ViewBuilder trailingBottom: () -> Footer) {
        self.title = title
        self.content = content()
        self.trailingBottom = trailingBottom()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.primary)
            content
            HStack {
                Spacer()
                trailingBottom
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 资料卡片：右上角上传按钮
private struct AttachmentGroupCard: View {
    let title: String
    let files: [HealthFile]
    let parsing: Bool
    let onUpload: () -> Void
    let onPreview: (HealthFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                GlassActionButton(title: parsing ? "解析中" : "上传", systemImage: "square.and.arrow.up", action: onUpload)
                    .disabled(parsing)
            }

            if files.isEmpty {
                Text("还没有上传\(title)资料")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(files) { file in
                        FileRow(file: file) {
                            onPreview(file)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

private struct PickerSelectionField: View {
    let title: String
    @Binding var value: String
    let options: [String]
    let placeholder: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { value = option }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(value.isEmpty ? placeholder : value)
                        .foregroundStyle(value.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(options.isEmpty)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// 单选选择器（就诊详情专用）
private struct InlineSingleSelectRow: View {
    let title: String
    @Binding var value: String
    let options: [String]
    let placeholder: String
    let onAdd: () -> Void

    var body: some View {
        InlineValueRow(title: title) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) { value = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(value.isEmpty ? placeholder : value)
                            .foregroundColor(value.isEmpty ? .secondary : .accentColor)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor.opacity(0.1)))
                }
            }
        }
    }
}

private struct InlineValueRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 12)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct InlineTextFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var axis: Axis = .horizontal

    var body: some View {
        InlineValueRow(title: title) {
            TextField(placeholder, text: $text, axis: axis)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct InlinePickerRow<Option: CaseIterable & Identifiable & Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        InlineValueRow(title: title) {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
}

private struct SettingsFieldRow<Content: View>: View {
    let title: String
    @ViewBuilder let trailing: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Color.primary)
            Spacer()
            trailing
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }
}

private struct AppScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ContentColumn<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > 500

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: isWide ? 430 : .infinity, alignment: .top)
                    .padding(.horizontal, isWide ? 24 : 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(minHeight: proxy.size.height, alignment: .top)
        }
    }
}

private struct MonthGroupedCheckups: View {
    let reports: [CheckupReport]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(reports) { report in
                NavigationLink {
                    CheckupDetailView(report: report)
                } label: {
                    CheckupCard(report: report)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MonthGroupedVisits: View {
    let visits: [VisitRecord]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(visits) { visit in
                NavigationLink {
                    VisitDetailView(visit: visit)
                } label: {
                    VisitCard(visit: visit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// 体检卡片
private struct CheckupCard: View {
    let report: CheckupReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AccentDateLabel(text: DateFormatter.appDayFormatter.string(from: report.checkupDate))
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(report.file.examName.isEmpty ? "体检报告" : report.file.examName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("检测机构：\(report.hospital)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                FileBadge(kind: "PDF")
            }
            .padding(16)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)
        }
    }
}

// 就诊卡片（日期已美化）
private struct VisitCard: View {
    let visit: VisitRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AccentDateLabel(text: DateFormatter.appDayFormatter.string(from: visit.visitDate))
            VStack(alignment: .leading, spacing: 6) {
                // 就诊原因
                Text(visit.reason.isEmpty ? "未填写就诊原因" : visit.reason)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                
                // 新增：医院 + 科室 显示
                HStack(spacing: 8) {
                    Text(visit.hospital.isEmpty ? "未填写医院" : visit.hospital)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !visit.department.isEmpty {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(visit.department)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)
        }
    }
}

private struct FileRow: View {
    let file: HealthFile
    let onPreview: () -> Void

    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 12) {
                FileBadge(kind: file.localURL.pathExtension.uppercased().isEmpty ? "FILE" : file.localURL.pathExtension.uppercased())
                    .scaleEffect(0.78)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.examName.isEmpty ? file.originalName : file.examName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(file.originalName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: file.localURL) {
                Label("保存或导出", systemImage: "square.and.arrow.up")
            }
        }
    }
}

private struct FileBadge: View {
    let kind: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor)
                .frame(width: 58, height: 66)
            Text(kind)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(6)
        }
        .shadow(color: .accentColor.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(20)
    }
}

// 原生系统背景
private struct AppBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// 全局使用系统配色
extension Color {
    static let appBlue = Color.accentColor
    static let appNavy = Color.primary
    static let appPurple = Color.accentColor
    static let appBackground = Color(.systemGroupedBackground)

    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

// 未使用组件保留
private struct VisitSummaryEditor: View {
    @EnvironmentObject private var store: HealthStore
    @Binding var visit: VisitRecord
    let onSave: () -> Void

    var body: some View { EmptyView() }
}

private struct VisitCardRow: View {
    let label: String
    let value: String
    var lineLimit: Int = 1
    var body: some View { EmptyView() }
}

private struct OptionInputField: View {
    let title: String
    @Binding var text: String
    let options: [String]
    let placeholder: String
    var body: some View { EmptyView() }
}

private struct SectionShell<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content
    var body: some View { EmptyView() }
}

private struct InlineTextRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var axis: Axis = .horizontal
    var body: some View { EmptyView() }
}

private struct InlineDateRow: View {
    let title: String
    @Binding var date: Date
    var body: some View { EmptyView() }
}

private struct InlineOptionRow: View {
    let title: String
    @Binding var text: String
    let options: [String]
    let placeholder: String
    var body: some View { EmptyView() }
}

private struct InlineSelectRow: View {
    let title: String
    @Binding var value: String
    let options: [String]
    let placeholder: String
    let onAdd: () -> Void
    var body: some View { EmptyView() }
}
