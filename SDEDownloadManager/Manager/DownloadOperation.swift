//
//  DownloadOperation.swift
//  SDEDownloadManager
//
//  Created by seedante on 6/13/17.
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

import Foundation

internal class DownloadOperation: Operation {
    weak var downloadManager: SDEDownloadManager?
    unowned var session: URLSession
    let URLString: String
    var downloadTask: URLSessionDownloadTask?
    var resumeData: Data?
    var downloadURL: URL?

    let stateKeyPath: String = #keyPath(URLSessionTask.state)
    private var privateContext: UInt8 = 0
    private(set) var started: Bool = false
    
    private var _finished: Bool = false
    override private(set) var isFinished: Bool{
        get {return _finished}
        set{
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    private var _executing: Bool = false
    override private(set) var isExecuting: Bool{
        get {return _executing}
        set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    
    // MARK: init
    override init() {
        fatalError("Use init(session:downloadURL:) or init(session:URLString:resumeData:)")
    }
    
    init(session: URLSession, downloadURL: URL) {
        self.session = session
        self.downloadURL = downloadURL
        self.URLString = downloadURL.absoluteString
        super.init()
        self.name = self.URLString
    }
    
    init(session: URLSession, URLString: String, resumeData: Data? = nil) {
        self.session = session
        self.URLString = URLString
        self.resumeData = resumeData
        super.init()
        self.name = URLString
    }
    
    // MARK: Overide
    /**
    The default implementation of start() is like this:
    func start() {
        if !isCancelled{
            executing = true
            main()
            executing = false
        }
        isFinished = true
    }
    */
    override func start() {
        if isCancelled{
            endOperation()
        }else if !started{
            if resumeData == nil{
                downloadTask = self.session.downloadTask(with: (downloadURL ?? URL.init(string: URLString)!))
            }else{
                if OSVersion.majorVersion == 10 && OSVersion.minorVersion < 2{
                    downloadTask = self.fixedDownloadTask
                }else{
                    downloadTask = self.session.downloadTask(withResumeData: resumeData!)
                }
            }
            downloadTask?.addObserver(self, forKeyPath: stateKeyPath, options: [.new, .old], context: &privateContext)
            downloadTask?.taskDescription = URLString
            started = true
            resume()
        }
    }
    
    /**
     Cancelling an operation allows the operation queue to call the operation's start method sooner and clear the object
     out of the queue. How sooner? cancel() remove dependency and make the operation to ready, that's all. And operation
     queue still call start() even call cancel() before.
     
     It's dispointed that there is no appropriate way to make operation queue don't call start() without mistake. Two ways
     to make an operation don't call start():
     
     1. KVO of 'finished == true' is only way to end an operation. Overriding 'finished' and posting its KVO manually to
        finish an operation before start() sounds good. 'finished' KVO will make operation queue to start another
        operation(it's normal), but this way(post a finished KVO before start()) make it happen even count of started
        operation has reached 'maxConcurrentOperationCount' of operation queue, it's not OK.
     2. It's weird that KVO of 'executing == true' also can make an operation don't call start(). But, the operation
        will be never finished and operation queue keep it in 'operations' forever, and then KVO of 'finished == true'
        has same result with last way.
     
     What we can do is make operation queue to call the operation's start method soonest: adjust queuePriority = .veryHigh.
     
     Here cancel() is just to stop execution of task, delete() to delete downloaded file.
     */
    override func cancel() {
        super.cancel()
        if !started{
            // make operation queue to call the operation's start method soonest.
            queuePriority = .veryHigh
        }else{
            self.downloadTask?.cancel(byProducingResumeData: {_ in })
        }
    }
    
    // MARK: Action
    func resume() {
        guard started else{
            debugNSLog("Operation must be started by the queue. \(URLString)")
            return
        }
        
        if downloadTask?.state == .suspended{
            if let receivedByteCount = downloadManager?.downloadTaskInfo[URLString]?[TIReceivedByteCountInt64Key] as? Int64{
                downloadManager?.downloadTracker.receivedBytesInfo[URLString] = receivedByteCount
            }
            //TIDownloadDetailStringKey: TIDeleteValueMark
            downloadManager?.updateMetaInfo([TITaskStateIntKey: DownloadState.downloading.rawValue,
                                             TIDownloadDetailStringKey: TIDeleteValueMark,
                                             TIReceivedByteCountInt64Key: TIDeleteValueMark,
                                             TIProgressFloatKey: TIDeleteValueMark
                ], forTask: URLString)
            downloadManager?.removeRecordInWaittingTaskQueueForTask(URLString)
            isExecuting = true
            downloadTask?.resume()
        }
    }
    
    lazy var formatter = ByteCountFormatter()
    func suspend(){
        guard started else{
            debugNSLog("Before suspend, operation must be started by the queue: %@", URLString)
            return
        }
        if downloadTask?.state == .running{
            isExecuting = false
            downloadTask?.suspend()
            var info: Dictionary<String, Any> = [TITaskStateIntKey: DownloadState.paused.rawValue]
            if let fileSize = downloadTask?.countOfBytesExpectedToReceive, let receivedSize = downloadTask?.countOfBytesReceived{
                var fileSizeFormat: String
                if fileSize > 0{
                    info[TIFileByteCountInt64Key] = fileSize
                    info[TIProgressFloatKey] = Float(receivedSize) / Float(fileSize)
                    fileSizeFormat = formatter.string(fromByteCount: fileSize)
                }else if let fileSizeInt64 = downloadManager?.downloadTaskInfo[URLString]?[TIFileByteCountInt64Key] as? Int64{
                    fileSizeFormat = formatter.string(fromByteCount: fileSizeInt64)
                }else{
                    fileSizeFormat = SDEPlaceHolder
                }
                
                let receivedSizeFormat: String = receivedSize <= 0 ? "0 KB" : formatter.string(fromByteCount: receivedSize)
                let detailText: String = receivedSizeFormat + "/" + fileSizeFormat
                
                info[TIDownloadDetailStringKey] = detailText
                info[TIReceivedByteCountInt64Key] = receivedSize
                downloadManager?.downloadTracker.completeTask(URLString, infoTuple: (receivedSize, fileSize, detailText), cleanLastBytesInfo: false)
            }
            downloadManager?.updateMetaInfo(info, forTask: URLString)
        }
    }

    func stop(){
        if started{
            debugNSLog("stop download: %@", URLString)
            downloadTask?.cancel(byProducingResumeData: {_ in})
        }else{
            super.cancel()
            queuePriority = .veryHigh
        }
    }
    
    func delete(){
        if started{
            downloadTask?.cancel()
        }else{
            if resumeData != nil{
                self.session.downloadTask(withResumeData: resumeData!).cancel()
            }
            super.cancel()
            queuePriority = .veryHigh
        }
    }
    
    func cleanResumeData(){
        resumeData = nil
    }
    
    // After isFinished = true, Operation is deinited immediately.
    private func endOperation(){
        isExecuting = false
        isFinished = true
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &privateContext, let observeredKeyPath = keyPath, let changeInfo = change else{return}
        if observeredKeyPath == stateKeyPath, let newValue = changeInfo[NSKeyValueChangeKey.newKey] as? Int, let oldValue = changeInfo[NSKeyValueChangeKey.oldKey] as? Int{
            // There are some repeats in state change of URLSessionTask: suspended -> suspended, running -> running and completed -> completed,
            // after other state change to there states first time.
            //
            // When to endOperation, otherState -> Completed, or Completed -> Completed? Any. Here I choose 2nd.
//            #if DEBUG
//                let newState = URLSessionTask.State(rawValue: newValue)
//                let oldState = URLSessionTask.State(rawValue: oldValue)
//                let fileName = (URLString as NSString).lastPathComponent
//                NSLog("URLSessionDownloadTask for: \(fileName) State change from \(oldState!.description) to \(newState!.description)")
//            #endif
            if newValue == URLSessionTask.State.completed.rawValue && newValue == oldValue{
                downloadTask?.removeObserver(self, forKeyPath: stateKeyPath)
                endOperation()
            }
        }
    }
    
    // MARK: Fix resumeData issue on iOS 10.0~10.1
    // iOS 10.0~10.1, URLSessionDownloadTask can't parse resumeData correctly: https://forums.developer.apple.com/thread/63585
    // Solution: https://stackoverflow.com/questions/39346231/resume-nsurlsession-on-ios10/39347461#39347461
    // Here get "-[NSKeyedUnarchiver initForReadingWithData:]: data is NULL" still, but it can resume.
    lazy var OSVersion = ProcessInfo().operatingSystemVersion
    lazy var fixedDownloadTask: URLSessionDownloadTask = {
        func correct(requestData data: Data?) -> Data? {
            guard let data = data else {
                return nil
            }
            if NSKeyedUnarchiver.unarchiveObject(with: data) != nil {
                return data
            }
            guard let archive = (try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: nil)) as? NSMutableDictionary else {
                return nil
            }
            // Rectify weird __nsurlrequest_proto_props objects to $number pattern
            var k = 0
            while ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "$\(k)") != nil {
                k += 1
            }
            var i = 0
            while ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_prop_obj_\(i)") != nil {
                let arr = archive["$objects"] as? NSMutableArray
                if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_prop_obj_\(i)"] {
                    dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                    dic.removeObject(forKey: "__nsurlrequest_proto_prop_obj_\(i)")
                    arr?[1] = dic
                    archive["$objects"] = arr
                }
                i += 1
            }
            if ((archive["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_props") != nil {
                let arr = archive["$objects"] as? NSMutableArray
                if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_props"] {
                    dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                    dic.removeObject(forKey: "__nsurlrequest_proto_props")
                    arr?[1] = dic
                    archive["$objects"] = arr
                }
            }
            /* I think we have no reason to keep this section in effect
             for item in (archive["$objects"] as? NSMutableArray) ?? [] {
             if let cls = item as? NSMutableDictionary, cls["$classname"] as? NSString == "NSURLRequest" {
             cls["$classname"] = NSString(string: "NSMutableURLRequest")
             (cls["$classes"] as? NSMutableArray)?.insert(NSString(string: "NSMutableURLRequest"), at: 0)
             }
             }*/
            // Rectify weird "NSKeyedArchiveRootObjectKey" top key to NSKeyedArchiveRootObjectKey = "root"
            if let obj = (archive["$top"] as? NSMutableDictionary)?.object(forKey: "NSKeyedArchiveRootObjectKey") as AnyObject? {
                (archive["$top"] as? NSMutableDictionary)?.setObject(obj, forKey: NSKeyedArchiveRootObjectKey as NSString)
                (archive["$top"] as? NSMutableDictionary)?.removeObject(forKey: "NSKeyedArchiveRootObjectKey")
            }
            // Reencode archived object
            let result = try? PropertyListSerialization.data(fromPropertyList: archive, format: .xml, options: 0)
            return result
        }
        
        func getResumeDictionary(_ data: Data) -> NSMutableDictionary? {
            // In beta versions, resumeData is NSKeyedArchive encoded instead of plist
            var iresumeDictionary: NSMutableDictionary? = nil
            if #available(iOS 10.0, OSX 10.12, *) {
                var root : Any? = nil
                let keyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
                
                do {
                    root = try keyedUnarchiver.decodeTopLevelObject(forKey: "NSKeyedArchiveRootObjectKey") ?? nil
                    if root == nil {
                        root = try keyedUnarchiver.decodeTopLevelObject(forKey: NSKeyedArchiveRootObjectKey)
                    }
                } catch {}
                keyedUnarchiver.finishDecoding()
                iresumeDictionary = root as? NSMutableDictionary
                
            }
            
            if iresumeDictionary == nil {
                do {
                    iresumeDictionary = try PropertyListSerialization.propertyList(from: data, options: [.mutableContainers], format: nil) as? NSMutableDictionary;
                } catch {}
            }
            
            return iresumeDictionary
        }
        
        func correctResumeData(_ data: Data?) -> Data? {
            let kResumeCurrentRequest = "NSURLSessionResumeCurrentRequest"
            let kResumeOriginalRequest = "NSURLSessionResumeOriginalRequest"
            
            guard let data = data, let resumeDictionary = getResumeDictionary(data) else {
                return nil
            }
            
            resumeDictionary[kResumeCurrentRequest] = correct(requestData: resumeDictionary[kResumeCurrentRequest] as? Data)
            resumeDictionary[kResumeOriginalRequest] = correct(requestData: resumeDictionary[kResumeOriginalRequest] as? Data)
            
            let result = try? PropertyListSerialization.data(fromPropertyList: resumeDictionary, format: .xml, options: 0)
            return result
        }
        
        func correctedDownloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
            let kResumeCurrentRequest = "NSURLSessionResumeCurrentRequest"
            let kResumeOriginalRequest = "NSURLSessionResumeOriginalRequest"
            
            let cData = correctResumeData(resumeData) ?? resumeData
            let task = self.session.downloadTask(withResumeData: cData)
            
            // a compensation for inability to set task requests in CFNetwork.
            // While you still get -[NSKeyedUnarchiver initForReadingWithData:]: data is NULL error,
            // this section will set them to real objects
            if let resumeDic = getResumeDictionary(cData) {
                if task.originalRequest == nil, let originalReqData = resumeDic[kResumeOriginalRequest] as? Data, let originalRequest = NSKeyedUnarchiver.unarchiveObject(with: originalReqData) as? NSURLRequest {
                    task.setValue(originalRequest, forKey: "originalRequest")
                }
                if task.currentRequest == nil, let currentReqData = resumeDic[kResumeCurrentRequest] as? Data, let currentRequest = NSKeyedUnarchiver.unarchiveObject(with: currentReqData) as? NSURLRequest {
                    task.setValue(currentRequest, forKey: "currentRequest")
                }
            }
            
            return task
        }
        
        return correctedDownloadTask(withResumeData: self.resumeData!)
    }()
}
