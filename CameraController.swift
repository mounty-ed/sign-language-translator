import AVFoundation
import UIKit
import SwiftUI

class CameraController: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()

    private var recordingStartTime: Date?
    private var actualRecordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var isActuallyRecording = false
    private var isWritingFinalVideo = false

    @Published var recordingCompleted: Bool = false
    @Published var flaskResponse: String = ""

    override init() {
        super.init()
        setupSession()
    }

    func getSession() -> AVCaptureSession {
        return session
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480  // ✅ Match model resolution

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                print("❌ Failed to access front camera.")
                return
            }

            self.session.addInput(input)

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func resetRecordingState() {
        recordingStartTime = nil
        actualRecordingStartTime = nil
        currentRecordingURL = nil
        isActuallyRecording = false
        recordingCompleted = false
    }

    func startRecording() {
        guard !isWritingFinalVideo else {
            print("⛔️ Still writing last file. Start blocked.")
            return
        }

        resetRecordingState()

        let tempDir = FileManager.default.temporaryDirectory
        let filename = "recorded-\(UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: fileURL)

        currentRecordingURL = fileURL
        recordingStartTime = Date()

        print("🎥 [DEBUG] Starting recording to: \(fileURL.lastPathComponent)")
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
    }

    func stopRecording() {
        guard isActuallyRecording,
              let actualStart = actualRecordingStartTime else {
            print("⛔️ Stop blocked: not actively recording")
            return
        }

        let elapsed = Date().timeIntervalSince(actualStart)
        print("🛑 [DEBUG] Attempting stop after \(elapsed) sec")

        if elapsed < 1.0 {
            let delay = 1.0 - elapsed
            print("⏳ Delaying stop by \(delay)s to ensure valid file")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.movieOutput.stopRecording()
            }
        } else {
            movieOutput.stopRecording()
        }
    }

    func isRecordingReady() -> Bool {
        return isActuallyRecording
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            print("✅ Recording started at \(Date())")
            self.actualRecordingStartTime = Date()
            self.isActuallyRecording = true
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        guard outputFileURL == self.currentRecordingURL else {
            print("❌ Ghost recording output, ignoring.")
            return
        }

        isWritingFinalVideo = true
        print("✅ Recording stopped at \(Date())")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recordingCompleted = true
            self.isActuallyRecording = false
            self.isWritingFinalVideo = false

            print("📁 Sending video to server without saving locally.")
            self.sendVideoToServer(videoURL: outputFileURL)
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }

    func sendVideoToServer(videoURL: URL) {
        print("🚀 Uploading video to server...")

        let boundary = UUID().uuidString
        let serverURL = URL(string: "http://10.232.41.56:5007/upload-video")!

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = videoURL.lastPathComponent
        let mimetype = "video/quicktime"
        let fieldName = "video"

        if let videoData = try? Data(contentsOf: videoURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        }

        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                print("❌ Upload error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("❌ No data received from server.")
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Server Response: \(jsonResponse)")

                    if let result = jsonResponse["result"] as? String {
                        print("🧠 Flask Response: \(result)")
                        DispatchQueue.main.async {
                            self.flaskResponse = result
                        }
                    }
                } else {
                    print("❌ Failed to parse JSON.")
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
}
