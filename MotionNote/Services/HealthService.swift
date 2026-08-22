import HealthKit

@MainActor
final class HealthService: ObservableObject {
    @Published private(set) var status = "尚未连接 Apple 健康"
    @Published private(set) var todayActiveEnergy: Double?
    @Published private(set) var todaySteps: Double?
    @Published private(set) var recentWorkouts: Int = 0
    private let store = HKHealthStore()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "此设备不支持 Apple 健康"
            return
        }
        do {
            let read: Set<HKObjectType> = [
                HKQuantityType(.activeEnergyBurned),
                HKQuantityType(.heartRate),
                HKQuantityType(.stepCount),
                HKWorkoutType.workoutType()
            ]
            try await store.requestAuthorization(toShare: [], read: read)
            await refreshToday()
            status = "已连接 Apple 健康"
        } catch {
            status = "授权未完成，请稍后重试"
        }
    }

    func refreshToday() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        do {
            todayActiveEnergy = try await statisticsSum(for: .activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
            todaySteps = try await statisticsSum(for: .stepCount, unit: .count(), predicate: predicate)
            recentWorkouts = try await workoutCount(predicate: predicate)
        } catch {
            status = "无法读取数据，请在健康 App 中检查授权"
        }
    }

    private func statisticsSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
        let type = HKQuantityType(identifier)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func workoutCount(predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
    }
}
