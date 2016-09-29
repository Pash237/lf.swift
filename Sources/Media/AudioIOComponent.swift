import Foundation
import AVFoundation

final class AudioIOComponent: IOComponent {
    var encoder:AACEncoder = AACEncoder()
    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.AudioIOComponent.lock", attributes: []
    )

    var input:AVCaptureDeviceInput? = nil {
        didSet {
            guard oldValue != input else {
                return
            }
            if let oldValue:AVCaptureDeviceInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input:AVCaptureDeviceInput = input {
                if mixer.session.canAddInput(input) {
                    mixer.session.addInput(input)
                }
            }
        }
    }

    private var _output:AVCaptureAudioDataOutput? = nil
    var output:AVCaptureAudioDataOutput! {
        get {
            if (_output == nil) {
                _output = AVCaptureAudioDataOutput()
            }
            return _output
        }
        set {
            if (_output == newValue) {
                return
            }
            if let output:AVCaptureAudioDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
                mixer.session.removeOutput(output)
            }
            _output = newValue
        }
    }

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
        encoder.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
    }
}
