//
//  DownloadTracker.swift
//  SDEDownloadManager
//
//  Created by seedante on 6/10/17.
//
//  Copyright (c) 2017 seedante <seedante@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

internal class DownloadTracker {
    unowned var downloadManager: SDEDownloadManager
    init(downloadManager: SDEDownloadManager) {
        self.downloadManager = downloadManager
    }
    
    /// Only isTrackingDownload and isTimerFired both are YES, DownloadTracker is really tracking.
    var isTrackingDownload: Bool = false
    /// After beginTrackingDownloadActivity() is called, isTrackingDownload is set to true immediately, isTimeFired is set to true 1s later.
    var isTimerFired: Bool = false
    weak var trackTimer: Timer?
    
    /// If 'downloadActivityHandler' is not nil, call this method to display download activity; or call 'beginDisplayingDownloadWithBlock:'.
    /// This method automatically stop displaying download activity after there is no more downloading task.
    func beginTrackingDownloadActivity(){
        guard downloadManager.downloadActivityHandler != nil || downloadManager.objcDownloadActivityHandler != nil else{
            debugNSLog("It makes no sense if downloadActivityHandler is nil")
            return
        }
        // Can't use Timer's valid to judge if it's in monitoring. A Timer always is valid until invalid it.
        // Timer cann't be reused after it's invalid, the newest documents remove this info.
        // http://stackoverflow.com/questions/9256981/how-to-validate-a-nstimer-after-invalidating-it
        // Why not check running task count? Because download task maybe doesn't start yet.
        if !isTrackingDownload && (downloadManager.countOfPendingTask > 0 || downloadManager.countOfRunningTask > 0){
            isTrackingDownload = true
            
            trackFromBackgroundThread()
        }
    }
    
    func stopTrackingDownloadActivity(){
        if isTrackingDownload{
            trackTimer?.invalidate()
            isTrackingDownload = false
            isTimerFired = false
            trackedTaskURLStringSet = Set(receivedBytesInfo.keys)
            receivedBytesInfo.removeAll()
            expectedBytesInfo.removeAll()
        }
    }
    
    func trackFromMainThread(){
        // timer has strong reference to the target, runloop has strong reference to the timer.
        let timer = Timer.init(timeInterval: 1, target: self, selector: #selector(switchToBackground), userInfo: nil, repeats: true)
        self.trackTimer = timer
        // Timer still work when scrolling only in NSRunLoopCommonMode
        // But Timer won't run after app enter background.
        RunLoop.current.add(timer, forMode: .commonModes)
    }
    
    func trackFromBackgroundThread(){
        let thread = Thread.init(target: self, selector: #selector(addTimer), object: nil)
        thread.name = "TrackDownloadActivity"
        thread.start()
    }
    
    func trackFromGCD() {
        // As an optimization, 'sync' function invokes the block on the current thread when possible.
        // Test in main thread, timer is fired in main thread runloop.
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            Thread.current.name = "TrackDownloadActivity"
            self.trackTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.trackDownloadActivity), userInfo: nil, repeats: true)
            RunLoop.current.run(mode: .defaultRunLoopMode, before: .distantFuture)
        }
    }
    
    @objc func addTimer() {
        self.trackTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(trackDownloadActivity), userInfo: nil, repeats: true)
        RunLoop.current.run(mode: .defaultRunLoopMode, before: .distantFuture)
    }
    
    @objc func switchToBackground() {
        DispatchQueue.global().async(execute: { [unowned self] in
            self.trackDownloadActivity()
        })
    }
    
    @objc func trackDownloadActivity(){
        if self.downloadManager.countOfRunningTask == 0{
            DispatchQueue.global().async(execute: { [unowned self] in
                self.downloadManager.saveData()
            })
            
            self.trackTimer?.invalidate()
            self.isTrackingDownload = false
            self.isTimerFired = false
            self.lastCountOfExecutingTask = 0
            self.downloadManager.tuningMaxConcurrentOperationCount()
            self.downloadManager.downloadCompletionHandler?()
        }else if self.isTimerFired == false{
            self.isTimerFired = true
        }
        
        if let handler = self.downloadManager.objcDownloadActivityHandler{
            handler(self.objcActivityInfo)
        }else if let handler = self.downloadManager.downloadActivityHandler{
            handler(self.activityInfo)
        }
    }
    
    var didExecutingTasksChanged: Bool{
        return isExecutingTaskCountChanged || isAnyTaskCompletedOrPaused
    }
    var lastCountOfExecutingTask: Int = 0
    var isExecutingTaskCountChanged: Bool = false
    var isAnyTaskCompletedOrPaused: Bool = false
        
    var receivedBytesInfo: Dictionary<String, Int64> = [:]
    var expectedBytesInfo: Dictionary<String, Int64> = [:]
    var completedTaskInfo: Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, detailInfo: String?)> = [:]
    var trackedTaskURLStringSet: Set<String> = []
    
    var activityInfo: Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, speed: Int64, detailInfo: String?)>{
        var speedInfo: Dictionary<String, Int64> = collectSpeedInfo()
        // Archive speed and progress of non-executing task which is completed or paused
        var currentReceivedBytesInfo = receivedBytesInfo
        var currentExpectedBytesInfo = expectedBytesInfo
        var detailInfo: Dictionary<String, String> = [:]
        if completedTaskInfo.count > 0{
            completedTaskInfo.forEach({ (URLString, infoTuple) in
                speedInfo[URLString] = EMPTYSPEED
                detailInfo[URLString] = infoTuple.detailInfo
                currentReceivedBytesInfo[URLString] = infoTuple.receivedBytes
                currentExpectedBytesInfo[URLString] = infoTuple.expectedBytes
            })
            completedTaskInfo.removeAll()
            isAnyTaskCompletedOrPaused = true
        }else{
            isAnyTaskCompletedOrPaused = false
        }
        
        var downloadActivity: Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, speed: Int64, detailInfo: String?)> = [:]
        speedInfo.forEach({ URLString, speed in
            downloadActivity[URLString] = (currentReceivedBytesInfo[URLString]!, currentExpectedBytesInfo[URLString]!, speed, detailInfo[URLString])
        })
        
        return downloadActivity
    }
    
    var objcActivityInfo: Dictionary<String, Dictionary<String, Any>>{
        var speedInfo: Dictionary<String, Int64> = collectSpeedInfo()
        // Archive speed and progress of non-executing task which is completed or paused
        var currentReceivedBytesInfo = receivedBytesInfo
        var currentExpectedBytesInfo = expectedBytesInfo
        var detailInfo: Dictionary<String, String> = [:]
        if completedTaskInfo.count > 0{
            completedTaskInfo.forEach({ (URLString, infoTuple) in
                speedInfo[URLString] = EMPTYSPEED
                detailInfo[URLString] = infoTuple.detailInfo
                currentReceivedBytesInfo[URLString] = infoTuple.receivedBytes
                currentExpectedBytesInfo[URLString] = infoTuple.expectedBytes
            })
            completedTaskInfo.removeAll()
            isAnyTaskCompletedOrPaused = true
        }else{
            isAnyTaskCompletedOrPaused = false
        }

        var downloadActivity: Dictionary<String, Dictionary<String, Any>> = [:]
        speedInfo.forEach({ URLString, speed in
            var activity: Dictionary<String, Any> = ["receivedBytes": currentReceivedBytesInfo[URLString]!, "expectedBytes": currentExpectedBytesInfo[URLString]!, "speed": speed]
            if let info =  detailInfo[URLString]{
                activity["detailInfo"] = info
            }
            downloadActivity[URLString] = activity
        })
        return downloadActivity
    }
    
    // 1. speed = currentReceivedBytes - lastSecondReceivedBytes
    // 2. except executing tasks, tasks which are paused or stopped in last 1s, need to update
    // 3. after a task is .finished, its info of receivedBytes and expectedBytes are cleaned
    func collectSpeedInfo() -> Dictionary<String, Int64>{
        var speedInfo: Dictionary<String, Int64> = [:]
        
        // Archive speed and progress info of executing task
        var currentCountOfExecutingTask: Int = 0
        let allOPs = downloadManager.downloadQueue.operations as! [DownloadOperation]
        for operation in allOPs {
            guard operation.isExecuting else{continue}
            currentCountOfExecutingTask += 1
            
            var speed: Int64 = 0
            let URLString = operation.URLString
            if let currentReceivedBytes = operation.downloadTask?.countOfBytesReceived{
                // Fetch file size
                if let _ = expectedBytesInfo[URLString]{
                }else if let expectedBytes = operation.downloadTask?.countOfBytesExpectedToReceive, expectedBytes > 0{
                    expectedBytesInfo[URLString] = expectedBytes
                }else if let fileSize = downloadManager.downloadTaskInfo[URLString]?[TIFileByteCountInt64Key] as? Int64{
                    expectedBytesInfo[URLString] = fileSize
                }else{
                    expectedBytesInfo[URLString] = UNKNOWNSIZE
                }
                
                // Calculate speed and fetch recevied size.
                // difficulty point:
                // 1. resume a Stopped task with recovery data: sometimes countOfBytesReceived: 0, downloadedSize, *, *, *...
                // 2. exit VC and enter it again: track is aborted after exitting VC, data in receivedBytesInfo is not longer right,
                //  so receivedBytesInfo and expectedBytesInfo are cleaned after exit. First speed of enter VC again is unknown.
                if let lastReceivedBytes = receivedBytesInfo[URLString], lastReceivedBytes > 0{
                    if currentReceivedBytes > 0{
                        receivedBytesInfo[URLString] = currentReceivedBytes
                    }
                    speed = currentReceivedBytes <= lastReceivedBytes ? 0 : currentReceivedBytes - lastReceivedBytes
                }else if currentReceivedBytes > 0{ // it's first time to receive data, or enter a VC again for executing task
                    receivedBytesInfo[URLString] = currentReceivedBytes
                    if trackedTaskURLStringSet.contains(URLString){// exit a VC and enter it again
                        speed = -10
                    }else if let _ = downloadManager.downloadTaskInfo[URLString]?[TIResumeDataKey]{ // resume a Stopped task
                        speed = 0 // here currentReceivedBytes is real downloaded size before resuming
                    }else{// receive data the first time really
                        speed = currentReceivedBytes
                    }
                }else{ // task receive no data yet, and have to keep receivedBytesInfo and expectedBytesInfo same count.
                    receivedBytesInfo[URLString] = 0
                }
            }
            speedInfo[URLString] = speed
        }
        
        isExecutingTaskCountChanged = currentCountOfExecutingTask != lastCountOfExecutingTask
        lastCountOfExecutingTask = currentCountOfExecutingTask

        // trackedTaskURLStringSet is one-off, only works when exit a VC and enter it again
        if trackedTaskURLStringSet.count > 0{
            trackedTaskURLStringSet.removeAll()
        }
        
        return speedInfo
    }
    
    /// If a download task is not executing any more, clean its info, and exception: task is Paused or Stopped by cancelByProducingResumeData:
    func completeTask(_ URLString: String, infoTuple: (receivedBytes: Int64, expectedBytes: Int64, detailInfo: String?), cleanLastBytesInfo clean: Bool = true){
        completedTaskInfo[URLString] = infoTuple
        if clean{
            receivedBytesInfo.removeValue(forKey: URLString)
            expectedBytesInfo.removeValue(forKey: URLString)
        }
    }
    
    func cleanInfoOfTask(_ URLString: String){
        receivedBytesInfo.removeValue(forKey: URLString)
        expectedBytesInfo.removeValue(forKey: URLString)
        completedTaskInfo.removeValue(forKey: URLString)
        trackedTaskURLStringSet.remove(URLString)
    }
}
