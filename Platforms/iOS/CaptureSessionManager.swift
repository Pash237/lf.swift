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
        session.automaticallyConfiguresApplicationAudioSession = false

        super.init()

        self.setupAudioSession()

        self.sessionPreset = sessionPreset

        setupCaptureSession()

        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChanged(_:)), name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSubjectAreaChanged(_:)), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupAudioSession()
    {
        //disable iOS audio processing
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with:[.defaultToSpeaker, .mixWithOthers])
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeMeasurement)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.debug("iOS audio processing disabled, mode = \(AVAudioSession.sharedInstance().mode)")
        } catch let error {
            logger.debug("Unable to disable iOS audio processing: \(error)")
        }
    }
    
    func setupCaptureSession()
    {
        do {
            let inputDevice = AVCaptureDevice.cameraWithPosition(position: .back)
            if let input = try? AVCaptureDeviceInput(device: inputDevice) {
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)

            orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
        }

        do {
            let inputDevice = AVCaptureDevice.defaultAudioInputDevice()
            if let input = try? AVCaptureDeviceInput(device: inputDevice) {
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            }

            let audioOutput = AVCaptureAudioDataOutput()
            session.addOutput(audioOutput)
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
    
    open var focusPointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5) {
        didSet {
            guard let device = session.videoInput?.device,
                  device.isFocusPointOfInterestSupported else {
                return
            }
            
            print("Setting new focus point: \(focusPointOfInterest)")
            
            do {
                try device.lockForConfiguration()
                device.isSubjectAreaChangeMonitoringEnabled = false
                device.focusPointOfInterest = focusPointOfInterest
                device.focusMode = .autoFocus   //focus and lock
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }
    
    open var enableContinuousFocus: Bool = true {
        didSet {
            guard let device = session.videoInput?.device,
                  device.isFocusPointOfInterestSupported else {
                return
            }
            
            if enableContinuousFocus {
                print("Setting continuous focus mode")
    
                do {
                    try device.lockForConfiguration()
                    device.isSubjectAreaChangeMonitoringEnabled = true
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    device.focusMode = .continuousAutoFocus
                    device.unlockForConfiguration()
                } catch let error as NSError {
                    logger.error("while locking device for continuousAutoFocus: \(error)")
                }
            } else {
                print("Setting manual focus mode")
                
                do {
                    try device.lockForConfiguration()
                    device.isSubjectAreaChangeMonitoringEnabled = false
                    device.focusPointOfInterest = focusPointOfInterest
                    device.focusMode = .autoFocus   //focus and lock
                    device.unlockForConfiguration()
                } catch let error as NSError {
                    logger.error("while locking device for autoFocus: \(error)")
                }
            }
        }
    }
    
    func onSubjectAreaChanged(_ notification:Notification)
    {
        guard let device = session.videoInput?.device,
              device.isFocusPointOfInterestSupported else {
            return
        }
    
        if device.focusMode == .locked {
            do {
                print("Subject area changed – changing focus")
                
                try device.lockForConfiguration()
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for continuousAutoFocus: \(error)")
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
