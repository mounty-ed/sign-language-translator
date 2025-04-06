import SwiftUI

struct ContentView: View {
    @StateObject private var cameraController = CameraController()
    @State private var isRecording = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Fingual")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 40)

                ZStack {
                    CameraView(session: cameraController.getSession())
                        .frame(width: 320, height: 440)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                }

                Button(action: {
                    if isRecording {
                        print("🛑 [UI] Stop button tapped")
                        cameraController.stopRecording()
                    } else {
                        print("🎬 [UI] Start button tapped")
                        cameraController.startRecording()
                    }
                    isRecording.toggle()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .frame(width: 220, height: 50)
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                }
                .disabled(cameraController.isRecordingReady() && !isRecording)

                if !cameraController.flaskResponse.isEmpty {
                    ScrollView {
                        Text(cameraController.flaskResponse)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }
}
