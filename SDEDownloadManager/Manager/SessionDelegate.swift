//
//  SDESessionDelegate.swift
//  SDEDownloadManager
//
//  Created by seedante on 5/16/17.
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

internal class SDESessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var downloadManager: SDEDownloadManager!
    let formatter = ByteCountFormatter()
    var processingTempFileTaskSet: Set<String> = []
    var processingTemporaryFileNotificationSet: Set<String> = []
    
    func waitForDownloadManagerLoadData(){
        while !(downloadManager._isDataLoaded) {
            debugNSLog("Wait for DownloadManager \(downloadManager!.identifier) to load data...")
        }
    }

    // MARK: - NSURLSessionDelegate
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        downloadManager?.saveData()
    }
    
    // Authentication Challenges and TLS Chain Validation:
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/URLLoadingSystem/Articles/AuthenticationChallenges.html#//apple_ref/doc/uid/TP40009507-SW1
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let handler = downloadManager.sessionDidReceiveChallengeHandler{
            handler(session, challenge, completionHandler)
            return
        }
        
        var position: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodNTLM:
            debugNSLog("Session Auth: NTLM. This part is not finished.")
        case NSURLAuthenticationMethodNegotiate:
            debugNSLog("Session Auth: Negotiate. This part is not finished.")
        case NSURLAuthenticationMethodClientCertificate:
            debugNSLog("session Auch: Client Certificate. This part is not finished.")
        case NSURLAuthenticationMethodServerTrust:
            debugNSLog("Session Auth: Server Trust.")
            guard let serverTrust = challenge.protectionSpace.serverTrust else{
                debugNSLog("proposedCredential is nil and no server trust, perform default handling.")
                break
            }
            position = .useCredential
            credential = URLCredential.init(trust: serverTrust)
        default:
            debugNSLog("Not session-level challenge: %@. Handle in urlSession(_:task:didReceiveChallenge:completionHandler:) method if implemented.", challenge.protectionSpace.authenticationMethod)
        }
        
        completionHandler(position, credential)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        waitForDownloadManagerLoadData()
        downloadManager.saveData()
        downloadManager.backgroundSessionDidFinishEventsHandler?(session)
    }
        
    // MARK: - NSURLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadManager?.downloadTaskWriteDataHandler?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        downloadManager?.downloadTaskResumeHandler?(session, downloadTask, fileOffset, expectedTotalBytes)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        waitForDownloadManagerLoadData()
        guard let URLString = fetchURLFromTask(downloadTask) else{
            debugNSLog("didFinishDownloadingToURL: Can't fetch valid URL from downloadTask: %@", downloadTask)
            return
        }
        
        guard let dm = downloadManager else{return}
        let downloadTracker = dm.downloadTracker
        guard let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode else{
            debugNSLog("Can't get status code")
            return
        }
        
        switch statusCode {
        case 200...206:
            let fileStoreName: String
            if let suggestedFileName = downloadTask.response?.suggestedFilename{
                fileStoreName = suggestedFileName
            }else{
                fileStoreName = dm.downloadTaskInfo[URLString]?[TIFileNameStringKey] as! String
            }
            
            // File URL convert to file path: use 'path', not 'absoluteString'.
            let documentDirectory = "Documents/"
            var storeURL = UserDirectoryURLFor(.documentDirectory).appendingPathComponent(fileStoreName)
            var relativePath: String = documentDirectory + fileStoreName
            /// URL.checkResourceIsReachable() won't return false if file is not existed, it throws an error.
            /// URL document says it returns false for other URL types, actually, it still throws an error.
            /// NSURL.checkResourceIsReachableAndReturnError(_:) could do it.
            if FileManager.default.fileExists(atPath: storeURL.path){
                // absoluteString will return a string begins with "file:///"
                // FileManager.contentsEqual(atPath: storeURL.path, andPath: location.path)
                debugNSLog("File name clash and change the name to store: %@", URLString)
                var newFileName = appendRandomID(from: location.lastPathComponent, separateString: "_", into: fileStoreName)
                storeURL = UserDirectoryURLFor(.documentDirectory).appendingPathComponent(newFileName)
                while FileManager.default.fileExists(atPath: storeURL.path){
                    debugNSLog("Name clash again. It's rare. Change name again with UUID.")
                    newFileName = appendRandomID(from: UUID().uuidString, separateString: "-", into: fileStoreName)
                    storeURL = UserDirectoryURLFor(.documentDirectory).appendingPathComponent(newFileName)
                }
                debugNSLog("New store name: %@", newFileName)
                relativePath = documentDirectory + newFileName
            }
            
            // Update task info here because handling file is a little long process, URLSession(_:task:didCompleteWithError:) maybe end before 
            // this method in the concurrent mode and NNDownloadIsCompletedBeforeTrackNotification is not handled at right time.
            let fileByteCount: Int64
            // Sometimes server's response is not right.
            if downloadTask.countOfBytesExpectedToReceive > 0 && downloadTask.countOfBytesReceived <= downloadTask.countOfBytesExpectedToReceive{
                fileByteCount = downloadTask.countOfBytesExpectedToReceive
            }else{
                // Then you need to check file real size. It's troublesome to handle error, so, just stop here.
                fileByteCount = downloadTask.countOfBytesReceived
            }
            let fileByteCountFormatString = formatter.string(fromByteCount: fileByteCount)
            
            let info: Dictionary<String, Any> = [TITaskStateIntKey: DownloadState.finished.rawValue,
                                     TIFileByteCountInt64Key: fileByteCount,
                                     TIDownloadDetailStringKey: fileByteCountFormatString,
                                     TIFileLocationStringKey: relativePath,
                                     TIProgressFloatKey: TIDeleteValueMark,
                                     TIResumeDataKey: TIDeleteValueMark,
                                     TIReceivedByteCountInt64Key: TIDeleteValueMark
                                    ]
            dm.updateMetaInfo(info, forTask: URLString)
            dm.downloadTracker.completeTask(URLString, infoTuple: (fileByteCount, fileByteCount, fileByteCountFormatString))
            
            if downloadTracker.isTrackingDownload == true && downloadTracker.isTimerFired == false{
                debugNSLog("%@ is downloaded before tracker work", URLString)
                // downloadTracker's time interval is 1s, if task is completed before downloadTracker start to track, there is no chance 
                // to update screen. if downloaded file is processing in URLSession(_:downloadTask:didFinishDownloadingToURL:), info on
                // screen will be not right.
                NotificationCenter.default.post(name: SDEDownloadManager.NNDownloadIsCompletedBeforeTrack,
                                                object: dm,
                                                userInfo: ["URLString": URLString])
            }
            
            // Begin to handle file
            processingTempFileTaskSet.insert(URLString)
            /*
             Usually moving temp file to other place is very very fast on iOS device, even file is very big, I test a 5 GB
             file on my iPad mini 1, it never take over 1s, most time it just take under 10ms. But if it take a long time.
             */
            DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                if self.processingTempFileTaskSet.contains(URLString){
                    debugNSLog("Process temporary file and post a notification for %@", URLString)
                    let info: Dictionary<String, Any> = [TIDownloadDetailStringKey: DMLS("Processing file...", comment: "Processing Temp File")]
                    dm.updateMetaInfo(info, forTask: URLString)
                    self.processingTemporaryFileNotificationSet.insert(URLString)
                    NotificationCenter.default.post(name: SDEDownloadManager.NNTemporaryFileIsProcessing,
                                                    object: dm,
                                                    userInfo: ["URLString": URLString])
                }
            })
            
            var fixedInfo: Dictionary<String, Any> = [:]
            // move temp file
            do{
                try FileManager.default.moveItem(at: location, to: storeURL)
            } catch let error as NSError{
                debugNSLog("Can't move temp file. Domain: %@ Code: %d Detail: %@", error.domain, error.code, error.localizedDescription)
                do{
                    try FileManager.default.copyItem(at: location, to: storeURL)
                } catch let copyError as NSError{
                    debugNSLog("Can't copy temp file also. Domain: %@ Code: %d Detail: %@", copyError.domain, copyError.code, copyError.localizedDescription)
                    fixedInfo[TITaskStateIntKey] = DownloadState.pending.rawValue
                    fixedInfo[TIProgressFloatKey] = 0.0
                    fixedInfo[TIDownloadDetailStringKey] = error.localizedDescription
                }
            }

            processingTempFileTaskSet.remove(URLString)
            
            // fixFinishedFileMissedIssues() or fixOperationMissedIssues() maybe override task state to .pending.
            let state = dm.downloadState(ofTask: URLString)
            if (state == .pending || state == .stopped) && FileManager.default.fileExists(atPath: storeURL.path){
                debugNSLog("Fix overrided state to .finished")
                fixedInfo[TITaskStateIntKey] = DownloadState.finished.rawValue
            }
            
            if processingTemporaryFileNotificationSet.contains(URLString){
                debugNSLog("Temporary file is processed and post a notification")
                processingTemporaryFileNotificationSet.remove(URLString)
                fixedInfo[TIDownloadDetailStringKey] =  fileByteCountFormatString
                dm.updateMetaInfo(fixedInfo, forTask: URLString)
                NotificationCenter.default.post(name: SDEDownloadManager.NNTemporaryFileIsProcessed,
                                                object: dm,
                                                userInfo: ["URLString": URLString])
            }else if fixedInfo.count > 0{
                debugNSLog("Fix info for %@", URLString)
                dm.updateMetaInfo(fixedInfo, forTask: URLString)
            }
            
            handleCompletionOfTask(URLString, fileLocation: storeURL, error: nil)
            if (!dm.downloadTracker.isTrackingDownload && dm.countOfRunningTask == 0) {
                dm.saveData()
            }
        default:
            debugNSLog("%@ File of %@ is downloaded already but not in the way we expected, status code: %d", #function, URLString, statusCode)
            break
        }
    }
    
    // MARK: Helper
    lazy var backgroundQueue = DispatchQueue.global(qos: .background)
    func handleCompletionOfTask(_ URLString: String, fileLocation: URL?, error: NSError?){
        var handler: ((_ URLString: String, _ fileLocation: URL?, _ error: NSError?) -> Void)?
        if let completionHandler = downloadManager?.taskHandlerDictionary[URLString]{
            downloadManager?.taskHandlerDictionary[URLString] = nil
            handler = completionHandler
        }else{
            handler = downloadManager?.taskSuccessOrFailHandler
        }
        
        if handler != nil{
            backgroundQueue.async(execute: {
                handler!(URLString, fileLocation, error)
            })
        }
    }
    
    /*
     The name of temporary file is like "CFNetworkDownload_T6QpCo.tmp", I extract "T6QpCo" and insert it into 
     original file name to reduce name clash, but this behavior increase the risk of lack of space.
     */
    func appendRandomID(from tempName: String, separateString: String, into originalName: String) -> String{
        let randomID = (tempName as NSString).deletingPathExtension.components(separatedBy: separateString).last ?? separateString
        let fileExtension = (originalName as NSString).pathExtension
        let fileNameWithoutExtension = (originalName as NSString).deletingPathExtension
        return fileNameWithoutExtension + "_" + randomID + "." + fileExtension
    }
    
    func fetchURLFromTask(_ task: URLSessionTask) -> String?{
        if let originalURL = task.originalURLString, downloadManager._downloadTaskSet.contains(originalURL){
            return originalURL
        }else if let currentURL = task.currentURLString, downloadManager._downloadTaskSet.contains(currentURL){
            return currentURL
        }else{
            return nil
        }
    }
    
    
    // MARK: - NSURLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        waitForDownloadManagerLoadData()
        guard let URLString = fetchURLFromTask(task) else{
            // It happens on iOS 8.x when you delete or move downloaded temporary file; it's fixed on iOS 9.x
            debugNSLog("didCompleteWithError: Can't fetch valid URL from task: %@", task)
            return
        }
        
        guard let dm = downloadManager else{return}
        let downloadTracker = dm.downloadTracker
        
        if error == nil{
            if let statusCode = (task.response as? HTTPURLResponse)?.statusCode{
                // HTTP Status Code Definitions: http://www.ietf.org/rfc/rfc2616.txt
                switch statusCode {
                case 200...206: return // handle it in URLSession(_:downloadTask:didFinishDownloadingToURL:)
                // On iOS 9.X, 404 error is here; On iOS 8.X(I just test on Simulator), 404 Error is here sometimes, most is included in 'error', code is 'NSURLErrorFileDoesNotExist';
                default:
                    let statusCodeDetail: String
                    if let codeDetail = HTTPStatusCodeDesriptionTable[statusCode]{
                        statusCodeDetail = "\(statusCode): \(codeDetail)"
                    }else{
                        statusCodeDetail = "ErrorCode: \(statusCode)"
                    }
                    
                    let info: Dictionary<String, Any> = [TITaskStateIntKey: DownloadState.pending.rawValue,
                                             TIProgressFloatKey: 0,
                                             TIDownloadDetailStringKey: statusCodeDetail,
                                             TIReceivedByteCountInt64Key: TIDeleteValueMark,
                                             ]
                    dm.updateMetaInfo(info, forTask: URLString)
                    downloadTracker.completeTask(URLString, infoTuple: (0, UNKNOWNSIZE, statusCodeDetail))
                    
                    // Handle download failure
                    if dm.taskSuccessOrFailHandler != nil || dm.taskHandlerDictionary[URLString] != nil{
                        var userInfo: Dictionary<String, Any> = [:]
                        userInfo["NSErrorFailingURLStringKey"] = URLString
                        userInfo["NSErrorFailingURLKey"] = URL.init(string: URLString)
                        userInfo["NSErrorHTTPStatusCode"] = statusCode
                        if let localizedDescription = HTTPStatusCodeDesriptionTable[statusCode]{
                            userInfo["NSLocalizedDescription"] = localizedDescription
                        }else{
                            userInfo["NSLocalizedDescription"] = "Unknown"
                        }
                        let errorCode: Int
                        if let code = HTTPStatusCodeMappingURLErrorCodeTable[statusCode]{
                            errorCode = code
                        }else{
                            errorCode = -1
                        }
                        let errorDIY = NSError(domain: NSURLErrorDomain,
                                               code: errorCode,
                                               userInfo: userInfo)
                        
                        handleCompletionOfTask(URLString, fileLocation: nil, error: errorDIY)
                    }
                }
            }else{// NSURLSession has not received response from server yet, I guess.
                // After downloadOperation resume, TIDownloadDetailStringKey, TIReceivedByteCountInt64Key and TIProgressFloatKey are deleted from downloadTaskInfo.
                var info: Dictionary<String, Any> = [:]
                
                let state = dm.resumeData(ofTask: URLString) == nil ? DownloadState.pending : DownloadState.stopped
                info[TITaskStateIntKey] = state.rawValue
                
                var receivedByteCount: Int64 = 0
                var receivedByteCountFormatString: String = "0 KB"
                if let resumeData = dm.resumeData(ofTask: URLString){
                    if let plistDic = (try? PropertyListSerialization.propertyList(from: resumeData as Data, options: [.mutableContainers], format: nil)) as? Dictionary<String, AnyObject>{
                        // iOS 8 Resume data keys: ["NSURLSessionResumeOriginalRequest", "NSURLSessionResumeBytesReceived", "NSURLSessionResumeServerDownloadDate", "NSURLSessionResumeCurrentRequest", "NSURLSessionResumeInfoLocalPath", "NSURLSessionResumeInfoVersion", "NSURLSessionDownloadURL"]
                        // iOS 9 Resume data keys: ["NSURLSessionResumeOriginalRequest", "NSURLSessionResumeBytesReceived", "NSURLSessionResumeServerDownloadDate", "NSURLSessionResumeCurrentRequest", "NSURLSessionResumeInfoVersion", "NSURLSessionResumeInfoTempFileName", "NSURLSessionDownloadURL"]
                        if let byteCountReceived = (plistDic["NSURLSessionResumeBytesReceived"] as? NSNumber)?.int64Value, byteCountReceived > 0{
                            info[TIReceivedByteCountInt64Key] = byteCountReceived
                            receivedByteCount = byteCountReceived
                            receivedByteCountFormatString = formatter.string(fromByteCount: byteCountReceived)
                        }
                    }
                }
                
                let fileByteCount = dm.fileByteCount(ofTask: URLString)
                let progress: Float = fileByteCount > 0 ? Float(receivedByteCount) / Float(fileByteCount) : -1
                info[TIProgressFloatKey] = progress
                
                let fileByteCountFormatString: String = fileByteCount > 0 ? formatter.string(fromByteCount: fileByteCount) : SDEPlaceHolder
                let fileDetail: String = receivedByteCountFormatString + "/" + fileByteCountFormatString
                info[TIDownloadDetailStringKey] = fileDetail
                
                dm.updateMetaInfo(info, forTask: URLString)
                downloadTracker.completeTask(URLString, infoTuple: (receivedByteCount, fileByteCount, fileDetail))
            }
        }else{
            let _error = error! as NSError
            var info: Dictionary<String, Any> = [:]
            
            // After cancel a download task, receivedSizeBytes is still count before cancelled, not 0.
            let receivedByteCount: Int64 = task.countOfBytesReceived >= 0 ? task.countOfBytesReceived : 0
            let receivedByteCountForamtString: String = receivedByteCount > 0 ? formatter.string(fromByteCount: receivedByteCount) : "0 KB"

            let fileByteCount: Int64
            if task.countOfBytesExpectedToReceive > 0 && task.countOfBytesReceived < task.countOfBytesExpectedToReceive{
                fileByteCount = task.countOfBytesExpectedToReceive
            }else if let byteCount = downloadManager?.fileByteCount(ofTask: URLString), byteCount > 0{
                fileByteCount = byteCount
            }else{
                fileByteCount = UNKNOWNSIZE
            }
            let fileByteCountFormatString = fileByteCount > 0 ? formatter.string(fromByteCount: fileByteCount) : SDEPlaceHolder
            
            info[TIFileByteCountInt64Key] = fileByteCount
            
            var fileDetail: String = receivedByteCountForamtString + "/" + fileByteCountFormatString
            var isRestoredFromForceQuit: Bool = false
            var cancelled: Bool = false
            let errorInfo = (_error.domain, _error.code)
            
            switch errorInfo {
            case let (domain, code) where domain == NSURLErrorDomain:
                // URL Loading System Error Codes and Explains:
                // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Constants/index.html#//apple_ref/doc/constant_group/URL_Loading_System_Error_Codes
                // An Alternative for Code Explain: http://nshipster.com/nserror/
                switch code {
                case -1022: //NSURLErrorAppTransportSecurityRequiresSecureConnection NS_ENUM_AVAILABLE(10_11, 9_0)
                    fileDetail = "ATS Enabled."
                case NSURLErrorCancelled: // Calling cancelByProducingResumeData: on NSURLSessionDownloadTask also get this code.
                    cancelled = true
                    // How to handle force quit? It's very like you call `cancelByProducingResumeData:` on a task. App keep all necessary datas until you relaunch app and
                    // create a session with a background session configuration with the same identifier, attention: just one chance. Don't worry the resume data could be lost
                    // before you do this: app keep it always even you restart app or device multi times unless you delete the app.
                    // After you recreate the session, its delegate receive this message. And error code is NSURLErrorCancelled also if you cancel a task explicitly. 
                    // What is difference? Look NSURLErrorBackgroundTaskCancelledReasonKey key in userInfo.
                    if let cancelledReason = _error.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int, cancelledReason == NSURLErrorCancelledReasonUserForceQuitApplication{
                        isRestoredFromForceQuit = true
                    }
                    
                    if _error.userInfo.index(forKey: NSURLSessionDownloadTaskResumeData) == nil{
                        fileDetail = "0 KB/" + fileByteCountFormatString
                    }
                default:
                    if let avaiableDescription = NSURLErrorDescriptionTable[code]{
                        fileDetail = avaiableDescription
                    }
                }
            default:
                fileDetail = String(errorInfo.1) + ": " + errorInfo.0
            }
            info[TIDownloadDetailStringKey] = fileDetail
            
            if let resumeData = _error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data{
                info[TITaskStateIntKey] = DownloadState.stopped.rawValue
                info[TIResumeDataKey] = resumeData
                info[TIReceivedByteCountInt64Key] = receivedByteCount
                info[TIProgressFloatKey] = fileByteCount > 0 ? Float(receivedByteCount)/Float(fileByteCount) : -1
                downloadTracker.completeTask(URLString, infoTuple: (receivedByteCount, fileByteCount, fileDetail), cleanLastBytesInfo: false)
            }else{
                info[TITaskStateIntKey] = DownloadState.pending.rawValue
                info[TIResumeDataKey] = TIDeleteValueMark
                info[TIReceivedByteCountInt64Key] = TIDeleteValueMark
                info[TIProgressFloatKey] = 0.0
                if !cancelled{
                    handleCompletionOfTask(URLString, fileLocation: nil, error: error! as NSError)
                }
                downloadTracker.completeTask(URLString, infoTuple: (receivedByteCount, fileByteCount, fileDetail))
            }
            
            dm.updateMetaInfo(info, forTask: URLString)
            
            if isRestoredFromForceQuit{
                debugNSLog("App ForceQuit in downloading: \(URLString)")
                NotificationCenter.default.post(name: SDEDownloadManager.NNRestoreFromAppForceQuit, object: downloadManager, userInfo: ["URLString": URLString])
                
                completeCount += 1
                let currentCompleteCount = completeCount
                
                // User force quit the app and relanch, then this session delegate maybe receive this method many times in the very short time,
                // I want to reduce the pressure of save data: after 1s, most this delegate method are called, then save them together.
                // How perform a selector after 1s in this method? performSelectorXXX of NSObject and NSTimer can't work here,
                // because they are all based on runloop, after 1s, runloop is gone with current thread, there's no chance to execute.
                DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                    self.saveDataIfCompleteCountIsEqualTo(currentCompleteCount)
                })
                return
            }
        }

        if (!dm.downloadTracker.isTrackingDownload && dm.countOfRunningTask == 0){
            dm.saveData()
        }
    }
    
//    func URLSession(session: NSURLSession, task: NSURLSessionTask, willPerformHTTPRedirection response: NSHTTPURLResponse, newRequest request: NSURLRequest, completionHandler: (NSURLRequest?) -> Void) {
//    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let challengeHandler = downloadManager.taskDidReceiveChallengeHandler{
            let condition: Bool
            switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
                condition = false
            default:
                condition = true
            }
            if condition{
                challengeHandler(session, task, challenge, completionHandler)
                return
            }
        }
        
        guard let _ = UIApplication.shared.keyWindow?.rootViewController else{
            debugNSLog("Not a UI environment. Skip auth.")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        /*
         
         If the right credential is existed, use it to finish authentication; or filter wrong credential and end authentication.
         
         proposedCredential is not nil when:
         
         1. A right credential for the visited server directory is stored in the ProtectionSpace.
         2. It's the most recent failed credential for current NSURLSessionTask object, just current NSURLSessionTask object, 
         not a new NSURLSessionTask object to request the same content(its proposedCredential is still nil if there is no right credential).
         */
        if let possibleCredential = challenge.proposedCredential{
            /*
             For a new NSURLSessionTask object, no matter whether it request the same content, previousFailureCount always be 0 initially.
             In current NSURLSessionTask object's life, previousFailureCount increase only if sended credential is wrong.
             So if previousFailureCount is 0, and proposedCredential is not nil, that's right credential.

             If the right credential is cached, for example, the previous request use the existed right credential or send a right credential,
             this delegate method for latter requests won't be called likely. If there is no active request in session, cached credential could
             be released until next request. For 404 file, this method is called every time almost.
             */
            if challenge.previousFailureCount == 0{
                completionHandler(.useCredential, possibleCredential)
            }else{
                /*
                 This is a wrong credential for current task. If last submitted credential is not right, this delegate method is called again
                 and again until a right credential is submitted or authentication is stopped(reject or cancel).
                 
                 The policy: just one chance for current task object to submit a credential, not matter whether it's failed. Infinite authentication is annoying.
                 
                 Wrong credentials won't be cleaned automatically in current session life cycle, in my test environment, relanch app, wrong credentials are 
                 cleaned. Here I delete wrong credential manually to keep right credential only.
                 
                 Credentials are isolated by server directory in storage.
                 */
                URLCredentialStorage.shared.remove(possibleCredential, for: challenge.protectionSpace)
                if let stillPossibleCredential = URLCredentialStorage.shared.credentials(for: challenge.protectionSpace)?.values.first, challenge.previousFailureCount == 1{
                    completionHandler(.useCredential, stillPossibleCredential)
                }else{
                    // If CancelAuthenticationChallenge, the entire request is cancelled.
                    completionHandler(.rejectProtectionSpace, nil)
                }
            }
        
//            debugNSLog("Remove existed credential: \(possibleCredential)")
//            NSURLCredentialStorage.sharedCredentialStorage().removeCredential(possibleCredential, forProtectionSpace: challenge.protectionSpace)
//            completionHandler(.CancelAuthenticationChallenge, nil)
            return
        }
        
        var position: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?

        // Use a serial queue to handle multiple authentications at the same time. 
        // If no right credential is existed, here it's the first time to handle authentication for current NSURLSessionTask object.
        serialQueue.sync(execute: { [unowned self] in
            switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
                /*
                 After you input and send a credential for previous request, the next request behind it in the queue can't fetch it here likely.
                 It means that if you input a right credential in previous request, you can't use it here. It's could be fixed to avoid user to
                 input again in 'while self.logining{...}'. And thanks to the delay, even a wrong credential is submitted in previous request,
                 it won't be used here.
                 
                 What's about latter requests(from third request) in the queue? No problem, the submitted 1st credential can be fetched. 
                 Of course, if 1st credential is wrong, it's will be deleted in above code, fetched credential here is likely right.
                 
                 */
                if let possibleCredential = URLCredentialStorage.shared.credentials(for: challenge.protectionSpace)?.values.first{
                    completionHandler(.useCredential, possibleCredential)
                    return
                }
                
                // Input user and password
                // Default dismiss animation time is about 0.25s.
                while self.loginView.isBeingPresented{}
                self.logining = true
                DispatchQueue.main.sync(execute: {
                    self.loginView.title = challenge.protectionSpace.realm
                    self.loginView.message = task.originalURLString
                    self.confirmAction.isEnabled = false
                    UIApplication.shared.keyWindow?.rootViewController?.present(self.loginView, animated: true, completion: nil)
                })
                
                // When login view is displayed on the screen, search possible credentials in the background.
                while self.logining {
                    if let possibleCredential = URLCredentialStorage.shared.credentials(for: challenge.protectionSpace)?.values.first{
                        /*
                         Leave time to filter wrong credential.
                         
                         How to judge a credential is right? Only the request which send this credential know. If send a wrong credential in loginView, this delegate method
                         is called again, and it will be deleted in the beginning code; If send a right credential, this delegate method won't be called again for current request.
                         So this possibleCredential must be created by previous request. 
                         
                         But different requests are concurrent, we don't know when wrong credential is removed, 1s is enough to handle it. Actually, if don't leave this time, 
                         its result is very funny: if possibleCredential is wrong, current request use this wrong credential, then this delegate method is called again and 
                         the entire authentication workflow is stoped at the beginning code. If this wrong credential is not deleted quickly, latter requests use this wrong 
                         credential and stop the authentication workflow quickly. It looks like there requests which need the same credential just handle authentication 
                         for one time. If wait 1s here, it's sure that if there is no right credential, every request is asked for authentication.
                         */
                        sleep(1)

                        // UIViewController's isBeingPresented() and isBeingDismissed() are not credible here.
                        // Only loginView is dismissed, logining change to false.
                        if !self.logining{
                            break
                        }else{
                            if let credibleCredential = URLCredentialStorage.shared.credentials(for: challenge.protectionSpace)?.values.first{
                                DispatchQueue.main.sync(execute: {
                                    self.loginView.textFields?.forEach({
                                        if $0.tag == 0{
                                            $0.text = possibleCredential.user
                                        }else{
                                            if let password = possibleCredential.password{
                                                $0.text = String.init(repeating: "*", count: password.count)
                                            }else{
                                                $0.text = String.init(repeating: "*", count: 6)
                                            }
                                        }
                                    })
                                    self.loginView.dismiss(animated: false, completion: { [unowned self] in
                                        self.loginView.textFields?.filter({$0.tag == 1}).first?.text = nil
                                    })
                                })
                                self.user = ""
                                self.password = ""
                                self.logining = false
                                completionHandler(.useCredential, credibleCredential)
                                return
                            }
                        }
                    }
                }
                
                if self.user != "" && self.password != ""{
                    position = .useCredential
                    /*
                     If you submit a wrong credential, this method is called again and again for current task object until you stop it. For any persistence option:
                     this wrong credential is stored and becomes proposedCredential for other task object; after relanch app, wrong credential is deleted automatically.
                     
                     If you submit a right credential, difference is here:
                     
                     1. None: A right credential is valid once and just for current task object, even you reqeust same content again with current session object, ask for auth again.
                     2. ForSession: The right credential is stored in app life cycle and is shared between sessions, which is different with document.
                     3. Permanent: The right credential is stored in the device, even app is deleted.
                     4. Synchronizable: Cross devices is not tested, other part is same with .Permanent.
                     
                     About challenge.proposedCredential: if submit a credential in current request(no matter whether it's right), it won't be challenge's proposedCredential for latter 
                     requests unless all current requests in the queue are completed(this condition is not completed), so if you request a group of file which need the same credential 
                     at one time, the method which send a right credential in this request and fetch it by challenge.proposedCredential in other requests doesn't work.
                     
                     It seems that wrong credential is stored extensively more than right credential.
                     */
                    credential = URLCredential.init(user: self.user, password: self.password, persistence: .permanent)
                }
                
                completionHandler(position, credential)
            case NSURLAuthenticationMethodHTMLForm:
                debugNSLog("Session Auth: Form. This part is not finished.")
            default:
                debugNSLog("Session-level challenge %@. Handled in URLSession:didReceiveChallenge:completionHandler: method if implemented.", challenge.protectionSpace.authenticationMethod)
            }
        })
    }

    // MARK: - Save Data Helper
    var completeCount: Int = 0
    func saveDataIfCompleteCountIsEqualTo(_ oldCount: Int){
        debugNSLog("\(#function): \(completeCount) \(oldCount)")
        if oldCount == completeCount{
            downloadManager?.saveData()
        }
    }
    
    // MARK: Logging Helper
    lazy var loginRequestCount: Int = 0
    lazy var logining: Bool = false
    lazy var user: String = ""
    lazy var password: String = ""
    lazy var serialQueue: DispatchQueue = DispatchQueue(label: "SerialQueue.SessionDelegate.SDEDownloadManager", attributes: [])
    lazy var loginView: UIAlertController = {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { accountTextField in
            accountTextField.tag = 0
            accountTextField.placeholder = DMLS("UserName", comment: "Placeholder for textfiled to input username in loginView")
            // UITextField's Target-Action mode is better choice than delegate mode to handle editing and return event.
            accountTextField.addTarget(self, action: #selector(SDESessionDelegate.textFieldDidChanged(_:)), for: .editingChanged)
            accountTextField.addTarget(self, action: #selector(SDESessionDelegate.textFieldDidReturn(_:)), for: .editingDidEndOnExit)

        })
        alert.addTextField(configurationHandler: { passwordTextField in
            passwordTextField.tag = 1
            passwordTextField.isSecureTextEntry = true
            // UITextField's Target-Action mode is better choice than delegate mode to handle editing and return event.
            passwordTextField.addTarget(self, action: #selector(SDESessionDelegate.textFieldDidChanged(_:)), for: .editingChanged)
            passwordTextField.addTarget(self, action: #selector(SDESessionDelegate.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
        })
        
        alert.addAction(self.confirmAction)
        alert.addAction(self.cancelAction)
        
        return alert
    }()
    
    lazy var confirmAction: UIAlertAction = UIAlertAction.init(title: confirmActionTitle, style: .default, handler: {[unowned self] sendAction in
        self.logining = false
        self.loginView.textFields?.forEach({
            $0.text = nil
        })
    })
    
    lazy var cancelAction: UIAlertAction = UIAlertAction.init(title: cancelActionTitle, style: .cancel, handler: {[unowned self] cancelAction in
        self.logining = false
        self.user = ""
        self.password = ""
        self.loginView.textFields?.forEach({
            $0.text = nil
        })
    })
    
    @objc private func textFieldDidChanged(_ tf: UITextField){
        if let inputText = tf.text, inputText.count > 0{
            if tf.tag == 0{
                user = inputText
            }else{
                password = inputText
            }
        }
        
        if let userTF = loginView.textFields?.first, let pwTF = loginView.textFields?.last, (userTF.text?.count)! > 0 && (pwTF.text?.count)! > 0{
            confirmAction.isEnabled = true
        }else{
            confirmAction.isEnabled = false
        }
    }
    
    @objc private func textFieldDidReturn(_ tf: UITextField){
        if let inputText = tf.text{
            if tf.tag == 0{
                user = inputText
            }else{
                password = inputText
            }
        }
    }
}
