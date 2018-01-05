//
//  FrameworkShare.swift
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

// MARK: Protocol in The Framework
/**
  Handle touch event for button in `DownloadTrackerCell`. `DownloadListController` conforms to the protocol.
  If you want `DownloadListController` to handle touch event for your custom UITableViewCell, implement
  `assignAccessoryButtonDeletegate(_:)` in protocol `DownloadActivityTrackable` and in button's action
  method, send the only protocol method to delegate object.
 */
@objc public protocol AccessoryButtonDelegate {
    /**
     Handle button touch event for UITableViewCell.
     
     - parameter cell:   The UITableViewCell contains touched button.
     - parameter button: The touched button in the cell.
     - parameter controlEvents: The touch event.
     */
    func tableViewCell(_ cell: UITableViewCell, didTouch button: UIButton, for controlEvents: UIControlEvents)
}

/**
  Make UITableViewCell coordinate with `DownloadListController` to:
  
  1. track download activity;
  2. handle button touch event;
  3. update button's title or image.
 
  All properties and methods in the protocol are optional. I have made UITableViewCell conform to this
  protocol in extension and don't implement any property or method.
 */
@objc public protocol DownloadActivityTrackable {
    //optional var fileIdentifier: String {get set}
    //optional func assignFileIdentifier(identifier: String)
    
    // MARK: Track Download Activity
    /**
     Update content of `detailTextLabel`. `DownloadTrackerCell` use it to displays download progress info. 
     This method will be called in necessary place if cell implement this method.
     
     - parameter info: A string describing download detail, e.g., "10 KB/117 MB".
     */
    @objc optional func updateDetailInfo(_ info: String?)
    
    /**
     Update download speed info. `DownloadTrackerCell` add a UILabel at the right of contentView to display
     speed info. This method will be called in necessary place if cell implement this method.
     
     - parameter info: A string describing download speed, e.g., "10 KB/s". If task is not
     downloading any more, this value is nil.
     */
    @objc optional func updateSpeedInfo(_ info: String?)
    
    /**
     Update download progress. `DownloadTrackerCell` add a UIProgressView at bottom of contentView to 
     display progress. This method will be called in necessary place if cell implement this method.
     
     - parameter progress: Usually its range is 0.0...1.0, and it's -1 if progress is unknown.
     */
    @objc optional func updateProgressValue(_ progress: Float)
    
    // MARK: AccessoryButton and Assign Delegate
    /// An optional UIButton. In `DownloadTrackerCell`, it's the assessoryView and used to resume/pause download.
    @objc optional var accessoryButton: UIButton {get}
    
    /**
     Assign delegate object to handle button touch event. If you want `DownloadListController` to handle
     button touch event for your custom UITableViewCell, you should implement this method, and in button
     action method, send message(only method in protocol `AccessoryButtonDelegate`) to its delegate to
     handle touch event. You could look code of`DownloadTrackerCell`, it's easy.
     
     - parameter delegate: A delegate object to handle button touch event.
     */
    @objc optional func assignAccessoryButtonDeletegate(_ delegate: AccessoryButtonDelegate)
    
    // MARK: Update AccessoryButton Appearance
    /**
     Update accessoryButton's enabled and image. In `DownloadListController`, when its
     cellAccessoryButtonStyle == .icon, this method will be called in necessary place if cell implement 
     this method.
     
     - parameter enabled: Enable button or not.
     - parameter image:   Button image.
     */
    @objc optional func updateAccessoryButtonState(_ enabled: Bool, image: UIImage?)

    /**
     Update accessoryButton's enabled and title. In `DownloadListController`, when its
     cellAccessoryButtonStyle == .title, this method will be called in necessary place if cell implement
     this method.
     
     - parameter enabled: Enable button or not.
     - parameter title:   Button title.
     */
    @objc optional func updateAccessoryButtonState(_ enabled: Bool, title: String)
}

// MARK: Extension in The Framework
extension UITableViewCell: DownloadActivityTrackable{}
@objc extension URLSessionTask{
    /// Returns a URL string from original URL request.
    public var originalURLString: String?{
        return originalRequest?.url?.absoluteString
    }
    
    /// Returns a URL string from current URL request.
    public var currentURLString: String?{
        return currentRequest?.url?.absoluteString
    }
}

extension String{
    /// Returns a new string made from original string by replacing all characters not allowed in a query URL component.
    public var percentEncodingURLQueryString: String?{
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}

extension URLSessionTask.State{
    /// State description.
    var description: String{
        switch self {
        case .running:
            return "Running"
        case .suspended:
            return "Suspended"
        case .canceling:
            return "Canceling"
        case .completed:
            return "Completed"
        }
    }
}

extension Array{
    // Array must be sorted already.
    internal mutating func insert(_ newElement: Element, inAscendingOrder: (Element, Element)-> Bool){
        if isEmpty{
            append(newElement)
        }else if count == 1{
            if inAscendingOrder(newElement, first!){
                insert(newElement, at: 0)
            }else{
                append(newElement)
            }
        }else if inAscendingOrder(first!, last!){// Binary search, now just enumerate it
            if inAscendingOrder(newElement, first!){
                insert(newElement, at: 0)
            }else if inAscendingOrder(last!, newElement){
                append(newElement)
            }else{
                
            }
        }else{
            if inAscendingOrder(newElement, first!){
                append(newElement)
            }else if inAscendingOrder(last!, newElement){
                insert(newElement, at: 0)
            }else{
                
            }
        }
    }
}

extension NSMutableArray{
    internal func binaryIndex(of element: String, ascendingComparator: (String, String) -> Bool) -> Int?{
        let index = binaryIndex(for: element, ascendingComparator: ascendingComparator)
        if index >= count{
            return nil
        }
        return self[index] as! String == element ? index : nil
    }
    
    internal func binaryIndex(for element: String, ascendingComparator: (String, String) -> Bool) -> Int{
        var start = 0
        var end = count
        while start < end {
            let middle = start + (end - start) / 2
            if ascendingComparator(self[middle] as! String, element){
                start = middle + 1
            }else{
                end = middle
            }
        }
        return start
    }

    internal func binaryInsert(_ element: String, ascendingComparator: (String, String) -> Bool){
        let index = binaryIndex(for: element, ascendingComparator: ascendingComparator)
        if index == count{
            self.add(element)
        }else if self[index] as! String != element{
            self.insert(element, at: index)
        }
    }
}

// Elements in Array must be sorted in ascending order.
extension Array where Element: Equatable{
    internal func binaryIndex(of element: Element, ascendingComparator: (Element, Element) -> Bool) -> Int?{
        let index = binaryIndex(for: element, ascendingComparator: ascendingComparator)
        if index >= count{
            return nil
        }
        return self[index] == element ? index : nil
    }
    
    internal func binaryIndex(for element: Element, ascendingComparator: (Element, Element) -> Bool) -> Int{
        var start = 0
        var end = count
        while start < end {
            let middle = start + (end - start) / 2
            if ascendingComparator(self[middle], element){
                start = middle + 1
            }else{
                end = middle
            }
        }
        return start
    }
    
    internal mutating func binaryInsert(_ element: Element, ascendingComparator: (Element, Element) -> Bool){
        let index = binaryIndex(for: element, ascendingComparator: ascendingComparator)
        if index == count{
            append(element)
        }else if self[index] != element{
            insert(element, at: index)
        }
    }
}

extension Collection{
    typealias Element = Self.Iterator.Element
    internal func sortedIndex(for element: Element, byOrder: ComparisonOrder, inAscendingOrder: ((Element, Element)-> Bool)? = nil) -> Int?{
        return nil
    }
    
    internal func sortedInsertIndex(for element: Element) -> Int{
        return 0
    }
}

extension Dictionary{
    /// Merge new key-value pairs in other dictionary.
    mutating func merge(_ other: Dictionary<Dictionary.Key, Dictionary.Value>){
        let newKeys = Set(other.keys).subtracting(Set(self.keys))
        guard newKeys.isEmpty == false else{return}
        newKeys.forEach({ newKey in
            updateValue(other[newKey]!, forKey: newKey)
        })
    }
}

// MARK: Enum in The Framework
/**
 There are two sort mode: manual mode(.manual) and predefined mode(the follow latter four types). Task order
 in `downloadList` of `SDEDownloadManager` is determined by `sortType` and `sortOrder` together.
 
 case `manual`:  You determine task location.
 
 case `addTime`: Sorted by time when task is added.
 
 case `fileName`: Sorted by file display name.
 
 case `fileSize`: Sorted by file size.
 
 case `fileType`: Sorted and grouped by file type. 
 */
@objc public enum ComparisonType: Int {
    /// You determine task location.
    case manual = -1
    /// Sorted by time when task is added.
    case addTime = 0
    /// Sorted by file display name.
    case fileName
    /// Sorted by file size.
    case fileSize
    /// Sorted and grouped by file type.
    case fileType
    /// Sort type description.
    public var description: String{
        switch self {
        case .manual:
            return "Manual"
        case .addTime:
            return "AddTime"
        case .fileName:
            return "FileName"
        case .fileSize:
            return "FileSize"
        case .fileType:
            return "FileType"
        }
    }
}

/**
 Task order in the list.
 
 case `ascending`: A -> Z; Old -> New; Small -> Big.
 
 case `descending`: Z -> A; New -> Old; Big -> Small.
 */
@objc public enum ComparisonOrder: Int{
    /// A -> Z; Old -> New; Small -> Big.
    case ascending = 0
    /// Z -> A; New -> Old; Big -> Small.
    case descending
    /// Literal string for enum value.
    public var description: String{
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
}

/**
 The state of download task in `SDEDownloadManager`.
 
 case `notInList`:   The URL which you query is not in the download manager. I set this value
 to make the framework be compatible with Objective-C. Because `Int?` can't be presented in Objective-C.
 
 case `pending`:     Not downloading and it's sure that task has no resume data.
 
 case `downloading`: Downloading.
 
 case `paused`:      Download is paused.
 
 case `stopped`:     Not downloading and it's sure that task has resume data to continue download.
 
 case `finished`:    File is downloaded successfully.
 
 */
@objc public enum DownloadState: Int {
    /// The URL which you query is not in the download manager. I set this value to make the framework
    /// be compatible with Objective-C. Because `Int?` can't be presented in Objective-C.
    case notInList = -1
    /// Not downloading and it's sure that task has no resume data.
    case pending = 0
    /// Downloading.
    case downloading
    /// Download is paused.
    case paused
    /// Not downloading and it's sure that task has resume data to continue download.
    case stopped
    /// File is downloaded successfully.
    case finished
    /// State description.
    public var description: String{
        switch self {
        case .notInList:
            return "The URL is not in 'downloadList' and not in 'toDeleteList'"
        case .pending:
            return "Pending"
        case .paused:
            return "Paused"
        case .downloading:
            return "Executing"
        case .stopped:
            return "Stopped"
        case .finished:
            return "Finished"
        }
    }
}

/**
 Select the content to display in `DownloadListController`.
 
 case `downloadList`: All tasks in `downloadList`, not include tasks in the trash(`toDeleteList`).
 
 case `unfinishedList`: All unfinished tasks, not include tasks in trash. Sorted by add time.
 
 case `toDeleteList`: Tasks in the trash. Sorted by delete time.
 
 case `subsection`: `downloadList` is a two-dimensional String array, select this case to display specified
 part. Property `subsectionIndex` determines which part.
 */
@objc public enum ListContent: Int{
    /// All tasks in `downloadList`, not include tasks in the trash(`toDeleteList`).
    case downloadList
    /// All unfinished tasks, not include tasks in trash. Sorted by add time.
    case unfinishedList
    /// Tasks in the trash. Sorted by delete time.
    case toDeleteList
    /// `downloadList` is a two-dimensional String array, select this case to display specified part.
    /// Property `subsectionIndex` determine which part.
    case subsection
}

/**
 Select how to detele a task in `DownloadListController`.
 
 case `fileAndRecord`: Delete task record and relative file both. If SDEDownloadManager's `isTrashOpened == true`,
 task is moved to the trash.
 
 case `onlyFile`: Only delete relative file, and keep task record.
 
 case `optional`: Offer options: only file or both.
 */
@objc public enum DeleteMode: Int {
    /// Delete task record and relative file both. If SDEDownloadManager's `isTrashOpened == true`, task is moved to the trash.
    case fileAndRecord
    /// Only delete relative file but keep task record.
    case onlyFile
    /// Offer options: only file or both.
    case optional
}

/**
 Appearance style of imageView in UITableViewCell in `DownloadListController`.
 
 case `thumbnail`: Show a thumbnail image at the location of cell's imageView.
 
 case `index`: Show index(begin from 1) at the location of cell's imageView.
 
 case `none`: Hidden cell's imageView.
 */
@objc public enum CellImageViewStyle: Int{
    /// Show a thumbnail image at the location of cell's imageView.
    case thumbnail
    /// Show index location(begin from 1) at the location of cell's imageView.
    case index
    /// Hidden cell's imageView.
    case none
}

/**
 Thumbnail shape of imageView in UITableViewCell in `DownloadListController`.
 
 case `original`: Displayed thumbnail has same width/height ratio with original image.
 
 case `square`: Displayed thumbnail's width/height ratio is 1:1. Sometimes thumbnail is smaller than
 requested, it's still displayed in original scale.
 */
@objc public enum ThumbnailShape: Int{
    /// Displayed thumbnail has same width/height ratio with original image.
    case original
    /// Displayed thumbnail's width/height ratio is 1:1. Sometimes thumbnail is smaller than 
    /// requested, it's still displayed in original scale.
    case square
}

/**
 Appearance style of accessoryView(a button) of `DownloadTrackerCell` in `DownloadListController`.
 If you want your custom UITableViewCell is compatible with this enum type, look property
 `cellAccessoryButtonStyle` of `DownloadListController`.
 
 case `icon`: Accessory button in the cell shows a predefined icon which bind to task state.
 
 case `title`: Accessory button in the cell shows a predefined title which bind to task state.
 
 case `none`: Hidden accessory button in the cell.
 
 case `custom`: Accessory button has no title or image to be visible and touching won't happen anything
 in this style. You could configure button in `DownloadListController` init method, and its closure
 `accessoryButtonTouchHandler`. It's up to you.
 */
@objc public enum AccessoryButtonStyle: Int {
    /// Button in the cell shows a predefined icon which bind to task state.
    case icon = 0
    /// Button in the cell shows a predefined title which bind to task state.
    case title
    /// Hidden accessory button in the cell.
    case none
    /// Accessory button has no title or image to be visible and touching won't happen anything in this
    /// style. You could configure button in `DownloadListController` init method, and its closure
    /// `accessoryButtonTouchHandler`. It's up to you.
    case custom
}

/**
 Appearance style of predefined UIBarButtonItem which are used in property `toolBarActions` and
 `leftNavigationItemActions` in `DownloadListController`.
 
 case `icon`: BarButtonItem shows an icon.
 
 case `title`: BarButtonItem shows a title.
 */
@objc public enum BarButtonAppearanceStyle: Int{
    /// BarButtonItem shows an icon.
    case icon
    /// BarButtonItem shows a title.
    case title
}

/**
 Predefined action for UIBarButtonItem in toolBar of `DownloadListController` by `toolBarActions`.
 For example, `toolBarActions = [.resumeAll, .stopAll]`, toolBar will show two UIBarButtonItem to 
 provide these two features.
 
 case `resumeAll`: Resume all unfinished tasks. It won't be displayed if `displayContent == .toDeleteList`.
 
 case `pauseAll`:  Pause all downloading tasks. It won't be displayed if `displayContent == .toDeleteList`.
 
 case `stopAll`:   Stop all downloading tasks and cancel all waitting tasks. It won't be displayed if
 `displayContent == .toDeleteList`.
 
 case `deleteAll`: Delete all tasks. It won't be displayed if `displayContent == .unfinishedList`.
 */
@objc public enum ToolBarAction: Int{
    /// Resume all unfinished tasks. It won't be displayed if `displayContent == .toDeleteList`.
    case resumeAll
    /// Pause all downloading tasks. It won't be displayed if `displayContent == .toDeleteList`.
    case pauseAll
    /// Stop all downloading tasks and cancel all waitting tasks. It won't be displayed if `displayContent == .toDeleteList`.
    case stopAll
    /// Delete all tasks. It won't be displayed if `displayContent == .unfinishedList`.
    case deleteAll
}

/**
 Predefined action for UIBarButtonItem in `leftBarButtonItems` of navigationItem of `DownloadListController`
 in multiple selection mode, and relative property: `leftNavigationItemActions`. For example,
 `leftNavigationItemActions = [.selectAll, .pauseSelected]`, in DownloadListController's multiple
 selection mode, left navigationItem will show two UIBarButtonItem to provide these two features.
 
 case `selectAll`: Select/Unselect all tasks(all cells).
 
 case `resumeSelected`: Resume resumeable tasks in selected tasks(selected cells). It won't be displayed if
 `displayContent == .toDeleteList`.
 
 case `pauseSelected`:  Pause downloading tasks in selected tasks(selected cells). It won't be displayed if
 `displayContent == .toDeleteList`.
 
 case `stopSelected`:   Stop downloading tasks and cancel waitting tasks in selected tasks(selected cells).
 It won't be displayed if `displayContent == .toDeleteList`, neither if `allowsStop == false`.
 
 case `deleteSelected`: Delete selected tasks(selected cells). It won't be displayed if
 `displayContent == .unfinishedList`, or `allowsDelete == false` in other lists(except for `.toDeleteList`).
 
 case `restoreSelected`: Restore selected deleted tasks back to download list. It is avaiable only if 
 `displayContent == .toDeleteList`.
 */
@objc public enum NavigationBarAction: Int{
    /// Select/Unselect all tasks(all cells).
    case selectAll
    /// Resume resumeable tasks in selected tasks(selected cells). It won't be displayed if 
    /// `displayContent == .toDeleteList`.
    case resumeSelected
    /// Pause downloading tasks in selected tasks(selected cells). It won't be displayed if
    /// `displayContent == .toDeleteList`.
    case pauseSelected
    /// Stop downloading tasks and cancel waitting tasks in selected tasks(selected cells). It won't be
    /// displayed if `displayContent == .toDeleteList`, neither if `allowsStop == false`.
    case stopSelected
    /// Delete selected tasks(selected cells). It won't be displayed if `displayContent == .unfinishedList`,
    /// or `allowsDelete == false` in other lists(except for `.toDeleteList`).
    case deleteSelected
    /// Restore selected deleted tasks back to download list. It is avaiable only if `displayContent == .toDeleteList`.
    case restoreSelected
}


//MARK: Global function
/// In framework's TARGET->Build Setting->Swift Complier - Custom Flags, two ways to enable it:
/// 1. Section: Active Compilation Conditions, add symbol "DEBUG", no "".
/// 2. Section: Other Swift Flags, add symbol "-D DEBUG", no "".
internal func debugNSLog(_ info: String, _ arguments: CVarArg...){
    #if DEBUG
        // NSLog/NSLogv don't support percent-encoding string. Use CVarArgType in Swift: http://stackoverflow.com/questions/37993693/nslog-is-unavailable
        // Even so, can't use like: debugNSLog("\(percent-encodeing-string)"), right usage: debugNSLog("%@", percent-encodeing-string)
        withVaList(arguments) { NSLogv(info, $0) }
    #endif
}

internal func isNotEmptyString(_ string: String) -> Bool{
    let characterSet = Set(string)
    if characterSet.count > 1{
        return true
    }else if characterSet.isEmpty || (characterSet.count == 1 && characterSet.first! == " "){
        return false
    }else{
        return true
    }
}

internal func DMLS(_ key: String, comment: String) -> String{
    return NSLocalizedString(key, tableName: nil, bundle: DownloadManagerBundle, value: key, comment: comment)
}

internal func UserDirectoryPathFor(_ directory: FileManager.SearchPathDirectory) -> String{
    return FileManager.default.urls(for: directory, in: FileManager.SearchPathDomainMask.userDomainMask)[0].path
}

internal func UserDirectoryURLFor(_ directory: FileManager.SearchPathDirectory) -> URL{
    return FileManager.default.urls(for: directory, in: FileManager.SearchPathDomainMask.userDomainMask)[0]
}

internal func fileTypeForExtension(_ fileExtension: String) -> String{
    if imageFileExtensionMajorSet.contains(fileExtension){
        return ImageType
    }else if shareFileExtensionBetweenAudioAndVideoMajorSet.contains(fileExtension){
        return VideoType
    }else if audioFileExtensionMajorSet.contains(fileExtension){
        return AudioType
    }else if videoFileExtensionMajorSet.contains(fileExtension){
        return VideoType
    }else if documentFileExtensionMajorSet.contains(fileExtension){
        return DocumentType
    }else{
        return OtherType
    }
}

//https://en.wikipedia.org/wiki/Media_type
//http://www.file-extensions.org
internal func fileTypeForMIME(_ mimeType: String) -> String{
    for topLevelType in supportedMIMEType{
        if mimeType.lowercased().contains(topLevelType){
            switch topLevelType {
            case "application":
                if mimeType == "application/pdf"{
                    return DocumentType
                }else{
                    return OtherType
                }
            case "audio":
                return AudioType
            case "image":
                return ImageType
            case "text":
                let contentTypes = mimeType.components(separatedBy: "/")
                if contentTypes.count > 1 && documentFileExtensionMajorSet.contains(contentTypes[1]){
                    return DocumentType
                }else{
                    return OtherType
                }
            case "video":
                return VideoType
            default:
                return OtherType
            }
        }
    }
    return OtherType
}

internal func fetchDownloadURLFromResumeData(_ data: Data) -> String?{
    if let plistDic = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)) as? Dictionary<String, Any>{
        return plistDic["NSURLSessionDownloadURL"] as? String
    }
    return nil
}

internal func infoOfResumeData(_ data: Data) -> Dictionary<String, Any>?{
    return (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)) as? Dictionary<String, Any>
}

internal func parseResumeData(_ data: Data){
    if let plistDic = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)) as? Dictionary<String, Any>{
        NSLog("Valid resume data")
        print(Array(plistDic.keys))
        plistDic.forEach({key, value in
            print("\(key): \(type(of: value))")
        })
        
        let resumeDataPath = plistDic["NSURLSessionResumeInfoTempFileName"]
        print("resumeData file name: \(String(describing: resumeDataPath))")
        let downloadURL = plistDic["NSURLSessionDownloadURL"] as? String
        print("download URL: \(downloadURL ?? "None")")
        let receivedCount = plistDic["NSURLSessionResumeBytesReceived"] as? Int64
        let count: Int64 = receivedCount ?? -1
        print("received count: \(count)|\(ByteCountFormatter().string(fromByteCount: count))")
    }
}


// MARK: Keys for Meta Info
let TIDeleteValueMark: String                            = "Key.Delete.Mark"
let TITaskStateIntKey: String                            = "Key.Int.DownloadState"
let TICreateDateKey: String                              = "Key.Date.TaskCreateDate"
let TIModifyDateKey: String                              = "Key.Date.TaskModifyDate"
let TIResumeDataKey: String                              = "Key.Data.ResumeData"
let TIFileNameStringKey: String                          = "Key.String.FileName"
let TIFileTypeStringKey: String                          = "Key.String.FileType"
let TIFileMIMEStringKey: String                          = "Key.String.MIMEType"
let TIFileExtensionStringKey: String                     = "Key.String.FileExtension"
let TIDownloadDetailStringKey: String                    = "Key.String.DownloadDetail"
let TIFileLocationStringKey: String                      = "Key.String.FileLocation"
let TIFileByteCountInt64Key: String                      = "Key.Int64.FileByteCount"
let TIReceivedByteCountInt64Key: String                  = "Key.Int64.DownloadedByteCount"
let TIProgressFloatKey: String                           = "Key.Float.DownloadProgress"

// MARK: Keys for Import and Export Download Data
/// Reserved key for section titles of download list to migrate. Its value should be [String].
internal let MigratingSectionTitlesKey = "MigratingSectionTitles.[String].Key"
/// Reserved key for download list to migrate. Its value should be [[String]].
internal let MigratingDownloadListKey = "MigratingDownloadList.[[String]].Key"
/// Reserved key for info of download task to migrate. Its value should be Dictionary<String, Dictionary<String, Any>>.
internal let MigratingTaskInfoKey = "MigratingTaskInfo.<String, <String, Any>>.Key"
/// Reserved key for ToDelete list to migrate. Its value should be [String].
internal let MigratingToDeleteListKey = "MigratingToDeleteList.[String].Key"

// MARK: Global constant in The Framework
let ZEROSPEED: String = "0 KB/s"
let EMPTYSPEED: Int64 = -1
let UNKNOWNSIZE: Int64 = -1
let SDEPlaceHolder: String = "--"

let DownloadManagerBundle = Bundle(for: SDEDownloadManager.self)
let supportedMIMEType = ["application", "audio", "image", "text", "video"]

let confirmActionTitle = DMLS("Button.Confirm", comment: "Confirm Action")
let cancelActionTitle = DMLS("Button.Cancel", comment: "Cancel Action")

let ImageType = "ImageType"
let AudioType = "AudioType"
let VideoType = "VideoType"
let DocumentType = "DocumentType"
let OtherType = "OtherType"

//https://en.wikipedia.org/wiki/Image_file_formats
let imageFileExtensionMajorSet: Set<String> = ["jpg", "jpeg", "tiff", "tif", "gif", "bmp", "png", "mng", "apng", "svg", "psd"]
//https://en.wikipedia.org/wiki/Audio_file_format
let audioFileExtensionMajorSet: Set<String> = ["3gp", "aa", "aac", "aax", "act", "aiff", "amr", "ape", "au", "awb", "dct", "dss", "dvf", "flac",
                                               "gsm", "iklax", "ivs", "m4a", "m4b", "m4p", "mmf", "mp3", "mpc", "msv",
                                               "ogg", "oga", "mogg", "opus", "ra", "rm", "raw", "sln", "tta", "vox", "wav", "webm", "wma", "wv"]
let musicFileExtensionMajorSet: Set<String> = ["mp3", "vox", "wav", "wma"]
//https://en.wikipedia.org/wiki/Video_file_format
let videoFileExtensionMajorSet: Set<String> = ["webm", "mkv", "flv", "vob", "ogv", "ogg", "drc", "gifv", "mng", "avi", "mov", "qt", "wmv", "yuv",
                                               "rm", "rmvb", "asf", "amv", "mp4", "m4p", "m4v", "mpg", "mp2", "mpeg", "mpe", "mpv",
                                               "m2v", "svi", "3gp", "3g2", "mxf", "roq", "nsv", "f4v", "f4p", "f4a", "f4b"]

let shareFileExtensionBetweenAudioAndVideoMajorSet: Set<String> = ["3gp", "m4p", "ogg", "rm", "webm"]
//https://en.wikipedia.org/wiki/Document_file_format
let documentFileExtensionMajorSet: Set<String> = ["pdf", "txt", "text", "srt", "ass", "rtf", "pages", "key", "numbers", "doc", "docx", "ppt", "pptx",
                                                  "xls", "xlsm", "xlsb", "wpd", "wp", "wp7", "fb2", "odt", "sxw", "epub", "md"]


internal let NSURLErrorDescriptionTable: Dictionary<Int, String> = [
    NSURLErrorUnknown: "Unknown",
    NSURLErrorCancelled: "Cancelled",
    NSURLErrorBadURL: "BadURL",
    NSURLErrorTimedOut: "TimedOut",
    NSURLErrorUnsupportedURL: "UnsupportedURL",
    NSURLErrorCannotFindHost: "CannotFindHost",
    NSURLErrorCannotConnectToHost: "CannotConnectToHost",
    NSURLErrorDataLengthExceedsMaximum: "DataLengthExceedsMaximum",
    NSURLErrorNetworkConnectionLost: "NetworkConnectionLost",
    NSURLErrorDNSLookupFailed: "DNSLookupFailed",
    NSURLErrorHTTPTooManyRedirects: "HTTPTooManyRedirects",
    NSURLErrorResourceUnavailable: "ResourceUnavailable",
    NSURLErrorNotConnectedToInternet: "NotConnectedToInternet",
    NSURLErrorRedirectToNonExistentLocation: "RedirectToNonExistentLocation",
    NSURLErrorBadServerResponse: "BadServerResponse",
    NSURLErrorUserCancelledAuthentication: "UserCancelledAuthentication",
    NSURLErrorUserAuthenticationRequired: "UserAuthenticationRequired",
    NSURLErrorZeroByteResource: "ZeroByteResource",
    NSURLErrorCannotDecodeRawData: "CannotDecodeRawData",
    NSURLErrorCannotDecodeContentData: "CannotDecodeContentData",
    NSURLErrorCannotParseResponse: "CannotParseResponse",
    NSURLErrorInternationalRoamingOff: "InternationalRoamingOff",
    NSURLErrorCallIsActive: "CallIsActive",
    NSURLErrorDataNotAllowed: "DataNotAllowed",
    NSURLErrorRequestBodyStreamExhausted: "RequestBodyStreamExhausted",
    NSURLErrorFileDoesNotExist: "FileDoesNotExist",
    NSURLErrorFileIsDirectory: "FileIsDirectory",
    NSURLErrorNoPermissionsToReadFile: "NoPermissionsToReadFile",
    
    // SSL errors
    NSURLErrorSecureConnectionFailed: "SecureConnectionFailed",
    NSURLErrorServerCertificateHasBadDate: "ServerCertificateHasBadDate",
    NSURLErrorServerCertificateUntrusted: "ServerCertificateUntrusted",
    NSURLErrorServerCertificateHasUnknownRoot: "ServerCertificateHasUnknownRoot",
    NSURLErrorServerCertificateNotYetValid: "ServerCertificateNotYetValid",
    NSURLErrorClientCertificateRejected: "ClientCertificateRejected",
    NSURLErrorClientCertificateRequired: "ClientCertificateRequired",
    NSURLErrorCannotLoadFromNetwork: "CannotLoadFromNetwork",
    
    // Download and file I/O errors
    NSURLErrorCannotCreateFile: "CannotCreateFile",
    NSURLErrorCannotOpenFile: "CannotOpenFile",
    NSURLErrorCannotCloseFile: "CannotCloseFile",
    NSURLErrorCannotWriteToFile: "CannotWriteToFile",
    NSURLErrorCannotRemoveFile: "CannotRemoveFile",
    NSURLErrorCannotMoveFile: "CannotMoveFile",
    NSURLErrorDownloadDecodingFailedMidStream: "DownloadDecodingStoppedMidStream",
    NSURLErrorDownloadDecodingFailedToComplete: "DownloadDecodingStoppedToComplete",
    
    NSURLErrorBackgroundSessionRequiresSharedContainer: "BackgroundSessionRequiresSharedContainer",
    NSURLErrorBackgroundSessionInUseByAnotherProcess: "BackgroundSessionInUseByAnotherProcess",
    NSURLErrorBackgroundSessionWasDisconnected: "BackgroundSessionWasDisconnected",
    
    //NSURLErrorAppTransportSecurityRequiresSecureConnection:
    -1022: "ATS: AppTransportSecurityRequiresSecureConnection",
]

//https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10
internal let HTTPStatusCodeDesriptionTable: Dictionary<Int, String> = [
    // Redirection 3xx
    300: "Multiple Choices",
    301: "Moved Permanently",
    302: "Found",
    303: "See Other",
    304: "Not Modified",
    305: "Use Proxy",
    307: "Temporary Redirect",

    // Client Error
    400: "Bad Request",
    401: "Unauthorized",
    402: "Payment Required",
    403: "Forbidden",
    404: "File Does Not Exist",
    405: "Method Not Allowed",
    406: "Not Acceptable",
    407: "Proxy Authentication Required",
    408: "Request Timeout",
    409: "Conflict",
    410: "Gone",
    411: "Length Required",
    412: "Precondition Stopped",
    413: "Request Entity Too Large",
    414: "Request-URI Too Long",
    415: "Unsupported Media Type",
    416: "Requested Range Not Satisfiable",
    417: "Expectation Stopped",
    
    // Server Error
    500: "Internal Server Error",
    501: "Not Implemented",
    502: "Bad Gateway",
    503: "Service Unavailable",
    504: "Gateway Timeout",
    505: "HTTP Version Not Supported",
]

// not finished
internal let HTTPStatusCodeMappingURLErrorCodeTable: Dictionary<Int, Int> = [
    400: NSURLErrorBadURL,
    404: NSURLErrorFileDoesNotExist,
    
    500: NSURLErrorBadServerResponse,
]
