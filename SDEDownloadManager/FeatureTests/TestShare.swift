//
//  BaseCase.swift
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

let appleDevHost = "http://devstreaming.apple.com"
var host = "http://devstreaming.apple.com"


// If 'manager' is declarated in class scope, before every test method run, the property will alloc and init separately.
// This design keep every test method don't impact other test methods.
// A little weird: the time of alloc and init in class scope is: test method count X 2.
var testManager: SDEDownloadManager = SDEDownloadManager.manager(identifier: "XCTest", manualMode: false)
let ONE_MINUTER: TimeInterval = 60
let sharedSession: URLSession = URLSession.shared


let Swift2014Slide   = "/videos/wwdc/2014/402xxgg8o88ulsr/402/402_introduction_to_swift.pdf"
let Swift2015Slide   = "/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_whats_new_in_swift.pdf?dl=1"
let Swift2016Slide   = "/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf"

let Swift2014SDVideo = "/videos/wwdc/2014/402xxgg8o88ulsr/402/402_sd_introduction_to_swift.mov"
let Swift2014HDVideo = "/videos/wwdc/2014/402xxgg8o88ulsr/402/402_hd_introduction_to_swift.mov"

let Swift2015SDVideo = "/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_sd_whats_new_in_swift.mp4?dl=1"
let Swift2015HDVideo = "/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_hd_whats_new_in_swift.mp4?dl=1"

let Swift2016SDVideo = "/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_sd_whats_new_in_swift.mp4?dl=1"
let Swift2016HDVideo = "/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_hd_whats_new_in_swift.mp4?dl=1"


let Network2013Slide      = "/videos/wwdc/2013/705xbx3xcjsmrdbtwl5grta6gq6r/705/705.pdf"
let Network2014Slide      = "/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_whats_new_in_foundation_networking.pdf"
let Network2015Slide      = "/videos/wwdc/2015/711y6zlz0ll/711/711_networking_with_nsurlsession.pdf?dl=1"
let Network2016Slide      = "/videos/wwdc/2016/714urluxe140lardrb7/714/714_networking_for_the_modern_internet.pdf"
let URLSession2016Slide   = "/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_nsurlsession_new_features_and_best_practices.pdf"

let Network2013SDVideo = "/videos/wwdc/2013/705xbx3xcjsmrdbtwl5grta6gq6r/705/705-SD.mov?dl=1" //496.5 MB
let Network2013HDVideo = "/videos/wwdc/2013/705xbx3xcjsmrdbtwl5grta6gq6r/705/705-HD.mov?dl=1" //2.84 GB

let Network2014SDVideo = "/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_sd_whats_new_in_foundation_networking.mov" //66.9 MB
let Network2014HDVideo = "/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_hd_whats_new_in_foundation_networking.mov" //196.1 MB

let Network2015SDVideo = "/videos/wwdc/2015/711y6zlz0ll/711/711_sd_networking_with_nsurlsession.mp4?dl=1" //
let Network2015HDVideo = "/videos/wwdc/2015/711y6zlz0ll/711/711_hd_networking_with_nsurlsession.mp4?dl=1"

let Network2016SDVideo = "/videos/wwdc/2016/714urluxe140lardrb7/714/714_sd_networking_for_the_modern_internet.mp4?dl=1" //315.5 MB
let Network2016HDVideo = "/videos/wwdc/2016/714urluxe140lardrb7/714/714_hd_networking_for_the_modern_internet.mp4?dl=1" //

let URLSession2016SDVideo = "/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_sd_nsurlsession_new_features_and_best_practices.mp4?dl=1" //336.4 MB
let URLSession2016HDVideo = "/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_hd_nsurlsession_new_features_and_best_practices.mp4?dl=1"

func waitForDownloadManagerReady(_ downloadManager: SDEDownloadManager){
    while !(downloadManager.isDataLoaded) {
        debugNSLog("\(#function): Waiting for load data...")
    }
}

// MARK: Verify Helper
func verifyPendingTaskOfURLString(_ URLString: String){
    XCTAssertEqual(testManager.downloadState(ofTask: URLString), DownloadState.pending)
    XCTAssertNil(testManager.resumeData(ofTask: URLString))
    XCTAssertNil(testManager.fileURL(ofTask: URLString))
    XCTAssertEqual(testManager.downloadProgress(ofTask: URLString), 0)
    if let operation = testManager.downloadOperation(ofTask: URLString){
        XCTAssertFalse(operation.started)
    }
}

func verifyRunningTaskOfURLString(_ URLString: String){
    XCTAssertEqual(testManager.downloadState(ofTask: URLString).rawValue, DownloadState.downloading.rawValue)
    XCTAssertNotNil(testManager.downloadOperation(ofTask: URLString))
}

func verifyDeletedTaskOfURLString(_ URLString: String, trashOpened: Bool, fileLocation: URL? = nil){
    XCTAssertNil(testManager.downloadOperation(ofTask: URLString), "Download operation for \(URLString) should end and gone")
    
    if trashOpened{
        XCTAssertNotEqual(testManager.downloadState(ofTask: URLString), DownloadState.notInList)
        XCTAssertNotNil(testManager.downloadTaskInfo[URLString], "Task info of \(URLString) should still be existed.")
        if fileLocation != nil{
            XCTAssertTrue((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil), "File at \(fileLocation!) should still be existed.")
        }
    }else{
        XCTAssertEqual(testManager.downloadState(ofTask: URLString), DownloadState.notInList)
        XCTAssertNil(testManager.downloadTaskInfo[URLString], "Task info of \(URLString) should be nil")
        if fileLocation != nil{
            XCTAssertFalse((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil), "File at \(fileLocation!) should be deleted.")
        }
    }
}

func verifyCleanedTaskOfURLString(_ URLString: String, fileLocation: URL? = nil){
    XCTAssertEqual(testManager.downloadState(ofTask: URLString), DownloadState.notInList)
    XCTAssertNil(testManager.downloadTaskInfo[URLString])
    if fileLocation != nil{
        XCTAssertFalse((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil), "File at \(fileLocation!) should be deleted.")
    }
}

func verifyFinishedTaskOfURLString(_ URLString: String){
    sleep(1)
    XCTAssertNil(testManager.downloadOperation(ofTask: URLString), "Operation for \(URLString) should end and gone")
    XCTAssertNil(testManager.resumeData(ofTask: URLString), "Finished task should clear resume data.")
    XCTAssertEqual(testManager.downloadState(ofTask: URLString).rawValue, DownloadState.finished.rawValue)
    XCTAssertEqual(testManager.downloadProgress(ofTask: URLString), 1.0)
    
    let filePath = testManager.filePath(ofTask: URLString)
    XCTAssertNotNil(filePath)
    if filePath != nil{
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath!))
    }
    
    
    let fileLocation = testManager.fileURL(ofTask: URLString)
    XCTAssertNotNil(fileLocation)
    if fileLocation != nil{
        XCTAssertTrue((fileLocation! as NSURL).checkResourceIsReachableAndReturnError(nil))
    }
    
    let recordedFileSize = testManager.fileByteCount(ofTask: URLString)
    let realFileSize = testManager.fileByteCountAtRealLocation(ofTask: URLString)
    XCTAssertNotNil(recordedFileSize)
    XCTAssertNotNil(realFileSize)
    XCTAssertEqual(recordedFileSize, realFileSize)
}

func verifyStoppedTaskOfURLString(_ URLString: String){
    XCTAssertNotNil(testManager.downloadProgress(ofTask: URLString), "Progress should be not nil")
    XCTAssertNil(testManager.filePath(ofTask: URLString), "There should be no file exited for \(URLString)")
    XCTAssertNil(testManager.downloadOperation(ofTask: URLString), "Download operation for \(URLString) should end and gone")
    
    let resumedData = testManager.resumeData(ofTask: URLString)
    if resumedData != nil{
        XCTAssertEqual(testManager.downloadState(ofTask: URLString).rawValue, DownloadState.stopped.rawValue)
    }else{
        XCTAssertEqual(testManager.downloadState(ofTask: URLString).rawValue, DownloadState.pending.rawValue)
        XCTAssertEqual(testManager.downloadProgress(ofTask: URLString), 0.0)
    }
}

func verifyPausedTaskOfURLString(_ URLString: String){
    XCTAssertEqual(testManager.downloadState(ofTask: URLString).rawValue, DownloadState.paused.rawValue)
    XCTAssertNotNil(testManager.downloadProgress(ofTask: URLString), "Progress should be not nil")
    
    let operation = testManager.downloadOperation(ofTask: URLString)
    XCTAssertNotNil(operation, "There shoule be a download operation for \(URLString)")
    if operation != nil{
        XCTAssertTrue(operation!.started == true)
        XCTAssertTrue(operation!.isExecuting == false)
    }else{
        XCTFail("A paused task should have a download operation.")
    }
}

