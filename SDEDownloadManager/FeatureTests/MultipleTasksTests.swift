//
//  BatchFunctionTests.swift
//  DownloadManager
//
//  Created by seedante on 8/28/17.
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

class MultipleTasksTests: XCTestCase {
    
    let slideTaskURLStrings: [String] = [host + Swift2014Slide,
                                         host + Swift2015Slide,
                                         host + Swift2016Slide,
                                         host + Network2013Slide,
                                         host + Network2014Slide,
                                         host + Network2015Slide,
                                         host + Network2016Slide,
                                         host + URLSession2016Slide]
    
    let videoTaskURLStrings: [String] = [host + Swift2014SDVideo,
                                         host + Swift2014HDVideo,
                                         host + Swift2015SDVideo,
                                         host + Swift2015HDVideo,
                                         host + Swift2016SDVideo,
                                         host + Swift2016HDVideo,
                                         host + Network2013SDVideo,
                                         host + Network2013HDVideo,
                                         host + Network2014SDVideo,
                                         host + Network2014HDVideo,
                                         host + Network2015SDVideo,
                                         host + Network2015HDVideo,
                                         host + Network2016SDVideo,
                                         host + Network2016HDVideo
                                        ]
    
    
    override func setUp() {
        super.setUp()
        waitForDownloadManagerReady(testManager)
        // Put setup code here. This method is called before the invocation of each test method in the class.
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
    
    func testBatchResume(){
        let finishedURLString = host + Swift2014Slide
        let expectation = self.expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        
        testManager.downloadNewFileImmediately = false
        let pendingURLString = host + Swift2014HDVideo
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        let pausedURLString = host + Swift2015HDVideo
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        let stoppedURLString = host + Swift2016HDVideo
        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(5)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        //
        let resumedLocations = testManager.resumeTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString])
        XCTAssertEqual(resumedLocations?.count, 3)
        sleep(3)
        verifyRunningTaskOfURLString(pendingURLString)
        verifyRunningTaskOfURLString(pausedURLString)
        verifyRunningTaskOfURLString(stoppedURLString)
        
        XCTAssertTrue(testManager.deleteFileOfTask(pendingURLString))
        sleep(1)
        verifyPendingTaskOfURLString(pendingURLString)
        
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        //
        testManager.resumeAllTasks()
        sleep(1)
        verifyRunningTaskOfURLString(pendingURLString)
        verifyRunningTaskOfURLString(pausedURLString)
        verifyRunningTaskOfURLString(stoppedURLString)
    }
    
    func testBatchPause(){
        let finishedURLString = host + Swift2014Slide
        let pendingURLString = host + Swift2014HDVideo
        let pausedURLString = host + Swift2015HDVideo
        let stoppedURLString = host + Swift2016HDVideo
        
        let expectation = self.expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        
        testManager.downloadNewFileImmediately = false
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)

        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(5)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        //
        var pausedLocations = testManager.pauseTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString])
        XCTAssertNil(pausedLocations)
        testManager.resumeAllTasks()
        sleep(1)
        verifyRunningTaskOfURLString(pendingURLString)
        verifyRunningTaskOfURLString(pausedURLString)
        verifyRunningTaskOfURLString(stoppedURLString)
        pausedLocations = testManager.pauseTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString])
        XCTAssertEqual(pausedLocations?.count, 3)
        verifyPausedTaskOfURLString(pendingURLString)
        verifyPausedTaskOfURLString(pausedURLString)
        verifyPausedTaskOfURLString(stoppedURLString)
        
    }
    
    func testBatchStop(){
        let finishedURLString = host + Swift2014Slide
        let pendingURLString = host + Swift2014HDVideo
        let pausedURLString = host + Swift2015HDVideo
        let stoppedURLString = host + Swift2016HDVideo
        
        let expectation = self.expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        
        testManager.downloadNewFileImmediately = false
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        //
        let stoppedLocations = testManager.stopTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString])
        XCTAssertEqual(stoppedLocations?.count, 1)
        sleep(1)
        testManager.resumeAllTasks()
        sleep(1)
        verifyRunningTaskOfURLString(pendingURLString)
        verifyRunningTaskOfURLString(pausedURLString)
        verifyRunningTaskOfURLString(stoppedURLString)

        //
        testManager.stopAllTasks()
        sleep(1)
        verifyStoppedTaskOfURLString(pendingURLString)
        verifyStoppedTaskOfURLString(pausedURLString)
        verifyStoppedTaskOfURLString(stoppedURLString)
    }
    
    func testBatchDeleteTask(){
        let finishedURLString = host + Swift2014Slide
        let pendingURLString = host + Swift2014HDVideo
        let pausedURLString = host + Swift2015HDVideo
        let stoppedURLString = host + Swift2016HDVideo
        
        // delete task directly
        var  finishExpectation = expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            finishExpectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        var fileLocation = testManager.fileURL(ofTask: finishedURLString)
        
        testManager.downloadNewFileImmediately = false
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)

        let downloadingURLString = host + Swift2016SDVideo
        XCTAssertNotNil(testManager.download([downloadingURLString]))
        sleep(3)
        verifyRunningTaskOfURLString(downloadingURLString)
        
        var deletedInfo = testManager.deleteTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString, downloadingURLString], keepFinishedFile: true)
        XCTAssertEqual(deletedInfo?.count, 5)
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
        
        sleep(1)
        verifyDeletedTaskOfURLString(finishedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(pendingURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(pausedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(stoppedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(downloadingURLString, trashOpened: testManager.isTrashOpened)
        
        // move to trash
        finishExpectation = expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            finishExpectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        fileLocation = testManager.fileURL(ofTask: finishedURLString)
        
        testManager.downloadNewFileImmediately = false
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        XCTAssertNotNil(testManager.download([downloadingURLString]))
        sleep(3)
        verifyRunningTaskOfURLString(downloadingURLString)
        
        testManager.isTrashOpened = true
        deletedInfo = testManager.deleteTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString, downloadingURLString], keepFinishedFile: true)
        XCTAssertEqual(deletedInfo?.count, 5)
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
        
        sleep(1)
        verifyDeletedTaskOfURLString(finishedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(pendingURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(pausedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(stoppedURLString, trashOpened: testManager.isTrashOpened)
        verifyDeletedTaskOfURLString(downloadingURLString, trashOpened: testManager.isTrashOpened)
        testManager.isTrashOpened = false
    }
    
    func testBatchDeleteFiles(){
        let finishedURLString = host + Swift2014Slide
        let pendingURLString = host + Swift2014HDVideo
        let pausedURLString = host + Swift2015HDVideo
        let stoppedURLString = host + Swift2016HDVideo
        
        // prepare
        var finishExpectation = expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            finishExpectation.fulfill()
        }
        XCTAssertNotNil(testManager.download([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        var fileLocation = testManager.fileURL(ofTask: finishedURLString)
        
        testManager.downloadNewFileImmediately = false
        XCTAssertNotNil(testManager.download([pendingURLString]))
        verifyPendingTaskOfURLString(pendingURLString)
        testManager.downloadNewFileImmediately = true
        
        XCTAssertNotNil(testManager.download([pausedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        
        XCTAssertNotNil(testManager.download([stoppedURLString]))
        sleep(3)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)
        
        let downloadingURLString = host + Swift2016SDVideo
        XCTAssertNotNil(testManager.download([downloadingURLString]))
        sleep(3)
        verifyRunningTaskOfURLString(downloadingURLString)

        var deletedInfo = testManager.deleteFilesOfTasks([finishedURLString, pendingURLString, pausedURLString, stoppedURLString, downloadingURLString])
        XCTAssertEqual(deletedInfo?.count, 5)
        sleep(3)
        if fileLocation != nil{
            XCTAssertFalse((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil))
        }
        verifyPendingTaskOfURLString(finishedURLString)
        verifyPendingTaskOfURLString(pendingURLString)
        verifyPendingTaskOfURLString(pausedURLString)
        verifyPendingTaskOfURLString(stoppedURLString)
        verifyPendingTaskOfURLString(downloadingURLString)
        
        // test again with deleteFilesOfAllTasks()
        finishExpectation = expectation(description: "Expectation")
        testManager.taskSuccessOrFailHandler = { _, location, error in
            XCTAssertNotNil(location)
            XCTAssertNil(error)
            finishExpectation.fulfill()
        }
        XCTAssertNotNil(testManager.resumeTasks([finishedURLString]))
        waitForExpectations(timeout: 3 * ONE_MINUTER, handler: nil)
        verifyFinishedTaskOfURLString(finishedURLString)
        testManager.taskSuccessOrFailHandler = nil
        fileLocation = testManager.fileURL(ofTask: finishedURLString)

        XCTAssertEqual(testManager.resumeTasks([downloadingURLString, pausedURLString, stoppedURLString])?.count, 3)
        sleep(3)
        verifyRunningTaskOfURLString(downloadingURLString)
        XCTAssertNotNil(testManager.pauseTasks([pausedURLString]))
        verifyPausedTaskOfURLString(pausedURLString)
        XCTAssertNotNil(testManager.stopTasks([stoppedURLString]))
        sleep(1)
        verifyStoppedTaskOfURLString(stoppedURLString)

        deletedInfo = testManager.deleteFilesOfAllTasks()
        XCTAssertEqual(deletedInfo?.count, 5)
        sleep(3)
        if fileLocation != nil{
            XCTAssertFalse((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil))
        }
        verifyPendingTaskOfURLString(finishedURLString)
        verifyPendingTaskOfURLString(pendingURLString)
        verifyPendingTaskOfURLString(pausedURLString)
        verifyPendingTaskOfURLString(stoppedURLString)
        verifyPendingTaskOfURLString(downloadingURLString)
    }
}
