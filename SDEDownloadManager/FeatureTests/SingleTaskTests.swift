//
//  DownloadManagerTests.swift
//  DownloadManagerTests
//
//  Created by seedante on 8/18/17.
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


import XCTest
@testable import SDEDownloadManager

class FileManagerDelegate: NSObject, Foundation.FileManagerDelegate {
    var deleteable: Bool
    
    init(deleteable: Bool){
        self.deleteable = deleteable
    }
    
    @objc func fileManager(_ fileManager: FileManager, shouldRemoveItemAt URL: URL) -> Bool {
        return deleteable
    }
}

extension SDEDownloadManager{
    internal func deleteTask(_ URLString: String, fileManager: FileManager) -> Bool{
        guard let indexPath = self[URLString] else {
            NSLog("\(URLString) doesn't exist in data base.")
            return false
        }
        let state = downloadState(ofTask: URLString)
        switch state {
            case .finished:
                guard let fileLocation = fileURL(ofTask: URLString) else {return false}
                guard (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true else{return true}
                do{
                    try fileManager.removeItem(at: fileLocation)
                }catch{
                    return false
                }
                
                guard (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == false else{return false}
            case .stopped:
                if let resumeData = resumeData(ofTask: URLString){
                    // Works even there is no internet.
                    sharedSession.downloadTask(withResumeData: resumeData).cancel()
                }
            case .pending, .downloading, .paused:
                downloadOperation(ofTask: URLString)?.cancel()
            default: return false
        }
        self.removeInfoOfTask(URLString, at: indexPath)
        return true
    }
}

class SingleTaskTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Switch between local host and apple developer host.
        host = appleDevHost
        waitForDownloadManagerReady(testManager)
        testManager.isTrashOpened = false
        _ = testManager.emptyToDeleteList()
        _ = testManager.deleteAllTasks()
        sleep(1)
        XCTAssert(testManager.downloadTaskInfo.isEmpty, "All tasks should be deleted")
        if testManager.countOfRunningTask > 0{
            XCTFail("All executing operations should be cancelled")
            NSLog("\(testManager.downloadQueue.operations)")
        }

        testManager.saveData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        testManager.taskSuccessOrFailHandler = nil
        testManager.isTrashOpened = false
        _ = testManager.emptyToDeleteList()
        _ = testManager.deleteAllTasks()
        sleep(1)
        XCTAssert(testManager.downloadTaskInfo.isEmpty, "All tasks should be deleted")
        if testManager.countOfRunningTask > 0{
            XCTFail("All executing operations should be cancelled")
            NSLog("\(testManager.downloadQueue.operations)")
        }

        testManager.saveData()
    }
    
    // MARK: Basic Function Test
    func testTaskCompletionHandler(){
        var expectation: XCTestExpectation
        var URLString: String
        var taskLocation: IndexPath?

        expectation = self.expectation(description: "Expectation for all tasks")
        
        //test task completion handler
        testManager.taskSuccessOrFailHandler = { _, fileLocation, error in
            if fileLocation == nil{
                XCTAssertNotNil(error, "error should be not nil.")
            }else{
                XCTAssertNil(error, "error should be nil.")
                XCTAssertTrue(FileManager.default.fileExists(atPath: fileLocation!.path), "File should be existed.")
            }
            expectation.fulfill()
        }
        // failed task
        URLString = host + "/42.file"
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: ONE_MINUTER, handler: nil)
        
        // successful task
        expectation = self.expectation(description: "Another expectation for all tasks")
        URLString = host + Swift2014Slide
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)

        // test individual task completion handler
        testManager.taskSuccessOrFailHandler = {URLString, fileLocation, error in
            XCTFail("`taskSuccessOrFailHandler` should be replaced by follow individual task completion handler")
        }
        
        // failed task
        expectation = self.expectation(description: "Expectation for a failed task")
        URLString = host + "/404.file"
        taskLocation = testManager.download([URLString], successOrFailHandler: { _, location, error in
            XCTAssertNil(location, "File should be not existed.")
            XCTAssertNotNil(error, "error shoule be not nil.")
            expectation.fulfill()
        })?.first
        XCTAssertEqual(taskLocation, IndexPath(row: 0, section: 0))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: ONE_MINUTER, handler: nil)
        XCTAssertNil(testManager.taskHandlerDictionary[URLString], "After task is failed, individual completion handler should be released.")
        verifyPendingTaskOfURLString(URLString)
        
        // successful task
        expectation = self.expectation(description: "Expectation for a successful task")
        URLString = host + Swift2015Slide
        taskLocation = testManager.download([URLString], successOrFailHandler: { _, location, error in
            XCTAssertNotNil(location, "File should be downloaded.")
            let fileExiseted = (location! as NSURL).checkResourceIsReachableAndReturnError(nil)
            XCTAssertTrue(fileExiseted, "File should be existed.")
            XCTAssertNil(error, "error should be nil.")
            expectation.fulfill()
        })?.first
        XCTAssertEqual(taskLocation, IndexPath(row: 0, section: 0))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: ONE_MINUTER, handler: nil)
        XCTAssertNil(testManager.taskHandlerDictionary[URLString], "After task is successful, individual completion handler should be released.")
        verifyFinishedTaskOfURLString(URLString)
    }

    
    func testAddNewTaskWithInvalidURL(){
        // Not Scheme
        let noSchemeURLStrings = ["blablabla", "devstreaming.apple.com"]
        noSchemeURLStrings.forEach({URLString in
            XCTAssertNil(testManager.download([URLString]))
        })
        
        // Background session support HTTP/HTTPS download only.
        let invalidSchemeURLStrings = ["data://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
                                       "file://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
                                       "ftp://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
                                       ]
        XCTAssertNil(testManager.download(invalidSchemeURLStrings))
        
        
        // Non-completed URL
        let nonCompletedURLStrings = ["htt://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
                                      "htp://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf"]
        XCTAssertNil(testManager.download(nonCompletedURLStrings))
        
    }


    func testAddNewTaskWithNonStandardURL(){
        var expectation = self.expectation(description: "Expectation for a Non-standard URL")
        var URLString = "http:devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf"
        
        testManager.taskSuccessOrFailHandler = {_, location, error in
            if location != nil{
                XCTAssertEqual((location! as NSURL).checkResourceIsReachableAndReturnError(nil), true)
            }else{
                XCTFail("File should be downloaded.")
            }
            
            expectation.fulfill()
        }

        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        
        URLString = "http:/devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf"
        expectation = self.expectation(description: "Expectation for another Non-standard URL")
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        
        testManager.taskSuccessOrFailHandler = nil
    }
    
    
    func testPauseTask(){
        let URLString = host + Swift2014SDVideo
        
        // pause a task by suspend NSURLSessionDownloadTask
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        verifyPausedTaskOfURLString(URLString)
        XCTAssertNil(testManager.resumeData(ofTask: URLString), "After this task is paused, it should have no resume data")
        XCTAssertNotNil(testManager.resumeTasks([URLString]))
        sleep(1)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        verifyPausedTaskOfURLString(URLString)
        XCTAssertNil(testManager.resumeData(ofTask: URLString), "After this task is paused, it should have no resume data")
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertNil(testManager.pauseTasks([URLString]))
        
        // pause a task by stop NSURLSessionDownloadTask
        XCTAssertNotNil(testManager.resumeTasks([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        testManager.pauseDownloadBySuspendingSessionTask = false
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertNil(testManager.pauseTasks([URLString]))
        testManager.pauseDownloadBySuspendingSessionTask = true
    }
    
    func testStopTask(){
        let URLString = host + Swift2014SDVideo
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        
        XCTAssertNotNil(testManager.resumeTasks([URLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
    }
    
    func testDeleteRunningTask(){
        let URLString = host + Swift2014SDVideo
        
        // delete task directly
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // only delete file
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertTrue(testManager.deleteFileOfTask(URLString))
        sleep(1)
        verifyPendingTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)

        // move task to trash
        testManager.isTrashOpened = true
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        XCTAssertNotNil(testManager.cleanupToDeleteTasks([URLString]))
        verifyCleanedTaskOfURLString(URLString)
        testManager.isTrashOpened = false
        
    }
    
    func testDeleteFinishedTask(){
        let URLString = host + Swift2014Slide
        var expectation: XCTestExpectation
        
        expectation = self.expectation(description: "Expectation for a successful task")
        testManager.taskSuccessOrFailHandler = {URLString, location, error in
            if location != nil{
                XCTAssertTrue((location! as NSURL).checkResourceIsReachableAndReturnError(nil))
                XCTAssertEqual(testManager.downloadState(ofTask: URLString), DownloadState.finished)
            }else{
                XCTFail("File should be downloaded.")
            }
            
            expectation.fulfill()
        }

        // delete task directly
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened, fileLocation: testManager.fileURL(ofTask: URLString))
        
        // keep downloaded file
        expectation = self.expectation(description: "Expectation for a successful task")
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        let fileLocation = testManager.fileURL(ofTask: URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString], keepFinishedFile: true))
        if fileLocation != nil{
            let fileExisted = (fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil)
            XCTAssertTrue(fileExisted)
            if fileExisted{
                do{
                    try FileManager.default.removeItem(at: fileLocation!)
                }catch{
                    XCTFail("Can't delete file at \(fileLocation!)")
                }
            }
        }
        XCTAssertTrue(testManager.allTasksSet?.contains(URLString) == false)
        
        // delete file only
        expectation = self.expectation(description: "Expectation for a successful task")
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        XCTAssertTrue(testManager.deleteFileOfTask(URLString))
        sleep(1)
        verifyPendingTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // move task to trash
        expectation = self.expectation(description: "Expectation for a successful task")
        testManager.isTrashOpened = true
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened, fileLocation: testManager.fileURL(ofTask: URLString))
        XCTAssertNotNil(testManager.cleanupToDeleteTasks([URLString]))
        verifyCleanedTaskOfURLString(URLString, fileLocation: testManager.fileURL(ofTask: URLString))
        testManager.isTrashOpened = false
    }

    func testDeletePausedTask(){
        let URLString = host + Swift2014SDVideo

        // delete task directly
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        verifyPausedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // delete file only
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        verifyPausedTaskOfURLString(URLString)
        XCTAssertTrue(testManager.deleteFileOfTask(URLString))
        sleep(1)
        verifyPendingTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // move task to trash
        testManager.isTrashOpened = true
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.pauseTasks([URLString]))
        verifyPausedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        XCTAssertNotNil(testManager.cleanupToDeleteTasks([URLString]))
        verifyCleanedTaskOfURLString(URLString)
        testManager.isTrashOpened = false
    }
    
    func testDeleteStoppedTask(){
        let URLString = host + Swift2014SDVideo
        
        // delete task directly
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // delete file only
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertTrue(testManager.deleteFileOfTask(URLString))
        verifyPendingTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        
        // move task to trash
        testManager.isTrashOpened = true
        XCTAssertNil(testManager.deleteTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        sleep(1)
        verifyDeletedTaskOfURLString(URLString, trashOpened: testManager.isTrashOpened)
        XCTAssertNotNil(testManager.cleanupToDeleteTasks([URLString]))
        verifyCleanedTaskOfURLString(URLString)
        testManager.isTrashOpened = false
    }
    
    func testRestartStoppedTask(){
        let URLString = host + Swift2014SDVideo
        
        XCTAssertNil(testManager.restartTasks([URLString]))
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        sleep(3)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.restartTasks([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
    }

    
    func testRestartFinishedTask(){
        let URLString = host + Swift2014Slide
        var expectation: XCTestExpectation
        
        expectation = self.expectation(description: "Expectation for a successful task")
        testManager.taskSuccessOrFailHandler = {URLString, location, error in
            if location != nil{
                XCTAssertEqual((location! as NSURL).checkResourceIsReachableAndReturnError(nil), true)
            }else{
                XCTFail("File should be downloaded.")
            }
            
            expectation.fulfill()
        }
        
        XCTAssertNotNil(testManager.download([URLString]))
        XCTAssertNil(testManager.download([URLString]))
        waitForExpectations(timeout: 2 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(URLString)
        testManager.taskSuccessOrFailHandler = nil
        XCTAssertNotNil(testManager.restartTasks([URLString]))
        sleep(1)
        verifyRunningTaskOfURLString(URLString)
        XCTAssertNotNil(testManager.stopTasks([URLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(URLString)
    }
}
