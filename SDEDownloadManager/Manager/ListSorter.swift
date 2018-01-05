//
//  ListSorter.swift
//  SDEDownloadManager
//
//  Created by seedante on 10/23/17.
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

internal class ListSorter {
    unowned var dm: SDEDownloadManager
    init(dm: SDEDownloadManager) {
        self.dm = dm
    }
    
    // MARK: Update 
    lazy var waittingSetForAddTime:  Set<String> = []
    lazy var waittingSetForFileName: Set<String> = []
    lazy var waittingSetForFileSize: Set<String> = []
    lazy var waittingSetForFileType: Set<String> = []
    
    lazy var serialQueue: DispatchQueue = {DispatchQueue(label: "SerialQueue.ListSorter.\(self.dm.identifier)", attributes: [])}()
    func addTasks(_ tasks: [String]){
        serialQueue.sync(execute: {
            sortType2Tasks[.addTime]?.append(contentsOf: tasks)
            if listSortedInfo[.fileName] == true{
                waittingSetForFileName.formUnion(tasks)
            }
            if listSortedInfo[.fileSize] == true{
                waittingSetForFileSize.formUnion(tasks)
            }
            if listSortedInfo[.fileType] == true{
                waittingSetForFileType.formUnion(tasks)
            }
        })
    }
    
    func restoreTasks(_ tasks: [String]){
        serialQueue.sync(execute: {
            if listSortedInfo[.addTime] == true{
                waittingSetForAddTime.formUnion(tasks)
            }
            
            if listSortedInfo[.fileName] == true{
                waittingSetForFileName.formUnion(tasks)
            }
            if listSortedInfo[.fileSize] == true{
                waittingSetForFileSize.formUnion(tasks)
            }
            if listSortedInfo[.fileType] == true{
                waittingSetForFileType.formUnion(tasks)
            }
        })
    }
    
    func removeTaskSet(_ taskSet: Set<String>){
        serialQueue.sync(execute: {
            let types: [ComparisonType] = [.addTime, .fileName, .fileSize]
            for type in types{
                // if it's not sorted, it means list is not sorted by that type ever.
                guard listSortedInfo[type] == true else {continue}
                
                listSortingInfo[type] = true
                let comparator = ascendingComparatorForType(type, compareWithDM: false)
                taskSet.forEach({
                    if let index = sortType2Tasks[type]!.binaryIndex(of: $0, ascendingComparator: comparator){
                        _ = sortType2Tasks[type]!.remove(at: index)
                    }else if let index = sortType2Tasks[type]!.index(of: $0){
                        _ = sortType2Tasks[type]!.remove(at: index)
                    }
                })
                subtractSet(taskSet, fromWaittingSetForType: type)
                listSortingInfo[type] = false
            }
            
            // handler .fileType
            guard listSortedInfo[.fileType] == true else{return}
            listSortingInfo[.fileType] = true
            let comparator = ascendingComparatorForType(.fileType, compareWithDM: false)
            taskSet.forEach({
                if let fileType = dm.fileType(ofTask: $0){
                    if let index = fileType2Tasks[fileType]!.binaryIndex(of: $0, ascendingComparator: comparator){
                        fileType2Tasks[fileType]!.removeObject(at: index)
                    }else{
                        fileType2Tasks[fileType]?.remove($0)
                    }
                }
            })
            subtractSet(taskSet, fromWaittingSetForType: .fileType)
            listSortingInfo[.fileType] = false
            
            dmTaskInfoCopy.removeAll()
        })
    }

    private func subtractSet(_ taskSet: Set<String>, fromWaittingSetForType type: ComparisonType){
        switch type {
        case .addTime:
            if waittingSetForAddTime.isEmpty == false{
                waittingSetForAddTime.subtract(taskSet)
            }
        case .fileName:
            if waittingSetForFileName.isEmpty == false{
                waittingSetForFileName.subtract(taskSet)
            }
        case .fileSize:
            if waittingSetForFileSize.isEmpty == false{
                waittingSetForFileSize.subtract(taskSet)
            }
        case .fileType:
            if waittingSetForFileType.isEmpty == false{
                waittingSetForFileType.subtract(taskSet)
            }
        default:break
        }
    }
    
    func handleWaittingTaskForType(_ type: ComparisonType){
        let waittingSet: Set<String>
        let comparator = ascendingComparatorForType(type, compareWithDM: true)
        switch type {
        case .addTime:
            guard waittingSetForAddTime.isEmpty == false else {return}
            waittingSet = waittingSetForAddTime
            waittingSetForAddTime.removeAll()
        case .fileName:
            guard waittingSetForFileName.isEmpty == false else {return}
            waittingSet = waittingSetForFileName
            waittingSetForFileName.removeAll()
        case .fileSize:
            guard waittingSetForFileSize.isEmpty == false else {return}
            waittingSet = waittingSetForFileSize
            waittingSetForFileSize.removeAll()
        case .fileType:
            guard waittingSetForFileType.isEmpty == false else {return}
            waittingSet = waittingSetForFileType
            waittingSetForFileType.removeAll()
        default: return
        }
        
        listSortingInfo[type] = true
        switch type {
        case .fileType:
            for task in waittingSet{
                if let fileType = dm.fileType(ofTask: task){
                    fileType2Tasks[fileType]?.binaryInsert(task, ascendingComparator: comparator)
                }
            }

        default:
            for task in waittingSet{
                sortType2Tasks[type]?.binaryInsert(task, ascendingComparator: comparator)
            }
        }
        listSortingInfo[type] = false
    }
    
    func adjustFileSizeLocationForTask(_ task: String){
        guard listSortedInfo[.fileSize] == true else {return}
        
        serialQueue.sync(execute: {
            let comparator = ascendingComparatorForType(.fileSize, compareWithDM: true)
            if let index = sortType2Tasks[.fileSize]?.binaryIndex(of: task, ascendingComparator: comparator){
                listSortingInfo[.fileSize] = true
                sortType2Tasks[.fileSize]?.remove(at: index)
                sortType2Tasks[.fileSize]?.binaryInsert(task, ascendingComparator: comparator)
                listSortingInfo[.fileSize] = false
            }
        })
    }
    
    // MARK: Change File Display Name
    func removeTaskBeforeChangeNameForTask(_ task: String){
        if listSortedInfo[.fileName] == true{
            listSortingInfo[.fileName] = true
            if let index = sortType2Tasks[.fileName]?.binaryIndex(of: task, ascendingComparator: fileNameAscendingComparator){
                sortType2Tasks[.fileName]?.remove(at: index)
            }
            listSortingInfo[.fileName] = false
        }
        
        if listSortedInfo[.fileType] == true{
            guard let fileType = dm.fileType(ofTask: task) else{return}
            listSortingInfo[.fileType] = true
            if let index = fileType2Tasks[fileType]?.binaryIndex(of: task, ascendingComparator: fileNameAscendingComparator){
                fileType2Tasks[fileType]?.removeObject(at: index)
            }
            listSortingInfo[.fileType] = false
        }
    }
    
    func readdTaskAfterChangeNameForTask(_ task: String){
        if listSortedInfo[.fileName] == true{
            listSortingInfo[.fileName] = true
            sortType2Tasks[.fileName]?.binaryInsert(task, ascendingComparator: fileNameAscendingComparator)
            listSortingInfo[.fileName] = false
        }
        
        if listSortedInfo[.fileType] == true{
            guard let fileType = dm.fileType(ofTask: task) else{return}
            listSortingInfo[.fileType] = true
            fileType2Tasks[fileType]?.binaryInsert(task, ascendingComparator: fileNameAscendingComparator)
            listSortingInfo[.fileType] = false
        }
    }
    
    // MARK: Cache Sorted Tasks From file
    func cacheAscendingTasks(_ sortedTasks: [String], forType type: ComparisonType){
        switch type {
        case .manual, .fileType: break
        default:
            listSortingInfo[type] = true
            sortType2Tasks[type] = sortedTasks
            listSortedInfo[type] = true
            listSortingInfo[type] = false
        }
    }
    
    func cacheAscendingTypeTasks(_ sortedTasks: [[String]], titles: [String]){
        listSortingInfo[.fileType] = true
        for (index, title) in titles.enumerated() {
            fileType2Tasks[title] = NSMutableArray.init(array: sortedTasks[index])
        }
        listSortedInfo[.fileType] = true
        listSortingInfo[.fileType] = false
    }
    
    func cleanAscendingTaskForType(_ type: ComparisonType){
        switch type {
        case .manual: break
        case .fileType:
            fileType2Tasks.keys.forEach({ fileType in
                fileType2Tasks[fileType]?.removeAllObjects()
            })
            listSortedInfo[type] = false
        default:
            sortType2Tasks[type] = nil
            listSortedInfo[type] = false
        }
    }
    
    // MARK: Sort Info
    var listSortingInfo: Dictionary<ComparisonType, Bool> = [.addTime: false, .fileName: false, .fileSize: false, .fileType: false]
    var listSortedInfo:  Dictionary<ComparisonType, Bool> = [.addTime: false, .fileName: false, .fileSize: false, .fileType: false]
    
    // MARK: Cached Ascending Tasks
    var sortType2Tasks: Dictionary<ComparisonType, [String]> = [:]
    lazy var fileTypeTitles: [String] = [ImageType, AudioType, VideoType, DocumentType, OtherType]
    lazy var fileType2Tasks: Dictionary<String, NSMutableArray> = [ImageType: [],
                                                                   AudioType: [],
                                                                   VideoType: [],
                                                                   DocumentType: [],
                                                                   OtherType: []]
    
    
    // MARK: Comparators
    private lazy var fileNameAscendingComparator: (String, String) -> Bool = {
        let fileName0 = self.dm.fileDisplayName(ofTask: $0)!
        let fileName1 = self.dm.fileDisplayName(ofTask: $1)!
        if fileName0 != fileName1{
            return fileName0.compare(fileName1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
        }else{
            let size0 = (self.dm.downloadTaskInfo[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
            let size1 = (self.dm.downloadTaskInfo[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
            return size0 < size1
        }
    }
    

    
    // copy downloadManager.downloadtaskInfo before delete task, and it's emptyed after removeTaskSet(_:).
    lazy var dmTaskInfoCopy: Dictionary<String, Dictionary<String, Any>> = [:]
    func fileName(ofTask URLString: String) -> String?{
        guard let taskInfo = dmTaskInfoCopy[URLString] else {return nil}
        
        let name = (taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] ?? taskInfo[TIFileNameStringKey]) as! String
        if dm.hiddenFileExtension{
            return name
        }else{
            if let fileExtension = taskInfo[TIFileExtensionStringKey] as? String{
                return name + "." + fileExtension
            }else{
                return name
            }
        }
    }

    func ascendingComparatorForType(_ type: ComparisonType, compareWithDM: Bool) -> (String, String) -> Bool{
        if compareWithDM{
            switch type {
            case .addTime:
                return {
                    let date0 = self.dm.downloadTaskInfo[$0]![TICreateDateKey] as! Date
                    let date1 = self.dm.downloadTaskInfo[$1]![TICreateDateKey] as! Date
                    return date0 < date1
                }
            case .fileSize:
                return {
                    let size0 = (self.dm.downloadTaskInfo[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    let size1 = (self.dm.downloadTaskInfo[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    if size0 != size1{
                        return size0 < size1
                    }else{
                        return self.dm.fileDisplayName(ofTask: $0)!.compare(self.dm.fileDisplayName(ofTask: $1)!,
                                                                            options: [.numeric, .caseInsensitive],
                                                                            range: nil,
                                                                            locale: .current) == .orderedAscending
                    }
                }
            default:
                return fileNameAscendingComparator
            }
        }else{
            switch type {
            case .addTime:
                return {
                    let date0 = self.dmTaskInfoCopy[$0]![TICreateDateKey] as! Date
                    let date1 = self.dmTaskInfoCopy[$1]![TICreateDateKey] as! Date
                    return date0 < date1
                }
            case .fileSize:
                return {
                    let size0 = (self.dmTaskInfoCopy[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    let size1 = (self.dmTaskInfoCopy[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    if size0 != size1{
                        return size0 < size1
                    }else{
                        return self.fileName(ofTask: $0)!.compare(self.fileName(ofTask: $1)!,
                                                                  options: [.numeric, .caseInsensitive],
                                                                  range: nil,
                                                                  locale: .current) == .orderedAscending
                    }
                }
            default:
                return {
                    let fileName0 = self.fileName(ofTask: $0)!
                    let fileName1 = self.fileName(ofTask: $1)!
                    if fileName0 != fileName1{
                        return fileName0.compare(fileName1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
                    }else{
                        let size0 = (self.dmTaskInfoCopy[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                        let size1 = (self.dmTaskInfoCopy[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                        return size0 < size1
                    }
                }
            }
        }
    }
    
    lazy var dateComparators: [(comparator: (Date) -> Bool, title: String)] = {
        let Future = "Time.Future"
        let Today = "Time.Today"
        let Yesterday = "Time.Yesterday"
        let Last7Days = "Time.Last 7 Days"
        let Last30Days = "Time.Last 30 Days"
        let Older = "Time.Older"
        
        let DayInterval: TimeInterval = 24 * 60 * 60
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let futureStart = todayStart.addingTimeInterval(DayInterval)
        
        let comparators: [(comparator: (Date) -> Bool, title: String)] =
            [({$0 >= futureStart}, Future),
             ({Calendar.current.isDateInToday($0)}, Today),
             ({Calendar.current.isDateInYesterday($0)}, Yesterday),
             ({todayStart.timeIntervalSince($0) < 7 * DayInterval}, Last7Days),
             ({todayStart.timeIntervalSince($0) < 30 * DayInterval}, Last30Days),
             ({todayStart.timeIntervalSince($0) >= 30 * DayInterval}, Older)]
        return comparators
    }()

    
    // MARK: Sort
    lazy var collation = UILocalizedIndexedCollation.current()
    lazy var sectionIndexTitles: [String] = {self.collation.sectionIndexTitles}()
    func indexingTitleForStr(_ string: String) -> String{
        let titleIndex = self.collation.section(for: string, collationStringSelector: #selector(NSString.description))
        return sectionIndexTitles[titleIndex]
    }
    
    func isSplitedForType(_ sortType: ComparisonType) -> Bool{
        switch sortType {
        case .addTime:
            return dm.sectioningAddTimeList
        case .fileName:
            return dm.indexingFileNameList
        case .fileSize:
            return dm.sectioningFileSizeList
        case .fileType:
            return true
        default:
            return false
        }
    }
    
    lazy var sizeStandards: [(standard: Int64, title: String)] = {
        let MB: Int64 = 1000000
        let GB: Int64 = 1000 * MB
        
        let UnknowSize = "Unknown Size"
        let ST1MB = "0 ~ 1 MB"
        let ST100MB = "1 MB ~ 100 MB"
        let ST1GB = "100 MB ~ 1 GB"
        let LT1GB = "Larger Than 1 GB"
        
        let standards: [(standard: Int64, title: String)] = [
            (0, UnknowSize), (MB, ST1MB), (100 * MB, ST100MB), (GB, ST1GB), (Int64.max, LT1GB)
        ]
        
        return standards
    }()
    
    func rawTitleForTask(_ task: String, sortType: ComparisonType) -> String?{
        switch sortType {
        case .addTime:
            for (comparator, title) in dateComparators{
                if comparator(dm.downloadTaskInfo[task]![TICreateDateKey] as! Date){
                    return title
                }
            }
            return nil
        case .fileName:
            return indexingTitleForStr(dm.fileDisplayName(ofTask: task)!)
        case .fileSize:
            let fileByteCount = dm.downloadTaskInfo[task]![TIFileByteCountInt64Key] as! Int64
            for (sizeTop, title) in sizeStandards{
                if fileByteCount < sizeTop{
                    return title
                }
            }
            return nil
        case .fileType:
            return dm.fileType(ofTask: task)
        default:
            return nil
        }
    }

    
    func sortedTitlesAndTasks(forType type: ComparisonType, order: ComparisonOrder) -> (titles: [String], tasksList: [[String]]){
        guard dm._downloadTaskSet.isEmpty == false else {return (dm.sectionTitleList, dm.sortedURLStringsList)}
        
        while listSortingInfo[type] == true {}
        let taskSet = dm._downloadTaskSet
        
        let split: Bool = isSplitedForType(type)
        switch type {
        case .addTime:
            if listSortedInfo[type] == false{
                sortType2Tasks[type] = sortedTaskSet(taskSet, byType: type, order: .ascending)
                listSortedInfo[type] = true
            }
            
            handleWaittingTaskForType(.addTime)
            
            if split{
                var descendingTasks = Array(sortType2Tasks[type]!.reversed())
                var title2Tasks: Dictionary<String, NSMutableArray> = [:]
                var titles: [String] = []

                var comparatorStopIndex: Int = 0
                let lastTask = descendingTasks.last!
                let lastTaskCreate = dm.downloadTaskInfo[lastTask]![TICreateDateKey] as! Date
                
                for (index, comparatorAndtitle) in dateComparators.enumerated() {
                    if comparatorAndtitle.comparator(lastTaskCreate){
                        comparatorStopIndex = index
                        break
                    }
                }
                
                var comparatorIndex: Int = 0
                var comparator = dateComparators[comparatorIndex].comparator
                var sectionTitle = dateComparators[comparatorIndex].title
                for (index, task) in descendingTasks.enumerated(){
                    let taskCreateDate = dm.downloadTaskInfo[task]![TICreateDateKey] as! Date
                    while comparator(taskCreateDate) == false {
                        comparatorIndex += 1
                        comparator = dateComparators[comparatorIndex].comparator
                        sectionTitle = dateComparators[comparatorIndex].title
                    }
                    
                    if title2Tasks[sectionTitle] != nil{
                        title2Tasks[sectionTitle]!.add(task)
                    }else{
                        titles.append(sectionTitle)
                        if comparatorIndex == comparatorStopIndex{
                            title2Tasks[sectionTitle] = NSMutableArray.init(array: Array(descendingTasks[index ..< descendingTasks.endIndex]))
                            break
                        }else{
                            title2Tasks[sectionTitle] = [task]
                        }
                    }
                }
                
//                // a little slow
//                for task in descendingTasks{
//                    let addTime = dm.downloadTaskInfo[task]![TICreateDateKey] as! Date
//                    if Calendar.current.isDateInToday(addTime){
//                        if title2Task[Today] != nil{
//                            title2Task[Today]?.add(task)
//                        }else{
//                            title2Task[Today] = [task]
//                            titles.append(Today)
//                        }
//                    }else if Calendar.current.isDateInYesterday(addTime){
//                        if title2Task[Yesterday] != nil{
//                            title2Task[Yesterday]?.add(task)
//                        }else{
//                            title2Task[Yesterday] = [task]
//                            titles.append(Yesterday)
//                        }
//                    }else if todayStart.timeIntervalSince(addTime) < 0{
//                        if title2Task[Future] != nil{
//                            title2Task[Future]?.add(task)
//                        }else{
//                            title2Task[Future] = [task]
//                            titles.insert(Future, at: 0)
//                        }
//                    }else if todayStart.timeIntervalSince(addTime) < 7 * DayInterval{
//                        if title2Task[Last7Days] != nil{
//                            title2Task[Last7Days]?.add(task)
//                        }else{
//                            title2Task[Last7Days] = [task]
//                            titles.append(Last7Days)
//                        }
//                    }else if todayStart.timeIntervalSince(addTime) < 30 * DayInterval{
//                        if title2Task[Last30Days] != nil{
//                            title2Task[Last30Days]?.add(task)
//                        }else{
//                            title2Task[Last30Days] = [task]
//                            titles.append(Last30Days)
//                        }
//                    }else{
//                        if title2Task[Older] != nil{
//                            title2Task[Older]?.add(task)
//                        }else{
//                            title2Task[Older] = [task]
//                            titles.append(Older)
//                        }
//                    }
//                }
                if order == .ascending{
                    titles.reverse()
                }
                
                return order == .descending ? (titles, titles.map({title2Tasks[$0]! as! [String] })) :
                    (titles, titles.map({title2Tasks[$0]!.reversed() as! [String] }))
            }else{
                let ascendingTasks = sortType2Tasks[type]!
                let sortedTasks = order == .ascending ? [ascendingTasks] : [ascendingTasks.reversed()]
                return (["HeaderViewTitle.Sorted by Add Time"], sortedTasks)
            }
        case .fileName:
            if listSortedInfo[type] == false{
                sortType2Tasks[type] = sortedTaskSet(taskSet, byType: type, order: .ascending)
                listSortedInfo[type] = true
            }
            
            handleWaittingTaskForType(type)
            
            if split{
                var titles: [String] = []
                var title2Tasks: Dictionary<String, NSMutableArray> = [:]
                
                
                // UILocalizedIndexedCollation.sectionIndexTitles is A~Z...#, but '#' < 'A'
                // ascendingTaskSet(_:ascendingComparator:) return a list of '#A~Z...'
                // cacheAscendingTasks(_:forType:) use a list of 'A~Z...#'
                let up3 = sectionIndexTitles.last!
                // '#A~Z...#'
                let indexTitles = { () -> [String] in
                    var fixedSectionIndexTitles = sectionIndexTitles
                    fixedSectionIndexTitles.insert(up3, at: 0)
                    return fixedSectionIndexTitles
                }()
                
                let ascendingTasks = sortType2Tasks[type]!
                
                let lastFileName = dm.fileDisplayName(ofTask: ascendingTasks.last!)!
                let lastTitle = indexingTitleForStr(lastFileName)
                var lastTitleIndex = indexTitles.index(of: lastTitle)!
                if lastTitle == up3{
                    let firstFileName = dm.fileDisplayName(ofTask: ascendingTasks.first!)!
                    let firstTitle = indexingTitleForStr(firstFileName)
                    if firstTitle == lastTitle{
                        lastTitleIndex = 0
                    }else{
                        lastTitleIndex = indexTitles.endIndex - 1
                    }
                }
                
                var currentTitleIndex: Int = 0
                var currentTitle: String = indexTitles.first!
                
                for (index, task) in ascendingTasks.enumerated(){
                    guard let fileName = dm.fileDisplayName(ofTask: task) else {continue}
                    
                    while indexingTitleForStr(fileName) != currentTitle {
                        currentTitleIndex += 1
                        currentTitle = indexTitles[currentTitleIndex]
                    }
                    
                    if title2Tasks[currentTitle] != nil{
                        title2Tasks[currentTitle]!.add(task)
                    }else{
                        titles.append(currentTitle)
                        if currentTitleIndex == lastTitleIndex{
                            title2Tasks[currentTitle] = NSMutableArray.init(array: Array(ascendingTasks[index ..< ascendingTasks.endIndex]))
                            break
                        }else{
                            title2Tasks[currentTitle] = [task]
                        }
                    }
                }
                
                if titles.first == up3{
                    _ = titles.removeFirst()
                    titles.append(up3)
                }
                
                if order == .descending{
                    titles.reverse()
                }
                
                return order == .ascending ? (titles, titles.map({ title2Tasks[$0]! as! [String] })) :
                    (titles, titles.map({ title2Tasks[$0]!.reversed() as! [String] }))
            }else{
                let ascendingTasks = sortType2Tasks[type]!
                let sortedTasks = order == .ascending ? [ascendingTasks] : [ascendingTasks.reversed()]
                return (["HeaderViewTitle.Sorted by File Name"], sortedTasks)
            }
        case .fileSize:
            if listSortedInfo[type] == false{
                sortType2Tasks[type] = sortedTaskSet(taskSet, byType: type, order: .ascending)
                listSortedInfo[type] = true
            }
            
            handleWaittingTaskForType(type)
            
            if split{
                let ascendingTasks = sortType2Tasks[type]!
                let lastFileSize = dm.fileByteCount(ofTask: ascendingTasks.last!)
                let UnknowSize = "Unknown Size"
                guard lastFileSize > 0 else {
                    return order == .ascending ? ([UnknowSize], [ascendingTasks]) : ([UnknowSize], [ascendingTasks.reversed()])
                }
              
                var titles: [String] = []
                var title2Tasks: Dictionary<String, NSMutableArray> = [:]
                
                // a little tiny slow
//                func regularEnumeration(){
//                    let MB: Int64 = 1000000
//                    let GB: Int64 = 1000 * MB
//                    
//                    let ST1MB = "0 ~ 1 MB"
//                    let ST100MB = "1 MB ~ 100 MB"
//                    let ST1GB = "100 MB ~ 1 GB"
//                    let LT1GB = "Larger Than 1 GB"
//
//                    func addTask(_ task: String, toSection title: String){
//                        if title2Tasks[title] != nil{
//                            title2Tasks[title]!.add(task)
//                        }else{
//                            title2Tasks[title] = [task]
//                        }
//                    }
//                    
//                    ascendingTasks.forEach({ task in
//                        let byteCount = (self.dm.downloadTaskInfo[task]![TIFileByteCountInt64Key] ?? -1) as! Int64
//                        if byteCount < 0{
//                            addTask(task, toSection: UnknowSize)
//                        }else{
//                            let priority = byteCount / MB
//                            switch priority{
//                            case 0..<1:
//                                addTask(task, toSection: ST1MB)
//                            case 1..<100:
//                                addTask(task, toSection: ST100MB)
//                            case 100..<1000:
//                                addTask(task, toSection: ST1GB)
//                            default:
//                                addTask(task, toSection: LT1GB)
//                            }
//                        }
//                    })
//                    
//                    let traitPriority = [UnknowSize: -1,
//                                         ST1MB: 1,
//                                         ST100MB: 100,
//                                         ST1GB: 1000,
//                                         LT1GB: 10000,]
//                    titles = title2Tasks.keys.sorted(by: {traitPriority[$0]! < traitPriority[$1]!})
//                }

                var standardStopIndex: Int = 0
                for (index, StandardAndTitle) in sizeStandards.enumerated() {
                    if lastFileSize <= StandardAndTitle.standard{
                        standardStopIndex = index
                        break
                    }
                }
                
                var standardIndex: Int = 0
                var currentStandard: Int64 = 0
                var taskTitle: String = UnknowSize
                for (index, task) in ascendingTasks.enumerated() {
                    let fileSize = dm.fileByteCount(ofTask: task)
                    while fileSize > currentStandard {
                        standardIndex += 1
                        currentStandard = sizeStandards[standardIndex].standard
                        taskTitle = sizeStandards[standardIndex].title
                    }
                    
                    if title2Tasks[taskTitle] != nil{
                        title2Tasks[taskTitle]!.add(task)
                    }else{
                        titles.append(taskTitle)
                        if standardIndex == standardStopIndex{
                            title2Tasks[taskTitle] = NSMutableArray.init(array: Array(ascendingTasks[index ..< ascendingTasks.endIndex]))
                            break
                        }else{
                            title2Tasks[taskTitle] = [task]
                        }
                    }
                }
                
                if order == .descending{
                    titles.reverse()
                }
                
                return order == .ascending ? (titles, titles.map({ title2Tasks[$0]! as! [String] })) :
                    (titles, titles.map({ title2Tasks[$0]!.reversed() as! [String] }))
            }else{
                let ascendingTasks = sortType2Tasks[type]!
                let sortedTasks = order == .ascending ? [ascendingTasks] : [ascendingTasks.reversed()]
                return (["HeaderViewTitle.Sorted by File Size"], sortedTasks)
            }
        case .fileType:
            if listSortedInfo[type] == false{
                for (title, tasks) in ascendingTasksByFileType(on: taskSet){
                    fileType2Tasks[title] = tasks
                }
                listSortedInfo[type] = true
            }
            
            handleWaittingTaskForType(type)
            
            let titles = fileTypeTitles.filter({ fileType2Tasks[$0]!.count > 0 })
            if order == .ascending{
                return (titles, titles.map({fileType2Tasks[$0]! as! [String]}))
            }else{
                return (titles, titles.map({fileType2Tasks[$0]!.reversed() as! [String]}))
            }
        case .manual:
            return (dm.sectionTitleList, dm.sortedURLStringsList)
        }
    }
    
    private func ascendingTaskSet(_ taskSet: Set<String>, ascendingComparator: (String, String) -> Bool) -> [String]{
        // Insert 10000 items: Array is a little better than NSMutableArray.
//        var startTime = Date()
        var sortedTasks: [String] = []
        taskSet.forEach({
            sortedTasks.binaryInsert($0, ascendingComparator: ascendingComparator)
        })
//        NSLog("\(#function)|Array|Time: \(Date().timeIntervalSince(startTime))s")
//        startTime = Date()
//        let sortedTaskArray: NSMutableArray = []
//        taskSet.forEach({
//            sortedTaskArray.binaryInsert($0, ascendingComparator: ascendingComparator)
//        })
//        NSLog("\(#function)|NSMutableArray|Time: \(Date().timeIntervalSince(startTime))s")
        return sortedTasks
    }
    
    /// returned titles include all file types
    func ascendingTasksByFileType(on taskSet: Set<String>) -> [(title: String, tasks: NSMutableArray)]{        
        let taskAscendingComparator: (String, String) -> Bool = fileNameAscendingComparator
        // Dictionary + NSMutableArray is better than Dictionary + Array in sorting 10000 items.
        var fileArchive: Dictionary<String, NSMutableArray> = [ImageType: [],
                                                               AudioType: [],
                                                               VideoType: [],
                                                               DocumentType: [],
                                                               OtherType: []]
        taskSet.forEach({
            if let fileType = dm.downloadTaskInfo[$0]?[TIFileTypeStringKey] as? String{
                switch fileType{
                case ImageType:
                    fileArchive[ImageType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                case AudioType:
                    fileArchive[AudioType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                case VideoType:
                    fileArchive[VideoType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                case DocumentType:
                    fileArchive[DocumentType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                default:
                    fileArchive[OtherType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                }
            }else{
                fileArchive[OtherType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
            }
        })
        
        var pairs: [(title: String, tasks: NSMutableArray)] = []
        for fileType in [ImageType, AudioType, VideoType, DocumentType, OtherType] {
            pairs.append((fileType, fileArchive[fileType]!))
        }
        
        return pairs
    }

    /// .fileType is sorted by file name here
    func sortedTaskSet(_ taskSet: Set<String>, byType type: ComparisonType, order: ComparisonOrder) -> [String]{
        let taskAscendingComparator: (String, String) -> Bool = ascendingComparatorForType(type, compareWithDM: true)
        let ascendingTasks: [String] = ascendingTaskSet(taskSet, ascendingComparator: taskAscendingComparator)
        return order == .ascending ? ascendingTasks : ascendingTasks.reversed()
    }
    
    func customSortedTitlesAndTasks(on taskSet: Set<String>,
                                    byOrder order: ComparisonOrder,
                                    taskTrait: ((_ URLString: String) -> String?)? = nil,
                                    traitAscending: ((_ trait: String, _ trait: String) -> Bool)? = nil,
                                    taskAscending: (_ URLString: String, _ URLString: String) -> Bool)
        -> (titles: [String], tasksList: [[String]])
    {
        
        var titles: [String] = []
        var sortedResult: [[String]] = []
        
        if !taskSet.isEmpty{
            if taskTrait == nil{
                titles.append(DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle"))
                let ascendingTasks = ascendingTaskSet(taskSet, ascendingComparator: taskAscending)
                sortedResult = order == .ascending ? [ascendingTasks] : [ascendingTasks.reversed()]
            }else{
                // Dictionary + NSMutableArray is better than Dictionary + Array in sorting 10000 items.
//                var startTime = Date()
                var title2MutableArray: Dictionary<String, NSMutableArray> = [:]
                let nonKeyTaskMutableArray: NSMutableArray = []
                taskSet.forEach({
                    if let sectionTitle = taskTrait!($0){
                        if title2MutableArray[sectionTitle] != nil{
                            title2MutableArray[sectionTitle]!.binaryInsert($0, ascendingComparator: taskAscending)
                        }else{
                            title2MutableArray[sectionTitle] = NSMutableArray.init(object: $0)
                        }
                    }else{
                        nonKeyTaskMutableArray.binaryInsert($0, ascendingComparator: taskAscending)
                    }
                })
//                NSLog("\(#function)|NSMutableArray BinaryInsert|Time: \(Date().timeIntervalSince(startTime))s")
                
                let ascendingTitleArray: NSMutableArray = []
                if traitAscending == nil{
                    title2MutableArray.keys.forEach({
                        ascendingTitleArray.binaryInsert($0, ascendingComparator: {
                            $0.compare($1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
                        })
                    })
                    titles = order == .ascending ? ascendingTitleArray as! [String] : ascendingTitleArray.reversed() as! [String]
                }else{
                    title2MutableArray.keys.forEach({
                        ascendingTitleArray.binaryInsert($0, ascendingComparator: traitAscending!)
                    })
                    titles = order == .ascending ? ascendingTitleArray as! [String] : ascendingTitleArray.reversed() as! [String]
                }
                
                titles.forEach({ title in
                    let tasks = title2MutableArray[title] as! [String]
                    switch order{
                    case .ascending:
                        sortedResult.append(tasks)
                    case .descending:
                        sortedResult.append(tasks.reversed())
                    }
                })
                
                if nonKeyTaskMutableArray.count > 0{
                    titles.append(DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle"))
                    switch order {
                    case .ascending:
                        sortedResult.append(nonKeyTaskMutableArray as! [String])
                    case .descending:
                        sortedResult.append(nonKeyTaskMutableArray.reversed() as! [String])
                    }
                }
                
//                NSLog("\(#function)|NSMutableArray|Order: \(order.description)|Time: \(Date().timeIntervalSince(startTime))s")
//                
//                
//                titles.removeAll()
//                sortedResult.removeAll()
//                startTime = Date()
//                
//                var title2tasks: Dictionary<String, [String]> = [:]
//                var nonKeyTasks: [String] = []
//                taskSet.forEach({
//                    if let sectionTitle = taskTrait!($0){
//                        if title2tasks[sectionTitle] != nil{
//                            title2tasks[sectionTitle]!.binaryInsert($0, ascendingComparator: taskAscending)
//                        }else{
//                            title2tasks[sectionTitle] = [$0]
//                        }
//                    }else{
//                        nonKeyTasks.binaryInsert($0, ascendingComparator: taskAscending)
//                    }
//                })
//                NSLog("\(#function)|Array BinaryInsert|Time: \(Date().timeIntervalSince(startTime))s")
//                
//                var ascendingTitles: [String] = []
//                if traitAscending == nil{
//                    title2tasks.keys.forEach({
//                        ascendingTitles.binaryInsert($0, ascendingComparator: {
//                            $0.compare($1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
//                        })
//                    })
//                }else{
//                    title2tasks.keys.forEach({
//                        ascendingTitles.binaryInsert($0, ascendingComparator: traitAscending!)
//                    })
//                }
//                if order == .descending{
//                    ascendingTitles.reverse()
//                }
//                titles = ascendingTitles
//                
//                titles.forEach({ title in
//                    let tasks = title2tasks[title]!
//                    switch order{
//                    case .ascending:
//                        sortedResult.append(tasks)
//                    case .descending:
//                        sortedResult.append(tasks.reversed())
//                    }
//                })
//                if nonKeyTasks.isEmpty == false{
//                    titles.append(DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle"))
//                    switch order {
//                    case .ascending:
//                        sortedResult.append(nonKeyTasks)
//                    case .descending:
//                        sortedResult.append(nonKeyTasks.reversed())
//                    }
//                }
//                NSLog("\(#function)|Array|Order: \(order.description)|Time: \(Date().timeIntervalSince(startTime))s")
            }
        }
        
        return (titles, sortedResult)
    }

    /**
     The first time to use UILocalizedIndexedCollation takes more time.
     */
    func sortedTitlesAndTasksOnTaskSet(_ taskSet: Set<String>, byType type: ComparisonType, order: ComparisonOrder, split: Bool) -> (titles: [String], tasksList: [[String]]){
        guard taskSet.isEmpty == false else{return ([], [])}
        
        let compareResult: ComparisonResult = order == .ascending ? .orderedAscending : .orderedDescending
        let taskAscendingComparator: (String, String) -> Bool
        
        switch type {
        case .addTime:
            taskAscendingComparator = {
                let date0 = self.dm.downloadTaskInfo[$0]![TICreateDateKey] as! Date
                let date1 = self.dm.downloadTaskInfo[$1]![TICreateDateKey] as! Date
                return date0 < date1
            }
            
            if !split{
                let titles = ["HeaderViewTitle.Sorted by Add Time"]
                let ascendingTasks: [String] = ascendingTaskSet(taskSet, ascendingComparator: taskAscendingComparator)
                return order == .ascending ? (titles, [ascendingTasks]) : (titles, [ascendingTasks.reversed()])
            }
            
            let today = Calendar.current.startOfDay(for: Date())
            let DayInterval: TimeInterval = 24 * 60 * 60
            
            let Future     = "Time.Future"
            let Today      = "Time.Today"
            let Yesterday  = "Time.Yesterday"
            let Last7Days  = "Time.Last 7 Days"
            let Last30Days = "Time.Last 30 Days"
            let Older      = "Time.Older"
            let traitPriority = [Future:      100000,
                                 Today:       1,
                                 Yesterday:  -10,
                                 Last7Days:  -100,
                                 Last30Days: -1000,
                                 Older:      -10000,
                                 ]
            return customSortedTitlesAndTasks(on: taskSet, byOrder: order, taskTrait: { URLString in
                let addTime = self.dm.downloadTaskInfo[URLString]![TICreateDateKey] as! Date
                if Calendar.current.isDateInToday(addTime){
                    return Today
                }else if Calendar.current.isDateInYesterday(addTime){
                    return Yesterday
                }else if today.timeIntervalSince(addTime) < 0{
                    return Future
                }else if today.timeIntervalSince(addTime) < 7 * DayInterval{
                    return Last7Days
                }else if today.timeIntervalSince(addTime) < 30 * DayInterval{
                    return Last30Days
                }else{
                    return Older
                }
            }, traitAscending: {traitPriority[$0]! < traitPriority[$1]!}, taskAscending: taskAscendingComparator)
        case .fileName:
            taskAscendingComparator = {
                let fileName0 = self.dm.fileDisplayName(ofTask: $0)!
                let fileName1 = self.dm.fileDisplayName(ofTask: $1)!
                if fileName0 != fileName1{
                    return fileName0.compare(fileName1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
                }else{
                    let size0 = (self.dm.downloadTaskInfo[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    let size1 = (self.dm.downloadTaskInfo[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    return size0 < size1
                }
            }
            
            if !split{
                let titles = ["HeaderViewTitle.Sorted by File Name"]
                let ascendingTasks: [String] = ascendingTaskSet(taskSet, ascendingComparator: taskAscendingComparator)
                return order == .ascending ? (titles, [ascendingTasks]) : (titles, [ascendingTasks.reversed()])
            }
            
            
            var title2Tasks: Dictionary<String, NSMutableArray> = [:]
            let selector = #selector(NSString.description)
            let sectionIndexTitles = collation.sectionIndexTitles
            taskSet.forEach({ URLString in
                let fileName = dm.fileDisplayName(ofTask: URLString)!
                let titleIndex = collation.section(for: fileName, collationStringSelector: selector)
                let title = sectionIndexTitles[titleIndex]
                if title2Tasks.index(forKey: title) != nil{
                    title2Tasks[title]?.binaryInsert(URLString, ascendingComparator: taskAscendingComparator)
                }else{
                    title2Tasks[title] = NSMutableArray.init(object: URLString)
                }
            })
            
            
            var titles: [String] = title2Tasks.keys.sorted(by: { $0.compare($1) == compareResult})
            if title2Tasks.index(forKey: "#") != nil && title2Tasks.count > 1{
                switch compareResult {
                case .orderedAscending:
                    let tail = titles.removeFirst()
                    titles.append(tail)
                case .orderedDescending:
                    let head = titles.removeLast()
                    titles.insert(head, at: 0)
                case .orderedSame: break
                }
            }
            var alphanumericURLStringsList: [[String]] = []
            if order == .ascending{
                titles.forEach({ title in
                    alphanumericURLStringsList.append(title2Tasks[title] as! [String])
                })
            }else{
                titles.forEach({ title in
                    alphanumericURLStringsList.append(title2Tasks[title]?.reversed() as! [String])
                })
            }
            
            return (titles, alphanumericURLStringsList)
        case .fileSize:
            taskAscendingComparator = {
                let size0 = (self.dm.downloadTaskInfo[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                let size1 = (self.dm.downloadTaskInfo[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                if size0 != size1{
                    return size0 < size1
                }else{
                    return self.dm.fileDisplayName(ofTask: $0)!.compare(self.dm.fileDisplayName(ofTask: $1)!,
                                                                        options: [.numeric, .caseInsensitive],
                                                                        range: nil,
                                                                        locale: .current) == .orderedAscending
                }
            }
            if !split{
                let titles = ["HeaderViewTitle.Sorted by File Size"]
                let sortedTasks: [String] = ascendingTaskSet(taskSet, ascendingComparator: taskAscendingComparator)
                return order == .ascending ? (titles, [sortedTasks]) : (titles, [sortedTasks.reversed()])
            }
            
            let MB: Int64 = 1000000
            let GB: Int64 = 1000 * MB
            
            let UnknowSize = "Unknown Size"
            let ST1MB = "0 ~ 1 MB"
            let ST100MB = "1 MB ~ 100 MB"
            let ST1GB = "100 MB ~ 1 GB"
            let LT1GB = "Larger Than 1 GB"
            let traitPriority = [UnknowSize: 1,
                                 ST1MB: 10,
                                 ST100MB: 100,
                                 ST1GB: 1000,
                                 LT1GB: 10000]
            
            return customSortedTitlesAndTasks(on: taskSet, byOrder: order, taskTrait: { URLString in
                let byteCount = (self.dm.downloadTaskInfo[URLString]![TIFileByteCountInt64Key] ?? -1) as! Int64
                if byteCount < 0{
                    return UnknowSize
                }else if byteCount <= MB{
                    return ST1MB
                }else if byteCount <= 100 * MB{
                    return ST100MB
                }else if byteCount <= GB{
                    return ST1GB
                }else{
                    return LT1GB
                }
            }, traitAscending: {traitPriority[$0]! < traitPriority[$1]!}, taskAscending: taskAscendingComparator)
        case .fileType:
            taskAscendingComparator = {
                let fileName0 = self.dm.fileDisplayName(ofTask: $0)!
                let fileName1 = self.dm.fileDisplayName(ofTask: $1)!
                if fileName0 != fileName1{
                    return fileName0.compare(fileName1, options: [.numeric, .caseInsensitive], range: nil, locale: .current) == .orderedAscending
                }else{
                    let size0 = (self.dm.downloadTaskInfo[$0]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    let size1 = (self.dm.downloadTaskInfo[$1]![TIFileByteCountInt64Key] ?? -1) as! Int64
                    return size0 < size1
                }
            }
            
            
            var fileArchive: Dictionary<String, NSMutableArray> = [ImageType: [],
                                                                   AudioType: [],
                                                                   VideoType: [],
                                                                   DocumentType: [],
                                                                   OtherType: []]
            taskSet.forEach({
                if let fileType = dm.downloadTaskInfo[$0]?[TIFileTypeStringKey] as? String{
                    switch fileType{
                    case ImageType:
                        fileArchive[ImageType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                    case AudioType:
                        fileArchive[AudioType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                    case VideoType:
                        fileArchive[VideoType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                    case DocumentType:
                        fileArchive[DocumentType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                    default:
                        fileArchive[OtherType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                    }
                }else{
                    fileArchive[OtherType]!.binaryInsert($0, ascendingComparator: taskAscendingComparator)
                }
            })
            
            var titles: [String] = []
            var sortedResult: [[String]] = []
            for fileType in [ImageType, AudioType, VideoType, DocumentType, OtherType] {
                if let archivedTasks = fileArchive[fileType], archivedTasks.count > 0{
                    titles.append(fileType)
                    if order == .ascending{
                        sortedResult.append(archivedTasks as! [String])
                    }else{
                        sortedResult.append(archivedTasks.reversed() as! [String])
                    }
                }
            }
            
            return split ? (titles, sortedResult) : (titles, [sortedResult.flatMap({$0})])
        default:
            return ([DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle")], [Array(taskSet)])
        }
    }

}
