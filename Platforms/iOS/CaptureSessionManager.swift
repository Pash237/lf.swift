//
// Created by Pavel Alexeev on 27/09/2016.
//

import Foundation
import AVFoundation

open class CaptureSessionManager: NSObject
{
    open var session: AVCaptureSession

    fileprivate var sessionPreset = AVCaptureSessionPresetMedium

    open var autorotate: Bool = true
    open var orientation: AVCaptureVideoOrientation = .portrait
    {
        didSet {
            if let connection = session.videoOutput?.connection(withMediaType: AVMediaTypeVideo) {
                if (connection.isVideoOrientationSupported && connection.videoOrientation != orientation) {
                    connection.videoOrientation = orientation
                }
            }
        }
    }
    
    public init(sessionPreset: String = AVCaptureSessionPresetMedium)
    {
        session = AVCaptureSession()
        session.sessionPreset = sessionPreset

        super.init()

        self.sessionPreset = sessionPreset

        setupCaptureSession()

        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChanged(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupCaptureSession()
    {
        do {
            let videoInput = AVCaptureDevice.cameraWithPosition(position: .back)
            try! session.addInput(AVCaptureDeviceInput(device: videoInput))

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)

            orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
        }

        do {
            let audioInput = AVCaptureDevice.defaultAudioInputDevice()
            try! session.addInput(AVCaptureDeviceInput(device: audioInput))

            let audioOutput = AVCaptureAudioDataOutput()
            session.addOutput(audioOutput)

            session.automaticallyConfiguresApplicationAudioSession = true
        }
    }

    open var cameraPosition: AVCaptureDevicePosition = .back {
        didSet {
            if session.videoInput?.device.position != cameraPosition {
                session.removeInput(session.videoInput)

                if let videoInput = AVCaptureDevice.cameraWithPosition(position: cameraPosition) {
                    var fallbackSessionPreset = sessionPreset
                    if fallbackSessionPreset != AVCaptureSessionPreset1920x1080 && !videoInput.supportsAVCaptureSessionPreset(fallbackSessionPreset) {
                        fallbackSessionPreset = AVCaptureSessionPreset1920x1080
                    }
                    if fallbackSessionPreset != AVCaptureSessionPreset1280x720 && !videoInput.supportsAVCaptureSessionPreset(fallbackSessionPreset) {
                        fallbackSessionPreset = AVCaptureSessionPreset1280x720
                    }
                    if fallbackSessionPreset != AVCaptureSessionPreset640x480 && !videoInput.supportsAVCaptureSessionPreset(fallbackSessionPreset) {
                        fallbackSessionPreset = AVCaptureSessionPreset640x480
                    }

                    if session.sessionPreset != fallbackSessionPreset {
                        session.sessionPreset = fallbackSessionPreset;
                        logger.debug("Setting session preset \(fallbackSessionPreset)")
                    }

                    try! session.addInput(AVCaptureDeviceInput(device: videoInput))

                    orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
                }
            }
        }
    }
}

extension CaptureSessionManager: Runnable
{
    var running:Bool
    {
        return session.isRunning
    }
    
    open func startRunning()
    {
        session.startRunning()
    }
    
    open func stopRunning()
    {
        session.stopRunning()
    }
}

extension CaptureSessionManager
{
    func onOrientationChanged(_ notification:Notification)
    {
        guard autorotate else {
            return
        }

        orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
    }
}