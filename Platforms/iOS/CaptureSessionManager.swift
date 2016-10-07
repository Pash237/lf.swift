//
// Created by Pavel Alexeev on 27/09/2016.
//

import Foundation
import AVFoundation

open class CaptureSessionManager: NSObject
{
    open var session: AVCaptureSession

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