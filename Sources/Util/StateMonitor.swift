//
// Created by Pavel Alexeev on 13/10/2016.
//

import Foundation

extension Notification.Name {
    static let onPublishingBroken = Notification.Name("onPublishingBroken")
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

	open var statusString: String
	{
		return "session – audio: \(audioCaptureSessionOutputActive), video: \(videoCaptureSessionOutputActive), " +
				"encoder – audio: \(audioEncoderActive), video: \(videoEncoderActive), " +
				"totalBytes – audio: \(totalAudioBytes) (\(audioInputActive)), video: \(totalVideoBytes) (\(videoInputActive)), " +
				"outputBitrate: \(Int(socketOutputBitrate / 1000)) KBit, in queue: \(totalBytesInQueue / 1024) KB"
	}
    
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
        if let pauseUntil = pauseUntil {
            if CFAbsoluteTimeGetCurrent() < pauseUntil {
	            print("...waiting more \(pauseUntil - CFAbsoluteTimeGetCurrent()) seconds")
                return
            } else {
                print("...waited enough – start monitoring")
                self.pauseUntil = nil
            }
        }
        
        audioCaptureSessionOutputActive = CFAbsoluteTimeGetCurrent() - audioCaptureSessionOutputActiveTime < interval*2
        videoCaptureSessionOutputActive = CFAbsoluteTimeGetCurrent() - videoCaptureSessionOutputActiveTime < interval*2
        audioEncoderActive = CFAbsoluteTimeGetCurrent() - audioEncoderActiveTime < interval*2
        videoEncoderActive = CFAbsoluteTimeGetCurrent() - videoEncoderActiveTime < interval*2
        audioInputActive = totalAudioBytes != previousPreviousTotalAudioBytes
        videoInputActive = totalVideoBytes != previousPreviousTotalVideoBytes
        socketOutputActive = !(socketOutputBitrate == 0 && previousSocketOutputBitrate == 0 && previousPreviousSocketOutputBitrate == 0)
        
        print("STATUS: \(statusString)")

	    if somethingIsWrongWithNetwork || somethingIsWrongWithAudioVideoInput
	    {
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

	fileprivate var previousTotalAudioBytes: Int = -1
	fileprivate var previousTotalVideoBytes: Int = -1
	fileprivate var previousSocketOutputBitrate: Double = -1
	fileprivate var previousPreviousTotalAudioBytes: Int = -2
	fileprivate var previousPreviousTotalVideoBytes: Int = -2
	fileprivate var previousPreviousSocketOutputBitrate: Double = -2
    
    var notEnoughBandwidth: Bool = false
}
