# 健康档案 iOS App

这是一个 SwiftUI iOS 工程，入口工程为 `HealthCare.xcodeproj`，最低部署版本 iOS 17，可在 Xcode 26 SDK 环境下编译。

## 已实现

- 家庭成员切换与新增
- 底部三栏：体检报告、就诊记录、我的
- 体检报告上传 PDF/图片，解析体检医院和体检日期，详情页可编辑、预览、导出
- 就诊记录手动填写：就诊时间、医院、科室、专家号/普通号、医生、就诊原因
- 就诊资料上传 PDF/图片，解析类别和检查名称
- 就诊详情按病例、报告、影像、其他分类展示原文件，支持预览和导出
- 本地 JSON 持久化，上传文件复制到 App Documents 目录

## AI 接口

在“我的”页填写接口地址和 API Key 后，App 会用 `POST` 请求发送：

```json
{
  "task": "parse_checkup 或 parse_visit_attachment",
  "fileName": "原文件名",
  "mimeHint": "pdf/jpg/png",
  "base64": "文件 base64"
}
```

体检解析期望返回：

```json
{ "hospital": "医院名称", "date": "2026.04.23" }
```

就诊资料解析期望返回：

```json
{ "category": "病例/报告/影像/其他", "examName": "检查名称" }
```

未配置接口时，会使用本地模拟解析，方便直接运行和调试。
