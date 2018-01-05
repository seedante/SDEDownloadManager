//
//  DownloadManagerExtension.swift
//  SDEDownloadManager
//
//  Created by seedante on 8/16/17.
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

@objc extension SDEDownloadManager{
    // MARK: - Subscript
    /**
     Get the location of download task in `downloadList` based on its download URL string.
     
     - parameter URLString: The download URL string.
     
     - returns: An index path representing task location in `downloadList`, or nil if
     it's not in `downloadList`.
     */
    public subscript(URLString: String) -> IndexPath?{
        guard _downloadTaskSet.contains(URLString) else{return nil}
        
        if _downloadTaskSet.count < 50 || _sortType == .manual{
            for (section, subList) in sortedURLStringsList.enumerated(){
                if let row = subList.index(of: URLString){
                    return IndexPath(row: row, section: section)
                }
            }
            return nil
        }
        
        let comparator = sorter.ascendingComparatorForType(sortType, compareWithDM: true)
        func updateSectionIndex(_ index: inout Int){
            guard let sectionTitle = sorter.rawTitleForTask(URLString, sortType: _sortType) else{return}
            guard let sectionIndex = sectionTitleList.index(of: sectionTitle) else{return}
            index = sectionIndex
        }
        func indexInSection(_ section: Int) -> Int?{
            let sortedList: [String] = sortOrder == .ascending ? sortedURLStringsList[section] : sortedURLStringsList[section].reversed()
            if let index = sortedList.binaryIndex(of: URLString, ascendingComparator: comparator){
                return sortOrder == .ascending ? index : sortedList.count - 1 - index
            }
            return nil
        }
        
        var sectionIndex: Int = 0
        switch sortType{
        case .addTime:
            if sectioningAddTimeList{
                updateSectionIndex(&sectionIndex)
            }
            if let index = indexInSection(sectionIndex){
                return IndexPath(row: index, section: sectionIndex)
            }
        case .fileName:
            if indexingFileNameList{
                updateSectionIndex(&sectionIndex)
            }
            if let index = indexInSection(sectionIndex){
                return IndexPath(row: index, section: sectionIndex)
            }
        case .fileSize:
            if indexingFileNameList{
                updateSectionIndex(&sectionIndex)
            }
            if let index = indexInSection(sectionIndex){
                return IndexPath(row: index, section: sectionIndex)
            }
        case .fileType:
            if let section = sectionTitleList.index(of: fileType(ofTask: URLString)!), let index = indexInSection(section){
                return IndexPath(row: index, section: section)
            }
        case .manual: break
        }
        
        for (section, subList) in sortedURLStringsList.enumerated(){
            if let row = subList.index(of: URLString){
                return IndexPath(row: row, section: section)
            }
        }

        return nil
    }
    
        
    /**
     Get the URL string of download task based on its location in `downloadList`.
     
     - parameter indexPath: Location in `downloadList`, which is a two-dimensional string array: `[[String]]`.
     
     - returns: The URL string at the location in `downloadList`, or nil if location is beyond the bounds.
     */
    @nonobjc public subscript(indexPath: IndexPath) -> String?{
        // This method must add @nonobjc because Objective-C does not support method overloading, otherwise you will get compile error:
        //
        // Subscript getter with Objective-C selector 'objectForKeyedSubscript:' conflicts with previous declaration with the same
        // Objective-C selector
        //
        // Actually this method get error because a reverse subscript `subscript(URLString: String) -> IndexPath?` is declared brefore it.
        // But reverse subscripts like `subscript(index: Int) -> String?` and `subscript(str: String) -> Int?` are OK.
        // And, if `subscript(indexPath: IndexPath) -> String?` is declared before `subscript(URLString: String) -> IndexPath?`,
        // latter will get the same issue.
        //
        // In Swift 4, @objc has a big change https://github.com/apple/swift-evolution/blob/master/proposals/0160-objc-inference.md
        guard indexPath.section >= 0 else{
            debugNSLog("section: \(indexPath.section) is not a positive.")
            return nil
        }
        guard indexPath.row >= 0 else{
            debugNSLog("row: \(indexPath.row) is not a positive.")
            return nil
        }
        guard indexPath.section < sortedURLStringsList.count else{
            debugNSLog("section:\(indexPath.section) is out of range.")
            return nil
        }
        guard indexPath.row < sortedURLStringsList[indexPath.section].count else{
            debugNSLog("row:\(indexPath.row) is out of range.")
            return nil
        }
        return sortedURLStringsList[indexPath.section][indexPath.row]
    }

    // MARK: - Manage Task Based on Location
    /**
     Resume(continue) tasks at specified locations and return locations of tasks which are resumed successfully.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - returns: Locations of tasks which are resumed successfully. If no task is resumed, return nil.
     */
    public func resumeTasks(at indexPaths: [IndexPath]) -> [IndexPath]?{
        guard !didReachMaxDownloadCount else {return nil}
        guard let taskIPInfo = fetchTaskIPInfo(at: indexPaths) else {return nil}
        guard let resumedTasks = resumeTasks(Array(taskIPInfo.keys)) else{return nil}
        return resumedTasks.map({taskIPInfo[$0]!})
    }

    /**
     Pause tasks at specified locations and return locations of tasks which are paused successfully.
     
     If `pauseDownloadBySuspendingSessionTask == true`, it suspends the relative NSURLSessionDownloadTask
     object; otherwise, stop it by 'cancel(byProducingResumeData:)', they are same results for users.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - returns: Locations of tasks which are paused successfully. If no task is paused, return nil.
     */
    public func pauseTasks(at indexPaths: [IndexPath]) -> [IndexPath]?{
        guard let taskIPInfo = fetchTaskIPInfo(at: indexPaths) else {return nil}
        guard let pausedTasks = pauseTasks(Array(taskIPInfo.keys)) else{return nil}
        return pausedTasks.map({taskIPInfo[$0]!})
    }
    
    /**
     Stop tasks at specified locations and return locations of tasks which are stopped successfully.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - returns: Locations of tasks which are stopped successfully. If no task is stopped, return nil.
     */
    public func stopTasks(at indexPaths: [IndexPath]) -> [IndexPath]?{
        guard let taskIPInfo = fetchTaskIPInfo(at: indexPaths) else {return nil}
        guard let stoppedTasks = stopTasks(Array(taskIPInfo.keys)) else{return nil}
        return stoppedTasks.map({taskIPInfo[$0]!})
    }
    
    /**
     Delete tasks at specified locations and return a Dictionary includes deleted task's URL string
     and its original location in `downloadList`. If data is not loaded, this method will wait.
     
     If `isTrashOpened == true`, tasks will be moved to `toDeleteList`.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - parameter keepFinishedFile: Just works for finished task whose file is downloaded completely.
     For task whose state is not finished, this parameter is ignored. The default value is `false`.
     You can get file location by `fileURL(ofTask:) -> URL?` before calling this method.
     
     - returns: A Dictionary includes info of deleted tasks. Key: URL string of deleted task, Value: task
     original location in `downloadList`. Return nil if no task is deleted.
     */
    public func deleteTasks(at indexPaths: [IndexPath], keepFinishedFile: Bool = false) -> Dictionary<String, IndexPath>?{
        waitIfDataNotLoaded()
        guard let validTaskIPs = fetchTaskIPs(at: indexPaths) else {return nil}
        return deleteTasksWithLocations(validTaskIPs, keepFile: keepFinishedFile)
    }
    
    /**
     Delete file only and keep task record, and return locations of tasks whose file are deleted successfully.
     If data is not loaded, this method will wait.
     
     Relative file will be deleted no matter whether file is downloaded completely or not.
     
     Specially, if task's state is .pending, it's also included in returned result.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - returns: Locations of tasks whose file are deleted, or nil if no file is deleted.
     */
    public func deleteFilesOfTasks(at indexPaths: [IndexPath]) -> [IndexPath]?{
        waitIfDataNotLoaded()
        guard let taskIPInfo = fetchTaskIPInfo(at: indexPaths) else {return nil}
        guard let deletedTasks = deleteFilesOfTasks(Array(taskIPInfo.keys)) else{return nil}
        return deletedTasks.map({taskIPInfo[$0]!})
    }
    
    /**
     Redownload files of tasks at the specified locations if task is finished or stopped, and return
     locations of tasks which are restarted successfully. The downloaded file will be deleted before
     restart.
     
     - parameter indexPaths: Task locations in `downloadList`.
     
     - returns: Locations of tasks which are restarted successfully, or nil if no task is restarted.
     */
    public func restartTasks(at indexPaths: [IndexPath]) -> [IndexPath]?{
        guard let taskIPInfo = fetchTaskIPInfo(at: indexPaths) else {return nil}
        guard let restartedTasks = restartTasks(Array(taskIPInfo.keys)) else{return nil}
        return restartedTasks.map({taskIPInfo[$0]!})
    }
    
    // MARK: Manage Tasks in Section
    /**
     Resume(continue) tasks in specified section and return locations of tasks which are resumed successfully.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - returns: Locations of tasks which are resumed successfully. If no task is resumed, return nil.
     */
    public func resumeTasksInSection(_ section: Int) -> [IndexPath]?{
        guard !didReachMaxDownloadCount else {return nil}
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return resumeTasks(at: indexPaths)
    }
    
    /**
     Pause tasks in specified section and return locations of tasks which are paused successfully.
     
     If `pauseDownloadBySuspendingSessionTask == true`, it suspends the relative NSURLSessionDownloadTask
     object; otherwise, stop it by 'cancel(byProducingResumeData:)', they are same results for users.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - returns: Locations of tasks which are paused successfully. If no task is paused, return nil.
     */

    public func pauseTasksInSection(_ section: Int) -> [IndexPath]?{
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return pauseTasks(at: indexPaths)
    }
    /**
     Stop tasks in specified section and return locations of tasks which are stopped successfully.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - returns: Locations of tasks which are stopped successfully. If no task is stopped, return nil.
     */

    public func stopTasksInSection(_ section: Int) -> [IndexPath]?{
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return stopTasks(at: indexPaths)
    }
    /**
     Delete tasks in specified section and return a Dictionary includes deleted task's URL string
     and its original location in `downloadList`. If data is not loaded, this method will wait.
     
     If `isTrashOpened == true`, tasks will be moved to `toDeleteList`.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - parameter keepFinishedFile: Just works for finished task whose file is downloaded completely.
     For task whose state is not finished, this parameter is ignored. The default value is `false`.
     You can get file location by `fileURL(ofTask:) -> URL?` before calling this method.
     
     - returns: A Dictionary includes info of deleted tasks. Key: URL string of deleted task, Value: task
     original location in `downloadList`. Return nil if no task is deleted.
     */
    public func deleteTasksInSection(_ section: Int, keepFinishedFile: Bool = false) -> Dictionary<String, IndexPath>?{
        waitIfDataNotLoaded()
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return deleteTasks(at: indexPaths, keepFinishedFile: keepFinishedFile)
    }
    /**
     Delete file only and keep task record, and return locations of tasks whose file are deleted successfully.
     If data is not loaded, this method will wait.
     
     Relative file will be deleted no matter whether file is downloaded completely or not.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - returns: Locations of tasks whose file are deleted, or nil if no file is deleted.
     */
    public func deleteFilesOfTasksInSection(_ section: Int) -> [IndexPath]?{
        waitIfDataNotLoaded()
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return deleteFilesOfTasks(at: indexPaths)
    }
    /**
     Redownload files of tasks in specified section if task is finished or stopped, and return
     locations of tasks which are restarted successfully. The downloaded file will be deleted before
     restart.
     
     - parameter section: The section index in `downloadList`. If it's beyond the bounds, return nil.
     
     - returns: Locations of tasks which are restarted successfully, or nil if no task is restarted.
     */
    public func restartTasksInSection(_ section: Int) -> [IndexPath]?{
        guard section >= 0 && sortedURLStringsList.count > section else {return nil}
        let count = sortedURLStringsList[section].count
        guard count > 0 else {return nil}
        let indexPaths = (0..<count).map({ IndexPath.init(row: $0, section: section) })
        return restartTasks(at: indexPaths)
    }
    
    /**
     Remove the section at the specified location if it's empty and return a Boolean value indicating
     whether it works.
     
     - parameter section: The index of the empty section which you want to remove.
     
     - returns: A Boolean value indicating whether empty section is removed. Return false if the specified
     section not empty.
     */
    internal func removeEmptySection(_ section: Int) -> Bool{
        let isEmptySection: Bool = sortedURLStringsList.count > section && sortedURLStringsList[section].isEmpty
        guard isEmptySection == true else{return false}
        sortedURLStringsList.remove(at: section)
        if sectionTitleList.count > section{
            sectionTitleList.remove(at: section)
        }
        return true
    }
    
    // MARK: Manage To-Delete List Based on Location
    /**
     Clean up to-delete tasks in `toDeleteList` at specified locations, and return a Dictionary 
     includes deleted task's URL string and its location info.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter indexes: An array of index location of to-delete task in `toDeleteList`. If you
     have an `IndexSet`, pass it as `Array(indexSet)`; if you have an array of `IndexPath`, pass it as
     `indexPaths.map({$0.row})`.
     
     - returns: A Dictionary includes deleted task info. Key: URL string of deleted task, Value: task
     original location in `toDeleteList` as a `IndexPath` with section 0, it is to be used in
     UITableView/UICollectionView directly. If no task is deleted, return nil.
     */
    public func cleanupToDeleteTasks(at indexes: [Int]) -> Dictionary<String, IndexPath>?{
        guard let todeleteIndexs = validIndexesIn(indexes) else {return nil}
        
        toDeleteCount = todeleteIndexs.count
        deletedCount = 0
        var deletedTaskIps: Dictionary<String, IndexPath> = [:]
        for index in todeleteIndexs.sorted(by: >) {
            if isDeletionCancelled{
                break
            }
            if let deletedTask = _cleanupToDeleteTask(at: index){
                let ip = IndexPath(row: index, section: 0)
                deletedTaskIps[deletedTask] = ip
                deletedCount += 1
                deleteCompletionHandler?(deletedTask, ip, toDeleteCount, deletedCount)
            }
        }
        resetDeleteHandler()
        
        return deletedTaskIps.isEmpty ? nil : deletedTaskIps
    }
    
    /**
     Clean up to-delete tasks in `toDeleteList` in specified continuous range, and return a Dictionary
     includes deleted task's URL string and its location info..
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter startIndex: The start index of range to clean up. It can't be small than 0.
     
     - parameter endIndex: The end index of range to clean up. This value is loose. If it's beyonds
     the bound, this method cleans up from start index to list tail. It can't be small than `startIndex`.
     
     - returns: A Dictionary includes deleted task info. Key: URL string of deleted task, Value: task
     original location in `toDeleteList` as a `IndexPath` with section 0, it is to be used in
     UITableView/UICollectionView directly. If no task is deleted, return nil.
     */
    public func cleanupToDeleteTasks(from startIndex: Int, to endIndex: Int = Int.max) -> Dictionary<String, IndexPath>?{
        guard let todeleteIndexes = descendingIndexes(from: startIndex, to: endIndex) else {return nil}
        
        toDeleteCount = todeleteIndexes.count
        deletedCount = 0
        var cleanedTaskIps: Dictionary<String, IndexPath> = [:]
        for index in todeleteIndexes{
            if isDeletionCancelled{
                break
            }
            if let cleanedTask = _cleanupToDeleteTask(at: index){
                let ip = IndexPath(row: index, section: 0)
                cleanedTaskIps[cleanedTask] = ip
                deletedCount += 1
                deleteCompletionHandler?(cleanedTask, ip, toDeleteCount, deletedCount)
            }

        }
        resetDeleteHandler()
    
        return cleanedTaskIps.isEmpty ? nil : cleanedTaskIps
    }

    /**
     Restore to-delete tasks in `toDeleteList` at specified locations back to `downloadList`
     and return original locations of restored tasks in `toDeleteList`.

     - parameter indexes: An array of index location of to-delete task in `toDeleteList`. If you
     have an IndexSet, pass it as `Array(indexSet)`; if you have an array of IndexPath, pass it as
     `indexPaths.map({$0.row})`.
     
     - parameter indexPath:  Restore location in `downloadList`. If `sortType != .manual`, this
     paramter is ignored. It's your resposibility to check whether location is valid.
     
     - returns: Original locations of restored tasks in `toDeleteList`, or nil if no task is restored.
     Returned value, `[IndexPath]`, not `[Int]`, is to be used in UITableView/UICollectionView directly
     */
    public func restoreToDeleteTasks(at indexes: [Int], toLocation indexPath: IndexPath = IndexPath(row: 0, section: 0)) -> [IndexPath]?{
        let ordered = _sortType == .manual ? true : false
        guard let toRestoreIndexes = validIndexesIn(indexes, ordered: ordered) else {return nil}
        
        let trashListCopy = trashList
        var restoredTasks: [String] = []
        toRestoreIndexes.sorted(by: >).forEach({ index in
            restoredTasks.append(trashList.remove(at: index))
        })
        _downloadTaskSet.formUnion(restoredTasks)
        
        if _sortType != .manual{
            restoreRecordInPredefinedModeForTasks(restoredTasks)
        }else{
            sortedURLStringsList[indexPath.section].insert(contentsOf: toRestoreIndexes.map({ trashListCopy[$0] }), at: indexPath.row)
        }
        
        return toRestoreIndexes.map({ IndexPath(row: $0, section: 0) })
    }
    
    // MARK: Helper
    @nonobjc private func filterSortedIPTasks(at indexPaths: [IndexPath]) -> [(ip: IndexPath, task: String)]? {
        guard !indexPaths.isEmpty else {return nil}
        var validIPTasks: [(ip: IndexPath, task: String)] = []
        
        let sectionCount = sectionTitleList.count
        var elementCountInfo: Dictionary<Int, Int> = [:]
        var indexFilter: Set<IndexPath> = []
        
        for indexPath in indexPaths{
            guard indexFilter.contains(indexPath) == false else {continue}
            indexFilter.insert(indexPath)
            guard indexPath.section < sectionCount else {continue}
            
            if let taskCount = elementCountInfo[indexPath.section]{
                guard indexPath.row < taskCount else {continue}
            }else{
                let taskCount = sortedURLStringsList[indexPath.section].count
                elementCountInfo[indexPath.section] = taskCount
                guard indexPath.row < taskCount else {continue}
            }
            let task = sortedURLStringsList[indexPath.section][indexPath.row]
            validIPTasks.append((indexPath, task))
        }
        return validIPTasks.isEmpty ? nil : validIPTasks
    }
    
    @nonobjc private func fetchTaskIPs(at indexPaths: [IndexPath]) -> [(String, IndexPath)]? {
        if indexPaths.isEmpty{
            return nil
        }
        var validTaskIPs: [(String, IndexPath)] = []
        Set(indexPaths).forEach({ ip in
            if let URLString = self[ip]{
                validTaskIPs.append((URLString, ip))
            }
        })
        return validTaskIPs.isEmpty ? nil : validTaskIPs
    }
    
    private func fetchTaskIPInfo(at indexPaths: [IndexPath]) -> Dictionary<String, IndexPath>?{
        if indexPaths.isEmpty{
            return nil
        }
        
        var taskIPInfo: Dictionary<String, IndexPath> = [:]
        Set(indexPaths).forEach({ ip in
            if let URLString = self[ip]{
                taskIPInfo[URLString] = ip
            }
        })
        
        return taskIPInfo.isEmpty ? nil : taskIPInfo
    }


    private func validIndexesIn(_ locations: [Int], ordered: Bool = false) -> [Int]?{
        guard !trashList.isEmpty else {return nil}
        guard !locations.isEmpty else {return nil}
        let maxIndex = trashList.count
        let validIndexes: [Int] = Set(locations).filter({ $0 < maxIndex })
        guard !validIndexes.isEmpty else {return nil}
        
        if ordered{
            let validIndexSet = Set(validIndexes)
            if validIndexSet.count == locations.count{
                return locations
            }else{
                var indexSet: Set<Int> = []
                return locations.filter({ index in
                    if validIndexSet.contains(index) && !indexSet.contains(index){
                        indexSet.insert(index)
                        return true
                    }else{
                        return false
                    }
                })
            }
        }else{
            return validIndexes
        }
    }
    
    private func descendingIndexes(from startIndex: Int, to endIndex: Int) -> [Int]?{
        guard !trashList.isEmpty else {return nil}
        guard endIndex >= startIndex else {return nil}
        guard startIndex >= 0 && startIndex < trashList.count else {return nil}
        let lastIndex = endIndex >= trashList.count ? trashList.count - 1 : endIndex
        
        return (startIndex...lastIndex).reversed()
    }

    // MARK: Change File Name and Section Title
    /**
     Change file display name.
     
     - precondition: Task is not in `toDeleteList`.
     
     - parameter URLString: The URL string of task which you want to change.
     - parameter newDisplayName: New Name. It can't be empty string.
     */
    public func changeDisplayNameOfTask(_ URLString: String, to newDisplayName: String){
        let changeIP = indexPathToChangeName
        indexPathToChangeName = nil
        guard let taskInfo = downloadTaskInfo[URLString] else {return}
        guard _downloadTaskSet.contains(URLString) else {return}
        guard isNotEmptyString(newDisplayName) else {return}
        
        let originalName = (taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] ?? taskInfo[TIFileNameStringKey]) as! String
        var destinationName: String?
        
        if newDisplayName.contains("."){
            let components = newDisplayName.components(separatedBy: ".")
            let newName: String
            if let fe = taskInfo[TIFileExtensionStringKey] as? String, fe == components.last!.lowercased(){
                // if newDisplayName is ".mp4", here newName is "", it's not allowed. 
                newName = components.dropLast().joined(separator: ".")
            }else{
                newName = newDisplayName
            }
            if newName != "" && newName != originalName{
                destinationName = newName
            }else{
                return
            }
        }else if newDisplayName != originalName{
            destinationName = newDisplayName
        }else{
            return
        }
        
        guard let newName = destinationName else {return}
        
        var userInfo: Dictionary<String, Any> = ["URLString": URLString]
        userInfo["IndexPath"] = changeIP
        sorter.removeTaskBeforeChangeNameForTask(URLString)
        downloadTaskInfo[URLString]?[SDEDownloadManager.TIFileDisplayNameStringKey] = newName
        sorter.readdTaskAfterChangeNameForTask(URLString)
        
        let newIPKey = "NewIndexPath"
        let newTitleKey = "NewSectionTitle"
        switch _sortType {
        case .fileName:
            let comparator = sorter.ascendingComparatorForType(.fileName, compareWithDM: true)
            if indexingFileNameList{
                let location = changeIP ?? self.indexPath(ofTask: URLString)!
                let section = location.section
                
                let titleForNewName = sorter.indexingTitleForStr(newName)
                if titleForNewName == sectionTitleList[section]{ // move in same section
                    var ascendingTasks = sortedURLStringsList[section]
                    ascendingTasks.remove(at: location.row)
                    if _sortOrder == .descending{
                        ascendingTasks.reverse()
                    }
                    let insertIndex = ascendingTasks.binaryIndex(for: URLString, ascendingComparator: comparator)
                    let newRow = _sortOrder == .ascending ? insertIndex : ascendingTasks.count - insertIndex
                    if newRow != location.row{
                        userInfo[newIPKey] = IndexPath(row: newRow, section: section)
                    }
                }else if let otherSection = sectionTitleList.index(of: titleForNewName){//move to another section
                    let ascendingTasks = _sortOrder == .ascending ? sortedURLStringsList[otherSection] : sortedURLStringsList[otherSection].reversed()
                    let insertIndex = ascendingTasks.binaryIndex(for: URLString, ascendingComparator: comparator)
                    let newRow = _sortOrder == .ascending ? insertIndex : ascendingTasks.count - insertIndex
                    userInfo[newIPKey] = IndexPath(row: newRow, section: otherSection)
                }else{//insert a new section
                    let titleComparator: (String, String) -> Bool = {
                        if $0 == "#" && $1 != "#"{
                            return false
                        }else if $0 != "#" && $1 == "#"{
                            return true
                        }else{
                            return $0 < $1
                        }
                    }
                    let titles = _sortOrder == .ascending ? sectionTitleList : sectionTitleList.reversed()
                    let insertIndex = titles.binaryIndex(for: titleForNewName, ascendingComparator: titleComparator)
                    let newSection = _sortOrder == .ascending ? insertIndex : titles.count - insertIndex
                    userInfo[newTitleKey] = titleForNewName
                    userInfo[newIPKey] = IndexPath.init(row: 0, section: newSection)
                }
            }else{
                var ascendingTasks = sortedURLStringsList[0]
                if let index = changeIP?.row{
                    ascendingTasks.remove(at: index)
                    if _sortOrder == .descending{
                        ascendingTasks.reverse()
                    }
                }else{
                    if _sortOrder == .descending{
                        ascendingTasks.reverse()
                    }
                    let index = ascendingTasks.binaryIndex(of: URLString, ascendingComparator: comparator) ?? ascendingTasks.index(of: URLString)!
                    ascendingTasks.remove(at: index)
                }

                let insertIndex = ascendingTasks.binaryIndex(for: URLString, ascendingComparator: comparator)
                let newRow = _sortOrder == .ascending ? insertIndex : ascendingTasks.count - insertIndex
                userInfo[newIPKey] = IndexPath(row: newRow, section: 0)
            }
        case .fileType:
            let location = changeIP ?? self.indexPath(ofTask: URLString)!
            var ascendingTasks = sortedURLStringsList[location.section]
            ascendingTasks.remove(at: location.row)
            if _sortOrder == .descending{
                ascendingTasks.reverse()
            }
            
            let comparator = sorter.ascendingComparatorForType(.fileType, compareWithDM: true)
            let insertIndex = ascendingTasks.binaryIndex(for: URLString, ascendingComparator: comparator)
            let newRow = _sortOrder == .ascending ? insertIndex : ascendingTasks.count - insertIndex
            if newRow != location.row{
                userInfo[newIPKey] = IndexPath(row: newRow, section: location.section)
            }
        default:
            break
        }
        
        NotificationCenter.default.post(name: SDEDownloadManager.NNChangeFileDisplayName,
                                        object: self,
                                        userInfo: userInfo)
    }
    

    
    /**
     Change section title in manual mode.
     
     - precondition: `sortType == .manual`.
     
     - parameter section:  The section which you want to change.
     - parameter newTitle: New title used in the header view.
     */
    public func changeTitleOfSection(_ section: Int, to newTitle: String){
        guard sortType == .manual else{return}
        guard section < sectionTitleList.count else {return}
        sectionTitleList[section] = newTitle
    }

    
    // MARK: - Query Info Based on URL String
    /**
     Query download task's location in `downloadList`.
     
     - parameter URLString: The download URL string of task.
     
     - returns: An index path representing task location in `downloadList`, or nil if
     it's not in `downloadList`(but it maybe in `toDeleteList`).
     */
    public func indexPath(ofTask URLString: String) -> IndexPath?{
        return self[URLString]
    }
    
    /**
     Query info of download task.
     
     - parameter URLString:  The download URL string of task.
     
     - returns: A dictionary includes task information, or nil if URLString is not in the download manager.
     */
    public func info(ofTask URLString: String) -> Dictionary<String, Any>?{
        return downloadTaskInfo[URLString]
    }
    
    /**
     Query specified info about download task. This method is designed to query info which is added from
     outer by `fetchMetaInfoHandler`.
     
     - parameter URLString: The download URL string of task.
     - parameter key: A string of key to query.
     
     - returns: Relavtive info. You must known which type it is.
     */
    public func info(ofTask URLString: String, about key: String) -> Any?{
        return downloadTaskInfo[URLString]?[key]
    }
    
    /**
     Query download task state.
     
     - parameter URLString: The download URL string of task.
     
     - returns: An enum value which indicates download task state.
     */
    public func downloadState(ofTask URLString: String) -> DownloadState{
        guard let stateValue = downloadTaskInfo[URLString]?[TITaskStateIntKey] as? Int else{return .notInList}
        return DownloadState(rawValue: stateValue)!
    }
    
    
    /**
     Query the display name of file in the download task. If `hiddenFileExtension == true`, returned string
     doesn't include file extension.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A string, or nil if URLString is not in download manager. Most time it's file name, it's
     maybe URL string self if file name can't be fetched.
     */
    public func fileDisplayName(ofTask URLString: String) -> String?{
        guard let taskInfo = downloadTaskInfo[URLString] else {return nil}
        
        let name = (taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] ?? taskInfo[TIFileNameStringKey]) as! String
        if hiddenFileExtension{
            return name
        }else{
            if let fileExtension = taskInfo[TIFileExtensionStringKey] as? String{
                return name + "." + fileExtension
            }else{
                return name
            }
        }
    }
    
    /**
     Query download progress([0, 1]). If task is downloading, value returned by this method is not right.
     How to get realtime progress when downloading? The answer is property `downloadActivityHandler`.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A float value in `0.0...1.0`. Specially, return -1 if URLString is not in the download
     manger; return 0 if progress is unknown.
     */
    public func downloadProgress(ofTask URLString: String) -> Float{
        let state = downloadState(ofTask: URLString)
        switch state {
        case .notInList: return -1
        case .finished:
            if let fileLocation = fileURL(ofTask: URLString), (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true{
                return 1.0
            }else{
                return 0
            }
        default:
            let progress = downloadTaskInfo[URLString]?[TIProgressFloatKey] as? Float
            return progress == nil ? 0.0 : progress!
        }
    }
    
    /**
     Query file size by byte count.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A Int64 value representing file byte count. Specially, return -1 if URLStrig is not in the
     download manager, or file size is unknown.
     */
    public func fileByteCount(ofTask URLString: String) -> Int64{
        guard let fileSize = downloadTaskInfo[URLString]?[TIFileByteCountInt64Key] as? Int64 else{return -1}
        return fileSize
    }
    
    
    /**
     Query local path of downloaded file.
     
     - parameter URLString: The download URL string of task.
     
     - returns: An absolute path string(start with "/") if file is downloaded already, otherwise nil.
     */
    public func filePath(ofTask URLString: String) -> String?{
        guard let relativePath = downloadTaskInfo[URLString]?[TIFileLocationStringKey] as? String else{return nil}
        if relativePath.starts(with: "/"){// this task is imported from outer
            return NSHomeDirectory() + relativePath
        }else{
            return NSHomeDirectory() + "/" + relativePath
        }
        
    }
    
    /**
     Query local path of downloaded file by URL.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A file URL if file is downloaded already; otherwise nil.
     */
    public func fileURL(ofTask URLString: String) -> URL?{
        guard let _relativePath = downloadTaskInfo[URLString]?[TIFileLocationStringKey] as? String else{return nil}
        let relativePath: String
        if _relativePath.starts(with: "/"){// this task is imported from outer
            let firstIndex = _relativePath.index(after: _relativePath.startIndex)
            relativePath = String(_relativePath[firstIndex..<_relativePath.endIndex])
        }else{
            relativePath = _relativePath
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(relativePath)
    }
    
    /**
     Query detail about download activity. 
     
     Sometimes it's error info. And most times this method return task's download progress info: if task is
     not finished, return a string of (downloadedSize)/(fileSize); if finished, return a string of
     (fileSize).
     
     Note: This method returns nil if task is downloading, you can fetch it in `downloadActivityHandler`.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A string describing download activity, or nil if URLString is not in the download manager or
     task is downloading.
     */
    open func downloadDetail(ofTask URLString: String) -> String?{
        return downloadTaskInfo[URLString]?[TIDownloadDetailStringKey] as? String
    }
    
    /**
     Query file type. Predefined types: Image, Audio, Video, Document, Other.
     
     - parameter URLString: The download URL string of task.
     
     - returns: A string describing file type, or nil if URLString is not in the download manager.
     */
    public func fileType(ofTask URLString: String) -> String?{
        return downloadTaskInfo[URLString]?[TIFileTypeStringKey] as? String
    }
    
    /**
     Check whether downloaded file is existed.
     
     - parameter URLString: The download URL string of task.
     
     - returns: Return true only if task is finished and file is existed, otherwise false.
     */
    public func isFileExisted(ofTask URLString: String) -> Bool{
        let filePath: String? = self.filePath(ofTask: URLString)
        if filePath == nil{
            return false
        }else{
            return FileManager.default.fileExists(atPath: filePath!)
        }
    }
    
    // MARK: Query Info Based on Location
    /**
     Query the URL string of download task at specified location.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A URL string, or nil if indexPath is beyond the bounds.
     */
    public func downloadURLString(at indexPath: IndexPath) -> String? {
        return self[indexPath]
    }
    
    /**
     Query download task state.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: An enum value which indicates task state.
     */
    public func downloadState(at indexPath: IndexPath) -> DownloadState{
        guard let URLString = self[indexPath] else{return .notInList}
        return downloadState(ofTask: URLString)
    }
    
    /**
     Query display name of file in the download task. If `hiddenFileExtension == true`, returned string
     doesn't include file extension.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A string, or nil if indexPath is beyond the bounds. Most time it's file name, maybe
     URL string if can't fetch file name from URL.
     */
    public func fileDisplayName(at indexPath: IndexPath) -> String?{
        guard let URLString = self[indexPath] else{return nil}
        return fileDisplayName(ofTask: URLString)
    }
    
    /**
     Query download progress([0, 1]). If task is downloading, value returned by this method is not right.
     How to get realtime progress when downloading? The answer is property `downloadActivityHandler`.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A Float value in `0.0...1.0`. Specially, return -1 if indexPath is beyond the bounds; return 0 if progress is unknown.
     */
    public func downloadProgress(at indexPath: IndexPath) -> Float{
        guard let URLString = self[indexPath] else{return -1}
        return downloadProgress(ofTask: URLString)
    }

    /**
     Query file size by byte count.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: An Int64 value. Specially, return -1 if indexPath is beyond the bounds or it's unknown.
     */
    public func fileByteCount(at indexPath: IndexPath) -> Int64{
        guard let URLString = self[indexPath] else{return -1}
        return fileByteCount(ofTask: URLString)
    }
    
    /**
     Query downloaded file's absolute path.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: An absolute path string(start with "/") if file is downloaded already, otherwise nil.
     */
    public func filePath(at indexPath: IndexPath) -> String?{
        guard let URLString = self[indexPath] else{return nil}
        return filePath(ofTask: URLString)
    }
    
    /**
     Query downloaded file's absolute path by URL.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A file URL if file is downloaded already, otherwise nil.
     */
    public func fileURL(at indexPath: IndexPath) -> URL? {
        guard let URLString = self[indexPath] else{return nil}
        return fileURL(ofTask: URLString)
    }
    
    /**
     Query detail about download activity.
     
     Sometimes it's error info. And most times this method return task's download progress info: if task is
     not finished, return a string of (downloadedSize)/(fileSize); if finished, return a string of
     (fileSize).

     Note: This method returns nil if task is downloading, you can fetch it in `downloadActivityHandler`.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A String describing download activity, or nil if location is beyond the bounds or task is downloading.
     */
    public func downloadDetail(at indexPath: IndexPath) -> String?{
        guard let URLString = self[indexPath] else{return nil}
        return downloadDetail(ofTask: URLString)
    }
    
    /**
     Query file type. Predefined types: Image, Audio, Video, Document, Other.
     
     - parameter indexPath: Task location in `downloadList`.
     
     - returns: A string describing file type, or nil if location is beyond the bounds.
     */
    public func fileType(at indexPath: IndexPath) -> String? {
        guard let URLString = self[indexPath] else{return nil}
        return fileType(ofTask: URLString)
    }
    
    // MARK: - Frequently-used Properties
    internal var isAnyTaskUnfinished: Bool{
        for URLString in _downloadTaskSet{
            if downloadState(ofTask: URLString) != .finished{
                return true
            }
        }
        return false
    }
    
    internal var countOfPendingTask: Int{
        return pendingOperations.count
    }
    
    // running task + paused task
    internal var countOfStartedTask: Int{
        return downloadOperations.filter({$0.started == true}).count
    }
    
    /// Count of downloading tasks.
    internal var countOfRunningTask: Int{
        return downloadQueue.operations.filter({$0.isExecuting == true}).count
    }
    
    internal var countOfPausedTask: Int{
        return downloadOperations.filter({$0.started == true && $0.isExecuting == false && $0.isFinished == false}).count
    }
    
    internal var downloadOperations: [DownloadOperation]{
        return (downloadQueue.operations as! [DownloadOperation])
    }
    
    internal var executingOperations: [DownloadOperation]{
        return downloadOperations.filter({$0.isExecuting == true})
    }
    
    internal var pendingOperations: [DownloadOperation]{
        return downloadOperations.filter({$0.started == false})
    }
    
    // MARK: Other Internal Query Methods
    internal func fileExtension(ofTask URLString: String) -> String?{
        return downloadTaskInfo[URLString]?[TIFileExtensionStringKey] as? String
    }
    
    internal func completedDisplayNameOfTask(_ URLString: String) -> String?{
        guard let _ = downloadTaskInfo[URLString] else {return nil}
        
        let fileExtension = downloadTaskInfo[URLString]?[TIFileExtensionStringKey] as? String
        let displayName = (downloadTaskInfo[URLString]![SDEDownloadManager.TIFileDisplayNameStringKey] ?? downloadTaskInfo[URLString]![TIFileNameStringKey]) as! String
        return fileExtension == nil ? displayName : displayName + "." + fileExtension!
    }    
    
    // Don't just pass a Int in parameter timeout http://stackoverflow.com/questions/25528695/dispatch-semaphore-wait-does-not-wait-on-semaphore
    @nonobjc private func info(ofTask URLString: String, timeout: DispatchTime = DispatchTime.distantFuture) -> (Int?, String?, String?, Int64?){
        var serverResponse: HTTPURLResponse?
        let sema = DispatchSemaphore(value: 0)
        let fetchURLRequest = NSMutableURLRequest(url: URL(string: URLString)!)
        fetchURLRequest.httpMethod = "HEAD"
        
        URLSession.shared.dataTask(with: fetchURLRequest as URLRequest, completionHandler: {data, response, error in
            serverResponse = response as? HTTPURLResponse
            sema.signal()
        }).resume()
        _ = sema.wait(timeout: timeout)
        return (serverResponse?.statusCode, serverResponse?.suggestedFilename, serverResponse?.mimeType, serverResponse?.expectedContentLength)
    }
    
    
    internal func downloadOperation(ofTask URLString: String) -> DownloadOperation?{
        return downloadOperations.first(where: {$0.URLString == URLString})
    }
    
    /// The resume data for download task based on URLString if the task was terminated and return data to resume.
    internal func resumeData(ofTask URLString: String) -> Data? {
        return downloadTaskInfo[URLString]?[TIResumeDataKey] as? Data
    }
    
    /// The absolute path of downloaded file, if download has not finished, return nil.
    /// Note: from iOS 8, app path is dynamically changed every time the app launch, this path is not the same with last launch, only relative path which file in the app keeps the same.
    /// Changes To App Containers on iOS 8: https://developer.apple.com/library/ios/technotes/tn2406/_index.html
    private func fileRelativePath(ofTaskURLstring URLString: String) -> String? {
        return downloadTaskInfo[URLString]?[TIFileLocationStringKey] as? String
    }
    
    @nonobjc private func fileByteCountAtRealLocation(ofTask URLString: String) -> Int64?{
        guard let filePath = filePath(ofTask: URLString) else{return nil}
        do{
            let attr = try FileManager.default.attributesOfItem(atPath: filePath) as NSDictionary
            return Int64(attr.fileSize())
        }catch{
            return nil
        }
    }
    
    internal func isReallyExecuting(ofTask URLString: String) -> Bool{
        guard let operation = downloadOperation(ofTask: URLString) else{return false}
        return operation.isExecuting
    }
    
    // MARK: - Fix State Issue
    /// resumeData on iOS 8 record its file absolute path, but from iOS 8, app directory is dynamic(it's changed everytime app lanch), so resumed task can't find data.
    func fixResumeDataIssueOniOS8(){
        guard ProcessInfo().operatingSystemVersion.majorVersion == 8 else {return}
        
        guard let stoppedTasks = allTasksSet?.filter({downloadTaskInfo[$0]?[TIResumeDataKey] != nil}) else{return}
        guard stoppedTasks.count > 0 else {return}
        
        let newAppDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path.replacingOccurrences(of: "Documents", with: "")
        
        stoppedTasks.forEach({ URLString in
            let resumeData = downloadTaskInfo[URLString]?[TIResumeDataKey] as! Data
            if var resumeInfo = (try? PropertyListSerialization.propertyList(from: resumeData, options: [.mutableContainersAndLeaves], format: nil)) as? Dictionary<String, AnyObject>{
                var dataLocalPath = resumeInfo["NSURLSessionResumeInfoLocalPath"] as? String
                let range = Range<String.Index>.init(uncheckedBounds: (newAppDirectory.startIndex, newAppDirectory.endIndex))
                dataLocalPath?.replaceSubrange(range, with: newAppDirectory)
                if FileManager.default.fileExists(atPath: dataLocalPath!){
                    resumeInfo["NSURLSessionResumeInfoLocalPath"] = dataLocalPath as AnyObject
                    if let updatedResumeData = try? PropertyListSerialization.data(fromPropertyList: resumeInfo, format: .binary, options: 0){
                        updateMetaInfo([TIResumeDataKey: updatedResumeData], forTask: URLString)
                    }
                }else{
                    let fileDetail = downloadTaskInfo[URLString]?[TIDownloadDetailStringKey] as? String
                    let fileSizeString = fileDetail?.components(separatedBy: "/").last
                    updateMetaInfo([TITaskStateIntKey: DownloadState.pending.rawValue,
                                    TIProgressFloatKey: 0.0,
                                    TIDownloadDetailStringKey: "0 KB/" + fileSizeString!,
                                    TIResumeDataKey: TIDeleteValueMark], forTask: URLString)
                }
            }
        })
    }
    
    /**
     Operation miss issue: .paused, .downloading task has no operation, this usually happen by killing app in Xcode,
     download mananger has no chance to synchronize state change.
     After relaunch the app, download manager will show wrong state for the task.
     */
    internal func fixOperationMissedIssues() -> Bool{
        let abnormalTasks = _downloadTaskSet.filter({
            let state = downloadState(ofTask: $0)
            return (state == .paused || state == .downloading) && downloadOperation(ofTask: $0) == nil
        })
        
        guard abnormalTasks.isEmpty == false else{return false}
        abnormalTasks.forEach({ URLString in
            if resumeData(ofTask: URLString) == nil{
                updateMetaInfo([TITaskStateIntKey: DownloadState.pending.rawValue], forTask: URLString)
            }else{
                updateMetaInfo([TITaskStateIntKey: DownloadState.stopped.rawValue], forTask: URLString)
            }
        })
        return true
    }
    
    // If temp file is processing, this method maybe override info. There need a temp state between .downloading and .finished, but it's rarely useful.
    internal func fixFinishedFileMissedIssues(){
        for task in _downloadTaskSet{
            if downloadState(ofTask: task) == .finished && isFileExisted(ofTask: task) == false{
                let fileSizeSting = (downloadTaskInfo[task]?[TIDownloadDetailStringKey] ?? SDEPlaceHolder) as! String
                updateMetaInfo([TITaskStateIntKey: DownloadState.pending.rawValue,
                                TIDownloadDetailStringKey: "0 KB/" + fileSizeSting,
                                TIResumeDataKey: TIDeleteValueMark], forTask: task)
            }
        }
    }
    
    /**
     Fix operation miss issuse for task which should has an opertion to download file.
     
     - parameter URLString: The download URL string of the task which you want to fix issue for.
     */
    internal func fixOperationMissIssueForTask(_ URLString: String){
        let state = downloadState(ofTask: URLString)
        switch state {
        case .downloading, .paused:
            if downloadOperation(ofTask: URLString) == nil{
                if resumeData(ofTask: URLString) == nil{
                    updateMetaInfo([TITaskStateIntKey: DownloadState.pending.rawValue, TIProgressFloatKey: 0.0], forTask: URLString)
                }else{
                    updateMetaInfo([TITaskStateIntKey: DownloadState.stopped.rawValue], forTask: URLString)
                }
            }
        case .notInList, .finished, .pending, .stopped: break
        }
    }
    
    // MARK: - Debug
    /// Debug method to reproduce download data with random create date and file size.
    /// If the count of existed tasks is larger than specified count, this method will
    /// reduce it to target count.
    ///
    /// - parameter count: The target count of records in `downloadTaskSet`.
    public func reproduceDataToCount(_ count: Int){
        guard count > 1 else {return}
        while !isDataLoaded {}
        guard _downloadTaskSet.isEmpty == false else{
            NSLog("No data to repeoduce")
            return
        }
        guard _downloadTaskSet.count != count else{return}
        sorter.cleanAscendingTaskForType(_sortType)

        let startTime = Date()
        defer {
            NSLog("\(#function)|Time: \(Date().timeIntervalSince(startTime))s")
        }

        NSLog("Start to reproduce data. Target count: \(count)")
        let formatter = ByteCountFormatter()
        
        if _downloadTaskSet.count < count{
            var reached: Bool = false
            while _downloadTaskSet.count < count {
                if reached{
                    break
                }
                for URLString in _downloadTaskSet{
                    if reached{
                        break
                    }
                    let characters = Array(URLString)
                    var clonedTasks: [String] = []
                    for (index, c) in characters.enumerated(){
                        if _downloadTaskSet.count + clonedTasks.count >= count{
                            reached = true
                            break
                        }
                        let cs = String(c)
                        let replace = cs == cs.uppercased() ? cs.lowercased() : cs.uppercased()
                        if replace == cs{
                            continue
                        }
                        var charactersCopy = characters
                        charactersCopy[index] = replace.first!
                        let replaceURLString = String(charactersCopy)
                        guard _downloadTaskSet.contains(replaceURLString) == false else {
                            continue
                        }
                        
                        clonedTasks.append(replaceURLString)
                        
                        guard var info = info(ofTask: URLString) else{continue}
                        let createDate = info[TICreateDateKey] as! Date
                        let fileByteCount = info[TIFileByteCountInt64Key] as! Int64
                        
                        let newCreateDate: Date
                        let newFileSize: Int64
                        if arc4random_uniform(2) == 1{
                            newCreateDate = Date.init(timeInterval: Double(arc4random_uniform(24 * 60 * 60 * 30)), since: createDate)
                            newFileSize = fileByteCount + Int64(arc4random_uniform(1000000))
                        }else{
                            newCreateDate = Date.init(timeInterval: -(Double(arc4random_uniform(24 * 60 * 60 * 30))), since: createDate)
                            if fileByteCount > 0{
                                let sizeSeed: UInt32 = fileByteCount > 1000000 ? 1000000 : UInt32(fileByteCount)
                                newFileSize = fileByteCount - Int64(arc4random_uniform(sizeSeed))
                            }else{
                                newFileSize = -1
                            }
                        }
                        info[TICreateDateKey] = newCreateDate
                        info[TIFileByteCountInt64Key] = newFileSize
                        info[TIDownloadDetailStringKey] = formatter.string(fromByteCount: newFileSize)
                        downloadTaskInfo[replaceURLString] = info
                    }
                    _downloadTaskSet.formUnion(clonedTasks)
                }
                
                NSLog("Reproduce progress: \(_downloadTaskSet.count)")
            }
        }else if _downloadTaskSet.count > count{
            NSLog("Count of existed tasks is larger than target count, reduce it.")
            while _downloadTaskSet.count > count {
                if let first = _downloadTaskSet.popFirst(){
                    downloadTaskInfo.removeValue(forKey: first)
                }
            }
        }
        
        saveData()
        NSLog("Reproduce is over, now task count is: \(_downloadTaskSet.count). Note: cloned data are not added to download list, please sort list to do it.")
    }
    
    /// Print task info. You should custom code to print info you want.
    public func printInfoForTask(_ task: String){
        guard downloadTaskInfo.index(forKey: task) != nil else {
            return
        }
        
        NSLog("Task URL: \(task) | State: \(downloadState(ofTask: task).description) | FileType: \(fileType(ofTask: task)!) | Size: \(ByteCountFormatter().string(fromByteCount: fileByteCount(ofTask: task))))")
        NSLog("maxDownloadCount: \(maxDownloadCount) maxConcurrentOperationCount: \(downloadQueue.maxConcurrentOperationCount) exe: \(countOfRunningTask) pau:\(countOfPausedTask)")
    }
}
