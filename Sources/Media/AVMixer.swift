#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

final class AVMixer: NSObject {

    static let supportedSettingsKeys:[String] = [
        "fps",
        "sessionPreset",
        "orientation",
        "continuousAutofocus",
        "continuousExposure",
    ]

    static let defaultFPS:Float64 = 30
    static let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static let defaultVideoSettings:[NSObject: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject
    ]

    var fps:Float64 {
        get { return videoIO.fps }
        set { videoIO.fps = newValue }
    }

    var continuousExposure:Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    var continuousAutofocus:Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

    var sessionPreset:String = AVMixer.defaultSessionPreset {
        didSet {
            guard sessionPreset != oldValue else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    var session:AVCaptureSession!

    fileprivate(set) var audioIO:AudioIOComponent!
    fileprivate(set) var videoIO:VideoIOComponent!
    fileprivate(set) lazy var recorder:AVMixerRecorder = AVMixerRecorder()

    override init() {
        super.init()
        audioIO = AudioIOComponent(mixer: self)
        videoIO = VideoIOComponent(mixer: self)
    }
}

extension AVMixer: Runnable {
    // MARK: Runnable
    var running:Bool {
        return session.isRunning
    }

    func startRunning() {
    }

    func stopRunning() {

    }
}
