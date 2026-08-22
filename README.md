# Motion Note iOS

Motion Note 是一个面向个人训练管理的 SwiftUI iOS App，支持训练计划、Apple 健康数据、语音训练辅助，以及通过安全中转连接飞书训练计划。

## 环境要求

- Xcode 26 或更高版本
- iOS 17 或更高版本
- 真机运行 HealthKit 功能时，需要可用的 Apple Developer Team

## 本地构建

1. 使用 Xcode 打开 `MotionNote.xcodeproj`。
2. 在 Signing & Capabilities 中选择自己的开发团队。
3. 选择模拟器或真机并运行 `MotionNote` scheme。

也可以在命令行执行：

```bash
xcodebuild \
  -project MotionNote.xcodeproj \
  -scheme MotionNote \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 飞书本机中转

`local-feishu/` 提供个人测试用的 OAuth 中转。App Secret 只通过终端隐藏输入进入本机进程，不应写入 App、Git 或网页。具体步骤见 [`local-feishu/README.md`](local-feishu/README.md)。

## 安全说明

- 仓库不包含飞书 App Secret、同步密钥或 OAuth Token。
- 本机 Xcode 用户状态、构建缓存和中转运行目录均被 `.gitignore` 排除。
- `FeishuService.swift` 中的 App ID 属于公开客户端配置；App Secret 必须留在服务端或本机中转进程。
