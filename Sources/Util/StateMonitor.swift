//
// Created by Pavel Alexeev on 13/10/2016.
//

import Foundation

extension Notification.Name {
    static let onPublishingBroken = Notification.Name("onPublishingBroken")
	static let onPublishingStatusChanged = Notification.Name("onPublishingStatusChanged")
}

open class StateMonitor: NSObject
{
	fileprivate var audioCaptureSessionOutputActiveTime: Double = 0
	fileprivate var videoCaptureSessionOutputActiveTime: Double = 0
	fileprivate var audioEncoderActiveTime: Double = 0
	fileprivate var videoEncoderActiveTime: Double = 0

	fileprivate var timer: Timer?
    
    fileprivate var pauseUntil: TimeInterval?

	let interval = 2.0

	open static let shared: StateMonitor = {
		let instance = StateMonitor()
		return instance
	}()
    
    open class func sharedInstance() -> StateMonitor {
        return StateMonitor.shared
    }

	open func start()
	{
        timer?.invalidate()
        pauseUntil = nil;
        
        audioCaptureSessionOutputActiveTime = 0
        videoCaptureSessionOutputActiveTime = 0
        audioEncoderActiveTime = 0
        videoEncoderActiveTime = 0
        totalAudioBytes = 0
        totalVideoBytes = 0
        totalBytesInQueue = 0
		videoBitrate = 0
        notEnoughBandwidth = false
        
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(self.timerFires), userInfo: nil, repeats: true)
	}
    
    open func stop()
    {
        print("Stop monitoring")
        timer?.invalidate()
        timer = nil
    }

	open func start(after time: TimeInterval)
	{
        start()
        
		print("Start monitoring after \(time) seconds...")
        pauseUntil = CFAbsoluteTimeGetCurrent() + time
	}
    
    open private(set) var audioCaptureSessionOutputActive: Bool = true
    open private(set) var videoCaptureSessionOutputActive: Bool = true
    open private(set) var audioEncoderActive: Bool = true
    open private(set) var videoEncoderActive: Bool = true
    open private(set) var audioInputActive: Bool = true
    open private(set) var videoInputActive: Bool = true
    open private(set) var socketOutputActive: Bool = true

	open var debugStatusText: String
	{
		return "inputBitrate: \(Int(inputBitrate / 1000)) kbit/s, outputBitrate: \(Int(socketOutputBitrate / 1000)) kbit/s, " +
				"in queue: \(totalBytesInQueue / 1024) KB " +
				"videoBitrate: \(videoBitrate / 1024) kbit/s, " +
				"session: audio \(audioCaptureSessionOutputActive ? 1 : 0), video \(videoCaptureSessionOutputActive ? 1 : 0), " +
				"encoder: audio \(audioEncoderActive ? 1 : 0), video \(videoEncoderActive ? 1 : 0), " +
				"totalBytes: audio \(totalAudioBytes) (\(audioInputActive)), video \(totalVideoBytes) (\(videoInputActive)), " +
				(pauseUntil == nil ? "" : "...waiting \(Int(pauseUntil! - CFAbsoluteTimeGetCurrent())) seconds")
	}

	open var statusText: String?
	{
		if somethingIsWrongWithNetwork {
			if notEnoughBandwidth {
				return "Not enough bandwidth."
			} else {
				return "Connecting…"
			}
		}
		if somethingIsWrongWithAudioVideoInput {
			return "Connecting…"
		}
		if videoBitrate != 0 && videoBitrate < 100*1000 {
			return "Slow connection."
		}
		return nil
	}

	fileprivate var previousStatusText: String?
    
    open var somethingIsWrongWithAudioVideoInput: Bool
    {
        return !audioCaptureSessionOutputActive || !videoCaptureSessionOutputActive
            || !audioEncoderActive || !videoEncoderActive
            || !audioInputActive
            || !videoInputActive
    }
    
    open var somethingIsWrongWithNetwork: Bool
    {
        return !socketOutputActive || notEnoughBandwidth
    }
    
    @objc func timerFires()
    {
	    audioCaptureSessionOutputActive = CFAbsoluteTimeGetCurrent() - audioCaptureSessionOutputActiveTime < interval*2
	    videoCaptureSessionOutputActive = CFAbsoluteTimeGetCurrent() - videoCaptureSessionOutputActiveTime < interval*2
	    audioEncoderActive = CFAbsoluteTimeGetCurrent() - audioEncoderActiveTime < interval*2
	    videoEncoderActive = CFAbsoluteTimeGetCurrent() - videoEncoderActiveTime < interval*2
	    audioInputActive = totalAudioBytes != previousPreviousTotalAudioBytes
	    videoInputActive = totalVideoBytes != previousPreviousTotalVideoBytes
	    socketOutputActive = !(socketOutputBitrate == 0 && previousSocketOutputBitrate == 0 && previousPreviousSocketOutputBitrate == 0)

	    let statusText = self.statusText
	    if previousStatusText != statusText {
		    NotificationCenter.default.post(name: .onPublishingStatusChanged, object: self)
	    }
	    previousStatusText = statusText
	
	    NotificationCenter.default.post(name: Notification.Name("onStateMonitorStatus"), object: self)

	    if let pauseUntil = pauseUntil {
            if CFAbsoluteTimeGetCurrent() < pauseUntil {
	            print("...waiting more \(pauseUntil - CFAbsoluteTimeGetCurrent()) seconds")
                return
            } else {
                print("...waited enough – start monitoring")
                self.pauseUntil = nil
            }
        }

        print("STATUS: \(debugStatusText)")

	    if somethingIsWrongWithNetwork || somethingIsWrongWithAudioVideoInput
	    {
            print("publishing is broken!")
		    NotificationCenter.default.post(name: .onPublishingBroken, object: self)
	    }

	    previousPreviousTotalAudioBytes = previousTotalAudioBytes
	    previousPreviousTotalVideoBytes = previousTotalVideoBytes
	    previousPreviousSocketOutputBitrate = previousSocketOutputBitrate
        previousTotalAudioBytes = totalAudioBytes
        previousTotalVideoBytes = totalVideoBytes
        previousSocketOutputBitrate = socketOutputBitrate
    }

	func setAudioCaptureSessionOutputActive()
	{
		audioCaptureSessionOutputActiveTime = CFAbsoluteTimeGetCurrent()
	}

	func setVideoCaptureSessionOutputActive()
	{
		videoCaptureSessionOutputActiveTime = CFAbsoluteTimeGetCurrent()
	}

	func setAudioEncoderActive()
	{
		audioEncoderActiveTime = CFAbsoluteTimeGetCurrent()
	}

	func setVideoEncoderActive()
	{
		videoEncoderActiveTime = CFAbsoluteTimeGetCurrent()
	}

	var totalAudioBytes: Int = 0
	var totalVideoBytes: Int = 0

	var socketOutputBitrate: Double = 0
	var totalBytesInQueue: Int = 0
	var videoBitrate: Int = 0
	var inputBitrate: Double = 0

	fileprivate var previousTotalAudioBytes: Int = -1
	fileprivate var previousTotalVideoBytes: Int = -1
	fileprivate var previousSocketOutputBitrate: Double = -1
	fileprivate var previousPreviousTotalAudioBytes: Int = -2
	fileprivate var previousPreviousTotalVideoBytes: Int = -2
	fileprivate var previousPreviousSocketOutputBitrate: Double = -2
    
    var notEnoughBandwidth: Bool = false
}
