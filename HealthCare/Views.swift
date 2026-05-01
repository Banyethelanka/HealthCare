// Views.swift
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root View
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
        .tint(.accentColor)
    }
}

private enum AppTab {
    case checkups, visits, profile
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
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(store.selectedCheckups) { report in
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
                        MemberPicker()
                        TopActionRow(buttonTitle: "新增就诊记录", systemImage: "plus") {
                            showingNewVisit = true
                        }
                        if store.selectedVisits.isEmpty {
                            EmptyStateView(title: "还没有就诊记录", message: "手动填写就诊信息后，可继续上传病历、报告和影像资料。")
                        } else {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(store.selectedVisits) { visit in
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
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewVisit) {
            NavigationStack {
                VisitEditorView()
            }
        }
    }
}

// MARK: - 我的页面
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
                        
                        // 家庭成员管理
                        VStack(alignment: .leading, spacing: 8) {
                            Text("家庭成员管理")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    if index < store.members.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                        }
                        
                        // 新增成员
                        VStack(alignment: .leading, spacing: 8) {
                            Text("新增成员")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                        }
                        
                        // AI 解析接口
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI 解析接口")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("接口地址")
                                    Spacer()
                                    TextField("https://api.example.com/parse", text: $endpointText)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.URL)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().padding(.leading, 16)
                                
                                HStack(spacing: 12) {
                                    Text("API Key")
                                    Spacer()
                                    SecureField("输入 API Key", text: $apiKey)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().padding(.leading, 16)
                                
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
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
                Button {
                    previewURL = report.file.localURL
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.file.examName.isEmpty ? report.file.originalName : report.file.examName)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                            Text(report.file.originalName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
            DocumentPreviewSheet(url: url)
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
    @State private var showingDeleteHospitalAlert = false
    @State private var showingDeleteDepartmentAlert = false
    @State private var hospitalToDelete = ""
    @State private var departmentToDelete = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // 就诊信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text("就诊信息")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    
                    VStack(spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("就诊日期")
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Spacer(minLength: 12)
                            DatePicker("", selection: $visit.visitDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .font(.subheadline)
                        
                        InlineSelectRow(
                            title: "就诊医院",
                            value: $visit.hospital,
                            options: store.hospitalOptions,
                            placeholder: "请选择",
                            onAdd: {
                                draftHospital = ""
                                showingHospitalInput = true
                            },
                            onDelete: { option in
                                hospitalToDelete = option
                                showingDeleteHospitalAlert = true
                            }
                        )
                        
                        InlineSelectRow(
                            title: "科室",
                            value: $visit.department,
                            options: store.departmentOptions,
                            placeholder: "请选择",
                            onAdd: {
                                draftDepartment = ""
                                showingDepartmentInput = true
                            },
                            onDelete: { option in
                                departmentToDelete = option
                                showingDeleteDepartmentAlert = true
                            }
                        )
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("挂号类型")
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Spacer(minLength: 12)
                            Picker("", selection: $visit.registrationType) {
                                ForEach(RegistrationType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }
                        .font(.subheadline)
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("医生")
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Spacer(minLength: 12)
                            TextField("输入医生", text: $visit.doctor)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("就诊原因")
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Spacer(minLength: 12)
                            TextField("输入就诊原因", text: $visit.reason, axis: .vertical)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                    }
                    
                    HStack {
                        Spacer()
                        Color.clear.frame(height: 0)
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)

                // 附件卡片
                ForEach(VisitAttachmentCategory.allCases.filter { $0 != .checkupReport }, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(category.rawValue)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            GlassActionButton(title: parsing ? "解析中" : "上传", systemImage: "square.and.arrow.up") {
                                uploadCategory = category
                                importing = true
                            }
                            .disabled(parsing)
                        }
                        
                        let files = visit.attachments.filter { $0.category == category }
                        if files.isEmpty {
                            Text("还没有上传\(category.rawValue)资料")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(files) { file in
                                    Button {
                                        previewURL = file.localURL
                                    } label: {
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
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
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
        .alert("确认删除", isPresented: $showingDeleteHospitalAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                store.deleteHospitalOption(hospitalToDelete)
                if visit.hospital == hospitalToDelete {
                    visit.hospital = ""
                }
            }
        } message: {
            Text("确定要删除“\(hospitalToDelete)”吗？所有使用该医院的就诊记录将被清空。")
        }
        .alert("确认删除", isPresented: $showingDeleteDepartmentAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                store.deleteDepartmentOption(departmentToDelete)
                if visit.department == departmentToDelete {
                    visit.department = ""
                }
            }
        } message: {
            Text("确定要删除“\(departmentToDelete)”吗？所有使用该科室的就诊记录将被清空。")
        }
        .sheet(item: $previewURL) { url in
            QuickLookPreview(url: url)
        }
    }
}

// MARK: - 就诊编辑器
struct VisitEditorView: View {
    @EnvironmentObject private var store: HealthStore
    @Environment(\.dismiss) private var dismiss
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
                
                HStack {
                    Text("就诊医院")
                    Spacer()
                    Menu {
                        ForEach(store.hospitalOptions, id: \.self) { option in
                            Button(option) { hospital = option }
                        }
                        Divider()
                        Button(action: { showingHospitalInput = true }) {
                            Label("新增医院", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(hospital.isEmpty ? "选择医院" : hospital)
                                .foregroundStyle(hospital.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button(action: { showingHospitalInput = true }) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor.opacity(0.1), in: Circle())
                    }
                }
                
                HStack {
                    Text("科室")
                    Spacer()
                    Menu {
                        ForEach(store.departmentOptions, id: \.self) { option in
                            Button(option) { department = option }
                        }
                        Divider()
                        Button(action: { showingDepartmentInput = true }) {
                            Label("新增科室", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(department.isEmpty ? "选择科室" : department)
                                .foregroundStyle(department.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button(action: { showingDepartmentInput = true }) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor.opacity(0.1), in: Circle())
                    }
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
                        .background(
                            Group {
                                if store.selectedMemberID == member.id {
                                    Capsule().fill(Color.accentColor)
                                } else {
                                    Capsule().fill(Color(.tertiarySystemBackground))
                                }
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 2)
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

private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white)
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    }
                )
                .shadow(color: Color.black.opacity(0.08), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                .scaleEffect(isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

private struct CheckupCard: View {
    let report: CheckupReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 22)
                Text(DateFormatter.appDayFormatter.string(from: report.checkupDate))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
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

private struct VisitCard: View {
    let visit: VisitRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 22)
                Text(DateFormatter.appDayFormatter.string(from: visit.visitDate))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(visit.reason.isEmpty ? "未填写就诊原因" : visit.reason)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                
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

private struct AppScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
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

private struct InlineSelectRow: View {
    let title: String
    @Binding var value: String
    let options: [String]
    let placeholder: String
    let onAdd: () -> Void
    let onDelete: (String) -> Void
    
    @State private var showDeleteAlert = false
    @State private var optionToDelete = ""
    @State private var showOptionsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
                Spacer()
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button {
                            value = option
                        } label: {
                            HStack {
                                Text(option)
                                if value == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button(action: onAdd) {
                        Label("新增\(title)", systemImage: "plus")
                    }
                    Button(action: { showOptionsSheet = true }) {
                        Label("管理\(title)", systemImage: "pencil")
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
            }
        }
        .font(.subheadline)
        .sheet(isPresented: $showOptionsSheet) {
            NavigationStack {
                List {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    optionToDelete = option
                                    showDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                .navigationTitle("管理\(title)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showOptionsSheet = false }
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete(optionToDelete)
                if value == optionToDelete {
                    value = ""
                }
            }
        } message: {
            Text("确定要删除“\(optionToDelete)”吗？")
        }
    }
}

// MARK: - Extensions
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

extension Color {
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
