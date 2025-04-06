import Foundation
import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    class CameraPreview: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreview {
        let view = CameraPreview()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreview, context: Context) {}
}
