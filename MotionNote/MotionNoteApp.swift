import SwiftUI

@main
struct MotionNoteApp: App {
    @StateObject private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .motionNoteFeishuCallback, object: url)
                }
        }
    }
}

extension Notification.Name {
    static let motionNoteFeishuCallback = Notification.Name("motionNoteFeishuCallback")
}
