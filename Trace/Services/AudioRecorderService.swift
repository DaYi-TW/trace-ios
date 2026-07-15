import AVFoundation
import Foundation

@MainActor
final class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionDenied = !granted
        return granted
    }

    func start() throws {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TraceRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("recording-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw AudioRecorderError.cannotStart
        }
        self.recorder = recorder
        self.startedAt = .now
        self.elapsed = 0
        self.isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.elapsed = Date.now.timeIntervalSince(startedAt)
        }
    }

    @discardableResult
    func stop() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = recorder.url
        reset()
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func cancel() {
        let url = recorder?.url
        recorder?.stop()
        reset()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        recorder = nil
        startedAt = nil
        isRecording = false
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // The view controls the stop action so the resulting URL is never silently discarded.
    }
}

enum AudioRecorderError: LocalizedError {
    case cannotStart

    var errorDescription: String? {
        switch self {
        case .cannotStart: return "無法開始錄音，請確認麥克風權限與裝置狀態。"
        }
    }
}
