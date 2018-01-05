//
//  LoadAndSaveTests.swift
//  DownloadManager
//
//  Created by seedante on 8/29/17.
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

extension SDEDownloadManager{
    fileprivate func saveDataWithoutCheckMechanism(){
        while !isDataLoaded {}
        
        let startTime = Date()
        
        let userDefaults = UserDefaults.standard
        let infoKey: String = "com.SDEDownloadManager.\(self.identifier).Info"
        // NSUserDefaults doesn't support String and Array in Swfit , use OC's version NSString and NSArray.
        let info: Dictionary<String, Int> = ["SortType": sortType.rawValue,
                                             "SortOrder": sortOrder.rawValue,
                                             "MaxDownloadCount": maxDownloadCount]
        userDefaults.set(info as NSDictionary, forKey: infoKey)
        userDefaults.synchronize()

        var savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).TaskInfo.db"
        print("savePath: \(savePath)")
        if downloadTaskInfo.count > 0{
            let plistData = try? PropertyListSerialization.data(fromPropertyList: downloadTaskInfo, format: .binary, options: 0)
            try? plistData?.write(to: URL(fileURLWithPath: savePath), options: [.atomic])
        }else{
            if FileManager.default.fileExists(atPath: savePath){
                debugNSLog("download list is empty and delete data file.")
                do{
                    try FileManager.default.removeItem(atPath: savePath)
                }catch let error as NSError{
                    debugNSLog("Can't delte taskInfo file: ％@", error.userInfo)
                }
            }
        }

        if sortType == .manual{
            savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).ListInfo.db"
            let listInfo: Dictionary<String, Any> = ["SortedURLStringsList": sortedURLStringsList, "SectionTitleList": sectionTitleList]
            if sectionTitleList.count > 0{
                let plistData = try? PropertyListSerialization.data(fromPropertyList: listInfo, format: .binary, options: 0)
                try? plistData?.write(to: URL(fileURLWithPath: savePath), options: [.atomic])
            }else{
                if FileManager.default.fileExists(atPath: savePath){
                    debugNSLog("List is empty and delete list data file")
                    do{
                        try FileManager.default.removeItem(atPath: savePath)
                    }catch let error as NSError{
                        debugNSLog("Can't delete list data file: %@", error.userInfo)
                    }
                }
            }
        }
        
        savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).Trash.db"
        if trashList.count > 0{
            let plistData = try? PropertyListSerialization.data(fromPropertyList: trashList, format: .binary, options: 0)
            try? plistData?.write(to: URL(fileURLWithPath: savePath), options: [.atomic])
        }else{
            if FileManager.default.fileExists(atPath: savePath){
                debugNSLog("Trash is empty and delete data file")
                do{
                    try FileManager.default.removeItem(atPath: savePath)
                }catch let error as NSError{
                    debugNSLog("Can't delete trash data file: %@", error.userInfo)
                }
            }
        }
        
        debugNSLog("ItemCount: \(downloadTaskInfo.count) SaveTime: %@s", NSNumber(value: Date().timeIntervalSince(startTime) as Double))
    }

}

class LoadAndSavePerformanceTests: XCTestCase {
    let URLString = host + Network2016HDVideo
    
    override func setUp() {
        super.setUp()
        waitForDownloadManagerReady(testManager)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Clean.
    func testZero(){
        testManager.pauseDownloadBySuspendingSessionTask = true
        testManager.isTrashOpened = arc4random_uniform(UInt32(2)) == 1
        testManager.maxDownloadCount = OperationQueue.defaultMaxConcurrentOperationCount
        XCTAssertNotNil(testManager.deleteTasks([URLString]))
        verifyDeletedTaskOfURLString(URLString, trashOpened: false)
        _ = testManager.deleteAllTasks()
        _ = testManager.emptyToDeleteList()
        XCTAssert(testManager.downloadTaskInfo.isEmpty, "All tasks should be deleted")
        if testManager.countOfRunningTask > 0{
            XCTFail("All executing operations should be cancelled")
            NSLog("\(testManager.downloadQueue.operations)")
        }
        testManager.saveDataWithoutCheckMechanism()
        XCTAssertTrue(SDEDownloadManager.destoryManager(testManager.identifier))
    }
    
    func getARealTaskInfo() -> Dictionary<String, Any>{
        if let taskInfo = testManager.downloadTaskInfo[URLString]{
            return taskInfo
        }else{
            XCTAssertNotNil(testManager.download([URLString]))
            sleep(15)
            XCTAssertNotNil(testManager.stopTasks([URLString]))
            sleep(1)
            verifyStoppedTaskOfURLString(URLString)
            return testManager.downloadTaskInfo[URLString]!
        }
    }
    
    // add almost 1000 items in everytime call
    func addFakeInfo(to DownloadInfo: Dictionary<String, Dictionary<String, Any>>, URLString: String, info: Dictionary<String, Any>) -> Dictionary<String, Dictionary<String, Any>>{
        var fakeDownloadInfo = DownloadInfo
        let saveItemsCount = 200
        (0...saveItemsCount).forEach({_ in
            UUID().uuidString.components(separatedBy: "-").forEach({ randomString in
                let fakeKey = URLString + randomString
                fakeDownloadInfo[fakeKey] = info
            })
        })
        return fakeDownloadInfo
    }
    
    func testSave1000Items() {
        let taskInfo = getARealTaskInfo()
        
        // Save almost 1000 Items
        testManager.downloadTaskInfo = addFakeInfo(to:testManager.downloadTaskInfo, URLString: URLString, info: taskInfo)
        self.measure {
            testManager.saveDataWithoutCheckMechanism()
        }
    }
    
    func testSave1000ItemsThenLoad(){
        self.measure({
            testManager.loadData()
        })
    }
    
    func testSave2000Items(){
        let taskInfo = getARealTaskInfo()
        
        // Save almost 2000 Items
        testManager.downloadTaskInfo = addFakeInfo(to: testManager.downloadTaskInfo, URLString: URLString, info: taskInfo)
        self.measure {
            testManager.saveDataWithoutCheckMechanism()
        }
    }
    
    func testSave2000ItemsThenLoad(){
        self.measure({
            testManager.loadData()
        })
    }
    
    func testSave3000Items(){
        let taskInfo = getARealTaskInfo()
        
        // Save almost 3000 Items
        testManager.downloadTaskInfo = addFakeInfo(to: testManager.downloadTaskInfo, URLString: URLString, info: taskInfo)
        self.measure {
            testManager.saveDataWithoutCheckMechanism()
        }
    }
    
    func testSave3000ItemsThenLoad(){
        self.measure({
            testManager.loadData()
        })
    }
    
    func testSave4000Items(){
        let taskInfo = getARealTaskInfo()
        
        // Save almost 4000 Items
        testManager.downloadTaskInfo = addFakeInfo(to: testManager.downloadTaskInfo, URLString: URLString, info: taskInfo)
        self.measure {
            testManager.saveDataWithoutCheckMechanism()
        }
    }
    
    func testSave4000ItemsThenLoad(){
        self.measure({
            testManager.loadData()
        })
    }
    
    func testSave5000Items(){
        let taskInfo = getARealTaskInfo()
        
        // Save almost 5000 Items
        testManager.downloadTaskInfo = addFakeInfo(to: testManager.downloadTaskInfo, URLString: URLString, info: taskInfo)
        self.measure {
            testManager.saveDataWithoutCheckMechanism()
        }
    }
    
    func testSave5000ItemsThenLoad(){
        self.measure({
            testManager.loadData()
        })
    }
    
}
