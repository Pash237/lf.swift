//
// Created by Pavel Alexeev on 27/09/2016.
//

import AVFoundation

extension AVCaptureDevice {
	static public func cameraWithPosition(position:AVCaptureDevicePosition) -> AVCaptureDevice? {
		for device in AVCaptureDevice.devices() {
			guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
				continue
			}
			if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
				return device
			}
		}
		return nil
	}

	static public func defaultAudioInputDevice() -> AVCaptureDevice? {
		return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
	}
}

extension AVCaptureSession {
    var audioOutput: AVCaptureAudioDataOutput?
    {
        for output in self.outputs {
            if output is AVCaptureAudioDataOutput {
                return output as? AVCaptureAudioDataOutput
            }
        }
        return nil
    }
    
    var videoOutput: AVCaptureVideoDataOutput?
    {
        for output in self.outputs {
            if output is AVCaptureVideoDataOutput {
                return output as? AVCaptureVideoDataOutput
            }
        }
        return nil
    }

	var audioInput: AVCaptureDeviceInput?
	{
		return input(mediaType: AVMediaTypeAudio)
	}

	var videoInput: AVCaptureDeviceInput?
	{
		return input(mediaType: AVMediaTypeVideo)
	}

	func input(mediaType: String) -> AVCaptureDeviceInput?
	{
		for input in self.inputs {
			if input is AVCaptureDeviceInput {
				if (input as! AVCaptureDeviceInput).device.hasMediaType(mediaType) {
					return input as? AVCaptureDeviceInput
				}
			}
		}
		return nil
	}
    
    func cleanup()
    {
        if self.isRunning {
            self.stopRunning()
        }

        for output in self.outputs {
            self.removeOutput(output as! AVCaptureOutput)
        }
        for input in self.inputs {
            self.removeInput(input as! AVCaptureInput)
        }

        logger.debug("AVCaptureSession cleaned up")
    }
}
