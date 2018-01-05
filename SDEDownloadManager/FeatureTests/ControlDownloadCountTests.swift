//
//  ControlCountOfDownloadTests.swift
//  DownloadManager
//
//  Created by seedante on 8/30/17.
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


class ControlDownloadCountTests: XCTestCase {
    let slideURLStrings: [String]   = [host + Network2013Slide,
                                       host + Network2014Slide,
                                       host + Network2015Slide,
                                       host + Network2016Slide,
                                       host + URLSession2016Slide]
    let SDVideoURLStrings: [String] = [host + Network2013SDVideo,
                                       host + Network2014SDVideo,
                                       host + Network2015SDVideo,
                                       host + Network2016SDVideo,
                                       host + URLSession2016SDVideo]
    let HDVideoURLStrings: [String] = [host + Network2013HDVideo,
                                       host + Network2014HDVideo,
                                       host + Network2015HDVideo,
                                       host + Network2016HDVideo,
                                       host + URLSession2016HDVideo]
    
    override func setUp() {
        NSLog("setUp")
        super.setUp()
        waitForDownloadManagerReady(testManager)
        testManager.isTrashOpened = false
        _ = testManager.emptyToDeleteList()
        _ = testManager.deleteAllTasks()
        sleep(1)
        XCTAssert(testManager.downloadTaskInfo.isEmpty, "All tasks should be deleted")
        if testManager.countOfRunningTask > 0{
            XCTFail("All executing operations should be cancelled")
        }
        
        testManager.pauseDownloadBySuspendingSessionTask = true
        testManager.maxDownloadCount = OperationQueue.defaultMaxConcurrentOperationCount
        testManager.saveData()
    }
    
    override func tearDown() {
        NSLog("tearDown")
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        testManager.isTrashOpened = false
        _ = testManager.emptyToDeleteList()
        _ = testManager.deleteAllTasks()
        sleep(1)
        XCTAssert(testManager.downloadTaskInfo.isEmpty, "All tasks should be deleted")
        if testManager.countOfRunningTask > 0{
            XCTFail("All executing operations should be cancelled")
        }
        
        testManager.pauseDownloadBySuspendingSessionTask = true
        testManager.maxDownloadCount = OperationQueue.defaultMaxConcurrentOperationCount
        testManager.saveData()
    }
    
    func testPauseTaskBySuspend(){
        testManager.pauseDownloadBySuspendingSessionTask = true
        testManager.maxDownloadCount = 5
        XCTAssertEqual(testManager.maxDownloadCount, 5)
        _ = testManager.download(SDVideoURLStrings)
        sleep(1)
        verifyRunningTaskOfURLString(SDVideoURLStrings[0])
        verifyRunningTaskOfURLString(SDVideoURLStrings[1])
        verifyRunningTaskOfURLString(SDVideoURLStrings[2])
        verifyRunningTaskOfURLString(SDVideoURLStrings[3])
        verifyRunningTaskOfURLString(SDVideoURLStrings[4])
        
        
        var testCount = 5
        while testCount > 0 {
            NSLog("Test No.\(6 - testCount)")
            let limitCount = Int(arc4random_uniform(UInt32(SDVideoURLStrings.count + 3)))
            NSLog("limitCount: \(limitCount)")
            testManager.maxDownloadCount = limitCount
            let compareValue = limitCount == 0 ? Int.max : limitCount
            XCTAssert(testManager.countOfRunningTask <= compareValue)
            testCount -= 1
            
            let seedValue = Int(arc4random_uniform(UInt32(100)))
            let randomIndex =  Int(arc4random_uniform(UInt32(testManager._downloadTaskSet.count)))
            if seedValue < 50{
                _ = testManager.pauseTasks(at: [IndexPath(row: randomIndex, section: 0)])
            }else if seedValue < 70{
                _ = testManager.stopTasks(at: [IndexPath(row: randomIndex, section: 0)])
            }else if seedValue < 90{
                _ = testManager.download([slideURLStrings[testCount]])
                sleep(5)
            }
        }
    }
    
    func testPauseTaskByStop(){
        testManager.pauseDownloadBySuspendingSessionTask = false
        testManager.maxDownloadCount = 5
        XCTAssertEqual(testManager.maxDownloadCount, 5)
        _ = testManager.download(SDVideoURLStrings)
        sleep(1)
        verifyRunningTaskOfURLString(SDVideoURLStrings[0])
        verifyRunningTaskOfURLString(SDVideoURLStrings[1])
        verifyRunningTaskOfURLString(SDVideoURLStrings[2])
        verifyRunningTaskOfURLString(SDVideoURLStrings[3])
        verifyRunningTaskOfURLString(SDVideoURLStrings[4])
        
        
        var testCount = 5
        while testCount > 0 {
            NSLog("Test No.\(6 - testCount)")
            let limitCount = Int(arc4random_uniform(UInt32(SDVideoURLStrings.count + 3)))
            NSLog("limitCount: \(limitCount)")
            testManager.maxDownloadCount = limitCount
            sleep(1)
            let compareValue = limitCount == 0 ? Int.max : limitCount
            XCTAssert(testManager.countOfRunningTask <= compareValue)
            testCount -= 1
            
            let seedValue = Int(arc4random_uniform(UInt32(100)))
            let randomIndex =  Int(arc4random_uniform(UInt32(testManager._downloadTaskSet.count)))
            if seedValue < 50{
                _ = testManager.pauseTasks(at: [IndexPath(row: randomIndex, section: 0)])
            }else if seedValue < 70{
                _ = testManager.stopTasks(at: [IndexPath(row: randomIndex, section: 0)])
            }else if seedValue < 90{
                _ = testManager.download([slideURLStrings[testCount]])
                sleep(5)
            }
        }

    }
    
    // Except for -1(NSOperationQueueDefaultMaxConcurrentOperationCount), for any number less than 1, maxDownloadCount will be set to -1.
    func testSetInvalidMaxDownloadCount(){
        testManager.maxDownloadCount = 1
        XCTAssert(testManager.maxDownloadCount == 1)
        
        testManager.maxDownloadCount = 0
        XCTAssert(testManager.maxDownloadCount == OperationQueue.defaultMaxConcurrentOperationCount)
        
        testManager.maxDownloadCount = 1
        XCTAssert(testManager.maxDownloadCount == 1)
        
        testManager.maxDownloadCount = -2
        XCTAssert(testManager.maxDownloadCount == OperationQueue.defaultMaxConcurrentOperationCount)
    }
    
}
