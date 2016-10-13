import Foundation

class NetSocket: NSObject {
    static let defaultTimeout:Int64 = 15 // sec
    static let defaultWindowSizeC:Int = 1024 * 1

    var timeout:Int64 = NetSocket.defaultTimeout
    var connected:Bool = false
    var inputBuffer:[UInt8] = []
    var inputStream:InputStream?
    var windowSizeC:Int = NetSocket.defaultWindowSizeC
    var outputStream:OutputStream?
    var networkQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetSocket.network", attributes: []
    )
    var securityLevel:StreamSocketSecurityLevel = .none
    private(set) var totalBytesIn:Int64 = 0
    private(set) var totalBytesOut:Int64 = 0

    private var runloop:RunLoop?
    private let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetSocket.lock", attributes: []
    )
    fileprivate var timeoutHandler:(() -> Void)?

    var totalBytesInQueue: Int = 0

    private(set) var outputBitrate: Double = 0
    fileprivate var bytesOutInLastMeasurement: Int = 0
    fileprivate var lastBitrateMeasurementTime: Double = 0
    fileprivate var bitrateMeasureTimer: Timer?

    @discardableResult
    final func doOutput(data:Data) -> Int {
        totalBytesInQueue += data.count

        lockQueue.async {
            self.doOutputProcess((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
        return data.count
    }

    @discardableResult
    final func doOutput(bytes:[UInt8]) -> Int {

        totalBytesInQueue += bytes.count

        lockQueue.async {
            self.doOutputProcess(UnsafePointer<UInt8>(bytes), maxLength: bytes.count)
        }
        return bytes.count
    }

    final func doOutputFromURL(_ url:URL, length:Int) {
        lockQueue.async {
            do {
                let fileHandle:FileHandle = try FileHandle(forReadingFrom: url)
                defer {
                    fileHandle.closeFile()
                }
                let endOfFile:Int = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seek(toFileOffset: UInt64(i * length))
                    self.doOutputProcess(fileHandle.readData(ofLength: length))
                }
                let remain:Int = endOfFile % length
                if (0 < remain) {
                    self.doOutputProcess(fileHandle.readData(ofLength: remain))
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    final func doOutputProcess(_ data:Data) {
        doOutputProcess((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
    }

    final func doOutputProcess(_ buffer:UnsafePointer<UInt8>, maxLength:Int) {
        guard let outputStream:OutputStream = outputStream else {
            return
        }
        var total:Int = 0
        while total < maxLength {
            let length:Int = outputStream.write(buffer.advanced(by: total), maxLength: maxLength - total)
            if (length <= 0) {
                break
            }
            total += length
            totalBytesOut += Int64(length)
        }

        //track data that waits to be sent
        totalBytesInQueue -= maxLength
        if totalBytesInQueue < 0 {
            totalBytesInQueue = 0
        }


        bytesOutInLastMeasurement += maxLength
    }
    
    @objc func measureBitrate()
    {
        let now = CFAbsoluteTimeGetCurrent()
        
        outputBitrate = Double(bytesOutInLastMeasurement) / (now - lastBitrateMeasurementTime)

        lastBitrateMeasurementTime = now
        bytesOutInLastMeasurement = 0
    }

    func close(isDisconnected:Bool) {
        lockQueue.async {
            guard let runloop = self.runloop else {
                return
            }
            self.deinitConnection(isDisconnected: isDisconnected)
            self.runloop = nil
            CFRunLoopStop(runloop.getCFRunLoop())
            logger.verbose("isDisconnected:\(isDisconnected)")
        }
    }

    func listen() {
    }

    func initConnection() {
        totalBytesIn = 0
        totalBytesOut = 0
        timeoutHandler = didTimeout
        inputBuffer.removeAll(keepingCapacity: false)

        guard let inputStream:InputStream = inputStream, let outputStream:OutputStream = outputStream else {
            return
        }

        runloop = .current

        inputStream.delegate = self
        inputStream.schedule(in: runloop!, forMode: .defaultRunLoopMode)
        inputStream.setProperty(securityLevel.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)

        outputStream.delegate = self
        outputStream.schedule(in: runloop!, forMode: .defaultRunLoopMode)
        outputStream.setProperty(securityLevel.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)

        inputStream.open()
        outputStream.open()
        
        bitrateMeasureTimer?.invalidate()
        bitrateMeasureTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(measureBitrate), userInfo: nil, repeats: true)

        if (0 < timeout) {
            lockQueue.asyncAfter(deadline: DispatchTime.now() + Double(timeout * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                guard let timeoutHandler:(() -> Void) = self.timeoutHandler else {
                    return
                }
                timeoutHandler()
            }
        }

        runloop?.run()
        connected = false
    }

    func deinitConnection(isDisconnected:Bool) {
        inputStream?.close()
        inputStream?.remove(from: runloop!, forMode: .defaultRunLoopMode)
        inputStream?.delegate = nil
        inputStream = nil
        outputStream?.close()
        outputStream?.remove(from: runloop!, forMode: .defaultRunLoopMode)
        outputStream?.delegate = nil
        outputStream = nil
        
        bitrateMeasureTimer?.invalidate()
        bitrateMeasureTimer = nil
    }

    func didTimeout() {
    }

    fileprivate func doInput() {
        guard let inputStream = inputStream else {
            return
        }
        var buffer:[UInt8] = [UInt8](repeating: 0, count: windowSizeC)
        let length:Int = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            totalBytesIn += Int64(length)
            inputBuffer.append(contentsOf: buffer[0..<length])
            listen()
        }
    }
}


extension NetSocket: StreamDelegate {
    // MARK: StreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        //  1 = 1 << 0
        case Stream.Event.openCompleted:
            guard let inputStream = inputStream, let outputStream = outputStream,
                inputStream.streamStatus == .open && outputStream.streamStatus == .open else {
                break
            }
            if (aStream == inputStream) {
                timeoutHandler = nil
                connected = true
            }
            print("Stream connected")
        //  2 = 1 << 1
        case Stream.Event.hasBytesAvailable:
            if (aStream == inputStream) {
                doInput()
            }
        //  4 = 1 << 2
        case Stream.Event.hasSpaceAvailable:
            break
        //  8 = 1 << 3
        case Stream.Event.errorOccurred:
            close(isDisconnected: true)
            print("Stream error occurred")
        // 16 = 1 << 4
        case Stream.Event.endEncountered:
            close(isDisconnected: true)
            print("Stream end")
        default:
            break
        }
    }
}
