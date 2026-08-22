import Foundation

enum WorkoutPhase: String, CaseIterable, Identifiable {
    case warmup = "热身"
    case training = "正式训练"
    case cooldown = "拉伸"
    var id: String { rawValue }
}

struct WorkoutStep: Identifiable, Hashable {
    let id = UUID()
    let phase: WorkoutPhase
    let name: String
    let prescription: String
    let cue: String
    let minutes: Int
}

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var goal = "全身力量"
    @Published var minutes = 45
    @Published var coachingNotes = ""
    @Published var coachingSourceURL = ""
    @Published var latestCoachSummary = ""
    @Published var effort = 6.0
    @Published var discomfort = ""
    @Published var steps: [WorkoutStep] = [
        .init(phase: .warmup, name: "快走或单车", prescription: "5 分钟，轻微出汗即可", cue: "保持能说完整句子的强度。", minutes: 5),
        .init(phase: .warmup, name: "髋部与踝关节活动", prescription: "各 8 次，做 2 轮", cue: "动作慢一些，先找活动范围。", minutes: 5),
        .init(phase: .training, name: "高脚杯深蹲", prescription: "3 组 × 10 次，组间休息 75 秒", cue: "膝盖朝脚尖方向，核心收紧；出现疼痛立即停止。", minutes: 12),
        .init(phase: .training, name: "哑铃罗马尼亚硬拉", prescription: "3 组 × 10 次，组间休息 75 秒", cue: "臀部向后送，背部保持中立。", minutes: 12),
        .init(phase: .training, name: "坐姿划船", prescription: "3 组 × 12 次，组间休息 60 秒", cue: "先沉肩再拉肘，避免耸肩。", minutes: 8),
        .init(phase: .cooldown, name: "臀肌、髋屈肌与胸椎拉伸", prescription: "每侧 30 秒，做 2 轮", cue: "只拉到轻微紧张，不要弹震或屏气。", minutes: 8)
    ]

    var totalMinutes: Int { steps.reduce(0) { $0 + $1.minutes } }

    func importCoachingNotes(_ text: String, sourceURL: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        coachingNotes = cleanText
        coachingSourceURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = cleanText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        latestCoachSummary = lines.prefix(4).joined(separator: "\n")
    }
}
