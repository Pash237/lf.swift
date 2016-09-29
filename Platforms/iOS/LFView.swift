import Foundation
import AVFoundation
import UIKit

open class LFView: UIView {
    open static var defaultBackgroundColor:UIColor = UIColor.black

    open override class var layerClass:AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return self.layer as! AVCaptureVideoPreviewLayer
    }

    public var videoGravity:String = AVLayerVideoGravityResizeAspectFill {
        didSet {
            previewLayer.videoGravity = videoGravity
        }
    }

    var orientation:AVCaptureVideoOrientation = .portrait {
        didSet {
            if (previewLayer.connection.isVideoOrientationSupported) {
                previewLayer.connection.videoOrientation = orientation
            }
        }
    }
    var position:AVCaptureDevicePosition = .front

    private weak var currentStream:NetStream? {
        didSet {
            guard let oldValue:NetStream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    public override init(frame:CGRect) {
        super.init(frame:frame)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func awakeFromNib() {
        backgroundColor = LFView.defaultBackgroundColor
        layer.contentsGravity = kCAGravityResizeAspect
        layer.backgroundColor = LFView.defaultBackgroundColor.cgColor

        setupCaptureSession()
        previewLayer.session = AVCaptureSession.shared
    }

    func setupCaptureSession() {
        let session = AVCaptureSession.shared

        do {
            let videoInput = AVCaptureDevice.cameraWithPosition(position: .back)
            try! session.addInput(AVCaptureDeviceInput(device: videoInput))

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)

            if let connection = videoOutput.connection(withMediaType: AVMediaTypeVideo) {
                if (connection.isVideoOrientationSupported) {
                    connection.videoOrientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
                }
            }
        }

        do {
            let audioInput = AVCaptureDevice.defaultAudioInputDevice()
            try! session.addInput(AVCaptureDeviceInput(device: audioInput))

            let audioOutput = AVCaptureAudioDataOutput()
            session.addOutput(audioOutput)

            session.automaticallyConfiguresApplicationAudioSession = true
        }
    }

    open override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview != nil {
            logger.debug("starting AVCaptureSession")
            AVCaptureSession.shared.startRunning()
        } else {
            logger.debug("stopping AVCaptureSession")
            AVCaptureSession.shared.stopRunning()
            _sharedAVCaptureSession = nil
        }
    }

    open override func layoutSubviews() {
        if (self.previewLayer.connection.isVideoOrientationSupported) {
            let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
            if (self.previewLayer.connection.videoOrientation != orientation) {
                self.previewLayer.connection.videoOrientation = orientation
            }
        }
    }
    
}

extension LFView: NetStreamDrawable {
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer) {
    }
    func draw(image:CIImage) {
    }
}
