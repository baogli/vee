import Foundation

/// Dead-simple file logger for debugging paste delivery issues.
/// Tail with: tail -f /tmp/vee.log
enum VeeLog {
    static func write(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "\(formatter.string(from: Date())) \(message)\n"

        let url = URL(fileURLWithPath: "/tmp/vee.log")

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
