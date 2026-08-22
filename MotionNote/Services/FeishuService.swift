import Foundation
import SwiftUI
import UIKit

@MainActor
final class FeishuService: ObservableObject {
    /// App ID is public client configuration. The App Secret remains server-side.
    let appID = "cli_aaf6d50ac2f95be2"
    @Published private(set) var status = "尚未连接飞书"
    @Published var selectedDocumentURL = ""
    @AppStorage("feishuGatewayURL") var gatewayURL = ""
    @AppStorage("planSyncURL") var planSyncURL = ""
    @AppStorage("planSyncKey") var planSyncKey = ""

    var isPlanSyncConfigured: Bool {
        !planSyncURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !planSyncKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        NotificationCenter.default.addObserver(forName: .motionNoteFeishuCallback, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            Task { @MainActor in self?.handleCallback(url) }
        }
    }

    var authorizationURL: URL? {
        guard let gateway = normalizedGatewayURL else { return nil }
        // The local relay creates and validates OAuth state. The App Secret stays on the Mac.
        return URL(string: "\(gateway)/api/feishu/start")
    }

    private var normalizedGatewayURL: String? {
        let trimmed = gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else { return nil }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    func openAuthorization() {
        guard let authorizationURL else {
            status = "请先填入本机隧道的 HTTPS 地址"
            return
        }
        UIApplication.shared.open(authorizationURL)
        status = "已打开飞书授权页面"
    }

    func prepareImport() {
        guard selectedDocumentURL.contains("feishu") || selectedDocumentURL.contains("larksuite") else {
            status = "请输入有效的飞书文档链接"
            return
        }
        status = "文档链接已保存，完成服务端授权后即可自动导入"
    }

    func syncWeeklyPlans() async throws -> [ImportedPlan] {
        guard let baseURL = normalizedPlanSyncURL else {
            throw PlanSyncError.invalidURL
        }
        guard !planSyncKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanSyncError.missingKey
        }

        var request = URLRequest(url: baseURL.appending(path: "api/plans"))
        request.setValue(planSyncKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-MotionNote-Key")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlanSyncError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw PlanSyncError.serverStatus(http.statusCode) }
        let payload = try JSONDecoder.motionNote.decode(WeeklyPlansResponse.self, from: data)
        let plans = Array(payload.plans.suffix(2))
        guard !plans.isEmpty else { throw PlanSyncError.noPlan }
        return plans
    }

    private var normalizedPlanSyncURL: URL? {
        let trimmed = planSyncURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), components.scheme == "https", components.host != nil else { return nil }
        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = existingPath.isEmpty ? "" : "/\(existingPath)"
        return components.url
    }

    private func handleCallback(_ url: URL) {
        guard url.scheme == "motionnote", url.host == "feishu-connected" else { return }
        let success = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "success" })?.value == "1"
        status = success ? "飞书已连接，可继续导入文档" : "飞书授权未完成，请重试"
    }
}

struct WeeklyPlansResponse: Decodable {
    let plans: [ImportedPlan]
}

struct ImportedPlan: Decodable, Identifiable {
    let title: String
    let rawContent: String
    let sourceURL: String
    let importedAt: Date

    enum CodingKeys: String, CodingKey {
        case title, rawContent = "raw_content", sourceURL = "source_url", importedAt = "imported_at"
    }

    var id: String { "\(sourceURL)|\(importedAt.timeIntervalSince1970)" }
}

enum PlanSyncError: LocalizedError {
    case invalidURL, missingKey, invalidResponse, noPlan, serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请先填入 Railway 的 HTTPS 服务地址"
        case .missingKey: return "请先填入计划同步密钥"
        case .invalidResponse: return "计划服务返回异常"
        case .noPlan: return "飞书里还没有可同步的训练计划"
        case .serverStatus(let code): return "计划服务暂时不可用（HTTP \(code)）"
        }
    }
}

private extension JSONDecoder {
    static let motionNote: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
