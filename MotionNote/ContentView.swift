import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var workout: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var health = HealthService()
    @StateObject private var coach = SpeechCoach()
    @StateObject private var feishu = FeishuService()
    @State private var tab = 0
    @State private var currentStep = 0
    @State private var importMessage = ""
    @State private var isSyncingPlan = false
    @State private var weeklyPlans: [ImportedPlan] = []
    @AppStorage("activeWeeklyPlanID") private var activeWeeklyPlanID = ""

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { planView }.tabItem { Label("计划", systemImage: "figure.strengthtraining.traditional") }.tag(0)
            NavigationStack { coachView }.tabItem { Label("语音教练", systemImage: "waveform") }.tag(1)
            NavigationStack { recordView }.tabItem { Label("训练档案", systemImage: "note.text") }.tag(2)
        }
        .tint(Color(red: 0.14, green: 0.33, blue: 0.23))
        .task {
            await synchronizeWeeklyPlans(silently: true)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await synchronizeWeeklyPlans(silently: true)
            }
        }
    }

    private var planView: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    bundledImage("motion-note-mark", fallback: "dumbbell.fill").resizable().scaledToFit().frame(width: 62, height: 62).clipShape(RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("零件充电站").font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("给身体的小零件，充个电。") .foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 12) {
                    Text("今天来练哪个小零件？").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("周三 · 训练日 · 不卷，练一下") .foregroundStyle(.secondary)
                    HStack { Text(workout.goal).font(.title3.bold()); Spacer(); Text("\(workout.totalMinutes) 分钟") }
                    Button("开始本次训练") { tab = 1 } .buttonStyle(.borderedProminent)
                }.padding(.vertical, 10)
            }
            Section("动力充值") {
                ZStack(alignment: .bottomLeading) {
                    bundledImage("motivation-hero", fallback: "figure.strengthtraining.traditional").resizable().scaledToFill().frame(height: 270).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("不用等状态满格，\n动起来，电量就会回来。")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("今天只要完成热身，也算打卡。")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    }.padding(18)
                }.clipShape(RoundedRectangle(cornerRadius: 20))
            }
            Section("本周课表") {
                Text("保留最近两节私教课；选择其中一节后，今日训练与语音教练都会用它作为依据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if weeklyPlans.isEmpty {
                    Text("飞书中的私教课会自动同步到这里。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(weeklyPlans.indices, id: \.self) { index in
                        weeklyPlanSelectionRow(index: index, plan: weeklyPlans[index])
                    }
                }
            }
            Section("今日训练") {
                Picker("训练目标", selection: $workout.goal) { Text("全身力量").tag("全身力量"); Text("下肢力量").tag("下肢力量"); Text("上肢力量").tag("上肢力量"); Text("轻度恢复").tag("轻度恢复") }
                ForEach(workout.steps) { step in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(step.phase.rawValue) · \(step.minutes) 分钟").font(.caption).foregroundStyle(.secondary)
                        Text(step.name).font(.headline)
                        Text(step.prescription).font(.subheadline)
                        Text("注意：\(step.cue)").font(.footnote).foregroundStyle(.orange)
                    }.padding(.vertical, 5)
                }
            }
        }.navigationTitle("Motion Note")
    }

    private var coachView: some View {
        let step = workout.steps[currentStep]
        return VStack(spacing: 24) {
            ProgressView(value: Double(currentStep + 1), total: Double(workout.steps.count)).tint(.orange)
            Text("第 \(currentStep + 1) / \(workout.steps.count) 项 · \(step.phase.rawValue)").font(.subheadline).foregroundStyle(.secondary)
            Text(step.name).font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
            Text(step.prescription).font(.title3).multilineTextAlignment(.center)
            Text("“\(step.cue)”").padding().frame(maxWidth: .infinity).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            Button("听取语音指导") { coach.speak(step) }.buttonStyle(.borderedProminent)
            Button(currentStep == workout.steps.count - 1 ? "完成训练" : "下一步") { currentStep = min(currentStep + 1, workout.steps.count - 1); coach.speak(workout.steps[currentStep]) }.buttonStyle(.bordered)
            Spacer()
            Text("若出现尖锐疼痛、头晕或异常不适，请停止训练并寻求专业建议。").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding().navigationTitle("语音教练")
    }

    private var recordView: some View {
        Form {
        Section("飞书连接") {
                TextField("本机飞书中转 HTTPS 地址", text: $feishu.gatewayURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("连接飞书") { feishu.openAuthorization() }
                Text(feishu.status).font(.footnote).foregroundStyle(.secondary)
            Text("授权后，把训练文档发送给 Motion Note 机器人；App 打开或回到前台时会自动检查本周课表。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        Section("飞书本周课表") {
            Text("机器人收到的最近两份训练文档会自动同步，并按第 1 练、第 2 练保留；不会自动改写动作、组数或注意事项。")
                .font(.footnote).foregroundStyle(.secondary)
                TextField("Railway HTTPS 服务地址", text: $feishu.planSyncURL)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
            SecureField("计划同步密钥", text: $feishu.planSyncKey)
                .textInputAutocapitalization(.never)
            if feishu.isPlanSyncConfigured {
                Label("已启用自动同步", systemImage: "checkmark.icloud.fill")
                    .foregroundStyle(.green)
            }
            Button {
                Task { await synchronizeWeeklyPlans(silently: false) }
            } label: {
                Label(isSyncingPlan ? "正在检查…" : "立即检查", systemImage: "arrow.clockwise")
            }
                .disabled(isSyncingPlan)
                .buttonStyle(.borderedProminent)
                if !importMessage.isEmpty {
                    Text(importMessage).font(.footnote).foregroundStyle(.green)
                }
            }
            Section("已导入的本周私教课") {
                if weeklyPlans.isEmpty {
                    Text("还没有导入课程内容").foregroundStyle(.secondary)
                } else {
                    ForEach(weeklyPlans.indices, id: \.self) { index in
                        weeklyPlanDetailRow(index: index, plan: weeklyPlans[index])
                    }
                }
            }
            Section("Apple Watch 与训练数据") {
                Text(health.status)
                if let energy = health.todayActiveEnergy { LabeledContent("今日活动能量", value: "\(Int(energy)) 千卡") }
                if let steps = health.todaySteps { LabeledContent("今日步数", value: "\(Int(steps)) 步") }
                if health.status == "已连接 Apple 健康" { LabeledContent("今日训练记录", value: "\(health.recentWorkouts) 次"); Button("刷新今日数据") { Task { await health.refreshToday() } } }
                Button("连接 Apple 健康") { Task { await health.requestAuthorization() } }
            }
            Section("训练后反馈") { Slider(value: $workout.effort, in: 1...10, step: 1) { Text("主观用力程度") }; Text("主观用力程度：\(Int(workout.effort))/10"); TextField("疼痛、不适或下次调整", text: $workout.discomfort) }
        }.navigationTitle("训练档案")
    }

    private func weeklyPlanSelectionRow(index: Int, plan: ImportedPlan) -> some View {
        Button {
            selectWeeklyPlan(plan)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: activeWeeklyPlanID == plan.id ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(activeWeeklyPlanID == plan.id ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("第 \(index + 1) 练")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        if activeWeeklyPlanID == plan.id {
                            Text("当前依据")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.14), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(planPreview(plan))
                        .lineLimit(2)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func weeklyPlanDetailRow(index: Int, plan: ImportedPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第 \(index + 1) 练")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if activeWeeklyPlanID == plan.id {
                    Text("当前依据")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.14), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            Text(plan.title).font(.headline)
            Text(planPreview(plan)).font(.subheadline).lineLimit(4)
            HStack {
                Button(activeWeeklyPlanID == plan.id ? "当前作为训练依据" : "设为当天训练依据") {
                    selectWeeklyPlan(plan)
                }
                .buttonStyle(.bordered)
                if let url = URL(string: plan.sourceURL) {
                    Link("查看原始飞书文档", destination: url)
                        .font(.footnote)
                }
            }
        }
    }

    private func planPreview(_ plan: ImportedPlan) -> String {
        let lines = plan.rawContent
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " · ")
    }

    private func selectWeeklyPlan(_ plan: ImportedPlan) {
        let selectionChanged = activeWeeklyPlanID != plan.id
        activeWeeklyPlanID = plan.id
        workout.importCoachingNotes(plan.rawContent, sourceURL: plan.sourceURL)
        if selectionChanged {
            currentStep = 0
        }
    }

    private func synchronizeWeeklyPlans(silently: Bool) async {
        guard !isSyncingPlan else { return }
        guard feishu.isPlanSyncConfigured else {
            if !silently { importMessage = "请先完成飞书计划同步配置。" }
            return
        }

        isSyncingPlan = true
        defer { isSyncingPlan = false }

        do {
            let plans = try await feishu.syncWeeklyPlans()
            weeklyPlans = plans
            guard let selectedPlan = plans.first(where: { $0.id == activeWeeklyPlanID }) ?? plans.first else {
                if !silently { importMessage = "还没有可用的私教课。" }
                return
            }
            let selectedIndex = (plans.firstIndex(where: { $0.id == selectedPlan.id }) ?? 0) + 1
            selectWeeklyPlan(selectedPlan)
            if !silently {
                importMessage = "已同步本周 \(plans.count) 节私教课；当前使用第 \(selectedIndex) 练。"
            }
        } catch {
            if !silently { importMessage = error.localizedDescription }
        }
    }

    private func bundledImage(_ name: String, fallback: String) -> Image {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return Image(systemName: fallback)
        }
        return Image(uiImage: uiImage)
    }
}
