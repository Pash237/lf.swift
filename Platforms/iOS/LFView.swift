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

    public override init(frame:CGRect) {
        super.init(frame:frame)
        awakeFromNib()
    }
    
    public init(frame:CGRect, captureSession: AVCaptureSession) {
        super.init(frame:frame)
        self.captureSession = captureSession
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open var captureSession: AVCaptureSession? {
        didSet {
            previewLayer.session = captureSession
        }
    }

    open var automaticallyManageSession: Bool = true

    override open func awakeFromNib() {
        backgroundColor = LFView.defaultBackgroundColor
        layer.contentsGravity = kCAGravityResizeAspectFill
        layer.backgroundColor = LFView.defaultBackgroundColor.cgColor
        
        previewLayer.session = captureSession
    }


    open override func willMove(toSuperview newSuperview: UIView?) {
        if automaticallyManageSession {
            if newSuperview != nil {
                logger.debug("starting AVCaptureSession")
                captureSession?.startRunning()
            } else {
                logger.debug("stopping AVCaptureSession")
                captureSession?.stopRunning()
            }
        }
    }

    open override func layoutSubviews() {
        if let connection = self.previewLayer.connection {
            if self.previewLayer.connection.isVideoOrientationSupported {
                let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation)
                if self.previewLayer.connection.videoOrientation != orientation {
                    self.previewLayer.connection.videoOrientation = orientation
                }
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
