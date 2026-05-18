import Foundation

final class FileStabilityTracker {
    private struct Snapshot {
        let size: UInt64
        let modifiedAt: Date
        let firstSeenStableAt: Date
    }

    private let stableSeconds: TimeInterval
    private var snapshots: [URL: Snapshot] = [:]

    init(stableSeconds: Int) {
        self.stableSeconds = TimeInterval(stableSeconds)
    }

    func observe(url: URL, size: UInt64, modifiedAt: Date, now: Date) {
        snapshots[url] = Snapshot(size: size, modifiedAt: modifiedAt, firstSeenStableAt: now)
    }

    func isStable(url: URL, size: UInt64, modifiedAt: Date, now: Date) -> Bool {
        guard let snapshot = snapshots[url] else {
            observe(url: url, size: size, modifiedAt: modifiedAt, now: now)
            return false
        }

        if snapshot.size != size || snapshot.modifiedAt != modifiedAt {
            snapshots[url] = Snapshot(size: size, modifiedAt: modifiedAt, firstSeenStableAt: now)
            return false
        }

        return now.timeIntervalSince(snapshot.firstSeenStableAt) >= stableSeconds
    }
}
