import Foundation
import AVFoundation

/// Manages audio input capture using AVAudioEngine.
/// Audio is streamed in-memory only and never stored to disk for privacy.
final class AudioCaptureManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    @Published var hasPermission = false

    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Data] = []
    private var audioFormat: AVAudioFormat?

    /// Callback when a new audio chunk is ready for transcription
    var onAudioChunkReady: ((Data) -> Void)?

    /// Minimum audio level to consider as speech (voice activity detection)
    private let vadThreshold: Float = -40.0 // dB

    // MARK: - Permission

    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if granted {
                    print("🎤 Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                }
            }
        }
    }

    // MARK: - Start/Stop

    func startCapture() {
        guard !isCapturing else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        self.audioFormat = format

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isCapturing = true
            print("🎤 Audio capture started")
        } catch {
            print("❌ Audio capture failed to start: \(error.localizedDescription)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
        audioLevel = 0.0
        print("🎤 Audio capture stopped")
    }

    func toggleCapture() {
        if isCapturing {
            stopCapture()
        } else {
            requestPermission()
            startCapture()
        }
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level for VAD
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frames = buffer.frameLength

        var sum: Float = 0
        for i in 0..<Int(frames) {
            let sample = channelDataValue[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frames))
        let avgPower = 20 * log10(max(rms, 0.000001))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = avgPower
        }

        // Voice Activity Detection — only process if audio above threshold
        guard avgPower > vadThreshold else { return }

        // Convert buffer to data
        guard let data = bufferToWAVData(buffer) else { return }
        audioBuffer.append(data)

        // Send chunks every ~2 seconds worth of audio
        if audioBuffer.count >= 20 { // ~2 seconds at 4096 buffer size
            let combinedData = combineAudioChunks()
            onAudioChunkReady?(combinedData)
            audioBuffer.removeAll()
        }
    }

    // MARK: - Data Conversion

    private func bufferToWAVData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frames = Int(buffer.frameLength)
        var data = Data()

        for i in 0..<frames {
            let sample = channelData[0][i]
            // Convert float to 16-bit PCM
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
            withUnsafeBytes(of: intSample) { data.append(contentsOf: $0) }
        }

        return data
    }

    private func combineAudioChunks() -> Data {
        var combinedPCM = Data()
        for chunk in audioBuffer {
            combinedPCM.append(chunk)
        }

        // Create WAV header + PCM data
        return createWAVFile(pcmData: combinedPCM, sampleRate: audioFormat?.sampleRate ?? 44100.0)
    }

    private func createWAVFile(pcmData: Data, sampleRate: Double) -> Data {
        var header = Data()

        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize

        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        header.append(pcmData)

        return header
    }

    /// Returns the current audio buffer as WAV data (for manual flush).
    func flushBuffer() -> Data? {
        guard !audioBuffer.isEmpty else { return nil }
        let data = combineAudioChunks()
        audioBuffer.removeAll()
        return data
    }
}
