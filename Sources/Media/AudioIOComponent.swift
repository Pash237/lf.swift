import Foundation
import AVFoundation

final class AudioIOComponent: IOComponent {
    var encoder:AACEncoder = AACEncoder()
    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.AudioIOComponent.lock", attributes: []
    )

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
    }

    deinit {
        removeCaptureSessionOutputDelegate()
    }
    
    func addCaptureSessionOutputDelegate() {
        if let output = mixer.session.audioOutput {
            output.setSampleBufferDelegate(self, queue: lockQueue)
        }
    }

    func removeCaptureSessionOutputDelegate() {
        if let output = mixer.session.audioOutput {
            output.setSampleBufferDelegate(nil, queue: nil)
        }
    }

}

extension AudioIOComponent: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, from connection:AVCaptureConnection!) {
        StateMonitor.shared.setAudioCaptureSessionOutputActive()
        encoder.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
    }
}
