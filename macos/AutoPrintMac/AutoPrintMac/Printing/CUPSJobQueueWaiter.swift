import Foundation

/// Parses the job id CUPS prints on stdout when `lp` accepts a job into the print queue.
///
/// `lp` returns exit code 0 as soon as a job is *submitted*, not once it has actually printed.
/// To know when a job is truly done, we need this id to poll the queue with `lpstat`.
enum CUPSJobIDParser {
    private static let marker = "request id is "

    static func parse(_ output: String) -> String? {
        guard let markerRange = output.range(of: marker) else { return nil }

        let remainder = output[markerRange.upperBound...].drop { $0 == " " }
        let jobID = remainder.prefix { !$0.isWhitespace }

        return jobID.isEmpty ? nil : String(jobID)
    }
}

/// Polls whether a submitted CUPS job is still sitting in the print queue, and waits (with a
/// timeout) until it either finishes or the caller gives up on it. This is what lets AutoPrint
/// tell "queued" apart from "actually printed" -- `lp` exiting 0 only means the former.
enum CUPSJobQueueWaiter {
    static func waitForCompletion(
        jobID: String,
        pollInterval: TimeInterval = 2,
        timeoutSeconds: Int,
        isJobQueued: @escaping (String) async -> Bool,
        sleep: @escaping (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
        }
    ) async -> Bool {
        let maxAttempts = max(1, Int(TimeInterval(timeoutSeconds) / pollInterval))

        for _ in 0..<maxAttempts {
            if await !isJobQueued(jobID) {
                return true
            }
            await sleep(pollInterval)
        }

        return false
    }
}

enum MacCUPSQueueStatus {
    static func isJobQueued(_ jobID: String) async -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-o", jobID]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            // If we can't ask CUPS, assume the job is done rather than blocking forever.
            return false
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !output.isEmpty
    }
}
