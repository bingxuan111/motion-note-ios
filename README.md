# Motion Note iOS

Motion Note 是一个面向个人训练管理的 Objective-C/UIKit iOS App，支持训练计划、Apple 健康数据、语音训练辅助，以及通过安全中转连接飞书训练计划。第三方依赖使用 CocoaPods 管理。

工程通过 CocoaPods 管理 `AFNetworking`、`Masonry` 和 `Mantle`：分别负责网络访问、UIKit 自动布局以及 JSON 模型的反序列化与序列化。

## 环境要求

- Xcode 26 或更高版本
- iOS 17 或更高版本
- CocoaPods 1.5.3 或更高版本（建议使用当前稳定版）
- 真机运行 HealthKit 功能时，需要可用的 Apple Developer Team

## 本地构建

1. 在工程根目录执行 `pod install`。
2. 使用 Xcode 打开 `MotionNote.xcworkspace`（不要打开 `.xcodeproj`）。
3. 在 Signing & Capabilities 中选择自己的开发团队。
4. 选择模拟器或真机并运行 `MotionNote` scheme。

也可以在命令行执行：

```bash
xcodebuild \
  -workspace MotionNote.xcworkspace \
  -scheme MotionNote \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 飞书本机中转

`local-feishu/` 提供个人测试用的 OAuth 中转。App Secret 只通过终端隐藏输入进入本机进程，不应写入 App、Git 或网页。具体步骤见 [`local-feishu/README.md`](local-feishu/README.md)。

## 训练档案 · 最近训练计划

「训练档案」直接使用 `RecordViewController.m` 中的 `IPAdress`、`apiLatestPlanAbstract` 和 `appSyncSecret` 请求 `GET /api/latest-plan/abstract`。AFNetworking 负责网络访问，Mantle 将响应反序列化为 `TrainPlanAbstractDataModel`。

服务端所在 Mac 的局域网 IP 发生变化时，在工程根目录执行以下脚本。脚本会自动获取当前 IPv4 地址，并将 `RecordViewController.m` 中的 `IPAdress` 更新为 `http://<本机IP>:3000`：

```bash
./scripts/update-local-ip.sh
```

页面以卡片展示训练日期、时长、全部训练前准备和训练后拉伸。计划标题是语音教练入口，点击后切换到语音教练页面；存在 `document_url` 时，下方另行显示原始训练文档入口，点击后推入独立的 WKWebView 页面。接口返回 JSON `null` 时显示暂无训练计划。

进入语音教练时会携带计划 `item_id` 和标题，先请求 `/api/latest-plan/pre_workout` 并以 `STEP 0 · 预热` 展示；之后每次点击“下一步”按序请求 `/api/latest-plan/train_item`。动作接口返回 404 或空数据后，自动请求 `/api/latest-plan/post_workout_stretch` 并进入“结束后拉伸”。三个阶段分别使用 `PrepareDataModel`、`TrainItemDataModel` 和 `PostDataModel`，展示内容可通过“听取语音指导”朗读。

运行摘要模型回归测试（先安装 Pods，无需服务端或模拟器）：`bash scripts/test-latest-plan-abstract-model.sh`。本地 IP 的 ATS 例外按 [Apple 的本地网络说明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking) 限定在回环及私有网段。

## 安全说明

- 仓库不包含飞书 App Secret、同步密钥或 OAuth Token。
- 本机 Xcode 用户状态、构建缓存和中转运行目录均被 `.gitignore` 排除。
- `FeishuService.m` 中的 App ID 属于公开客户端配置；App Secret 必须留在服务端或本机中转进程。
