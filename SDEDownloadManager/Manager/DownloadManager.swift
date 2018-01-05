//
//  SDEDownloadManager.swift
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


/**
 `SDEDownloadManager` is a download management tool, support background download.

 If you want to build interface to display and manage download tasks, or track download activity,
 `DownloadListController` is a good choice, which is a UITableViewController subclass to coordinate
 with `SDEDownloadManager` and has rich options to reduce a lot of work for you.

 Features:

 * Basic download management: download/pause/stop/resume/restart/delete
 
   All actions for the download task in `SDEDownloadManager` are basis on its download URL string.
   `SDEDownloadManager` doesn't support reduplicative task, but it doesn't disable it totally:
   URL(string: URLString) and URL(string: URLString.uppercased()) request the same file.

 
 * As a data source for UITableView/UICollectionView

   `SDEDownloadManager` maintains a download list(`[[String]]`), so it could manage download task
   based on its location(`IndexPath`) also.

 
 * Sort download list
 
   Use `sortListBy(type:order:)` to change the order of download list. It supports to switch between
   five types: `manual`, `addTime`, `fileName`, `fileSize` and `fileType`. I classify these sort types
   as two modes: manual mode and predefined mode(latter four types).You could choose its sort mode
   when create a download manager in `manager(identifier:manualMode:)`.
 
   Specially, in manual mode, a section in `downloadList` must has a title, and it will lose all section
   titles when switching from manual mode to predefined mode. And all tasks will be integrated into a 
   single section with a placeholder title when switching from predefined mode to manual mode.
 
   In manual mode, reorder tasks by `moveTask(at:to:)` and `moveTasks(inSection:to)`.
 
   `sortListBy(type:order:)` is limited by file meta info and just use four predefined sort types,
   `sortListBy(order:taskTrait:traitAscending:taskAscending:)` free you to custom sort function.
 
 
 * Control download count

   Adjust `maxDownloadCount` to control the maximum count of tasks which download at the same time.
   Don't worry, it's good as you think.


 * Track download activity: download progress and speed

   Download activity info is provided in `downloadActivityHandler`, you could use the closure to update
   view. Call `beginTrackingDownloadActivity()` to track download activity, it executes
   `downloadActivityHandler` every second in the background until there is no more download or
   call `stopTrackingDownloadActivity()` to stop it.


 * Data persistence

   When you need, call `saveData()`. `SDEDownloadManager` use property list serialization to save data,
   so when you add custom meta info for task by `fetchMetaInfoHandler`, it must be property list object.
   It has enough load and save performance for usual scenes which has almost under 10000 records. You'd
   better test it in your scene. If load performance is not good in your scene, I suggest that you create
   download manager in advance to leave time to load data.
 

 * Cache thumbnails for files

   Request thumbnail by `requestThumbnail(forTask:targetHeight:orLaterProvidedInHandler:)`. Generally,
   only image and video should have thumbnail, but there are some scenes where you want to associate a
   image with the file, e.g., an album art for the song, a poster for the movie. You can custom thumbnail
   for any file(except for image) by `setCustomThumbnail(_:forTask:cacheInMemoryOnly:)`.

 
 * Authentication

   `SDEDownloadManager` handle part authentication types for you: Basic, Digest, and server trust. For 
   other authentication types, you could handle them by `sessionDidReceiveChallengeHandler` and
   `taskDidReceiveChallengeHandler`.

 
 * Custom Other Behaviors in Session Delegate
 
   `SDEDownloadManager` use `NSURLSessionDownloadTask` to download files, and session delegate is internal,
    I leave closure interfaces to custom behaviors in session delegate. See MARK: Closures to Custom 
    Behaviors in Session Delegate.
 
 
 * Trash
 
   Enable this feature by `isTrashOpened`. If true, task to delete will be moved to the trash first; if
   false, task is deleted directly.
 
 
 * Handle app force quit in downloading and you don't have to do anything.
 */
@objcMembers open class SDEDownloadManager: NSObject {
    // MARK: - Create a DownloadManager
    /**
     Create a download manager with specified identifier.
     
     After download manager is inited, it begins to load data in the background immediately.
     
     Choose sort mode based on your usage scenario. SDEDownloadManager has two sort mode: manual and
     predefined mode. The two sort modes can switch to each other. Except for obvious sort difference,
     what's difference between with two modes? 
     
     1. Download new file. In predefined mode, you just need to offer download URL, but in manual mode, 
     you must offer its insert location in `downloadList`, which is `[[String]]` and is designed for
     UITableView/UICollectionView.
     2. A section in UITableView with `.plain` style can't be distinguished from last section if it 
     doesn't have a title, so in manual mode, you must offer a title.

     Although you can switch between with two sort modes freely, switching from manual mode to predefined
     mode will lose all section titles, and switching from predefined mode to manual mode will integrate
     all tasks into one section with a placeholder title, so choose sort mode based on your usage scenario
     discreetly.
     
     - parameter identifier:  The unique identifier. If a download manager object with the same identifier
     exists in the memory, return it.
     
     - parameter manualMode:  Choose manual sort mode as initial sort mode or not. The default value is `false`.
     This property is valid only when you are the first time to create a SDEDownloadManager object with
     the identifier, if app has record about identifier, this property is ignored. If true, download manager
     is inited in manual sort mode, which means it's your responsibility to order task locations; if false,
     it's inited with default sort type: `addTime`. Sort mode could be changd by `sortListBy(type:order:)`.
     
     - returns: A SDEDownloadManager object. If a download manager object with the same identifier exists
     in the memory, return it. This method is thread safe, other method is not thread safe if it's not indicated
     thread safe explicitly.
     */
    public static func manager(identifier: String, manualMode: Bool = false) -> SDEDownloadManager {
        if let dm = downloadManagerSet.filter({$0.identifier == identifier}).first{
            return dm
        }else{
            if identifier == SDEDownloadManager.placeHolderIdentifier{
                return SDEDownloadManager.placeHolderManager
            }else{                
                SDEDownloadManager.initLock.lock()
                let dm: SDEDownloadManager
                if let _dm = downloadManagerSet.filter({$0.identifier == identifier}).first{
                    SDEDownloadManager.initLock.unlock()
                    dm = _dm
                }else{
                    dm = SDEDownloadManager.init(id: identifier, manual: manualMode)
                    SDEDownloadManager.downloadManagerSet.insert(dm)
                    SDEDownloadManager.initLock.unlock()
                }
                return dm
            }
        }
    }

    private static let initLock: NSLock = NSLock.init()
    private static var downloadManagerSet: Set<SDEDownloadManager> = []
    private init(id: String, manual: Bool) {
        self.identifier = id
        if id == SDEDownloadManager.placeHolderIdentifier{
            self.downloadSession = URLSession.shared
            super.init()
            self._isDataLoaded = true
            return
        }else{
            let downloadDelegate = SDESessionDelegate()
            let internaID = "Identifier." + identifier + ".SDEDownloadManager"
            let configuration = URLSessionConfiguration.background(withIdentifier: internaID)
            // If delegateQueue is nil, in session delegate, after a method is returned, next methos is called;
            // otherwise, they are called in call orders, but don't need to wait last method return.
            self.downloadSession = URLSession(configuration: configuration, delegate: downloadDelegate, delegateQueue: OperationQueue())
            super.init()
            downloadDelegate.downloadManager = self
            self.downloadSession.sessionDescription = identifier
        }

        if manual{
            _sortType = .manual
        }
        saveDataIfAppEnterBackground()

        // After force quit and relanch, session delegate wait download manager to load data. 
        // Priority of queue to load data should be higher than queue of session delegate,
        // otherwise that block for a while. Specially can't use BACKGROUND queue here, 
        // it takes a very long time.
        DispatchQueue.global().async(execute: {
            self.loadData()
            self._isDataLoaded = true
        })
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
        debugNSLog("SDEDownloadManager: \(self.identifier) deinit")
    }

    private func saveDataIfAppEnterBackground(){
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground,
                                               object: nil,
                                               queue: OperationQueue(),
                                               using: { [weak self] _ in
                                                self?.saveData()})
    }

    // Don't use this identifier.
    static let placeHolderIdentifier: String = "Identifier.GKYNF.PlaceHolder.DONTSAVEDATA.SDEDownloadManager"
    /// PlaceholderManager won't load and save data.
    static let placeHolderManager: SDEDownloadManager = SDEDownloadManager.init(id: SDEDownloadManager.placeHolderIdentifier, manual: false)
    
    // MARK: Save Data
    /**
     This method is synchronous, and it's executed in current thread. Everytime
     app enter background, `SDEDownloadManager` calls this method automatically.
     
     Data are splited into several parts and are saved separately, only changed part will
     be saved, so it has a good performance at the most time if data is not huge(like under
     10000 records). You'd better test its performance in your environment.
     */
    public func saveData(){
        guard identifier != SDEDownloadManager.placeHolderIdentifier else{return}
        while !_isDataLoaded {}
        while saving {debugNSLog("Another thread is saving, wait.")}
        guard isConfigurationChanged || isTaskInfoChanged || isListChanged || isTrashChanged || isCustomThumbnailChanged else{
            debugNSLog("No changed data to save, return.")
            return
        }
        saveDataToFile()
    }

    // MARK: Import and Export
    /**
     Migrate your download data to a new SDEDownloadManager. This method won't change original data.
     
     Before we get started, I suggest you read document of `manager(identifier:manualMode:)` first.
     
     What information about download task you need to provide and how to organize these information?
     
     Dictionary<String, ValueType> is proper format to present download task and its data. It takes download URL string
     as key, what about ValueType? We need info about task, like, location of downloaded file, resume data of uncompleted
     download, MIME type of task, for kinds of data types, Dictionary<String, Any> is proper type. And here is specified
     key and value type:
     
     If file is downloaded completely, two ways to present it, it's up to you:
     
     Key: "FileAbsolutePath", Value: String.
     
     Key: "FileRelativePath", Value: String. Path relative to app home directory, e.g., "/Documents/file.extension", this method
     will get file absolute path by: NSHomeDirectory() + "/Documents/file.extension".
     
     If file is not download completely, give its resume data:
     
     Key: "ResumeData", Value: Data.
     
     Other data:
     
     Key: "CreateDate", Value: Date. If this key-value is not available, this method will take current date.
     
     Key: "MIME", Value: String, e.g. "application/pdf", it's could be fetched from `URLResponse.mimeType`.
     
     Key: "DisplayName", Value: String.
     
     All above key-value pairs are optional.
     
     So use Dictionary<String, Dictionary<String, Any>> as download info's data type and put it in Parameter
     `info: Dictionary<String, Any>` with specified key `MigratingTaskInfoKey`.
     
     `MigratingTaskInfoKey`: Dictionary<String, Dictionary<String, Any>>
     
     SDEDownloadMananger support trash feature, you can mark task as ToDelete, specify [String] of download URL
     String as ToDeleteList with specified key `MigratingToDeleteListKey`.
     
     `MigratingToDeleteListKey`: [String]
     
     How to sort tasks? SDEDownloadManager has four predefined sort types: .addTime, .fileName, .fileSize, .fileType.
     It's easy to understand. sortType `ComparisonType` and sortOrder `ComparisonOrder` are enum, specify them with
     following key and value type:
     
     "SortType": Int, "SortOrder": Int
     
     If you want to order task location as you specify, use following key and value type:
     
     `MigratingDownloadListKey`: [[String]]
     
     `MigratingSectionTitlesKey`: [String]

     SDEDownloadManager maintains a `downloadList`, which is `[[String]]` and is designed for UITableView/UICollectionView.
     So, sorted tasks is a `[[String]]`, not a `[String]`, and it need you to provide title which is used in header view of
     UITableView/UICollectionView. Why it needs title? Read document of `manager(identifier:manualMode:)`. These two key-value
     pairs must be provided both, otherwise the only one is ignored.
     
     - parameter info: The download data to migrate. This method won't change original data.
     - parameter identifier: A new identifier to create a SDEDownloadManager object. If download manager with
     the same identifier is existed already, migration will be aborted.
     
     - returns: A Boolean value indicating whether migration is successful.
     */
    private static func importDownloadInfo(_ info: Dictionary<String, Any>, intoNewTarget identifier: String) -> Bool{
        let dmIdentifier: String = "com.SDEDownloadManager.\(identifier).Info"
        guard UserDefaults.standard.dictionary(forKey: dmIdentifier) == nil else {
            debugNSLog("The identifier: %@ is existed yet. Try other identifier.", identifier)
            return false
        }
        
        guard let taskInfo = info[MigratingTaskInfoKey] as? Dictionary<String, Dictionary<String, Any>> else {
            return false
        }
        
        let formatter = ByteCountFormatter()
        var downloadInfo: Dictionary<String, Dictionary<String, Any>> = [:]
        let createDate = Date()
        let homeDirectory0 = NSHomeDirectory()
        let homeDirectory1 = NSHomeDirectory() + "/"
        let documentDirectory = NSHomeDirectory() + "/Documents/"
        
        for (URLString, dataInfo) in taskInfo{
            guard let downloadURL = URL.init(string: URLString) else{continue}
            guard let _ = downloadURL.scheme else{continue}
            
            var metaInfo: Dictionary<String, Any> = [:]
            
            var _filePath: String?
            if let absolutePath = dataInfo["FileAbsolutePath"] as? String{
                _filePath = absolutePath
            }else if let relativePath = dataInfo["FileRelativePath"] as? String{
                _filePath = homeDirectory0 + relativePath
            }
            if let filePath = _filePath{
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir){
                    if isDir.boolValue == false{
                        // The migration should not change original data
                        if filePath.starts(with: documentDirectory){
                            metaInfo[TIFileLocationStringKey] = String(filePath[homeDirectory1.endIndex..<filePath.endIndex])
                        }else{
                            metaInfo[TIFileLocationStringKey] = String(filePath[homeDirectory0.endIndex..<filePath.endIndex])
                        }
                        metaInfo[TITaskStateIntKey] = DownloadState.finished.rawValue
                        if let fileByteCount = (try? FileManager.default.attributesOfItem(atPath: filePath))?[.size] as? Int64{
                            metaInfo[TIFileByteCountInt64Key] = fileByteCount
                            metaInfo[TIDownloadDetailStringKey] = formatter.string(fromByteCount: fileByteCount)
                        }
                    }else{
                        NSLog("File path should be not a directory.")
                    }
                }
            }
            
            if let resumeData = dataInfo["ResumeData"] as? Data, let resumeDataInfo = infoOfResumeData(resumeData){
                if resumeDataInfo["NSURLSessionDownloadURL"] as? String == URLString{
                    metaInfo[TIResumeDataKey] = resumeData
                    metaInfo[TITaskStateIntKey] = DownloadState.stopped.rawValue
                    if let receivedCount = resumeDataInfo["NSURLSessionResumeBytesReceived"] as? Int64{
                        metaInfo[TIReceivedByteCountInt64Key] = receivedCount
                        metaInfo[TIDownloadDetailStringKey] = "\(formatter.string(fromByteCount: receivedCount))/--"
                    }
                }
            }
            if metaInfo.index(forKey: TITaskStateIntKey) == nil{
                metaInfo[TITaskStateIntKey] = DownloadState.pending.rawValue
            }
            
            if let date = dataInfo["CreateDate"] as? Date{
                metaInfo[TICreateDateKey] = date
            }else{
                metaInfo[TICreateDateKey] = createDate
            }
            
            if let displayName = dataInfo["DisplayName"] as? String{
                metaInfo[TIFileDisplayNameStringKey] = displayName
            }
            
            let fileName = downloadURL.lastPathComponent
            if fileName != ""{
                let fileExtension = downloadURL.pathExtension
                if fileExtension != ""{
                    metaInfo[TIFileNameStringKey] = String(fileName[..<fileName.index(fileName.endIndex, offsetBy: -(fileExtension.count+1))])
                    metaInfo[TIFileExtensionStringKey] = fileExtension.lowercased()
                }else{
                    metaInfo[TIFileNameStringKey] = fileName
                }
            }else{
                metaInfo[TIFileNameStringKey] = URLString.components(separatedBy: "/").last ?? URLString
            }
            
            if let mimeType = dataInfo["MIME"] as? String{
                metaInfo[TIFileTypeStringKey] = fileTypeForMIME(mimeType)
            }else if let fileExtension = metaInfo[TIFileExtensionStringKey] as? String{
                metaInfo[TIFileTypeStringKey] = fileTypeForExtension(fileExtension)
            }else{
                metaInfo[TIFileTypeStringKey] = OtherType
            }
            
            downloadInfo[URLString] = metaInfo
        }
        
        guard downloadInfo.isEmpty == false else {return false}
        do{
            let plistData = try PropertyListSerialization.data(fromPropertyList: downloadInfo, format: .binary, options: 0)
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).TaskInfo" + SDEDownloadManager.postfix
            do{
                try plistData.write(to: URL(fileURLWithPath: savePath), options: [.atomic])
            }catch{
                NSLog("Can't save task info data to file because of: %@", error.localizedDescription)
                return false
            }
        }catch{
            NSLog("Some data are NOT property list type. Check compatible data types: https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/PropertyList.html#//apple_ref/doc/uid/TP40008195-CH44. In Swift, all primitive data types(except for Float80) are compatible, for collection type, Array and Dictionary consist of these primitive data types are compatible also.")
            return false
        }
        
        var manualMode: Bool = false
        var listInfo: Dictionary<String, Any> = [:]
        var titleCount: Int = 0
        if let sectionTitles = info[MigratingSectionTitlesKey] as? [String]{
            manualMode = true
            listInfo["SectionTitleList"] = sectionTitles
            titleCount = sectionTitles.count
        }
        
        if let sortedTasks = info[MigratingDownloadListKey] as? [[String]]{
            listInfo["SortedURLStringsList"] = sortedTasks
            if titleCount != sortedTasks.count{
                manualMode = false
            }
        }else{
            manualMode = false
        }
        
        var sortType: ComparisonType
        var sortOrder: ComparisonOrder = .ascending
        if manualMode{
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).ListInfo" + SDEDownloadManager.postfix
            let plistData = try! PropertyListSerialization.data(fromPropertyList: listInfo, format: .binary, options: 0)
            do{
                try plistData.write(to: URL(fileURLWithPath: savePath), options: [.atomic])
                sortType = .manual
            }catch{
                NSLog("Can't save task list data to file because of: %@", error.localizedDescription)
                return false
            }
        }else if let rawValue = info["SortType"] as? Int, let _sortType = ComparisonType(rawValue: rawValue){
            sortType = _sortType
            if let _rawValue = info["SortOrder"] as? Int, let _sortOrder = ComparisonOrder(rawValue: _rawValue){
                sortOrder = _sortOrder
            }
        }else{
            sortType = .addTime
        }
        
        var trashList: [String] = []
        if let _trashList = info[MigratingToDeleteListKey] as? [String]{
            var trashSet: Set<String> = []
            for URLString in _trashList{
                guard downloadInfo.index(forKey: URLString) != nil else{continue}
                if !trashSet.contains(URLString){
                    trashList.append(URLString)
                    trashSet.insert(URLString)
                }
            }
            if !trashList.isEmpty{
                let plistData = try! PropertyListSerialization.data(fromPropertyList: trashList, format: .binary, options: 0)
                let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).Trash" + SDEDownloadManager.postfix
                do{
                    try plistData.write(to: URL.init(fileURLWithPath: savePath), options: .atomic)
                }catch{
                    NSLog("Can't save ToDelete list to file because of: %@", error.localizedDescription)
                    return false
                }
            }
        }
        
        let userDefaults = UserDefaults.standard
        // NSUserDefaults doesn't support String and Array in Swfit , use OC's version NSString and NSArray.
        let configuration: NSDictionary = ["SortType": sortType.rawValue,
                                  "SortOrder": sortOrder.rawValue,
                                  "MaxDownloadCount": -1,
                                  "indexingFileNameList": false,
                                  "sectioningAddTimeList": false,
                                  "sectioningFileSizeList": false,
                                  "isTrashOpened": false]
        userDefaults.set(configuration, forKey: dmIdentifier)
        if userDefaults.synchronize() == false{
            return false
        }
        
        return true
    }
    
    /**
     Migrate download data in SDEDownloadManager to other tool.
     
     If you want to destroy download manager after migration, use `destoryManager(_:)`.
     
     Export content:
     
     * `MigratingTaskInfoKey`: Dictionary<String, Dictionary<String, Any>>
     
     Value's key is download URL string, its value Dictionary<String, Any> has following content:
     
     "FileRelativePath": String. If file is downloaded completely, this key-value pair is available.
     
     "ResumeData": Data. If download is not finished, this key-value pair is available.
     
     "FileByteCount": Int64. If file size is unknown, this value is -1.
     
     "CreateDate": Date. The date when task is added.
     
     "DisplayName": String.
     
     
     * `MigratingToDeleteListKey`: [String]
     
     SDEDownloadManager support trash feature. If ToDelete list is not empty, this key-value pair is available.
     
     
     * `MigratingDownloadListKey`: [[String]]
     
     Current download list.
     
     * `MigratingSectionTitlesKey`: [String]
     
     If this download manager sort its tasks manually, this key-value pair is available.
     
     - parameter identifier: The identifier of download manager which you want to export.
     
     - returns: Info about download task. Return nil if there is no enough info or specified download manager is not existed.
     */
    private static func exportDownloadManager(identifier: String) -> Dictionary<String, Any>?{
        let dmIdentifier: String = "com.SDEDownloadManager.\(identifier).Info"
        guard let configuration = UserDefaults.standard.dictionary(forKey: dmIdentifier) else{return nil}
        
        let defaultPersistentDirectory = NSHomeDirectory() + SDEDownloadManager.persistentDirectory
        let taskInfoFilePath = defaultPersistentDirectory + "\(identifier).TaskInfo" + SDEDownloadManager.postfix
        guard FileManager.default.fileExists(atPath: taskInfoFilePath) else{return nil}
        
        var exportInfo: Dictionary<String, Any> = [:]
        
        var format: PropertyListSerialization.PropertyListFormat = .binary
        if  let data = try? Data(contentsOf: URL(fileURLWithPath: taskInfoFilePath)),
            let downloadTaskInfo = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: &format)) as? Dictionary<String, Dictionary<String, Any>>{
            var taskInfo: Dictionary<String, Dictionary<String, Any>> = [:]
            for (URLString, info) in downloadTaskInfo{
                var migratingTaskInfo: Dictionary<String, Any> = [:]
                if let relativePath = info[TIFileLocationStringKey] as? String{
                    if relativePath.starts(with: "/"){// this task is imported from outer
                        migratingTaskInfo["FileRelativePath"] = relativePath
                    }else{
                        migratingTaskInfo["FileRelativePath"] = "/" + relativePath
                    }
                }
                migratingTaskInfo["FileByteCount"] = info[TIFileByteCountInt64Key]
                migratingTaskInfo["ResumeData"] = info[TIResumeDataKey]
                migratingTaskInfo["CreateDate"] = info[TICreateDateKey]
                migratingTaskInfo["DisplayName"] = info[SDEDownloadManager.TIFileDisplayNameStringKey] ?? info[TIFileNameStringKey]
                taskInfo[URLString] = migratingTaskInfo
            }
            guard taskInfo.isEmpty == false else{return nil}
            exportInfo[MigratingTaskInfoKey] = taskInfo
        }else{
            return nil
        }
        
        // If data is migrated from other place and download manager is not inited ever, this path is not existed.
        let listInfoFilePath = defaultPersistentDirectory + "\(identifier).ListInfo" + SDEDownloadManager.postfix
        if let data = try? Data(contentsOf: URL(fileURLWithPath: listInfoFilePath)),
            let info = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: &format)) as? Dictionary<String, Any>{
            if let URLStringsList = info["SortedURLStringsList"] as? [[String]]{
                exportInfo[MigratingDownloadListKey] = URLStringsList
            }
            
            if let rawValue = configuration["SortType"] as? Int, rawValue == -1, let titles = info["SectionTitleList"] as? [String]{
                exportInfo[MigratingSectionTitlesKey] = titles
            }
        }
        
        let trashListFilePath = defaultPersistentDirectory + "\(identifier).Trash" + SDEDownloadManager.postfix
        if  let data = try? Data(contentsOf: URL(fileURLWithPath: trashListFilePath)),
            let array = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: &format)) as? [String]{
            exportInfo[MigratingToDeleteListKey] = array
        }
        
        return exportInfo
    }

    // MARK: Destory a DownloadManager
    /**
     Check whether specified download manager could be destoryed safely. This method returns true only when:
     
     1. The specified download manager is existed in the database.
     2. The specified download manager is not existed in the memory. Because of implementation of
     `manager(identifier:manualMode:)`, once it's called, returned manager is existed in the memory
     until app is exited.
     
     - parameter identifier: The download manager's identifier.
     
     - returns: Returns a Boolean value indicating whether the download manager could be destoryed safely.
     */
    public static func isDestoryableForManager(_ identifier: String) -> Bool{
        // The second limitation is caused by that this class is NSObject subclass. There is no public way to
        // get reference count of an Objective-C object. There is a `isKnownUniquelyReferenced(_:)` for Swift
        // class. Converting `SDEDownloadManager` to Swift class is not difficult...
        guard UserDefaults.standard.object(forKey: "com.SDEDownloadManager.\(identifier).Info") != nil else{
            return false
        }
        guard SDEDownloadManager.downloadManagerSet.first(where: {$0.identifier == identifier}) == nil else{
            return false
        }
        
        return true
    }
    
    /**
     Destroy underlying data of specified download manager, not includes live data if specified download manager exists
     in the memory already. You should call `isDestoryableForManager(_:)` to check whether specified download manager
     is destoryable before calling this method because destoryed data cannot be recovered.
     
     Note: This method won't delete downloaded files.
     
     - parameter identifier: The download manager's identifier.
     
     - returns: Return true if underlying data are destoryed.
     */
    public static func destoryManager(_ identifier: String) -> Bool{
        var dmExisted: Bool = false
        
        let userDefaults = UserDefaults.standard
        let infoKey: String = "com.SDEDownloadManager.\(identifier).Info"
        if let _ = userDefaults.object(forKey: infoKey){
            userDefaults.removeObject(forKey: infoKey)
            if userDefaults.synchronize() == false{
                debugNSLog("Destory process for %@ is aborted because can't delete its info in NSUserDefaults.", identifier)
                return false
            }
            dmExisted = true
        }
        
        let prefixPath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory
        
        let taskInfoSavePath = prefixPath + "\(identifier).TaskInfo" + SDEDownloadManager.postfix
        if FileManager.default.fileExists(atPath: taskInfoSavePath){
            do{
                try FileManager.default.removeItem(atPath: taskInfoSavePath)
                dmExisted = true
            }catch{
                debugNSLog("Destory process for %@ is aborted because can't delete taskInfo file: %@", identifier, error.localizedDescription)
                return false
            }
        }
        
        let listInfoSavePath = prefixPath + "\(identifier).ListInfo" + SDEDownloadManager.postfix
        if FileManager.default.fileExists(atPath: listInfoSavePath){
            do{
                try FileManager.default.removeItem(atPath: listInfoSavePath)
                dmExisted = true
            }catch{
                debugNSLog("Destory process for %@ is aborted because can't delete listInfo file: %@", identifier, error.localizedDescription)
                return false
            }
        }
        
        let trashInfoSavePath = prefixPath + "\(identifier).Trash" + SDEDownloadManager.postfix
        if FileManager.default.fileExists(atPath: trashInfoSavePath){
            do{
                try FileManager.default.removeItem(atPath: trashInfoSavePath)
                dmExisted = true
            }catch{
                debugNSLog("Destory process for %@ is aborted because can't delete trash file: %@", identifier, error.localizedDescription)
                return false
            }
        }
        
        let customThumbnailInfoSavePath = prefixPath + "\(identifier).CustomThumbnailInfo" + SDEDownloadManager.postfix
        if FileManager.default.fileExists(atPath: customThumbnailInfoSavePath){
            do{
                try FileManager.default.removeItem(atPath: customThumbnailInfoSavePath)
                dmExisted = true
            }catch{
                debugNSLog("Destory process for %@ is aborted because can't delete custom thumbnail info file: %@", identifier, error.localizedDescription)
                return false
            }
        }
        
        #if DEBUG
            if let _ = userDefaults.object(forKey: infoKey){
                NSLog("\(identifier) is not deleted from NSUserDefaults. This happens in simulator only.")
            }
            
            if dmExisted{
                NSLog("Destory download manager with identifier: \(identifier) successfully.")
            }
        #endif
        
        return dmExisted
    }


    // MARK: - Query the State
    /**
     The unique identifier. Specify it in `manager(identifier:manualMode:)`, if a SDEDownloadManager object
     with the identifier exists in the memory already, this methos return it directly.
     */
    public let identifier: String
    /// A Boolean value indicating whether data is loaded. After a SDEDownloadManager object is inited, 
    /// it loads data in the background. Usually it's very soon to load data.
    public var isDataLoaded: Bool{
        return _isDataLoaded
    }

    /**
     The current sort type of download list(read-only). The default value is `.addTime`.

     sortType has five values: `.manual`, `.addTime`, `.fileName`, `.fileSize`, `.fileType`. They are
     classified as two modes: manual mode(`.manual`) and predefined mode(latter four types). For `.manual`
     type, you determine task locations; for latter four types, task locations are determined by `sortType`
     and `sortOrder` together.
     
     Call `sortListBy(type:order:)` to switch between sort types.
     */
    public var sortType: ComparisonType{
        return _sortType
    }
    
    /**
     `.ascending` or `.descending`. This property is ignored if `sortType == .manual`. The default value
     is `.ascending`.
     
     You can call `sortListBy(sortType:sortOrder:)` to change sort order.
     */
    public var sortOrder: ComparisonOrder{
        return _sortOrder
    }
    
    // MARK: Query Tasks
    /// A URL string array includes all section titles for UITableView/UICollectionView.
    public var sectionTitles: [String]?{
        return sectionTitleList.count > 0 ? sectionTitleList : nil
    }

    /// URL strings of current all tasks.
    public var downloadList: [[String]]?{
        return sortedURLStringsList
    }
    
    /// A URL string array includes tasks to delete. Sorted by delete time and the head is the most recent deleted task.
    public var toDeleteList: [String]?{
        return trashList.isEmpty ? nil : trashList
    }
    
    /// A URL string array includes all unfinished tasks(not include task in `toDeleteList`). It's dynamic:
    /// URL string will be removed from this list after its task is finished. Sorted by add time in `downloadList`
    /// and the head is the most recent added task.
    public var unfinishedList: [String]?{
        let unfinishedTasks: [String] = _downloadTaskSet.filter({
            downloadTaskInfo[$0]?[TIFileLocationStringKey] == nil
        })
        if unfinishedTasks.isEmpty{
            return nil
        }
        return unfinishedTasks.sorted(by: {
            let date0 = downloadTaskInfo[$0]![TICreateDateKey] as! Date
            let date1 = downloadTaskInfo[$1]![TICreateDateKey] as! Date
            return date0.compare(date1) == .orderedDescending
        })
    }
    
    /// A URL string set includes all tasks in `downloadList`.
    public var downloadTaskSet: Set<String>?{
        return _downloadTaskSet.isEmpty ? nil : _downloadTaskSet
    }
    
    
    /// A URL string set includes all tasks in the download manager: `downloadList` and `toDeleteList`.
    public var allTasksSet: Set<String>?{
        return downloadTaskInfo.isEmpty ? nil : Set(downloadTaskInfo.keys)
    }
    
    // MARK: Data Source for UITableView/UICollectionView
    /// Section count of `downloadList`.
    public var sectionCount: Int{
        return sectionTitleList.isEmpty ? 0 : sectionTitleList.count
    }
    
    /**
     Task count in the specified section.
     
     - parameter section: Section index of `downloadList`.
     
     - returns: Task count. Return -1 if section index is beyond bounds.
     */
    public func taskCountInSection(_ section:Int) -> Int{
        return (section < 0 || sortedURLStringsList.count <= section) ? -1 : sortedURLStringsList[section].count
    }
    
    /**
     Header title used in UITableView/UICollectionView.
     
     - parameter section: Section index of `downloadList`.
     
     - returns: Header title string or nil.
     */
    public func titleForHeaderInSection(_ section: Int) -> String?{
        if sectionTitleList.count > section{
            return localizedTitleForString(sectionTitleList[section])
        }
        return nil
    }
    
    private func localizedTitleForString(_ title: String) -> String{
        switch _sortType {
        case .addTime:
            return DMLS(title, comment: "HeaderView Title for AddTime")
        case .fileName:
            if indexingFileNameList{
                return title
            }else{
                return DMLS(title, comment: "HeaderView Title for FileName")
            }
        case .fileSize:
            return DMLS(title, comment: "HeaderView Title for FileSize")
        case .fileType:
            if title == ImageType{
                return DMLS("FileType.Image", comment: "Image File Type")
            }else if title == AudioType{
                return DMLS("FileType.Audio", comment: "Audio File Type")
            }else if title == VideoType{
                return DMLS("FileType.Video", comment: "Video File Type")
            }else if title == DocumentType{
                return DMLS("FileType.Document", comment: "Document File Type")
            }else{
                return DMLS("FileType.Other", comment: "Other File Type")
            }
        case .manual:
            return title
        }
    }

    // MARK: -
    internal lazy var downloadQueue: OperationQueue = OperationQueue()
    private var downloadSession: URLSession
    
    /// Basic info: sortType, sortOrder, maxDownloadCount
    private var isConfigurationChanged: Bool = false
    private var isTaskInfoChanged: Bool = false
    private var isListChanged: Bool = false
    private var isTrashChanged: Bool = false
    private var isCustomThumbnailChanged: Bool = false
    
    internal var _isDataLoaded: Bool = false
    internal var _sortType: ComparisonType = .addTime{
        didSet{
            isConfigurationChanged = true
        }
    }
    internal var _sortOrder: ComparisonOrder = .ascending{
        didSet{
            isConfigurationChanged = true
        }
    }
    internal var downloadTaskInfo: Dictionary<String, Dictionary<String, Any>> = [:]{
        didSet{
            isTaskInfoChanged = true
        }
    }
    internal var _downloadTaskSet: Set<String> = []
    internal var sectionTitleList: [String] = []{
        didSet{
            isListChanged = true
        }
    }
    internal var sortedURLStringsList: [[String]] = []{
        didSet{
            isListChanged = true
        }
    }
    internal var trashList: [String] = []{
        didSet{
            isTrashChanged = true
        }
    }
    internal var customThumbnailInfo: Dictionary<String, String> = [:]{
        didSet{
            isCustomThumbnailChanged = true
        }
    }
    
    internal static let persistentDirectory: String = "/Library/DownloadManagerDB/"
    internal static let postfix = ".db"

    // MARK: - Download New File in Predefined Sort Mode
    /**
     Download a group of new files in predefined sort mode(sortType != .manual) and return locations of
     new files in `downloadList` immediately. If data is not loaded, this method will wait.
     
     If current sortType is not `.addTime`, download mananger switch to `.addTime` automatically.
     
     If `downloadNewFileImmediately` is false, this method just add a record, you can start the task by
     `resumeTasks(_:successOrFailHandler:)`.
     
     - precondition: `sortType != .manual`, otherwise, return nil directly.
     
     - parameter URLStrings: The string array of download URL. Repeated or invalid URL will be filtered.
     It's your responsibility to encode URL string if it contains Non-ASCII charater. Use
     `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` or computed property
     `percentEncodingURLQueryString` in the extension to encode string.
     
     - parameter successOrFailHandler: A temporary closure to execute after a task is successful, or failed
     (not include cancelling task) to replace `taskSuccessOrFailHandler` which is executed for every task. 
     The default value is nil. Closure parameters `fileLocation` and `error`, only one is not
     nil at the same time. Check parameters in `taskSuccessOrFailHandler` property, they are same.

     - returns: Locations of new tasks in `downloadList`. If no task is added, return nil.
     */
    public func download(_ URLStrings: [String], successOrFailHandler: ((_ URLString: String, _ fileLocation: URL?, _ error: NSError?) -> Void)? = nil) -> [IndexPath]?{
        waitIfDataNotLoaded()
        guard sortType != .manual else{return nil}
        guard !URLStrings.isEmpty else{return nil}
        guard let (newTasks, newTaskURLs) = collectNewTasksIn(URLStrings) else{
            debugNSLog("\(#function) There is no valid URL or new URL.")
            return nil}
        
        if _downloadTaskSet.isEmpty{
            sectionTitleList.removeAll()
            sortedURLStringsList.removeAll()
            let sectionTitle: String = sectioningAddTimeList ? "Time.Today" : "HeaderViewTitle.Sorted by Add Time"
            sectionTitleList.append(sectionTitle)
            sortedURLStringsList.append([])
            _sortType = .addTime
        }else if sortType != .addTime{
            (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: .addTime, order: sortOrder)
            _sortType = .addTime
        }

        let oldTaskCount = _downloadTaskSet.count
        _downloadNewFilesAt(newTaskURLs, newTasks, handler: successOrFailHandler)
        
        return insertTasksInAddTimeMode(newTasks: newTasks, oldTaskCount: oldTaskCount)
    }
    
    private func insertTasksInAddTimeMode(newTasks:[String], oldTaskCount: Int) -> [IndexPath]{
        var insertedIndexPaths: [IndexPath] = []
        let todayTitle = "Time.Today"
        let futureTitle = "Time.Future"
        
        if sectioningAddTimeList{
            if let sectionIndex = sectionTitleList.index(of: todayTitle){
                let rowCount = sortedURLStringsList[sectionIndex].count
                if sortOrder == .ascending{
                    sortedURLStringsList[sectionIndex].append(contentsOf: newTasks)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row + rowCount, section: sectionIndex))
                    })
                }else{
                    sortedURLStringsList[sectionIndex].insert(contentsOf: newTasks.reversed(), at: 0)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row, section: sectionIndex))
                    })
                }
            }else if let futureIndex = sectionTitleList.index(of: futureTitle){
                if sortOrder == .descending{
                    sectionTitleList.insert(todayTitle, at: 1)
                    sortedURLStringsList.insert(newTasks.reversed(), at: 1)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row, section: 1))
                    })
                }else{
                    let section = futureIndex == 0 ? 0 : futureIndex - 1
                    sectionTitleList.insert(todayTitle, at: section)
                    sortedURLStringsList.insert(newTasks, at: section)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row, section: section))
                    })
                }
            }else{
                if sortOrder == .descending{
                    sectionTitleList.insert(todayTitle, at: 0)
                    sortedURLStringsList.insert(newTasks.reversed(), at: 0)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row, section: 0))
                    })
                }else{
                    let section = sectionTitleList.count
                    sectionTitleList.append(todayTitle)
                    sortedURLStringsList.append(newTasks)
                    (0..<(newTasks.count)).forEach({ row in
                        insertedIndexPaths.append(IndexPath(row: row, section: section))
                    })
                }
            }
        }else{
            if sortOrder == .ascending{// newer task is added at the tail.
                for row in 0..<newTasks.count{
                    insertedIndexPaths.append(IndexPath(row: row + oldTaskCount, section: 0))
                }
                if sortedURLStringsList.isEmpty{
                    sortedURLStringsList.append(newTasks)
                }else{
                    sortedURLStringsList[0].append(contentsOf: newTasks)
                }
            }else{
                for row in 0..<newTasks.count{
                    insertedIndexPaths.append(IndexPath(row: row, section: 0))
                }
                if sortedURLStringsList.isEmpty{
                    sortedURLStringsList.append(newTasks.reversed())
                }else{
                    sortedURLStringsList[0].insert(contentsOf: newTasks.reversed(), at: 0)
                }
            }
        }

        return insertedIndexPaths
    }
    
    // MARK: Download New File in Manual Sort Mode: Insert A New Section
    /**
     Insert an empty section as placeholder in manual sort mode(`sortType == .manual`) and return a Boolean value
     indicating whether insertion is successful. If data is not loaded, this method will wait.
     
     - precondition: `sortType == .manual`.
     
     - parameter section: Section location in `downloadList`. If it's beyond the bounds, return false.
     - parameter title: Title for section header view.
     
     - returns: A Boolean value indicating whether insertion is successful.
     */
    public func insertPlaceHolderSectionInManualModeAtSection(_ section: Int, withTitle title: String) -> Bool{
        waitIfDataNotLoaded()
        guard sortType == .manual else{
            debugNSLog("\(#function) only work in manual mode(sortType = .manual)")
            return false}
        guard sectionTitleList.count >= section else{
            debugNSLog("Section to insert is out of range.")
            return false}
        
        sectionTitleList.insert(title, at: section)
        sortedURLStringsList.insert([], at: section)
        return true
    }

    /**
     Download a group of new files in manual sort mode(`sortType == .manual`), insert them in `downloadList` at
     the section which you specify, and return a Boolean value indicating whether insertion is successful immediately.
     `downloadList` is a two-dimensional string array: `[[String]]`. If data is not loaded, this method will wait.
     
     - precondition: `sortType == .manual`.
     
     - parameter URLStrings:   The string array of download URL. Repeated or invalid URL will be filtered.
     It's your responsibility to encode URL string if it contains Non-ASCII charater. Use
     `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` or computed property
     `percentEncodingURLQueryString` in the extension to encode string.
     
     - parameter section: Section location in `downloadList`. If it's beyond the bounds, return false.
     
     - parameter title: Titles for section header view. Tip: There is no header view in UITableView
     if its section title is empty string "", and if tableView's style is `.plain`, section is distinguished
     from last section.
     
     - returns: A Boolean value indicating whether insertion is successful.
     */
    public func download(_ URLStrings: [String], inManualModeAtSection section: Int, withTitle title: String) -> Bool{
        waitIfDataNotLoaded()
        guard sortType == .manual else{
            debugNSLog("\(#function) only work in manual mode(sortType = .manual)")
            return false}
        guard sectionTitleList.count >= section else{
            debugNSLog("Section to insert is out of range.")
            return false}
        guard !URLStrings.isEmpty else{return false}
        guard let (newTasks, newTaskURLs) = collectNewTasksIn(URLStrings) else{return false}
        
        sortedURLStringsList.insert(newTasks, at: section)
        sectionTitleList.insert(title, at: section)
        _downloadNewFilesAt(newTaskURLs, newTasks)
        return true
    }
    
    /**
     Download several groups of new files in manual sort mode(`sortType == .manual`), insert them in
     `downloadList` at the section which you specify, and return indexes of inserted sections in
     `downloadList` immediately. `downloadList` is a two-dimensional string array: [[String]].
     If data is not loaded, this method will wait.
     
     - precondition: `sortType == .manual`.
     
     - parameter URLStringsList: The download URLs of a two-dimensional array. Any Non-ASII, repeated URL
     will be filterd.
     
     - parameter section: Section location in `downloadList`. If it's beyond the bounds, return nil.
     
     - parameter titles: Titles for section header view. Its count should be equal to count of parameter
     `URLStringsList`, more is OK, otherwise return nil. Tip: There is no header view in UITableView if its
     section title is empty string "", and if tableView's style is `.plain`, section is distinguished
     from last section.
     
     - returns: Indexes of inserted sections in `downloadList`. If no task is added, return nil.
     */
    public func download(_ URLStringsList: [[String]], inManualModeAtSection section: Int, withTitles titles: [String]) -> IndexSet?{
        //check conditions
        guard section >= 0 else{
            debugNSLog("Section index to insert should >= 0")
            return nil}
        waitIfDataNotLoaded()
        guard sortType == .manual else{
            debugNSLog("\(#function) only work in manual sort mode: sortType == .manual")
            return nil}
        guard sectionCount >= section else{
            debugNSLog("Current section count is \(sectionCount), so valid max section index, which you can insert, is \(sectionCount), and the section index in the parameter is \(section).")
            return nil}
        guard !URLStringsList.isEmpty else{
            debugNSLog("FilesList is empty")
            return nil}
        guard URLStringsList.count <= titles.count else{
            debugNSLog("URLStringsList's count must be not larger than titles's count")
            return nil}
        
        //filter list
        var filteredURLStringsList: [[String]] = []
        var filteredURLsList: [[URL]] = []
        var filteredSectionTitleList: [String] = []
        var comparisionSet = Set(downloadTaskInfo.keys)
        
        for (index, list) in URLStringsList.enumerated(){
            if let (newTasks, newTaskURLs) = collectNewTasksIn(list, comparisonSet: comparisionSet){
                filteredURLStringsList.append(newTasks)
                filteredURLsList.append(newTaskURLs)
                filteredSectionTitleList.append(titles[index])
                comparisionSet.formUnion(newTasks)
                _downloadNewFilesAt(newTaskURLs, newTasks)
            }
        }
        
        guard !filteredURLStringsList.isEmpty else{
            debugNSLog("All URL strings in parameter URLStringsList are in the download list or trash already.")
            return nil}
        
        // insert list
        // It's your responsibility to check if index location is right: section index to insert should <= sectionCount.
        sortedURLStringsList.insert(contentsOf: filteredURLStringsList, at: section)
        sectionTitleList.insert(contentsOf: filteredSectionTitleList, at: section)
        let sectionIndexSet = IndexSet(integersIn: section..<(section + filteredURLStringsList.count))
        
        return sectionIndexSet
    }
        
    // MARK: Download New File in Manual Sort Mode: Insert At A Existed Section
    /**
     Download a group of new files in manual mode(`sortType == .manual`), insert them in `downloadList` at
     the location which you specify, and return inserted locations in `downloadList` immediately.
     If data is not loaded, this method will wait.
     
     - precondition: `sortType == .manual`
     
     - parameter URLStrings: The download URL strings. Any Non-ASII, repeated URL will be filterd.
     - parameter indexPath:  Insert location in `downloadList`. The section in the parameter must be existed.
     
     - returns: Insert locations in `downloadList`. If no task is added, return nil.
     */
    public func download(_ URLStrings: [String], inManualModeAt indexPath: IndexPath) -> [IndexPath]?{
        waitIfDataNotLoaded()
        guard sortType == .manual else{
            debugNSLog("\(#function) only work in custom sort mode(sortType = .manual)")
            return nil}
        guard indexPath.section >= 0 else{
            debugNSLog("A valid section index to insert should >= 0.")
            return nil}
        guard sectionCount > indexPath.section else{
            if sectionCount == 0{
                debugNSLog("\(#function): This method is used to add download tasks to a existed section: now download list is empty, so you need to add a section first. Use download(_:inManualModeAtSection:withTitle:) to create a new section and add download tasks to this new section.")
            }else{
                debugNSLog("\(#function): This method is used to add download tasks to a existed section: current section count is \(sectionCount), so valid max section index in the parameter is: \(sectionCount - 1), and the section index which you specify in the parameter is: \(indexPath.section). Use download(_:inManualModeAtSection:withTitle:) to create a new section and add download tasks to this new section.")
            }
            return nil}
        guard let (newTasks, newTaskURLs) = collectNewTasksIn(URLStrings) else{
            debugNSLog("All valid URLStrings in the array are in the download list.")
            return nil}
        
        // insert data
        // This method is used to add download tasks to a existed section. And it's your responsibility to check if indexPath is appropriate.
        // Use download(_:inManualModeAtSection:withTitle:) to create a new section and add download tasks to this new section.
        sortedURLStringsList[indexPath.section].insert(contentsOf: newTasks, at: indexPath.row)
        
        // download files
        var insertedIndexPaths: [IndexPath] = []
        _downloadNewFilesAt(newTaskURLs, newTasks)
        for (index, _) in newTasks.enumerated(){
            insertedIndexPaths.append(IndexPath(row: indexPath.row + index, section: indexPath.section))
        }
        
        return insertedIndexPaths
    }
    
    // MARK: Underlying Download Function
    // Add DownloadOperation and update info in downloadTaskInfo, don't update sortedURLStringsList.
    private func _downloadNewFilesAt(_ URLs: [URL], _ tasks: [String], dataInfo: Dictionary<String, Data>? = nil, handler: (( String, URL?, NSError?) -> Void)? = nil){
        var _waittingTasks: [String] = []
        for (index, downloadURL) in URLs.enumerated(){
            let URLString = tasks[index]
            let resumeData = dataInfo?[URLString]
            let taskState: Int = resumeData == nil ? DownloadState.pending.rawValue : DownloadState.stopped.rawValue
            
            var metaInfo: Dictionary<String, Any> = [
                TITaskStateIntKey: taskState,
                TICreateDateKey: Date(),
                TIFileByteCountInt64Key: Int64(-1)
            ]

            let fileName = downloadURL.lastPathComponent
            if  fileName != ""{
                let fileExtension = downloadURL.pathExtension
                if fileExtension != ""{
                    metaInfo[TIFileNameStringKey] = String(fileName[..<fileName.index(fileName.endIndex, offsetBy: -(fileExtension.count+1))])
                    metaInfo[TIFileExtensionStringKey] = fileExtension.lowercased()
                }else{
                    metaInfo[TIFileNameStringKey] = fileName
                }
            }else{
                metaInfo[TIFileNameStringKey] = URLString.components(separatedBy: "/").last ?? URLString
            }
            
            if let fileExtension = metaInfo[TIFileExtensionStringKey] as? String{
                metaInfo[TIFileTypeStringKey] = fileTypeForExtension(fileExtension)
            }else{
                metaInfo[TIFileTypeStringKey] = OtherType
            }
            
            downloadTaskInfo[URLString] = metaInfo
            taskHandlerDictionary[URLString] = handler
            fetchFileMetaInfoForTask(URLString)
            
            if downloadNewFileImmediately{
                if !didReachMaxDownloadCount{
                    let downloadOperation = DownloadOperation(session: downloadSession, URLString: URLString, resumeData: resumeData)
                    downloadOperation.downloadManager = self
                    downloadOperation.completionBlock = {[unowned downloadOperation] in
                        self.handleCompletionOfOperation(downloadOperation)
                    }
                    downloadQueue.addOperation(downloadOperation)
                }else{
                    debugNSLog("Reach maxDownloadCount and add task to waitting list: %@", URLString)
                    _waittingTasks.append(URLString)
                }
            }
        }
        _downloadTaskSet.formUnion(tasks)
        if sortType != .manual{
            sorter.addTasks(tasks)
        }
        // make task lanch order keep same its order in download list.
        if _waittingTasks.isEmpty == false{
            waittingTaskQueue.addObjects(from: _waittingTasks.reversed())
        }
    }
    
    // MARK: Import Download Task with Resume Data
    /**
     Take over outer download task. If data is not loaded, this method will wait.
     
     - parameter resumeData: The data to resume download.
     - parameter indexPath: Insert location in `downloadList`. If `sortType == .manual`, this value must be not nil;
     if `sortType != .manual`, this value is ignored.
     
     - returns: A Boolean value indicating whether this download is taked over.
     */
    public func resumeOuterDownload(with resumeData: Data, insertAt indexPath: IndexPath?) -> Bool{
        waitIfDataNotLoaded()
        if sortType == .manual && indexPath == nil{
            debugNSLog("In manual mode, you must offer insert location for new task.")
            return false
        }
        guard let downloadURLString = fetchDownloadURLFromResumeData(resumeData) else {
            debugNSLog("Passed resumData is invalid.")
            return false
        }
        guard downloadTaskInfo.index(forKey: downloadURLString) == nil else{
            debugNSLog("%@ is existed in this download manager yet.", downloadURLString)
            return false
        }
        guard let downloadURL = URL(string: downloadURLString) else{
            debugNSLog("%@ is not a valid URL conform to RFC 1808, or it contains Non-ASCII charater. Use `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` to encode it", downloadURLString)
            return false
        }
        guard let _ = downloadURL.scheme?.lowercased() else {
            debugNSLog("%@ has no scheme like http or https.", downloadURLString)
            return false
        }
        
        if sortType == .manual{
            sortedURLStringsList[indexPath!.section].insert(downloadURLString, at: indexPath!.row)
            _downloadNewFilesAt([downloadURL], [downloadURLString], dataInfo: [downloadURLString: resumeData], handler: nil)
        }else{
            if _downloadTaskSet.isEmpty{
                sectionTitleList.removeAll()
                sortedURLStringsList.removeAll()
                let sectionTitle: String = sectioningAddTimeList ? "Time.Today" : "HeaderViewTitle.Sorted by Add Time"
                sectionTitleList.append(sectionTitle)
                sortedURLStringsList.append([])
                _sortType = .addTime
            }else if sortType != .addTime{
                (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: .addTime, order: sortOrder)
                _sortType = .addTime
            }
            
            let oldTaskCount = _downloadTaskSet.count
            _downloadNewFilesAt([downloadURL], [downloadURLString], dataInfo: [downloadURLString: resumeData], handler: nil)
            _ = insertTasksInAddTimeMode(newTasks: [downloadURLString], oldTaskCount: oldTaskCount)
        }
        
        return true
    }
    
    // MARK: - Manage Tasks Based on URL String
    /**
     Resume(continue) tasks and return tasks which are resumed successfully.
     
     This method is not used to download new files, if you want that, use `download(_:)` series.
     
     A task can be resumed if it satisfies the following conditions:
     
     1. download manager has not reach `maxDownloadCount`;
     2. URL is in `downloadList`; If task is in `toDeleteList` and you want to resume it, you must first
     restore it back to `downloadList` by `restoreToDeletedTasks(_:toLocation:)`.
     3. task can be resumed: its state is not finished and downloading.
     
     - parameter URLStrings: An array of URL string of task which you want to resume.
     
     - parameter successOrFailHandler: A temporary closure to execute after a task is successful, or failed
     (not include cancelling task) to replace `taskSuccessOrFailHandler` which is executed for every task.
     The default value is nil. Closure parameters `fileLocation` and `error`, only one is not
     nil at the same time. Check parameters in `taskSuccessOrFailHandler` property, they are same.
     
     - returns: An array of URL string of task which is resumed successfully. If no task is resumed, return nil.
     */
    public func resumeTasks(_ URLStrings: [String], successOrFailHandler: ((_ URLString: String, _ fileLocation: URL?, _ error: NSError?) -> Void)? = nil) -> [String]?{
        guard !didReachMaxDownloadCount else {return nil}
        let ordered = _maxDownloadCount == OperationQueue.defaultMaxConcurrentOperationCount ? false : true
        guard let validTasks = collectValidTasksIn(URLStrings, comparisonSet: _downloadTaskSet, ordered: ordered) else {return nil}
        
        var resumedTasks: [String] = []
        // .notInList:-1, .pending:0, .downloading:1, .paused:2, stopped:3, .finished:4
        let resumeableStateSet: Set<Int> = [0, 2, 3]
        var taskStateInfo: Dictionary<String, Int> = [:]
        let resumeableTasks = validTasks.filter({
            let stateRawValue = downloadTaskInfo[$0]![TITaskStateIntKey] as! Int
            if resumeableStateSet.contains(stateRawValue){
                taskStateInfo[$0] = stateRawValue
                return true
            }else{
                return false
            }
        })
        guard !resumeableTasks.isEmpty else {return nil}
        
        for task in resumeableTasks{
            if didReachMaxDownloadCount {break}
            if resumeTheTask(task, handleConcurrentCount: true){
                resumedTasks.append(task)
                taskHandlerDictionary[task] = successOrFailHandler
            }
        }
        
        return resumedTasks.isEmpty ? nil : resumedTasks
    }
    
    /**
     Pause downloading tasks and return tasks which are paused successfully. The method has no effect
     if task is not downloading.
     
     - parameter URLStrings: An array of URL string of task which you want to pause.
     
     - returns: An array of URL string of task which is paused successfully, or nil if no task is paused.
     */
    public func pauseTasks(_ URLStrings: [String]) -> [String]?{
        guard let validTasks = collectValidTasksIn(URLStrings, comparisonSet: _downloadTaskSet) else {return nil}
        
        var pausedTasks: [String] = []
        
        downloadQueue.isSuspended = true
        for task in validTasks{
            guard downloadState(ofTask: task) == .downloading else {continue}
            
            if let operation = downloadOperation(ofTask: task){
                if pauseDownloadBySuspendingSessionTask{
                    operation.suspend()
                    increaseMaxConcurrentCountAfterPauseTask(task)
                }else{
                    operation.stop()
                }
                pausedTasks.append(task)
            }else{
                fixOperationMissIssueForTask(task)
            }
        }
        downloadQueue.isSuspended = false
        
        return pausedTasks.isEmpty ? nil : pausedTasks
    }
    
    /**
     Stop downloading/paused tasks and cancel waitting tasks and return tasks which are stopped successfully.
     
     How to define "stop"? `SDEDownloadManager` use `NSURLSessionDownloadTask` to download files.
     Usually we "pause" a task by `suspend()`, and the task still keeps connection with server; here
     "stop" a task by `cancel(byProducingResumeData:)`, disconnect from server.
     
     - parameter URLStrings: An array of URL string of task which you want to stop.
     
     - returns: An array of URL string of task which is stopped successfully, or nil if no task is stopped.
     */
    public func stopTasks(_ URLStrings: [String]) -> [String]?{
        guard let validTasks = collectValidTasksIn(URLStrings, comparisonSet: _downloadTaskSet) else {return nil}
        
        var stopedTasks: [String] = []
        // .notInList:-1, .pending:0, .downloading:1, .paused:2, stopped:3, .finished:4
        let stopableStateSet: Set<Int> = [0, 1, 2, 3]
        var taskStateInfo: Dictionary<String, Int> = [:]
        let stopableTasks = validTasks.filter({
            if let stateRawValue = downloadTaskInfo[$0]![TITaskStateIntKey] as? Int{
                if stopableStateSet.contains(stateRawValue){
                    taskStateInfo[$0] = stateRawValue
                    return true
                }else{
                    return false
                }
            }else{
                return false
            }
        })
        guard !stopableTasks.isEmpty else {return nil}
        
        downloadQueue.isSuspended = true
        for task in validTasks{
            if let stateRawValue = taskStateInfo[task]{
                switch stateRawValue {
                case 0, 3://.pending, .stopped
                    removeRecordInWaittingTaskQueueForTask(task)
                    if let operation = downloadOperation(ofTask: task), operation.isCancelled == false{
                        operation.cancel()
                        stopedTasks.append(task)
                    }
                case 1, 2://.downloading, .paused
                    if stateRawValue == 2{
                        removeRecordInWaittingTaskQueueForTask(task)
                    }
                    if let operation = downloadOperation(ofTask: task){
                        operation.stop()
                        // stop a paused task
                        if operation.isExecuting == false{
                            reduceMaxConcurrentCountAfterResumeOrStopPausedTask()
                        }
                    }else{
                        fixOperationMissIssueForTask(task)
                    }
                    stopedTasks.append(task)
                default: break
                }
            }
        }
        
        downloadQueue.isSuspended = false
        return stopedTasks.isEmpty ? nil : stopedTasks
    }
    
    /**
     Delete task records and choose to delete relative files or not, and return a Ditionary includes
     deleted task's URL string and its original location in `downloadList`. If data is not loaded,
     this method will wait.
     
     PS.: If you want to delete many tasks, you better use `deleteTasks(at:keepFinishedFile:deletionHandler:)`,
     this method takes more time when delete same tasks.
     
     If `isTrashOpened == true`, tasks will be moved to `toDeleteList`.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter URLStrings: An array of URL string of task which you want to delete.
     
     - parameter keepFinishedFile: Just works for finished task whose file is downloaded completely.
     For task whose state is not finished, this parameter is ignored. The default value is `false`.
     You can get file location by `fileURL(forTask:)` before calling this method.
     
     - returns: A Dictionary includes deleted task info. Key: URL string of deleted task, Value: task
     original location in `downloadList`. If no task is deleted, return nil.
     */
    public func deleteTasks(_ URLStrings: [String], keepFinishedFile: Bool = false) -> Dictionary<String, IndexPath>?{
        waitIfDataNotLoaded()
        var taskIPs: [(task: String, ip: IndexPath)] = []
        Set(URLStrings).forEach({ URLString in
            if let ip = self[URLString]{
                taskIPs.append((URLString, ip))
            }
        })
        guard !taskIPs.isEmpty else {return nil}
        return deleteTasksWithLocations(taskIPs, keepFile: keepFinishedFile)
    }
    
    /**
     Delete relative files of tasks but keep record, and return locations of tasks whose files are
     deleted successfully. If data is not loaded, this method will wait.
     
     Specially, if task's state is .pending, it's also included in returned result.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter URLStrings: An array of URL string of task whose file you want to delete.
     
     - returns: An array of URL string of task whose file is deleted successfully, or nil if no file
     is deleted.
     */
    public func deleteFilesOfTasks(_ URLStrings: [String]) -> [String]?{
        waitIfDataNotLoaded()
        var deletedTasks: [String] = []
        downloadQueue.isSuspended = true
        
        toDeleteCount = URLStrings.count
        deletedCount = 0
        let ip = IndexPath(row: 0, section: 0)
        for task in URLStrings{
            if isDeletionCancelled{
                break
            }
            if deleteFileOfTask(task){
                deletedCount += 1
                deletedTasks.append(task)
                deleteCompletionHandler?(task, ip, toDeleteCount, deletedCount)
            }
        }
        resetDeleteHandler()
        
        downloadQueue.isSuspended = false
        return deletedTasks.isEmpty ? nil : deletedTasks
    }
    
    /**
     Redownload file if task's finished or stopped and return locations of tasks which are
     restarted successfully. The downloaded file will be deleted before restart.
     
     - parameter URLStrings: An array of URL string of task which you want to restart.
     
     - returns: An array of URL string of task which is restarted successfully, or nil if no task is
     restarted.
     */
    public func restartTasks(_ URLStrings: [String]) -> [String]?{
        guard let validTasks = collectValidTasksIn(URLStrings, comparisonSet: _downloadTaskSet) else {return nil}
        
        var restartedTasks: [String] = []
        for task in validTasks{
            switch downloadState(ofTask: task) {
            case .downloading, .pending, .paused, .notInList: continue
            case .finished:
                if let fileLocation = fileURL(ofTask: task), (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true{
                    do{
                        try FileManager.default.removeItem(at: fileLocation as URL)
                    }catch{
                        continue
                    }
                }
                
                let infoToUpdate: Dictionary<String, Any> = [TITaskStateIntKey: DownloadState.pending.rawValue,
                                                             TIFileLocationStringKey: TIDeleteValueMark]
                updateMetaInfo(infoToUpdate, forTask: task)
            case .stopped:
                if let operation = downloadOperation(ofTask: task){
                    operation.cleanResumeData()
                }
                
                if let resumeData = resumeData(ofTask: task){
                    URLSession.shared.downloadTask(withResumeData: resumeData as Data).cancel()
                }
                
                removePartInfoWithKeys([TIResumeDataKey, TIReceivedByteCountInt64Key, TIDownloadDetailStringKey, TIProgressFloatKey], forTask: task)
                updateMetaInfo([TITaskStateIntKey: DownloadState.pending.rawValue], forTask: task)
            }
            //            thumbnailCacher.removeThumbnailForTask(task)
            resumePendingTask(task)
            fetchFileMetaInfoForTask(task)
            restartedTasks.append(task)
        }
        
        return restartedTasks.isEmpty ? nil : restartedTasks
    }
    
    // MARK: Manage All Tasks in DownloadList
    /**
     Resume all unfinished tasks. What's difference between this method and `resumeTasks(_:)`?
     If download manager has reach maxDownloadCount, this method will put task into waitting list, the
     latter won't.
     
     - parameter limited: A switch to lock/unlock the limitation of maxDownloadCount. If the value is true,
     keep count of executing task at the same time is not large than maxDownloadCount, the default value is
     true; if false, unlock maxDownloadCount, maxDownloadCount is setted to
     `OperationQueue.defaultMaxConcurrentOperationCount`, which means no limitation.
     */
    public func resumeAllTasks(underLimit limited: Bool = true) {
        guard isAnyTaskUnfinished else{return}
        
        if limited && downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount{
            waittingTaskQueue.removeAllObjects()
            downloadQueue.isSuspended = true
            
            sortedURLStringsList.flatMap({$0}).reversed().forEach({ URLString in
                // .notInList:-1, .pending:0, .downloading:1, .paused:2, stopped:3, .finished:4
                let stateRawValue = downloadTaskInfo[URLString]![TITaskStateIntKey] as! Int
                switch stateRawValue{
                case -1, 1, 4: break
                default: waittingTaskQueue.add(URLString)
                }
            })
            
            var lackCount = _maxDownloadCount - countOfRunningTask
            if lackCount > 0{
                var _waittingTaskQueue: [String] = waittingTaskQueue.array as! [String]
                while _waittingTaskQueue.isEmpty == false {
                    if lackCount == 0 && didReachMaxDownloadCount{
                        break
                    }
                    let URLString = _waittingTaskQueue.removeLast()
                    if lackCount > 0 {
                        lackCount -= 1
                    }
                    
                    _ = resumeTheTask(URLString, handleConcurrentCount: true)
                }
            }
            
            downloadQueue.isSuspended = false
        }else{
            waittingTaskQueue.removeAllObjects()
            if _maxDownloadCount != OperationQueue.defaultMaxConcurrentOperationCount{
                downloadQueue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
                _maxDownloadCount = OperationQueue.defaultMaxConcurrentOperationCount
            }
            
            sortedURLStringsList.flatMap({$0}).forEach({ URLString in
                _ = resumeTheTask(URLString)
            })
        }
    }
    
    /**
     Pause all downloading tasks and dequeue waitting tasks in the queue.
     If `pauseDownloadBySuspendingSessionTask == false`, this method call `stopAllTasks()`.
     */
    public func pauseAllTasks(){
        guard pauseDownloadBySuspendingSessionTask else{
            stopAllTasks()
            return
        }
        
        guard downloadQueue.operations.isEmpty == false else{ return }
        
        downloadQueue.isSuspended = true
        if waittingTaskQueue.count > 0{
            waittingTaskQueue.removeAllObjects()
        }
        
        let executingOPs = executingOperations
        if executingOPs.count > 0{
            executingOPs.forEach({$0.suspend()})
            if downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount{
                downloadQueue.maxConcurrentOperationCount = countOfPausedTask + _maxDownloadCount
            }
        }
        pendingOperations.forEach({ $0.cancel() })
        
        downloadQueue.isSuspended = false
    }
    
    /**
     Stop all downloading tasks and cancel waitting tasks in the queue.
     */
    public func stopAllTasks(){
        guard downloadQueue.operations.isEmpty == false else{ return }
        
        downloadQueue.isSuspended = true
        if waittingTaskQueue.count > 0{
            waittingTaskQueue.removeAllObjects()
        }
        if downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount{
            downloadQueue.maxConcurrentOperationCount = _maxDownloadCount
        }
        
        downloadOperations.forEach({ $0.stop() })
        downloadQueue.isSuspended = false
    }
    
    /**
     Delete all task records and choose to delete relative files or not. If data is not loaded, this method will wait.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - parameter keepFinishedFile: Just aim at finished task whose file is downloaded completely, if file
     is not downloaded completely, even this value is True, temporary file still will be deleted. If this
     value is false, regardless of task's download progress, record and relative file will be deleted both.
     The default is false. You can get file location by `fileURL(forTask:)` before calling this method.
     
     - returns: A Dictionary of deleted task info. Key: URL string of the deleted task, Value: task
     original location in `downloadList`. If no task is deleted, return nil.
     */
    public func deleteAllTasks(_ keepFinishedFile: Bool = false) -> Dictionary<String, IndexPath>?{
        waitIfDataNotLoaded()
        return deleteTasks(Array(_downloadTaskSet), keepFinishedFile: keepFinishedFile)
    }
    
    /**
     Delete all files but keep records. If data is not loaded, this method will wait.
     
     If you want to do something after a task is deleted in this method, use `deleteCompletionHandler`.
     After this method returns, `deleteCompletionHandler` is reset to nil.
     
     - returns: An array of URL string of tasks whose file are deleted successfully. If no file is deleted, return nil.
     */
    public func deleteFilesOfAllTasks() -> [String]?{
        waitIfDataNotLoaded()
        return _downloadTaskSet.isEmpty ? nil : deleteFilesOfTasks(Array(_downloadTaskSet))
    }

    // MARK: - Custom Options for Download Feature
    /**
     A Boolean value that determines whether download manager should download files over a cellular network.
     
     The default value is false.
     */
    public var allowsCellularAccess: Bool = false{
        didSet{
            if identifier != SDEDownloadManager.placeHolderIdentifier{
                self.downloadSession.configuration.allowsCellularAccess = allowsCellularAccess
            }
        }
    }
    /**
     The maximum count of task that could download at the same time.
     
     Reducing it will pause redundant downloading tasks automatically; increasing it will
     resume tasks which are paused in reducing maxDownloadCount.
     
     The defalut value is `OperationQueue.defaultMaxConcurrentOperationCount`, which means no limit.
     Assign a nagative or 0 to this property, this property is set to
     `OperationQueue.defaultMaxConcurrentOperationCount` directly.
     */
    dynamic public var maxDownloadCount: Int{
        get{return _maxDownloadCount}
        set{
            if newValue == _maxDownloadCount || (_maxDownloadCount == OperationQueue.defaultMaxConcurrentOperationCount && newValue <= 0){
                return
            }
            
            let newMaxDownloadCount = newValue <= 0 ? OperationQueue.defaultMaxConcurrentOperationCount : newValue
            _maxDownloadCount = newMaxDownloadCount
            adjustMaxDownloadCount()
        }
    }
    /**
     A Boolean value indicating that whether download manager resume waitting tasks when `maxDownloadCount`
     is increased. The default value is `true`. This option won't be saved.
     
     Waitting task include:
     1. When download a new file or resume a task, if downloading tasks has reach `maxDownloadCount`, this
     task is a waitting task;
     2. If 5 tasks is downloading and `maxDownloadCount` is set to 3, then 2 tasks are paused and they are
     waitting tasks now.
     */
//    public var resumeTaskAutomaticallyAfterIncreasingMaxDownloadCount: Bool = true
    /**
     A Boolean value determining that how download manager pause a download task. `SDEDownloadManager` use
     `NSURLSessionDownloadTask` to download file, calling `suspend()` or `cancel(byProducingResumeData:)`
     on NSURLSessionDownloadTask has same results for users: they both pause the download.
     
     If true, call `suspend()`; if false, call `cancel(byProducingResumeData:)`. The default value is `true`.
     This option won't be saved.
     */
    public var pauseDownloadBySuspendingSessionTask: Bool = true
    /**
     A Boolean value indicating that whether download manager start to download immediately after add a new
     download task if it has not reach `maxDownloadCount`. The default value is `true`. This option won't be
     saved.
     */
    public var downloadNewFileImmediately: Bool = true
    
    // MARK: Custom Options for Delete Feature
    /**
     A Boolean value determining whether move the task to `toDeleteList` when delete it.
     If true, task to delete will be moved to the trash first; if false, delete the task directly.
     */
    public var isTrashOpened: Bool = false{
        didSet{
            if isTrashOpened != oldValue{
                isConfigurationChanged = true
            }
        }
    }
    
    /**
     A closure to execute after a task is deleted. Paratmeters in closure:
     
     String: URL string of deleted task.
     
     IndexPath: Deleted task's location in `downloadList` or `toDeleteList`. This parameter should be ignored
     when only task's file is deleted in these methods: `deleteFilesOfTasks(_:)`, `deleteFilesOfTasks(at:)`
     and `deleteFilesOfAllTasks()` .
     
     Int: Count of all tasks to delete.
     
     Int: The Nth deleted task. Starts from 1.
     */
    public var deleteCompletionHandler: ((String, IndexPath, Int, Int) -> Void)? = nil
    
    // MARK: Custom Options to Sort Download List
    /**
     A Boolean value determining whether split download list into groups by their alphanumeric order
     when sorting by file name. This property is used to switch on/off a feature: section index titles.
     If false, download list won't be splited into groups. Works only when `sortType == .fileName`.
     The default value is `false`.
     */
    public var indexingFileNameList: Bool = false{
        didSet{
            if indexingFileNameList != oldValue{
                isConfigurationChanged = true
            }
        }
    }
    
    /**
     A Boolean value determining whether split download list into groups when sorting by add time,
     like: "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "Older". If false, download list
     won't be splited into groups. Works only when `sortType == .addTime`. The default value is `false`.
     */
    public var sectioningAddTimeList: Bool = false{
        didSet{
            if sectioningAddTimeList != oldValue{
                isConfigurationChanged = true
            }
        }
    }
    /**
     A Boolean value determining whether split download list into groups when sorting by file size,
     like: "0 ~ 1 MB", "1 MB ~ 10 MB", "10MB ~ 100 MB", "100 MB ~ 1 GB", "Larger Than 1 GB".
     If false, download list won't be splited into groups. Works only when `sortType == .fileSize`.
     The default value is `false`.
     */
    public var sectioningFileSizeList: Bool = false{
        didSet{
            if sectioningFileSizeList != oldValue{
                isConfigurationChanged = true
            }
        }
    }
    
    /**
     A Boolean value determining whether display name returned by `fileDisplayName(ofTask:)` and
     `fileDisplayName(at:)` hidden its file extension if it has a file extension. The default vale
     is `true`.
     */
    public var hiddenFileExtension: Bool = true
    // MARK: Closures to Track Download Activity
    /**
     This closure provides download activity info. The default value is nil.
     
     `beginTrackingDownloadActivity()` executes this closure every second in the background until there is
     no more download or call `stopTrackingDownloadActivity()` to stop it. If there is no more download
     activity, `downloadCompletionHandler` will be executed.
     
     In `DownloadListController`, this closure is set to update download activity in view.
     
     Dictionary's key is download URL string, and value is a tuple include task's download activity info.
     
     - receivedBytes: downloaded bytes for now.
     
     - expectedBytes: file size by bytes. Sometimes it's negative number, means unknown size.
     
     - speed: downloaded bytes in last second. This value is -1 if download is over, you should remove
     speed info in your view at this time.
     
     - detailInfo: additional information. Usually it's nil, unless speed == -1(it means download is over).
     If this value is not nil, it most be format string of download progress, for example: if task is
     paused, this value could be "41.6 MB/402.5 MB"; if task is finished, this value could be "402.5 MB".
     */
    public var downloadActivityHandler: ((Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, speed: Int64, detailInfo: String?)>) -> Void)?
    /**
     Alternate for `downloadActivityHandler` in Objective-C code. This closure provides download activity info.
     The default value is nil.
     
     `beginTrackingDownloadActivity()` executes this closure every second in the background until there is
     no more download or call `stopTrackingDownloadActivity()` to stop it. If there is no more download
     activity, `downloadCompletionHandler` will be executed.
     
     This property is Objective-C version of `downloadActivityHandler` which can't be seen in Objective-C file.
     
     Dictionary's key is download URL string, and the value is a dictionary include this task's
     download activity info, key and value:
     
     - key: "receivedBytes", value type: Int64, downloaded bytes for now.
     - key: "expectedBytes", value type: Int64, file size by bytes. Sometimes it's negative number,
     means unknown size.
     - key: "speed", value type: Int64, downloaded bytes in last second. This value is -1 if download is
     over, you should remove speed info in your view at this time.
     - key: "detailInfo", value type: String, additional information, usually this key-value is not
     existed, unless speed == -1(it means download is over). Most time it is format string of download
     progress, for example: if task is paused, this value could be "41.6 MB/402.5 MB"; if task is
     finished, this value could be "402.5 MB".
     */
    public var objcDownloadActivityHandler: ((Dictionary<String, Dictionary<String, Any>>) -> Void)?
    /**
     The closure to execute after all downloads are over. It won't be executed if `stopTrackingDownloadActivity()`
     is called. Specially, if all downloading tasks are paused, this closure will be executed also.
     */
    public var downloadCompletionHandler: (() -> Void)?
    /**
     A closure to execute after any task is successful or failed(not include cancelling task and
     stopping task). The default is nil. If you specify handler for special task in
     `download(_:successOrFailHandler:)` or `resumeTasks(_:successOrFailHandler:)`, this closure
     won't be executed for the special task.
     
     Closure parameters `fileLocation` and `error`, only one is not nil at the same time.
     
     - parameter URLString: The download URL string of file.
     - parameter fileLocation: File location. It's not nil only when file is downloaded successfully.
     - parameter error: It's not nil only when download is failed.
     */
    public var taskSuccessOrFailHandler: ((_ URLString: String, _ fileLocation: URL?, _ error: NSError?) -> Void)?
    
    // MARK: Closures to Custom Behaviors in Session Delegate
    /**
     A closure to execute in session delegate method:
     `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:`.
     The default value is nil. Although `SDEDownloadManager` provides download activity track feature,
     you still could use this closure to implement this target.
     */
    public var downloadTaskWriteDataHandler: ((_ session: URLSession, _ downloadTask: URLSessionDownloadTask, _ bytesWritten: Int64, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void)?
    /// A closure to execute in session delegate method: `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`. The default value is nil.
    public var downloadTaskResumeHandler: ((_ session: URLSession, _ downloadTask: URLSessionDownloadTask, _ didResumeAtOffset: Int64, _ expectedTotalBytes: Int64) -> Void)?
    /**
     A closure to execute in session delegate method:
     `URLSessionDidFinishEventsForBackgroundURLSession:`. The default value is nil. Use this closure
     to push a notification after all tasks are done when app is in the background, or update
     screenshot in Multitasking Screen. Look for `configurateListVC()` in this project to see
     the example.
     */
    public var backgroundSessionDidFinishEventsHandler: ((_ session: URLSession) -> Void)?
    /**
     A closure to execute in session delegate method:
     `URLSession:didReceiveChallenge:completionHandler:`. The default value is nil. Use this closure
     to handle session-level authentication.
     */
    public var sessionDidReceiveChallengeHandler: ((_ session: URLSession, _ challenge: URLAuthenticationChallenge, _ completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    /**
     A closure to execute in session delegate method:
     `URLSession:task:didReceiveChallenge:completionHandler:`.
     
     The default value is nil. Use this closure to handle non session-level authentication.
     
     Note: I have handled basic and digest authentication, if authentication type is basic and digest,
     this closure won't be executed.
     */
    public var taskDidReceiveChallengeHandler: ((_ session: URLSession, _ task: URLSessionTask, _ challenge: URLAuthenticationChallenge, _ completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    
    // MARK: Closure to Add Meta Info for A Download Task
    /**
     A closure to fetch meta info when download a new file. The default value is nil. Sometimes, meta info
     fetched by `SDEDownloadManager` maybe are not what you want, you could append additional info in this
     closure by `updateMetaInfo(_:forTask:)`. There are two reserved keys for you:
     `TIFileDisplayNameStringKey` and `TIFileIntroStringKey`.
     */
    public var fetchMetaInfoHandler: ((_ URLString: String) -> Void)?
    
    // MARK: - Load and Save Data
    internal func waitIfDataNotLoaded(){
        while !_isDataLoaded {}
    }
    /**
     Performance Test on iPad mini:
     
     Under 10000 records: per 1000 records add about 0.5s.
     20000 records about: 9~18s
     */
    private func loadData(){
        #if DEBUG
            NSLog("Begin to load data for %@", identifier)
            let startTime = Date()
            defer {
                if trashList.count > 0{
                    NSLog("DM: %@ load data: \(downloadTaskInfo.count - trashList.count) items in download list and \(trashList.count) items in the trash. LoadTime: \(Date().timeIntervalSince(startTime))s", identifier)
                }else{
                    NSLog("DM: %@ load \(downloadTaskInfo.count) items. LoadTime: \(Date().timeIntervalSince(startTime))s", identifier)
                }
            }
        #endif

        let defaultPersistentDirectory = NSHomeDirectory() + SDEDownloadManager.persistentDirectory
        let isDirectoryExisted = FileManager.default.fileExists(atPath: defaultPersistentDirectory)
        if !isDirectoryExisted{
            do{
                try FileManager.default.createDirectory(atPath: defaultPersistentDirectory, withIntermediateDirectories: true, attributes: nil)
            }catch {
                fatalError("Can't save data in Directory /Library: \(error.localizedDescription)")
            }
        }

        let dmIdentifier: String = "com.SDEDownloadManager.\(self.identifier).Info"
        if let sortInfo = UserDefaults.standard.dictionary(forKey: dmIdentifier){
            if  let typeRawValue = sortInfo["SortType"] as? Int{
                self._sortType = ComparisonType(rawValue: typeRawValue)!
            }

            if let orderRawValue = sortInfo["SortOrder"] as? Int{
                self._sortOrder = ComparisonOrder(rawValue: orderRawValue)!
            }

            if let maxDownloadCount = sortInfo["MaxDownloadCount"] as? Int{
                self._maxDownloadCount = maxDownloadCount
            }

            if let indexing = sortInfo["indexingFileNameList"] as? Bool{
                self.indexingFileNameList = indexing
            }
            
            if let sectioning = sortInfo["sectioningAddTimeList"] as? Bool{
                self.sectioningAddTimeList = sectioning
            }
            
            if let sectioning = sortInfo["sectioningFileSizeList"] as? Bool{
                self.sectioningFileSizeList = sectioning
            }
            
            if let opened = sortInfo["isTrashOpened"] as? Bool{
                self.isTrashOpened = opened
            }

            isConfigurationChanged = false
        }
        else{// Init first time
            isConfigurationChanged = true
        }

        var format: PropertyListSerialization.PropertyListFormat = .binary
        // The performance of `sorted(by:)` in the standard library is not good. Reading sorted list is faster than sorting it when
        // list count is a little big, like 1000.
        let listInfoFilePath = defaultPersistentDirectory + "\(identifier).ListInfo" + SDEDownloadManager.postfix
        if let plistData = try? Data(contentsOf: URL(fileURLWithPath: listInfoFilePath)),
            let info = (try? PropertyListSerialization.propertyList(from: plistData, options: [.mutableContainers], format: &format)) as? Dictionary<String, Any>{
            if let URLStringsList = info["SortedURLStringsList"] as? [[String]]{
                sortedURLStringsList = URLStringsList
            }
            
            if let titles = info["SectionTitleList"] as? [String]{
                sectionTitleList = titles
            }
        }


        let trashListFilePath = defaultPersistentDirectory + "\(identifier).Trash" + SDEDownloadManager.postfix
        if  let plistData = try? Data(contentsOf: URL(fileURLWithPath: trashListFilePath)),
            let array = (try? PropertyListSerialization.propertyList(from: plistData, options: [.mutableContainers], format: &format)) as? [String]{
                self.trashList = array
        }
        
        let customThumbnailInfoFilePath = defaultPersistentDirectory + "\(identifier).CustomThumbnailInfo" + SDEDownloadManager.postfix
        if  let plistData = try? Data(contentsOf: URL(fileURLWithPath: customThumbnailInfoFilePath)),
            let info = (try? PropertyListSerialization.propertyList(from: plistData, options: [.mutableContainers], format: &format)) as? Dictionary<String, String>{
            customThumbnailInfo = info
        }

        let taskInfoFilePath = defaultPersistentDirectory + "\(identifier).TaskInfo" + SDEDownloadManager.postfix
        if  let plistData = try? Data(contentsOf: URL(fileURLWithPath: taskInfoFilePath)),
            let info = (try? PropertyListSerialization.propertyList(from: plistData, options: [.mutableContainers], format: &format)) as? Dictionary<String, Dictionary<String, Any>>{
            downloadTaskInfo = info
            _downloadTaskSet = Set(downloadTaskInfo.keys).subtracting(Set(trashList))
            if _downloadTaskSet.isEmpty == false {
                if (FileManager.default.fileExists(atPath: listInfoFilePath) == false) {
                    if _sortType != .manual{
                        (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: sortType, order: sortOrder)
                    }else{
                        (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: .addTime, order: sortOrder)
                    }
                }
                switch _sortType {
                case .manual: break
                case .fileType:
                    var typeTasks: [[String]] = []
                    if _sortOrder == .descending{
                        for sortedTasks in sortedURLStringsList {
                            typeTasks.append(sortedTasks.reversed())
                        }
                    }else{
                        typeTasks = sortedURLStringsList
                    }
                    sorter.cacheAscendingTypeTasks(typeTasks, titles: sectionTitleList)
                default:
                    var sortedTasks = sortedURLStringsList.flatMap({$0})
                    if _sortOrder == .descending{
                        sortedTasks.reverse()
                    }
                    sorter.cacheAscendingTasks(sortedTasks, forType: _sortType)
                    if _sortType == .addTime && sectioningAddTimeList{
                        let lastSortDate = (try? FileManager.default.attributesOfItem(atPath: listInfoFilePath))?[.modificationDate] as? Date
                        if lastSortDate == nil || Calendar.current.isDateInToday(lastSortDate!) == false{
                            (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: .addTime, order: _sortOrder)
                        }
                    }
                }
            }
        }

        isTaskInfoChanged = false
        isListChanged = false
        isTrashChanged = false
        isCustomThumbnailChanged = false
        
        DispatchQueue.global().async(execute: {
            self.fixResumeDataIssueOniOS8()
            _ = self.fixOperationMissedIssues()
            self.fixFinishedFileMissedIssues()
        })
    }
    
    internal var saving: Bool = false
    // It cannot be lazy variable, otherwise it doesn't work when access this property
    // from multiple threads at the first time.
    //
    // Lazy property is still not inialized atomically in Swift 4, it means that
    // saveLock maybe init more than once when access this property from multiple threads.
    // using {}() is more worse.
    let saveLock: NSLock = NSLock.init()
    private func saveDataToFile(){
        /*
         I hope this method can execute save process as little as possible in following situation :
         
         for _ in 1...1000 {
         DispatchQueue.global().async(execute: {
         dm.saveData()
         })
         }
         
         The alternative is a separate serial queue for this method.
         */
        saveLock.lock()
        guard isConfigurationChanged || isTaskInfoChanged || isListChanged || isTrashChanged || isCustomThumbnailChanged else{
            debugNSLog("No changed data to save, unlock and return.")
            saveLock.unlock()
            return
        }
        
        #if DEBUG
            let startTime = Date()
            defer {
                if trashList.count > 0{
                    NSLog("DM: %@ save data: \(downloadTaskInfo.count - trashList.count) items in download list and \(trashList.count) items in the trash. SaveTime: \(Date().timeIntervalSince(startTime))s", identifier)
                }else{
                    NSLog("DM: %@ save \(downloadTaskInfo.count) items. SaveTime: \(Date().timeIntervalSince(startTime))s", identifier)
                }
        }
        #endif
        
        saving = true
        
        if isConfigurationChanged{
            let userDefaults = UserDefaults.standard
            let dmIdentifier: String = "com.SDEDownloadManager.\(self.identifier).Info"
            // NSUserDefaults doesn't support String and Array in Swfit , use OC's version NSString and NSArray.
            let info: NSDictionary = ["SortType": _sortType.rawValue,
                                      "SortOrder": _sortOrder.rawValue,
                                      "MaxDownloadCount": maxDownloadCount,
                                      "indexingFileNameList": indexingFileNameList,
                                      "sectioningAddTimeList": sectioningAddTimeList,
                                      "sectioningFileSizeList": sectioningFileSizeList,
                                      "isTrashOpened": isTrashOpened]
            userDefaults.set(info, forKey: dmIdentifier)
            if userDefaults.synchronize(){
                isConfigurationChanged = false
            }
        }
        
        if isTaskInfoChanged{
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).TaskInfo" + SDEDownloadManager.postfix
            if downloadTaskInfo.isEmpty{
                syncEmptyDataToPath(savePath, changeSymbol: &isTaskInfoChanged, errorOwner: "downloadTaskInfo")
            }else{
                do{
                    let plistData = try PropertyListSerialization.data(fromPropertyList: downloadTaskInfo, format: .binary, options: 0)
                    savePlistData(plistData, toPath: savePath, changeSymbol: &isTaskInfoChanged, errorOwner: "downloadTaskInfo")
                }catch{
                    fatalError("Some data are NOT property list type. Check compatible data types: https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/PropertyList.html#//apple_ref/doc/uid/TP40008195-CH44. In Swift, all primitive data types(except for Float80) are compatible, for collection type, Array and Dictionary consist of these primitive data types are compatible also.")
                }
            }
        }
        
        
        if isListChanged{
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).ListInfo" + SDEDownloadManager.postfix
            if sectionTitleList.isEmpty && _downloadTaskSet.isEmpty{
                syncEmptyDataToPath(savePath, changeSymbol: &isListChanged, errorOwner: "List")
            }else{
                let listInfo: Dictionary<String, Any> = ["SortedURLStringsList": sortedURLStringsList, "SectionTitleList": sectionTitleList]
                let plistData = try! PropertyListSerialization.data(fromPropertyList: listInfo, format: .binary, options: 0)
                savePlistData(plistData, toPath: savePath, changeSymbol: &isListChanged, errorOwner: "List")
            }
        }
        
        if isTrashChanged{
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).Trash" + SDEDownloadManager.postfix
            if trashList.isEmpty{
                syncEmptyDataToPath(savePath, changeSymbol: &isTrashChanged, errorOwner: "Trash")
            }else{
                let plistData = try! PropertyListSerialization.data(fromPropertyList: trashList, format: .binary, options: 0)
                savePlistData(plistData, toPath: savePath, changeSymbol: &isTrashChanged, errorOwner: "Trash")
            }
        }
        
        if isCustomThumbnailChanged{
            let savePath = NSHomeDirectory() + SDEDownloadManager.persistentDirectory + "\(identifier).CustomThumbnailInfo" + SDEDownloadManager.postfix
            if customThumbnailInfo.isEmpty{
                syncEmptyDataToPath(savePath, changeSymbol: &isCustomThumbnailChanged, errorOwner: "CustomThumbnail")
            }else{
                let plistData = try! PropertyListSerialization.data(fromPropertyList: customThumbnailInfo, format: .binary, options: 0)
                savePlistData(plistData, toPath: savePath, changeSymbol: &isTrashChanged, errorOwner: "CustomThumbnail")
            }
        }
        
        saving = false
        saveLock.unlock()
    }
    
    private func savePlistData(_ data: Data, toPath path: String, changeSymbol symbol: inout Bool, errorOwner: String){
        do{
            try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
            symbol = false
        }catch{
            NSLog("Can't save data of %@ to file because of: %@", errorOwner, error.localizedDescription)
        }
    }

    private func syncEmptyDataToPath(_ path: String, changeSymbol symbol: inout Bool, errorOwner: String){
        if FileManager.default.fileExists(atPath: path){
            debugNSLog("Data is empty and delete data file at \(path)")
            do{
                try FileManager.default.removeItem(atPath: path)
                symbol = false
            }catch{
                NSLog("Can't delete data file at path: %@ because of: %@", path, error.localizedDescription)
            }
        }else{
            symbol = false
        }
    }
    

    // MARK: - Control Download Count
    private lazy var startOPSerialQueue: DispatchQueue = DispatchQueue(label: "SerialQueue.\(self.identifier).SDEDownloadManager")
    internal lazy var waittingTaskQueue: NSMutableOrderedSet = []
    internal var didReachMaxDownloadCount: Bool{
        if downloadQueue.maxConcurrentOperationCount == OperationQueue.defaultMaxConcurrentOperationCount{
            return false
        }
        
        if downloadQueue.operationCount < _maxDownloadCount{
            return false
        }
        
        let executingOperationCount = countOfRunningTask
        if executingOperationCount >= _maxDownloadCount{
            debugNSLog("Count of executing task: \(executingOperationCount), maxDownloadCount: \(_maxDownloadCount) is reached.")
            return true
        }
        
        if countOfPendingTask >= _maxDownloadCount - executingOperationCount{
            debugNSLog("Reach MaxDownloadCount: pending task count >= avaiable count")
            return true
        }else{
            return false
        }
    }

    /**
     The target is keeping count of executing task <= maxDownloadCount.

     If count of executing task is more than maxDownloadCount, supernumerary executing tasks will be paused
     and put them into the Array `waittingTaskQueue`. When a executing task end(stop, cancel, or finish) or
     maxDownloadCount is increased, tasks in `waittingTaskQueue` have a higher priority to execute.

     If user pause a executing task explicitly, I think it means user don't want this task to resume only
     when user want it.

     For NSOperationQueue, a started operation is a unfinished operation, whatever it's executing or not,
     it takes a quota of `maxConcurrentOperationCount`. For user, an executing operation pause and there 
     should be one more operation could to execute or start. How to balance the deviation? It's easy.

     Use a variable `maxDownloadCount` to replace maxConcurrentOperationCount, initially, maxDownloadCount
     = maxConcurrentOperationCount. If 
     maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount(-1):
     Pause a operation, downloadQueue.maxConcurrentOperationCount += 1,
     Resume a paused operation, downloadQueue.maxConcurrentOperationCount -= 1.

     NSOperation won't stop you to resume a paused operation or pause a execting operation, it doesn't care
     that operation is really executing or not. So be careful to resume a paused operation: check whether
     count of executing operation is less than maxDownloadCount, YES, resume it, NO, don't.

     ------------------------------------------------------------------------------------------------------
     Adjust maxConcurrentOperationCount by stopping a task(cancelByProducingResumeData), don't need the
     above rule, just set maxConcurrentOperationCount = maxDownloadCount.
     */
    private var _maxDownloadCount: Int = OperationQueue.defaultMaxConcurrentOperationCount
    private func adjustMaxDownloadCount(){
        isConfigurationChanged = true
        
        #if DEBUG
            defer {
                NSLog("After adjusting maxDownloadCount to \(_maxDownloadCount), maxConcurrentOperationCount is: \(downloadQueue.maxConcurrentOperationCount)")
                NSLog("exutingCount: \(countOfRunningTask) pausedCount: \(countOfPausedTask) startedCount: \(countOfStartedTask)")
        }
        #endif
        
        if _maxDownloadCount == OperationQueue.defaultMaxConcurrentOperationCount{
            downloadQueue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
            if waittingTaskQueue.count > 0 {
                let _waittingTaskQueue = waittingTaskQueue.array as! [String]
                waittingTaskQueue.removeAllObjects()
                _waittingTaskQueue.forEach({_ = resumeTheTask($0)})
            }
            return
        }
        
        downloadQueue.isSuspended = true
        
        let executingTaskArray = executingOperations.map({$0.URLString})
        let executingTaskSet = Set(executingTaskArray)
        #if DEBUG
            if executingTaskArray.count != executingTaskSet.count{
                NSLog("There are multiple operations for same task. It should not. It happened in XCTest only for now.")
            }
        #endif
        
        if executingTaskSet.count > _maxDownloadCount{
            let sortedExecutingTasks: [String]
            if sortType == .manual || sortType == .fileType || executingTaskSet.count > 500{
                sortedExecutingTasks = sortedURLStringsList.flatMap({$0}).filter({executingTaskSet.contains($0)})
            }else{
                sortedExecutingTasks = sorter.sortedTaskSet(executingTaskSet, byType: sortType, order: sortOrder)
            }
            
            var toWaitTasks: [String] = []
            if pauseDownloadBySuspendingSessionTask{
                sortedExecutingTasks[_maxDownloadCount..<executingTaskSet.count].forEach({
                    if let operation = downloadOperation(ofTask: $0), operation.isExecuting == true{
                        debugNSLog("Pause supernumerary task: \(($0 as NSString).lastPathComponent)")
                        operation.suspend()
                        toWaitTasks.append($0)
                    }
                })
            }else{
                sortedExecutingTasks[_maxDownloadCount..<executingTaskSet.count].forEach({
                    if let operation = downloadOperation(ofTask: $0), operation.isExecuting == true{
                        debugNSLog("Stop supernumerary task: \(($0 as NSString).lastPathComponent)")
                        operation.stop()
                        toWaitTasks.append($0)
                    }
                })
            }
            
            if toWaitTasks.isEmpty == false{
                waittingTaskQueue.addObjects(from: toWaitTasks.reversed())
            }
        }
        
        if pauseDownloadBySuspendingSessionTask{
            downloadQueue.maxConcurrentOperationCount = _maxDownloadCount + countOfPausedTask
        }else{
            downloadQueue.maxConcurrentOperationCount = _maxDownloadCount
        }
        
        // Sometimes executing operations maybe are completed in this time.
        startOPSerialQueue.sync(execute: {[unowned self] in
            self.supplementExecutingTasks()
        })
        
        downloadQueue.isSuspended = false
    }
    
    private func supplementExecutingTasks(){
        while let URLString = waittingTaskQueue.lastObject as? String {
            if didReachMaxDownloadCount{
                debugNSLog("Stop to supplement task to execute.")
                break
            }else{
                waittingTaskQueue.remove(URLString)
                debugNSLog("Supplement a task to execute: \(URLString)")
                guard resumeTheTask(URLString, handleConcurrentCount: true) == false else {continue}
                guard downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount else {
                    continue
                }
                // fix maxConcurrentOperationCount
                let fixCount = _maxDownloadCount + countOfPausedTask
                if downloadQueue.maxConcurrentOperationCount != fixCount{
                    // download task is suspended or stopped but underlying work is not suspended or stopped in time.
                    debugNSLog("Candidate task: \(URLString) can't be resumed, fix maxConcurrentOperationCount from \(downloadQueue.maxConcurrentOperationCount) to \(fixCount).")
                    downloadQueue.maxConcurrentOperationCount = fixCount
                }
            }
        }
    }

    
    private func handleCompletionOfOperation(_ operation: DownloadOperation){
        guard operation.started == true else{
            taskHandlerDictionary[operation.URLString] = nil
            return
        }
        
        guard downloadQueue.isSuspended == false else {return}
        guard waittingTaskQueue.count > 0 else {return}
        guard didReachMaxDownloadCount == false else {return}
        
        // Lanch anothor task to make it like automatic. It should be operation queue's work, but I delay to create an operation 
        // as far as possible, so I have to do it manually.
        startOPSerialQueue.sync(execute: {[unowned self] in
            self.startATaskIfNecessary()
        })
    }
    
    private func startATaskIfNecessary(){
        while let URLString = self.waittingTaskQueue.lastObject as? String {
            self.waittingTaskQueue.remove(URLString)
            guard resumeTheTask(URLString, handleConcurrentCount: true) == false else {break}
            guard downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount else {
                continue
            }

            // When adjust maxDownloadCount, if a task is about to finished and suspended, when operation queue is avaiable to
            // start other operation, this task maybe resume byself and the operation is finished, normally, this operation should
            // resume and reduce maxConcurrentOperationCount at the same time, so maxConcurrentOperationCount maybe is not right.
            let fixCount = _maxDownloadCount + countOfPausedTask
            if downloadQueue.maxConcurrentOperationCount != fixCount{
                debugNSLog("Waitting task: \(URLString) can't be resumed, fix maxConcurrentOperationCount from \(downloadQueue.maxConcurrentOperationCount) to \(fixCount).")
                downloadQueue.maxConcurrentOperationCount = fixCount
            }
        }
    }
    
    // Works for increase maxDownloadCount/resume task manually
    internal func removeRecordInWaittingTaskQueueForTask(_ URLString: String){
        if waittingTaskQueue.contains(URLString){
            self.waittingTaskQueue.remove(URLString)
        }
    }
    
    // Called only when download is over.
    internal func tuningMaxConcurrentOperationCount(){
        if _maxDownloadCount != OperationQueue.defaultMaxConcurrentOperationCount{
            let count = _maxDownloadCount + countOfPausedTask
            if downloadQueue.maxConcurrentOperationCount != count{
                debugNSLog("Tuning maxConcurrentOperationCount from \(downloadQueue.maxConcurrentOperationCount) to \(count).")
                downloadQueue.maxConcurrentOperationCount = count
            }
        }
    }


    private func sortWaittingList(){
        if sortType == .manual{
            let _waittingTaskSet = waittingTaskQueue.set as! Set<String>
            var _waittingList: [String] = []
            sortedURLStringsList.flatMap({$0}).forEach({ URLString in
                if _waittingTaskSet.contains(URLString){
                    _waittingList.append(URLString)
                }
            })
            waittingTaskQueue = NSMutableOrderedSet.init(array: _waittingList.reversed())
        }else{
            let reversedOrder: ComparisonOrder = _sortOrder == .ascending ? .descending : .ascending
            let array = sorter.sortedTaskSet(waittingTaskQueue.set as! Set<String>, byType: sortType, order: reversedOrder)
            waittingTaskQueue = NSMutableOrderedSet.init(array: array)
        }
    }

    private func increaseMaxConcurrentCountAfterPauseTask(_ URLString: String){
        guard downloadQueue.maxConcurrentOperationCount != OperationQueue.defaultMaxConcurrentOperationCount else{return}

        self.downloadQueue.maxConcurrentOperationCount += 1
        debugNSLog("Task is paused and maxConcurrentOperationCount ＋1 ＝ \(downloadQueue.maxConcurrentOperationCount)")
        if countOfPendingTask == 0 && waittingTaskQueue.count > 0{
            startOPSerialQueue.sync(execute: {[unowned self] in
                self.startATaskIfNecessary()
            })
        }
    }

    private func reduceMaxConcurrentCountAfterResumeOrStopPausedTask(){
        guard downloadQueue.maxConcurrentOperationCount > _maxDownloadCount else{return}
        self.downloadQueue.maxConcurrentOperationCount -= 1
        debugNSLog("Resume/Stop a paused task and maxConcurrentOperationCount -1 = \(downloadQueue.maxConcurrentOperationCount)")
    }

    
    // MARK: - Sort Download List
    lazy var sorter: ListSorter = {ListSorter.init(dm: self)}()
    
    /**
     Sort `downloadList` in place with predefined type or switch sort mode.
     
     Note: This method's performance is not good when download list has more than 1000 tasks. When parameter
     `sortType` is `.fileName` and `indexingFileNameList == true`, its performance is worst.
     
     - parameter type: In manual mode, a section in `downloadList` must has a title, and it will lose all
     section titles when switching from `.manual` to other types. And all tasks will be integrated into a
     single section with a placeholder title when switching from other types to `.manual`.
     - parameter order: Sort order for tasks in section: `.ascending` or `.descending`. The default value
     is `.ascending`.
     */
    public func sortListBy(type: ComparisonType, order: ComparisonOrder = .ascending){
        guard _isDataLoaded && _downloadTaskSet.isEmpty == false else{return}

        switch (sortType, type) {
        case (.manual, .manual): return
        case (.manual, _):
            _sortType = type
            _sortOrder = order
            (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: type, order: order)
        case (_, .manual):
            let headSection = sortedURLStringsList.flatMap({$0})
            sortedURLStringsList.removeAll()
            sectionTitleList.removeAll()
            
            _sortType = .manual
            _sortOrder = order
            if headSection.count > 0{
                sortedURLStringsList.append(headSection)
                sectionTitleList.append(DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle"))
            }
        case (_, _):
            if _sortType == type && _sortOrder != order{
                _sortOrder = order
                var reversedList: [[String]] = []
                let listToSort = type == .fileType ? sortedURLStringsList : sortedURLStringsList.reversed()
                for section in listToSort{
                    reversedList.append(section.reversed())
                }
                sortedURLStringsList = reversedList
                if type != .fileType{
                    sectionTitleList.reverse()
                }
            }else{
                _sortType = type
                _sortOrder = order
                (sectionTitleList, sortedURLStringsList) = sorter.sortedTitlesAndTasks(forType: type, order: order)
            }
        }
        DispatchQueue.global().async(execute: {
            self.saveData()
            self.sortWaittingList()
        })
    }
    
    /**
     Sort `downloadlist` in place with powerful predicate.
     
     Object comforms to `Sequence` has a method `sort(by:)` to sort list with custom predicate, which is
     used to implement `sortListBy(type:order:)`, and it also could be used to custom sort in this method,
     and very powerful, e.g., `sortListBy(type: .fileSize, order: .ascending)` could be implmented by this
     method like this:
     
         dm.sortListBy(order: .ascending, taskAscending: {
             dm.fileByteCount(ofTask: $0) < dm.fileByteCount(ofTask: $1)
         })
     
     `sortListBy(type:order:)` supports only four predefined sort types because it can't use unknown info
     to sort download list. Now you could add other info for task(by `fetchMetaInfoHandler`) and sort list
     by it in this method, e.g., you bulit a list of movies with release year, now sort movies by its
     release year:
     
         // Just show what this method do, some details are omited.
         dm.sortListBy(order: .descending, taskAscending: {
             let year0 = dm.info(ofTask: $0, about: ReleaseYearKey) as! Int
             let year1 = dm.info(ofTask: $1, about: ReleaseYearKey) as! Int
             return year0 < year1
         })
     
     In above two examples, there is only one section. When sort list with `.fileType`, tasks are splited
     into several sections by their file type. Technically, implement way is: filter tasks that have same
     trait and integrate these tasks into the same section; then sort sections and tasks in section. It
     likes sorting a Dictionary. What is appropriate trait? How to sort splited sections, based on what?
     There is an example, sort a list of songs: splited by its singer and singers are sorted by alphabet,
     singer's songs are sorted by release year and song name.
     
         dm.sortListBy(order: .ascending, taskTrait: { URLString in
             // Tasks which return same trait string will be integrated into the same section.
             // Returned trait string is also title for section in `downloadList`.
             // Sections are sorted by trait string in alphabet order.
             // If return nil, task will be in the last section with a placeholder title.
             dm.info(ofTask: URLString, about: SingerKey) as? String
         }, taskAscending: {
             // Sort tasks in section.
             let releaseYear0 = dm.info(ofTask: $0, about: ReleaseYearKey) as? Int
             let releaseYear1 = dm.info(ofTask: $1, about: ReleaseYearKey) as? Int
             let sing0 = dm.fileDisplayName(ofTask: $0)!
             let sing1 = dm.fileDisplayName(ofTask: $1)!
     
             switch (year0, year1){
             case (nil, nil): return sing0 < sing1
             case (nil, _): return true
             case (_, nil): return false
             case (_, _):
                 if year0! < year1!{
                     return true
                 }else if year0! > year1!{
                     return false
                 }else{
                     return sing0 < sing1
                 }
             }
         })
     
     Above sections are sorted by trait titles in alphabet order, sometimes it's not what you want, e.g.,
     I want to sort list by add time but split into sections like this:
     
         ["Today", "Yesterday", "Last 7 Days", "Last 30 Days", "Older"]
     
     If sort it in in alphabet order, this method will get the following result or reversed:
     
         ["Last 30 Days", "Last 7 Days", "Older", "Today", "Yesterday"]
     
     Sectin location can be adjusted manually by `moveTasks(inSection:to:)`, but it's not good way, and
     it's getting worse if some titles are not existed. Actually, it's easy to fix: add another predicate
     to reorder trait strings created in `taskTrait`.
     
         let AddTimeKey = "Key.Date.TaskCreateDate"
         let today = Calendar.current.startOfDay(for: Date())
         let DayInterval: TimeInterval = 24 * 60 * 60
         let traitPriority = ["Today": 0, "Yesterday": -10, "Last 7 Days": -100, "Last 30 Days": -1000, "Older": -10000]
     
         dm.sortListBy(order: .ascending, taskTrait: { URLString in
             // Tasks which have same trait string will be integrated into the same section.
             // Returned trait string is also title for section in `downloadList`.
             // Sections are sorted by trait string with custom predicate `traitAscending`.
             // If return nil, task will be in the last section with a placeholder title.
             let addTime = dm.info(ofTask: URLString, about: AddTimeKey) as! Date
             if Calendar.current.isDateInToday(addTime){
                 return "Today"
             }else if Calendar.current.isDateInYesterday(addTime){
                 return "Yesterday"
             }else if today.timeIntervalSince(addTime) < 7 * DayInterval{
                 return "Last 7 Days"
             }else if today.timeIntervalSince(addTime) < 30 * DayInterval{
                 return "Last 30 Days"
             }else{
                 return "Older"
             }
         }, traitAscending: {
             // Sort trait strings, and relative section is reordered also.
             traitPriority[$0]! < traitPriority[$1]!
         }, taskAscending: {
             // Sort tasks in section.
             dm.fileDisplayName(ofTask: $0)! < dm.fileDisplayName(ofTask: $1)!
         })
     
     
     Note: `sortType` will be set to `.manual` in this method. I was going to add another sort mode
     `.custom`, but there is no benefit except adding complexity.
     
     - parameter order: Sort order for section and tasks in section: `.ascending` or `.descending`.
     
     - parameter taskTrait: A closure that returns trait string for task. The default value is nil,
     which means that there will be one section with a placeholder title only. Tasks which have same
     trait string will be integrated into the same section, and trait string is also section title.
     If closure returns nil, task will be in the last section with a placeholder title. Sections are
     sorted by their titles with predicate `traitAscending`, if `traitAscending` is nil, sections 
     are sorted by their titles in alphabet order.
     
     - parameter traitAscending: A predicate that returns true if the first trail string should be
     ordered before the second trait string; otherwise, false. Trait string is also section title.
     It's used to sort section titles returned by `taskTrait` and relative sections.
     
     - parameter taskAscending: A predicate that returns true if the first task should be ordered before
     the second task; otherwise, false. It's used to sort tasks in section.
     */
    public func sortListBy(order: ComparisonOrder,
                       taskTrait: ((_ URLString: String) -> String?)? = nil,
                       traitAscending: ((_ trait: String, _ trait: String) -> Bool)? = nil,
                       taskAscending: (_ URLString: String, _ URLString: String) -> Bool){
        guard _isDataLoaded && _downloadTaskSet.isEmpty == false else{return}
        
        _sortType = .manual
        _sortOrder = order
        (sectionTitleList, sortedURLStringsList) = sorter.customSortedTitlesAndTasks(on: _downloadTaskSet,
                                                                                     byOrder: order,
                                                                                     taskTrait: taskTrait,
                                                                                     traitAscending: traitAscending,
                                                                                     taskAscending: taskAscending)
        DispatchQueue.global().async(execute: {
            self.saveData()
        })
    }
    

    
    /**
     Sort the specified section in `downloadList` and return sorted list.
     
     - parameter section: The index of section which you want to sort in `downloadList`.
     - parameter inplace: Reorder original section or not.
     - parameter type:    Except for `.manual` and `.fileType`, otherwise this method doesn't sort
     subsection and return nil.
     - parameter order:   `.ascending` or `.descending`.
     
     - returns: The sorted list of the subsection. Return nil if index is beyond the bounds, or subsection
     is empty, or parameter `type` is `.manual` or `.fileType`.
     */
    internal func sortSection(_ section: Int, inplace: Bool, byType type: ComparisonType, order: ComparisonOrder) -> [String]?{
        guard type != .manual && type != .fileType else {return nil}
        guard sortedURLStringsList.count > section else{return nil}
        
        let subsection = sortedURLStringsList[section]
        if subsection.isEmpty{
            return nil
        }else if subsection.count == 1{
            return subsection
        }
        
        if sortType != type{
            let sortedSubsection = sorter.sortedTaskSet(Set(subsection), byType: type, order: order)
            if inplace{
                sortedURLStringsList[section] = sortedSubsection
            }
            return sortedSubsection
        }else{
            let sortedSubsection = sortOrder == order ? subsection : subsection.reversed()
            if inplace && sortOrder != order{
                sortedURLStringsList[section] = sortedSubsection
            }
            return sortedSubsection
        }
    }
    
    internal func customSortSection(_ section: Int, inplace: Bool, byOrder order: ComparisonOrder, taskAscending: (String, String) -> Bool) -> [String]?{
        guard sortedURLStringsList.count > section else{return nil}
        guard sortedURLStringsList[section].isEmpty == false else {return nil}
        
        let sortedSection = sorter.customSortedTitlesAndTasks(on: Set(sortedURLStringsList[section]),
                                                              byOrder: order,
                                                              taskAscending: taskAscending).tasksList.first!
        if inplace{
            sortedURLStringsList[section] = sortedSection
        }
        return sortedSection
    }
        
    // MARK: Move Task Location in Manual Sort Mode
    /**
     Move task's location in `downloadList`. It's your responsibility to check indexPath's validity.
     
     - precondition: `sortType == .manual`
     
     - parameter indexPath:    Source location.
     - parameter newIndexPath: Destination location.
     */
    public func moveTask(at indexPath: IndexPath, to newIndexPath: IndexPath){
        guard sortType == .manual else{
            debugNSLog("\(#function) works only when sortType == .manual.")
            return
        }
        guard indexPath != newIndexPath else{
            debugNSLog("SourceIndexPath == DestionationIndexPath")
            return
        }
        
        let URLString = sortedURLStringsList[indexPath.section].remove(at: indexPath.row)
        sortedURLStringsList[newIndexPath.section].insert(URLString, at: newIndexPath.row)
    }
    
    internal var indexPathToChangeName: IndexPath?
    
    /**
     Move a whole section in `downloadList`. It's your responsibility to check section's validity.
     
     - precondition: `sortType == .manual`
     
     - parameter section:    Source location.
     - parameter newSection: Destionation location.
     */
    public func moveTasks(inSection section: Int, to newSection: Int){
        guard sortType == .manual else{
            debugNSLog("\(#function) works only when sortType == .manual.")
            return
        }
        guard section != newSection else{
            debugNSLog("SourceSection == DestionationSection")
            return
        }
        
        let URLStrings = sortedURLStringsList.remove(at: section)
        sortedURLStringsList.insert(URLStrings, at: newSection)
        let sectionTitle = sectionTitleList.remove(at: section)
        sectionTitleList.insert(sectionTitle, at: newSection)
    }

    // MARK: - Track Download Activity
    internal lazy var downloadTracker: DownloadTracker = DownloadTracker(downloadManager: self)

    /// True if satisfy any of the following conditions:
    /// 1. Any task begins to execute;
    /// 2. Any .Downloading task changes to other state.
    internal var didExecutingTasksChanged: Bool{
        return downloadTracker.didExecutingTasksChanged
    }

    /// `taskSuccessOrFailHandler` is executed for every task, sometimes you just want to do something
    /// after specific download URL string. Add a completionHandler to specific URL in
    /// `downloadFile(atURLString:completionHandler:)`. The completionHandler replace
    /// `taskSuccessOrFailHandler` to execute after this task is completed.
    internal lazy var taskHandlerDictionary: Dictionary<String, (_ URLString: String, _ fileLocation: URL?, _ error: NSError?) -> Void> = [:]

    /**
     If any download task is executing, download manager begins to collect download activity info, include:
     download size for now, file size, download speed, optional additional information, and then execute
     `downloadActivityHandler` closure every second until no more download.

     You should update UI in `downloadActivityHandler` closure. `DownloadListController` class is a good
     choice, I have done everything for you.
     */
    public func beginTrackingDownloadActivity(){
        downloadTracker.beginTrackingDownloadActivity()
    }

    /**
     Stop both collecting download activity info and executing `downloadActivityHandler` closure
     immediately. You should call this method to reduce resource consumption after your view disappear;
     call `beginTrackingDownloadActivity()` to continue after your view appear again. 
     `downloadCompletionHandler` closure won't be executed if call this method.
     */
    public func stopTrackingDownloadActivity(){
        downloadTracker.stopTrackingDownloadActivity()
    }

    // MARK: Cache Thumbnail
    lazy var thumbnailCacher: ThumbnailCacher = {
        return ThumbnailCacher.init(dm: self)
    }()

    var cacheOriginalRatioThumbnail: Bool = true{
        didSet{
            if cacheOriginalRatioThumbnail != oldValue{
                self.thumbnailCacher.emptyCache()
            }
        }
    }

    /**
     Request a thumbnail with specified height. This method is synchronous.

     If file is not image or video, and you don't custom thumbnail for it by `setCustomThumbnail(_:forTask:)`,
     this method returns a type icon. About type icon, you could offer custom icon(must be png file) for specified
     type by naming image file with file extension's uppercased, e.g., you want a .psd file to display custom icon,
     add "PSD.png" to this library, into /Resource/FileExtensionIcon.xcassets, this method will return an UIImage
     object inited from "PSD.png" for all .psd files.
     
     - parameter URLString: The URL string of task which you want to request thumbnail for.
     - parameter height: The target height of image to return.
     - parameter thumbnailHandler: A closure to provide fetched thumbnail. This closure will be called 
     only when: 1. no cache when calling this method; 2. thumbnail is created successfully.
     - parameter thumbnail: Thumbnail image for the request. And you will find image height is not exactly
     requested height sometimes, but its width is. It's adapted for `DownloadListController`.

     - returns: A thumbnail if it's in the cache, otherwise a type icon. Return nil if URLString is not
     in the list.
     */
    public func requestThumbnail(forTask URLString: String, targetHeight height: CGFloat, orLaterProvidedInHandler thumbnailHandler: @escaping (_ thumbnail: UIImage) -> Void) -> UIImage?{
        guard let _ = downloadTaskInfo[URLString] else{return nil}
        return thumbnailCacher.requestThumbnail(forTask: URLString, height: height, orLaterProvideThumbnailInHandler: thumbnailHandler)
    }
    
    /**
     Remove all thumbnails.
     */
    public func emptyThumbnailCache(){
        thumbnailCacher.emptyCache()
    }

    /**
     Custom thumbnail for the task, except for image file.

     - precondition: File is not a image.
     
     - parameter thumbnail: Image to used as thumbnail.
     - parameter URLString: The URL string of task which you want to custom thumbnail for.
     - parameter cacheInMemoryOnly: If false, thumbnail will be stored. If multiple files need a same 
     thumbail, e.g., an album art for songs, caching it in memory only could reduce memory usage.
     */
    public func setCustomThumbnail(_ thumbnail: UIImage, forTask URLString: String, cacheInMemoryOnly: Bool) {
        guard let _ = downloadTaskInfo[URLString] else{return}
        guard fileType(ofTask: URLString) != ImageType else {return}
        
        if cacheInMemoryOnly{
            thumbnailCacher.thumbnailFetchFailedTaskSet.remove(URLString)
            thumbnailCacher.thumbnailIsSourceSet.insert(URLString)
            thumbnailCacher.memoryOnlyTaskSet.insert(URLString)
            thumbnailCacher.cache.setObject(thumbnail, forKey: URLString as NSString)
            return
        }
        
        if let _ = thumbnailCacher.cache.object(forKey: (URLString as NSString)){
            thumbnailCacher.thumbnailFetchFailedTaskSet.remove(URLString)
            thumbnailCacher.thumbnailIsSourceSet.insert(URLString)
            thumbnailCacher.memoryOnlyTaskSet.remove(URLString)
            thumbnailCacher.cache.setObject(thumbnail, forKey: (URLString as NSString))
        }
        
        var imageExtension: String = ".png"
        let imageData: Data
        if let data = UIImagePNGRepresentation(thumbnail){
            imageData = data
        }else if let data = UIImageJPEGRepresentation(thumbnail, 1){
            imageExtension = ".jpg"
            imageData = data
        }else{
            return
        }
        
        let writeRelativePath: String
        if let relativePath = customThumbnailInfo[URLString]{
            writeRelativePath = relativePath
        }else{
            let fileName = downloadTaskInfo[URLString]![TIFileNameStringKey] as! String
            writeRelativePath = "Documents/" + fileName + "_Thumbnail_" + UUID().uuidString.components(separatedBy: "-").first! + imageExtension
            customThumbnailInfo[URLString] = writeRelativePath
        }

        try? imageData.write(to: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(writeRelativePath))
    }

    /**
     Remove custom thumbnail for the task and return it.

     - parameter URLString: The URL string of task whose custom thumbnail you want to remove.

     - returns: Return the image which is used as thumbnail for the task. Return nil if no custom thumbnail.
     */
    public func removeCustomThumbnailForTask(_ URLString: String) -> UIImage?{
        if thumbnailCacher.memoryOnlyTaskSet.contains(URLString),
            let thumbnail = thumbnailCacher.cache.object(forKey: URLString as NSString){
            thumbnailCacher.removeThumbnailForTask(URLString)
            _ = removeStoredCustomThumbnailForTask(URLString)
            return thumbnail
        }else{
            thumbnailCacher.removeThumbnailForTask(URLString)
            return removeStoredCustomThumbnailForTask(URLString)
        }
    }
    
    private func removeStoredCustomThumbnailForTask(_ URLString: String) -> UIImage?{
        guard let relavtivePath = customThumbnailInfo[URLString] else {return nil}
        
        let thumbnailPath = NSHomeDirectory() + "/" + relavtivePath
        if let thumbnail = UIImage(contentsOfFile: thumbnailPath){
            do{
                try FileManager.default.removeItem(atPath: thumbnailPath)
                customThumbnailInfo[URLString] = nil
                return thumbnail
            }catch{
                debugNSLog("Can't delete custom thumbnail file of %@: %@", URLString, error.localizedDescription)
                return nil
            }
        }
        
        customThumbnailInfo[URLString] = nil
        return nil
    }
    
    // MARK: - Helper Method to Manage Task Based on URL String
    /**
     Delete file only and keep task record, and return a Boolean value indicating whether it works.
     
     Relative file will be deleted no matter whether file is downloaded completely or not.
     
     - parameter URLString: The download URL string of file which you want to delete.
     
     - returns: A Boolean value indicating whether relative file is deleted. Specially, return false
     if task state is `.pending`.
     */
    internal func deleteFileOfTask(_ URLString: String) -> Bool{
        let state = downloadState(ofTask: URLString)
        switch state {
        case .notInList: return false
        case .finished:
            if let fileLocation = fileURL(ofTask: URLString), (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true{
                do{
                    try FileManager.default.removeItem(at: fileLocation as URL)
                }catch{
                    debugNSLog("Can't delete file of %@", URLString)
                    return false
                }
            }
            resetStateToPendingForTask(URLString)
            return true
        case .paused, .downloading:
            if let operation = downloadOperation(ofTask: URLString){
                operation.delete()
                if state == .paused{
                    reduceMaxConcurrentCountAfterResumeOrStopPausedTask()
                }
                return true
            }else{
                fixOperationMissIssueForTask(URLString)
                return false
            }
        case .pending:
            downloadOperation(ofTask: URLString)?.cancel()
            removeRecordInWaittingTaskQueueForTask(URLString)
            return true
        case .stopped:
            downloadOperation(ofTask: URLString)?.cancel()
            removeRecordInWaittingTaskQueueForTask(URLString)
            if let resumeData = resumeData(ofTask: URLString){
                URLSession.shared.downloadTask(withResumeData: resumeData as Data).cancel()
            }
            resetStateToPendingForTask(URLString)
            return true
        }
    }
    
    internal var isDeletionCancelled: Bool = false
    internal var toDeleteCount: Int = 0
    internal var deletedCount: Int = 0
    internal func resetDeleteHandler(){
        toDeleteCount = 0
        deletedCount = 0
        isDeletionCancelled = false
        deleteCompletionHandler = nil
    }
    internal func deleteTasksWithLocations(_ taskIPs: [(task: String, ip: IndexPath)], keepFile: Bool) -> Dictionary<String, IndexPath>?{
        downloadQueue.isSuspended = true
        
        var deleteInfo: Dictionary<String, IndexPath> = [:]
        let sortedTaskIps = taskIPs.sorted(by: {
            if $0.ip.section > $1.ip.section{
                return true
            }else if $0.ip.section == $1.ip.section{
                if $0.ip.row >= $1.ip.row{
                    return true
                }else{
                    return false
                }
            }else{
                return false
            }
        })
        
        sorter.dmTaskInfoCopy = downloadTaskInfo
        
        toDeleteCount = taskIPs.count
        deletedCount = 0
        for (task, ip) in sortedTaskIps {
            if isDeletionCancelled{
                break
            }
            if deleteTask(task, at: ip, keepFile: keepFile){
                deleteInfo[task] = ip
                deletedCount += 1
                // a memory link in some simulators, use autoreleasepool(invoking: {})
                deleteCompletionHandler?(task, ip, toDeleteCount, deletedCount)
            }
        }
        resetDeleteHandler()
        _downloadTaskSet.subtract(deleteInfo.keys)
        
        downloadQueue.isSuspended = false
        
        if !deleteInfo.isEmpty{
            // dmTaskInfoCopy is emptyed in this method
            sorter.removeTaskSet(Set(deleteInfo.keys))
        }else{
            sorter.dmTaskInfoCopy.removeAll()
        }
        
        return deleteInfo.isEmpty ? nil : deleteInfo
    }
    
    internal func deleteTask(_ URLString: String, at indexPath: IndexPath, keepFile: Bool) -> Bool{
        // .notInList:-1, .pending:0, .downloading:1, .paused:2, stopped:3, .finished:4
        guard let stateRawValue = downloadTaskInfo[URLString]?[TITaskStateIntKey] as? Int else{return false}
        _ = _downloadTaskSet.remove(URLString)
        
        if isTrashOpened{
            switch stateRawValue {
            case 0, 1, 3://.pending, .downloading, .stopped
                downloadOperation(ofTask: URLString)?.stop()
                removeRecordInWaittingTaskQueueForTask(URLString)
            case 2://.paused
                if let op = downloadOperation(ofTask: URLString){
                    op.stop()
                    reduceMaxConcurrentCountAfterResumeOrStopPausedTask()
                }
                removeRecordInWaittingTaskQueueForTask(URLString)
            default:break
            }
            
            sortedURLStringsList[indexPath.section].remove(at: indexPath.row)
            trashList.insert(URLString, at: 0)
            return true
        }else{
            switch stateRawValue {
            case 0, 3://.pending, .stopped:
                downloadOperation(ofTask: URLString)?.cancel()
                if let resumeData = resumeData(ofTask: URLString){
                    // Works even there is no internet.
                    URLSession.shared.downloadTask(withResumeData: resumeData as Data).cancel()
                }
            case 1, 2://.downloading, .paused:
                downloadOperation(ofTask: URLString)?.delete()
            case 4://.finished
                if let fileLocation = fileURL(ofTask: URLString), (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true{
                    if !keepFile{
                        do{
                            try FileManager.default.removeItem(at: fileLocation as URL)
                        }catch{
                            debugNSLog("Can't delete file of %@: %@", URLString, error.localizedDescription)
                            return false
                        }
                    }
                }
            default: return false
            }
            removeInfoOfTask(URLString, at: indexPath)
            return true
        }
    }


    // MARK: Helper Method to Resume Task
    private func resumeTheTask(_ URLString: String, handleConcurrentCount: Bool = false) -> Bool{
        // .notInList:-1, .pending:0, .downloading:1, .paused:2, stopped:3, .finished:4
        guard let stateRawValue = downloadTaskInfo[URLString]?[TITaskStateIntKey] as? Int else{return false}
        switch stateRawValue{
        case 0://.pending
            if downloadOperation(ofTask: URLString) == nil{
                resumePendingTask(URLString)
            }else{
                debugNSLog("Operation for a pending task: %@ is existed, wait for queue to start it.", URLString)
            }
            return true
        case 2://.paused
            if resumePausedTask(URLString) == false{
                debugNSLog("Operation for a paused task is missed: %@. Fix it.", URLString)
                fixOperationMissIssueForTask(URLString)
                _ = resumeTheTask(URLString)
            }else if handleConcurrentCount{
                reduceMaxConcurrentCountAfterResumeOrStopPausedTask()
            }
            return true
        case 3://.stopped
            if downloadOperation(ofTask: URLString) == nil{
                resumeStoppedTask(URLString)
            }else{
                debugNSLog("Operation for a stopped task: %@ is existed, wait for queue to start it.", URLString)
            }
            return true
        default:
            debugNSLog("Task state for \(URLString) is: \(DownloadState(rawValue: stateRawValue)!.description). No need to resume it.")
            return false
        }
    }

    private func resumePendingTask(_ URLString: String){
        let downloadOperation = DownloadOperation(session: downloadSession, URLString: URLString)
        downloadOperation.name = URLString
        downloadOperation.downloadManager = self
        downloadOperation.completionBlock = {[unowned downloadOperation] in
            self.handleCompletionOfOperation(downloadOperation)
        }

        downloadQueue.addOperation(downloadOperation)
    }

    private func resumePausedTask(_ URLString: String) -> Bool{
        if let downloadOperation = downloadOperation(ofTask: URLString){
            downloadOperation.resume()
            return true
        }else{
            return false
        }
    }

    private func resumeStoppedTask(_ URLString: String){
        let downloadOperation: DownloadOperation
        if let resumeData = downloadTaskInfo[URLString]?[TIResumeDataKey] as? Data{
            downloadOperation = DownloadOperation.init(session: downloadSession, URLString: URLString, resumeData: resumeData)
        }else{
            downloadOperation = DownloadOperation.init(session: downloadSession, URLString: URLString)
        }
        downloadOperation.name = URLString
        downloadOperation.downloadManager = self
        downloadOperation.completionBlock = {[unowned downloadOperation] in
            self.handleCompletionOfOperation(downloadOperation)
        }

        downloadQueue.addOperation(downloadOperation)
    }

    // MARK: - Manage To-Delete List
    internal func _cleanupToDeleteTask(at index: Int) -> String?{
        let URLString = trashList[index]
        switch downloadState(ofTask: URLString) {
        case .notInList:return nil
        case .finished:
            if let fileLocation = filePath(ofTask: URLString), FileManager.default.fileExists(atPath: fileLocation){
                do{
                    try FileManager.default.removeItem(atPath: fileLocation)
                }catch{
                    debugNSLog("Can't delete file of %@: %@", URLString, error.localizedDescription)
                    return nil
                }
            }
            thumbnailCacher.removeThumbnailForTask(URLString)
        case .stopped, .pending:
            downloadOperation(ofTask: URLString)?.cancel()
            if let resumeData = resumeData(ofTask: URLString){
                URLSession.shared.downloadTask(withResumeData: resumeData as Data).cancel()
            }
        case  .downloading, .paused: // never executed actually
            downloadOperation(ofTask: URLString)?.delete()
        }
        trashList.remove(at: index)
        _ = removeCustomThumbnailForTask(URLString)
        downloadTaskInfo.removeValue(forKey: URLString)
        return URLString
    }

    /**
     Clean up to-delete tasks in `toDeleteList` and return a Dictionary includes deleted task's
     URL string and its location info.

     - parameter URLStrings: An array of download URL string of task which you want to clean up in `toDeleteList`.

     - returns: A Dictionary includes deleted task info. Key: URL string of deleted task, Value: task
     original location in `toDeleteList` as a `IndexPath` with section 0, it is to be used in 
     UITableView/UICollectionView directly. If no task is deleted, return nil.
     */
    public func cleanupToDeleteTasks(_ URLStrings: [String]) -> Dictionary<String, IndexPath>?{
        guard !URLStrings.isEmpty else{return nil}
        guard !trashList.isEmpty else{return nil}

        let indexes = Set(URLStrings).flatMap({trashList.index(of: $0)}).sorted(by: >)
        guard indexes.isEmpty == false else{return nil}

        toDeleteCount = indexes.count
        deletedCount = 0
        var deletedTaskIps: Dictionary<String, IndexPath> = [:]
        for index in indexes{
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
     Clean up all to-delete tasks in `toDeleteList` and return a Dictionary includes deleted task's
     URL string and its location info..

     - returns: A Dictionary includes cleaned task info. Key: URL string of cleaned task, Value: task
     original location in `toDeleteList` as a `IndexPath` with section 0, it is to be used in
     UITableView/UICollectionView directly. If no task is deleted, return nil.
     */
    public func emptyToDeleteList() -> Dictionary<String, IndexPath>?{
        return cleanupToDeleteTasks(from: 0)
    }

    /**
     Restore to-delete tasks in `toDeleteList` back to `downloadList` and return locations of restored
     deleted tasks in `toDeleteList`.
     
     - parameter URLStrings: An array of download URL string of task which you want to restore in 
     `toDeleteList`. If `sortType == .manual`, restored tasks keeps same orders in this parameter.
     
     - parameter indexPath:  Restore location in `downloadList`. If `sortType != .manual`, this
     paramter is ignored. It's your resposibility to check whether location is valid.

     - returns: Original locations of restored tasks in `toDeleteList`, or nil no task is restored.
     Returned value, `[IndexPath]`, not `[Int]`, is to be used in UITableView/UICollectionView directly.
     */
    public func restoreToDeleteTasks(_ URLStrings: [String], toLocation indexPath: IndexPath = IndexPath(row: 0, section: 0)) -> [IndexPath]?{
        let ordered = _sortType == .manual ? true : false
        guard let validTasks = collectValidTasksIn(URLStrings, comparisonSet: Set(trashList), ordered: ordered) else {return nil}
        let indexs = validTasks.flatMap({trashList.index(of: $0)})
        
        indexs.sorted(by: { $0 > $1 }).forEach({ trashList.remove(at: $0) })
        _downloadTaskSet.formUnion(validTasks)
        if sortType != .manual{
            restoreRecordInPredefinedModeForTasks(URLStrings)
        }else{
            sortedURLStringsList[indexPath.section].insert(contentsOf: validTasks, at: indexPath.row)
        }
        
        return indexs.map({ IndexPath(row: $0, section: 0) })
    }
    
    internal func restoreRecordInPredefinedModeForTasks(_ tasks: [String]){
        sorter.restoreTasks(tasks)
        sortListBy(type: sortType, order: sortOrder)
    }

    /**
     Restore all to-delete tasks in `toDeleteList` back to `downloadList` and return locations of restored deleted
     tasks in `toDeleteList`.
     
     - parameter indexPath: The restore location in `downloadList`. If `sortType != .manual`, this paramter is
     ignored. It's your resposibility to check whether location is valid. The default value is (0, 0).

     - returns: The locations of restored tasks in `toDeleteList`. If no task is restored, return nil.
     Returned value, `[IndexPath]`, not `[Int]`, is to be used in UITableView/UICollectionView directly.
     */
    public func restoreAllToDeleteTasks(toLocation indexPath: IndexPath = IndexPath(row: 0, section: 0)) -> [IndexPath]?{
        return restoreToDeleteTasks(trashList, toLocation: indexPath)
    }

    // MARK: - Hashable
    // http://stackoverflow.com/questions/33319959/nsobject-subclass-in-swift-hash-vs-hashvalue-isequal-vs
    /// The hash value.
    override open var hash: Int{
        return identifier.hash
    }
    
    /// ==
    override open func isEqual(_ object: Any?) -> Bool {
        if let other = object as? SDEDownloadManager {
            return self.identifier == other.identifier
        } else {
            return false
        }
    }

    // MARK: - Interface to update task info.
    /// Reserved key for outer to store file name in meta info. More details in `SDEDownloadManager`'s `fetchMetaInfoHandler`.
    public static let TIFileDisplayNameStringKey: String = "Key.String.FileDisplayName"
    /// Reserved key for outer to store file intro in meta info. More details in `SDEDownloadManager`'s `fetchMetaInfoHandler`.
    public static let TIFileIntroStringKey: String = "Key.String.FileIntro"
    
    lazy var keysCannotDelete: Set<String> = [TIFileNameStringKey, TITaskStateIntKey, TICreateDateKey, TIFileTypeStringKey]
    /**
     Update or add meta info for download task.
     
     - parameter info: Meta info to update. Its value should be [property list type](https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/PropertyList.html#//apple_ref/doc/uid/TP40008195-CH44),
     otherwise it can't be saved. In Swift, all relative primitive value types are compatible, like: String, Data, Date, Bool, 
     all integer types(e.g., Int, Int8, UInt32), all floating-point types(e.g., Float, Double, CGFloat, except for Float80),
     for collectiontypes, Array and Dictionary consist of these primitive value types are OK.
     
     - parameter URLString: The download URL string of the task which you want to update.
     */
    public func updateMetaInfo(_ info: Dictionary<String, Any>, forTask URLString: String){
        guard let _ = downloadTaskInfo[URLString] else {return}
        var filterdInfo = info
        filterdInfo[TICreateDateKey] = nil
        if let newName = (filterdInfo[SDEDownloadManager.TIFileDisplayNameStringKey] ?? filterdInfo[TIFileNameStringKey]) as? String{
            filterdInfo[TIFileNameStringKey] = nil
            filterdInfo[SDEDownloadManager.TIFileDisplayNameStringKey] = nil
            changeDisplayNameOfTask(URLString, to: newName)
        }
        
        for (infoKey, infoValue) in filterdInfo{
            if (infoValue as? String) == TIDeleteValueMark{
                if keysCannotDelete.contains(infoKey) == false{
                    downloadTaskInfo[URLString]?.removeValue(forKey: infoKey)
                }
            }else{
                downloadTaskInfo[URLString]?[infoKey] = infoValue
            }
        }
    }
    
    /// add code here to fetch meta info
    internal func fetchFileMetaInfoForTask(_ URLString: String){
        let fetchURLRequest = NSMutableURLRequest(url: URL(string: URLString)!)
        fetchURLRequest.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: fetchURLRequest as URLRequest, completionHandler: {data, response, error in
            if let statusCode = (response as? HTTPURLResponse)?.statusCode{
                if statusCode >= 200 && statusCode <= 206{
                    var taskInfo: Dictionary<String, Any> = [:]

                    if let MIME = response?.mimeType?.lowercased(), let fileType = self.downloadTaskInfo[URLString]?[TIFileTypeStringKey] as? String, [AudioType, VideoType, OtherType].contains(fileType){
                        taskInfo[TIFileTypeStringKey] = fileTypeForMIME(MIME)
                    }
                    
                    let state = self.downloadState(ofTask: URLString)
                    if (state != .finished && state != .stopped), let fileSize = response?.expectedContentLength {
                        taskInfo[TIFileByteCountInt64Key] = fileSize > 0 ? fileSize : Int64(-1)
                    }

                    if let name = response?.suggestedFilename{
                        if name.contains("."){
                            let components = name.components(separatedBy: ".")
                            if components.count > 1{
                                taskInfo[TIFileExtensionStringKey] = components.last?.lowercased()
                                taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] = components.dropLast().joined(separator: ".")
                            }else{
                                taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] = name
                            }
                        }else{
                            taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] = name
                        }
                    }

                    if taskInfo.isEmpty == false{
                        self.updateMetaInfo(taskInfo, forTask: URLString)
                    }
                }
            }
        }).resume()

        fetchMetaInfoHandler?(URLString)
    }

    /// Delete special info for download task with URLString.
    internal func removePartInfoWithKeys(_ infoKeys: [String], forTask URLString: String){
        if let _ = downloadTaskInfo.index(forKey: URLString){
            infoKeys.forEach({
                downloadTaskInfo[URLString]?[$0] = nil
            })
        }
    }

    internal func removeInfoOfTask(_ URLString: String, at indexPath: IndexPath){
        sortedURLStringsList[indexPath.section].remove(at: indexPath.row)
        removeRecordInWaittingTaskQueueForTask(URLString)
        downloadTaskInfo.removeValue(forKey: URLString)
        downloadTracker.cleanInfoOfTask(URLString)
        thumbnailCacher.removeThumbnailForTask(URLString)
        _ = removeCustomThumbnailForTask(URLString)
    }

    internal func resetStateToPendingForTask(_ URLString: String){
        let taskDescription: String
        let fileSize: Int64 = self.fileByteCount(ofTask: URLString)
        if fileSize != -1{
            taskDescription = "0 KB/" + ByteCountFormatter().string(fromByteCount: fileSize)
        }else{
            taskDescription = "0 KB/" + SDEPlaceHolder
        }

        let info: Dictionary<String, Any> = [TITaskStateIntKey: DownloadState.pending.rawValue,
                                             TIProgressFloatKey: 0.0,
                                             TIDownloadDetailStringKey: taskDescription,
                                             TIResumeDataKey: TIDeleteValueMark,
                                             TIReceivedByteCountInt64Key: TIDeleteValueMark,
                                             TIFileLocationStringKey: TIDeleteValueMark,
                                             ]
        updateMetaInfo(info, forTask: URLString)
        thumbnailCacher.removeThumbnailForTask(URLString)
    }
        
    // MARK: Filter URL String
    func collectNewTasksIn(_ URLStrings: [String], comparisonSet: Set<String>? = nil) -> ([String], [URL])?{
        let newTaskSet = Set(URLStrings).subtracting((comparisonSet ?? Set(downloadTaskInfo.keys)))
        var filteredURLStrings: [String] = []
        var filteredURLs: [URL] = []
        
        for task in URLStrings{
            if !newTaskSet.contains(task){
                continue
            }
            
            // Prevent non-ASCII string only.
            guard let downloadURL = URL(string: task) else{
                debugNSLog("%@ is not a valid URL conform to RFC 1808, or it contains Non-ASCII charater. Use `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` to encode it", task)
                continue
            }
            guard let _ = downloadURL.scheme?.lowercased() else {
                debugNSLog("%@ has no scheme like http or https.", task)
                continue
            }
            
            filteredURLStrings.append(task)
            filteredURLs.append(downloadURL)
        }
        
        return filteredURLStrings.isEmpty ? nil : (filteredURLStrings, filteredURLs)
    }
    
    internal func collectValidTasksIn(_ URLStrings: [String], comparisonSet: Set<String>, ordered: Bool = false) -> [String]?{
        guard !URLStrings.isEmpty else {return nil}
        guard !comparisonSet.isEmpty else {return nil}
        let commonset = Set(URLStrings).intersection(comparisonSet)
        guard !commonset.isEmpty else {return nil}
        
        if ordered{
            if commonset.count == URLStrings.count{
                return URLStrings
            }else{
                var taskSet: Set<String> = []
                let filteredTasks = URLStrings.filter({
                    if commonset.contains($0) && !taskSet.contains($0){
                        taskSet.insert($0)
                        return true
                    }else{
                        return false
                    }
                })
                return filteredTasks.isEmpty ? nil : filteredTasks
            }
        }else{
            return Array(commonset)
        }
    }
    
    // MARK: Notifications
    /// The notification is posted for any interrupted download task in download manager when app is forcely
    /// quited and relanched again. Task's download info is changed, which can be get from `downloadDetail(ofTask:)`.
    ///
    /// Get the only value in notification info, task URL string: `notification.userInfo?["URLString"] as? String`.
    public static let NNRestoreFromAppForceQuit: Notification.Name = Notification.Name(rawValue: "RestoreFromAppForceQuitNotification")
    /// The notification is posted for task which changed display name. Task's display name can be get from `fileDisplayName(ofTask:)`.
    ///
    /// Get the only value in notification info, task URL string: `notification.userInfo?["URLString"] as? String`.
    public static let NNChangeFileDisplayName: Notification.Name = Notification.Name(rawValue: "ChangeFileDisplayNameNotification")
    /// The notification is posted for task whose file is downloaded before download manager begin to track.
    /// Task's download info is changed, which can be get from `downloadDetail(ofTask:)`.
    ///
    /// Get the only value in notification info, task URL string: `notification.userInfo?["URLString"] as? String`.
    public static let NNDownloadIsCompletedBeforeTrack: Notification.Name = Notification.Name(rawValue: "DownloadIsCompletedBeforeTrackNotification")
    /// The notification is posted for task whose downloaded temporary file is processing.
    /// Task's download info is changed, which can be get from `downloadDetail(ofTask:)`.
    ///
    /// Get the only value in notification info, task URL string: `notification.userInfo?["URLString"] as? String`.
    public static let NNTemporaryFileIsProcessing: Notification.Name = Notification.Name(rawValue: "TemporaryFileIsProcessingNotification")
    /// The notification is posted for task whose downloaded temporary file has been processed.
    /// Task's download info is changed, which can be get from `downloadDetail(ofTask:)`.
    ///
    /// Get the only value in notification info, task URL string: `notification.userInfo?["URLString"] as? String`.
    public static let NNTemporaryFileIsProcessed: Notification.Name = Notification.Name(rawValue: "TemporaryFileIsProcessedNotification")

}
