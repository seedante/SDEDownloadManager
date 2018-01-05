//
//  DownloadListController.swift
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

import UIKit

private let ThumbnailViewTag: Int = 1000
private let IndexLabelTag: Int = 1001
private let InsertButtonTag: Int = 100
private let RemoveButtonTag: Int = 101

/**
 `DownloadListController` is a UITableViewController subclass and is born to coordinate with
 `SDEDownloadManager` to manage download tasks and track download activity.
 
 It has rich custom options:
 
 * You can display the whole download list, or specified part by `displayContent`.
   ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/DownloadListType.png)
 
 * All elements in the default cell `DownloadTrackerCell` are customizable.
 
   Of course, they are predefined and limited. If default cell can't satisfy your needs, you could
   use your custom UITableViewCell. More details in init method:
   `init(downloadManager:tableViewStyle:registerCellClasses:configureCell:)`.
   ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/CellTypeA.png)
  
 * Adjust max download count by `adjustButtonItem`.
   ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/PresentSliderAlertController.png)

 * Sort list by `sortButtonItem`.
   ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/SortListInTwoModes.png)
   ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/Demo.TwoModes.gif)

 * Custom task management features in cell swipe. All features are disabled by default.
   Relative properties: `allowsStop`, `allowsDeletion`, `allowsRedownload`, `allowsRestoration`.
 
 * Support multiple selection. Task management features in multiple selection mode(also edit mode) could be
   customed in `leftNavigationItemActions`. Multiple selection is disabled by default. Two way to
   activate it:
    1. editButtonItem: enable `allowsEditingByEditButtonItem` to display editButtonItem at the right of
       navigationBar, or put editButtonItem on somewhere directly.
    2. long press gesture: enable `allowsEditingByLongPress`.
 
 * Offer management features for all tasks on the toolbar. Disabled by default and enable it by
   `allowsManagingAllTasksOnToolBar`. These features could be customed in `toolBarActions`.
 
 * Predefined UIBarButtonItem has two appearances: title or icon. Relative properties:
   `barButtonAppearanceStyle`, `buttonIconFilled`.
 
 * Provide custom headerView in `headerViewProvider`.
 
 * Custom selection behavior by `didSelectCellHandler` and `didDeselectCellHandler`.
 */
@objcMembers open class DownloadListController: SDETableViewController, AccessoryButtonDelegate, UIPopoverPresentationControllerDelegate{
    // MARK: - Init From storyboard/nib File
    /// If init from storyboard/nib file, reassign `downloadManager` after initialization.
    required public init?(coder aDecoder: NSCoder) {
        self.downloadManager = SDEDownloadManager.placeHolderManager
        super.init(coder: aDecoder)
        self.initFromCoder = true
    }
    
    // MARK: Init Programmatically
    /**
     UITableViewController subclass issue only on iOS 8.x: init a subclass programmatically and you get
     fatal error: use of unimplemented initializer `init(nibName:bundle:)`.
     
     Reproduction condition:
     1. Swift. Objective-C has no the issue, why? A similar issue on stackoverflow: http://stackoverflow.com/a/24036440/4399027
     2. Define a UITableViewController subclass, not only just UITableViewController's direct subclass
     3. Add a designated init method in the subclass.
     
     Solution: implement `init(nibName:bundle:)`(UIViewController's designated init method) in your 
     UITableViewController subclass.
     
     And this bring another issue because of Swift's init integrity: “All of a class’s stored properties—
     including any properties the class inherits from its superclass—must be assigned an initial value 
     during initialization.”
     
     Here is the init chain:
     
     Your custom designated init method
     -> ...
     -> UITableViewController.init(style: UITableViewStyle)
     -> UIViewController.init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?)
     
     You must implement `init(nibName:bundle:)` in your subclass on iOS 8.x because of the above issue and
     you must init all stored properties which has no default value. So these properties will be inited
     twice(a let property also, weird but true): first inited in your custom designated init, then in
     `init(nibName:bundle:)`, so outer input values in your custom designated init method are replaced by
     values in `init(nibName:bundle:)`.
     
     Solution for this issue:
     1. assign initial value to store property again after call super.init(style: UITableViewStyle), like
        in this class.
     2. provide default value for all store properties, so there's no any store property need to inited in
        initializer, then assign wanted value to porperties, like in URLPickerController class.
     
     Because store property is assigned twice at least in your custom designated init method, let property
     is not appropriate. There is one thing that needs to be clarified: in your custom designated init and
     `init(nibName:bundle:)`, like variable property, let property must be assigned a value before calling
     relevant super's designated init method, so a let property is inited twice, no conflict. I know it's
     weird. Of course, after init is finished(calling super's designated init), let property can't be 
     reassigned.
     */
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.downloadManager = SDEDownloadManager.placeHolderManager
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        debugNSLog("\(#function): Init with DownloadManager-\(self.downloadManager.identifier). Only happened on iOS 8 && Swift project.")
    }
    
    /**
     One of designated init method with optional cell configuration closure. In this initializer, tableView
     use `DownloadTrackerCell`, which adds a label to show download speed, a progressView to show download 
     progress and a button to pause/resume download. You can configure cell in parameter `configureCell`.
     If you want to use your custom UITableViewCell subclass, you can use the other designated init method:
     `init(downloadManager:tableViewStyle:registerCellClasses:configureCell:)`.
     
     - parameter downloadManager:  A SDEDownloadManager object.
     - parameter style:            UITableView style. The default value is `.plain`.
     - parameter cellClosure:      The closure to configure cell in `tableView(_:cellForRowAtIndexPath:)`. The default is nil.
     - parameter cell:             A DownloadTrackerCell.
     - parameter indexPath:        Cell location.
     - parameter URLString:        The download URL string at this location.
     */
    public init(downloadManager: SDEDownloadManager,
            tableViewStyle style: UITableViewStyle = .plain,
            configureCell cellClosure: ((_ cell: DownloadTrackerCell, _ indexPath: IndexPath, _ URLString: String) -> Void)? = nil){
        self.downloadManager = downloadManager
        super.init(style: style)
        if ProcessInfo().operatingSystemVersion.majorVersion == 8{
            self.downloadManager = downloadManager
            debugNSLog("Reassign DownloadManager to \(self.downloadManager.identifier). Only happened on iOS 8 && Swift project.")
        }
        cellClassesToRegister.append(DownloadTrackerCell.self)
        if cellClosure != nil{
            func cellConfigurationFuncForTableView(_ tableView: UITableView, at indexPath: IndexPath, URLString: String) -> UITableViewCell{
                let cell = tableView.dequeueReusableCell(withIdentifier: defaultCellIdentifier, for: indexPath) as! DownloadTrackerCell
                cellClosure!(cell, indexPath, URLString)
                return cell
            }
            self.cellConfigurationClosure = cellConfigurationFuncForTableView
        }
    }
    
    /**
     One of designated init method with required cell configuration closure. In this initializer, you must
     specify UITableViewCell class which you want to use in the tableView and configure it. The follow init
     code is equal to the other initializer: `init(downloadManager:tableViewStyle:configureCell:)`:
     
         DownloadListController.init(
             downloadManager: downloadManager,
             tableViewStyle: .plain,
             registerCellClasses: [DownloadTrackerCell.self],
             configureCell: { tableView, indexPath, URLString in
                 return tableView.dequeueReusableCell(withIdentifier: "DownloadTrackerCell", for: indexPath)
         })
     
     If your custom UITableViewCell subclass implement methods in protocol `DownloadActivityTrackable`
     (I make UITableViewCell comform to this protocol in extension already), your custom UITableViewCell is
     compatible with some existed properties, include:
     
     1. `allowsTrackingDownloadDetail`: If your cell implement `updateDetailInfo(_ info: String?)`;
     2. `allowsTrackingProgress`: If your cell implement `updateProgressValue(_ progress: Float)`;
     3. `allowsTrackingSpeed`: If your cell implement `updateSpeedInfo(_ text: String?)`;
     4. `cellAccessoryButtonStyle`: A little long, look detail in `cellAccessoryButtonStyle` document.
     
     - parameter downloadManager:  A SDEDownloadManager object.
     - parameter style:            UITableView style. The default is `.plain`.
     - parameter cellClasses:      Custom UITableViewCell subclasses which you want to use in the
     tableView, for example: `[UITableViewCell.self]`. The registered identifier of cell is class name.
     - parameter cellClosure: The closure to configure cell in `tableView(_:cellForRowAtIndexPath:)`.
     - parameter tableView: The tableView.
     - parameter indexPath: Cell location.
     - parameter URLString: The download URL string at this location.
     */
    public init(downloadManager: SDEDownloadManager,
            tableViewStyle style: UITableViewStyle = .plain,
            registerCellClasses cellClasses: [UITableViewCell.Type],
            configureCell cellClosure: @escaping ((_ tableView: UITableView, _ indexPath: IndexPath, _ URLString: String) -> UITableViewCell)){
        self.downloadManager = downloadManager
        super.init(style: style)
        if ProcessInfo().operatingSystemVersion.majorVersion == 8{
            self.downloadManager = downloadManager
        }
        cellClassesToRegister.append(contentsOf: cellClasses)
        self.cellConfigurationClosure = cellClosure
    }
    
    var cellClassesToRegister: [UITableViewCell.Type] = []
    // MARK: Download Manager
    /// A SDEDownloadManager object to manage download tasks.
    public var downloadManager: SDEDownloadManager{
        didSet{
            if displayContent == .unfinishedList{
                unfinishedTasks = downloadManager.unfinishedList ?? []
            }
        }
    }

    // MARK: -
    // MARK: Custom List Content
    /// A Enum value to select content to display, the whole download list or part. The default value is
    /// `.downloadList`.
    public var displayContent: ListContent = .downloadList

    /// Specify which subsection in download list you want to display. The default value is 0. Works only
    /// when `displayContent == .subsection`.
    lazy public var subsectionIndex: Int = 0
    /**
     A Boolean value that determines whether display header title. The default value is `true`. Note: when
     tableView.style == .plain, subsections can't be distinguished if it doesn't display header title.
     */
    public var shouldDisplaySectionTitle: Bool = true
    
    // MARK: Custom Cell Content: imageView, textLabel, accessoryView
    /// A Boolean value decides to display file name or download url in cell's textLabel. The default value is `true`.
    public var isFileNamePriorThanURL: Bool = true
    /// A Enum value to set content to display in UITableViewCell's imageView. The default value is 
    /// `.thumbnail`. This property is valid no matter what UITableViewCell type you use in this class.
    public var cellImageViewStyle: CellImageViewStyle = .thumbnail
    /// A Enum value to specify thumbnail shape. Works only when `cellImageViewStyle == .thumbnail`. 
    /// The default value is `.original`. If thumbnail is smaller than requested, even this property
    /// is `.square`, thumbnail is still displayed in original scale.
    public var fileThumbnailShape: ThumbnailShape = .original{
        didSet{
            self.downloadManager.cacheOriginalRatioThumbnail = fileThumbnailShape == .original
        }
    }
    /**
     A Enum value to specify appearance of accessory button in DownloadTrackerCell: icon, title, or just
     hidden button. The default value is `.icon`.
     
     - `.icon`:  Accessory button shows an icon which bind to task state and is predefined.
     - `.title`: Accessory button shows a title which bind to task state and is predefined.
     - `.none`:  Hidden accessory button in the cell.
     
     If above styles can't satisfy you, you could custom button totally by setting it to `.custom`:
     
     - `.custom`: Accessory button has no title or image to be visible in this style; touching button
     won't happen anything. It's all up to you.
     
     How to custom DownloadTrackerCell in `.custom` style?
     
     1. custom its title or image in init method parameter `configureCell`;
     2. custom button action in `accessoryButtonTouchHandler`. There is an example in the document of
        `accessoryButtonTouchHandler`.
     
     If you use custom UITableViewCell, not default DownloadTrackerCell, and want to get the same effect
     like DownloadTrackerCell, it's easy:
     
     To be compatible with `.icon` style, your custom UITableViewCell should implement 
     ` updateAccessoryButtonState(_:image:)` in protocol `DownloadActivityTrackable`, this method will
     be called in nececssary place to update accessory button;
     
     To be compatible with `.title` style, your custom UITableViewCell should implement 
     `updateAccessoryButtonState(_:title:)` in protocol `DownloadActivityTrackable`, this method will be
     called in nececssary place to update accessory button;
     
     For `.none` and `custom` style, `DownloadListController` doesn't do anything to accessory button
     of `DownloadTrackerCell`. Of cource, in `.none` style, your custom UITableViewCell should hidden
     button, actually, `DownloadTrackerCell` only display button in `icon` and `.title` style, your custom
     UITableViewCell could do same thing, or do it in init method parameter `configureCell`, it's up to you.
     */
    public var cellAccessoryButtonStyle: AccessoryButtonStyle = .icon{
        didSet{
            DownloadTrackerCell.displayAccessoryButton = cellAccessoryButtonStyle != .none
            if cellAccessoryButtonStyle == .title{
                DownloadTrackerCell.buttonWider = true
            }
        }
    }
    
    /**
     A closure to custom action method of accessory button in the `DownloadTrackerCell`. The default value
     is nil.
     
     If predefined action can't satisfy your needs, you colud set `cellAccessoryButtonStyle = .custom` and
     configure button action in this closure. And when `cellAccessoryButtonStyle == .custom`, you must set
     accessory button's title or image to make it visible, do it in init method parameter `configureCell`.
     
     An example, you want accessory button to show other icon and response as you want, do it like this:
     
     
         let listVC = DownloadListController.init(
                         downloadManager: downloadManager,
                         tableViewStyle: .plain,
                         configureCell: {
                             trackerCell, indexPath, URLString in
                             if /....../{
                                 trackerCell.accessoryButton?.setImage(icon0, for: .normal)
                             }else{
                                 trackerCell.accessoryButton?.setImage(icon1, for: .normal)
                             }
                      })
         listVC.cellAccessoryButtonStyle = .custom
         listVC.accessoryButtonTouchHandler = { tableView, cell, button in
             /* custom button action */
         }
     
     - precondition: `cellAccessoryButtonStyle == .custom`
     */
    public var accessoryButtonTouchHandler: ((_ tableView: UITableView, _ cell: UITableViewCell, _ button: UIButton) -> Void)?
    
    // MARK: Track Download Activity in Cell
    /**
     A Boolean value that determines whether DownloadTrackerCell displays download progress info in
     detailTextLabel. The default value is `true`. If you use custom UITableViewCell, implement
     `updateDetailInfo(_ info: String?)` in protocol `DownloadActivityTrackable` to be compatible with
     this property.
     */
    public var allowsTrackingDownloadDetail: Bool = true
    /**
     A Boolean value that determines whether DownloadTrackerCell displays download speed in a label. The
     default value is `true`. If you use custom UITableViewCell, implement `updateSpeedInfo(_ info:
     String?)` in protocol `DownloadActivityTrackable` to be compatible with this property.
     */
    public var allowsTrackingSpeed: Bool = true
    /**
     A Boolean value that determines whether DownloadTrackerCell displays download progress in a 
     progressView. The default value is `true`. If you use custom UITableViewCell, implement 
     `updateProgressValue(_ progress: Float)` in protocol `DownloadActivityTrackable` to be
     compatible with this property.
     */
    public var allowsTrackingProgress: Bool = true
    
    // MARK: Features in Cell Swipe: Stop, Delete, Redownload, Restore and Rename
    /// A Boolean value that determines whether user can stop downloading task in cell swipe
    /// and multiple selection mode. The default value is `false`.
    lazy public var allowsStop: Bool = false
    /// A Boolean value that determines whether user can delete file in cell swipe and multiple
    /// selection mode. The default value is `false`. Use `deleteMode` to decide how to delete a task.
    lazy public var allowsDeletion: Bool = false
    /// A Enum value to decide how to delete a task, file or record? The defalut value is `.fileAndRecord`.
    public var deleteMode: DeleteMode = .fileAndRecord{
        didSet{
            self.deleteFileOnly = deleteMode == .onlyFile ? true : false
        }
    }
    /// A Boolean value that determines whether user can redownload a file in cell swipe.
    /// The default value is `false`. This feature is just available for finished or stoped task.
    lazy public var allowsRedownload: Bool = false
    /// A Boolean value that determines whether user can restore deleted task in cell swipe and multiple
    /// selection mode. The default value is `false`. Works only when `displayContent == .toDeleteList`.
    lazy public var allowsRestoration: Bool = false
    /// A Boolean value that determines whether user can rename file in cell swipe.
    /// The default value is `false`. This feature is just available for finished or stoped task.
    lazy public var allowsRenamingFile: Bool = false

    // MARK: Custom Button Appearance
    /**
     A Enum value that select the appearance style of the predefined BarButtonItems which are defined in
     `toolBarActions` and `leftNavigationItemActions`, except for editButtonItem.
     The default value is `.title`.
     */
    public var barButtonAppearanceStyle: BarButtonAppearanceStyle = .title
    /// A Boolean value that determines whether use filled icon or not. The default value is `true`.
    lazy public var buttonIconFilled: Bool = true
    
    // MARK: Edit Mode and Multiple Tasks Management
    /// A Boolean value that determines whether display editButtonItem at the right of navigationBar.
    /// The default value is `false`.
    lazy public var allowsEditingByEditButtonItem: Bool = false
    /// A Boolean value that determines whether user can enter edit mode(also multiple selection mode)
    /// by long press. The default value is `false`.
    lazy public var allowsEditingByLongPress: Bool = false
    /// A Boolean value that determines whether exit edit mode(also multiple selection mode) after user
    /// confirm operation. The default value is `false`.
    lazy public var shouldExitEditModeAfterConfirmAction: Bool = false
    /**
     Decide what features to display at the left of navigationBar in edit mode(also multiple selection
     mode). The default value includes all features.
     
     This property is invisible in Objective-C code, use `leftNavigationItemActionRawValues`.
     
     There is a way to filter part features in Objective-C code, e.g., if `allowsDeletion == false`,
     `.deleteSelected` will be filtered. `allowsStop` and `allowsRestoration` also works.
     */
    lazy public var leftNavigationItemActions: [NavigationBarAction] = [.selectAll, .resumeSelected, .pauseSelected, .stopSelected, .deleteSelected, .restoreSelected]
    /**
     Alternate for `leftNavigationItemActions` in Objective-C code.
     */
    public var leftNavigationItemActionRawValues: [Int]?
    /**
     A Boolean value that determines whether display Toolbar with predefined features. The default value
     is `false`. Custom features in `toolBarActions`. This property is ignored and toolbar won't
     be displayed if `displayContent == .toDeleteList`.
     */
    public var allowsManagingAllTasksOnToolBar: Bool = false
    /**
     Predefined features displayed on the Toolbar. The default value include features: ResumeAllTask(), PauseAllTask(),
     StopAllTasks(). This property is ignored if `allowsManagingAllTasksOnToolBar == false`.

     This property is invisible in Objective-C code, use `toolBarActionRawValues`.
     */
    lazy public var toolBarActions: [ToolBarAction] = [.resumeAll, .pauseAll, .stopAll]
    /**
     Alternate for `toolBarActions` in Objective-C code.
     */
    public var toolBarActionRawValues: [Int]?

    // MARK: Edit Section in Manual Sort Mode
    /**
     A Boolean value that determines whether user can edit title of section when long pressing
     on header view. The default value is `false`.
     
     - precondition: `downloadManager.sortType == .manual`.
     */
    lazy public var allowsEditingSectionTitle: Bool = false
    /**
     A Boolean value that determines wherther remove section automatically after all tasks in it are
     gone(moved or deleted). In predefined mode, empty section are removed automatically. The default
     value is `true`.
     
     - precondition: `displayContent == .downloadList && downloadManager.sortType == .manual`.
     */
    lazy public var shouldRemoveEmptySection: Bool = true
    /**
     A Boolean value that determines wherther provide an control at the left of header view to insert an
     empty new section after that section when tableView enter edit mode(also multiple selection mode).
     The default value is `false`.
     
     Note: This property is valid only when enter edit mode by `editButtonItem`, `allowsEditingByEditButtonItem`
     or `allowsEditingByLongPress`.
     
     - precondition: `displayContent == .downloadList && downloadManager.sortType == .manual`.
     */
    lazy public var allowsInsertingSection: Bool = false
    
    // MARK: Closures to Custom Cell Selection
    /// A closure to be executed in UITableView delegate method: `tableView(_:didSelectRowAtIndexPath:)`.
    /// String parameter in closure is download URL string at that location. The default value is nil.
    public var didSelectCellHandler: ((_ tableView: UITableView, _ indexPath: IndexPath, _ URLString: String) -> Void)?
    /// A closure to be executed in UITableView delegate method: `tableView(_:didDeselectRowAtIndexPath:)`.
    /// String parameter in closure is download URL string at that location. The default value is nil.
    public var didDeselectCellHandler: ((_ tableView: UITableView, _ indexPath: IndexPath, _ URLString: String) -> Void)?
    
    // MARK: Closure to Custom HeaderView
    /// A closure to provide header view. The default value is nil. I suggest you use `UITableViewHeaderFooterView`.
    public var headerViewProvider: ((_ tableView: UITableView, _ section: Int) -> UIView?)?
    
    // MARK: Improve Scroll Performance
    /**
     This property is used to optimize scroll performance when any file is downloading. Scroll speed is 
     count of scrolled cell in 1 second. When downloading file, download manager track download activity
     and update cells in DownloadListController. It's no necessary if scroll speed is high. Of course, 
     download activities in cells are updated in other place even scroll speed is high. I suggest that 
     the value is the half value of cell count which screen could have. The default value is 10.
     */
    public var scrollSpeedThresholdForPerformance: Int = 10

    // MARK: Feature BarButtonItem
    /**
     A UIBarButtonItem to display a view to sort the download list. And use `shouldDisplaySortOrderInSortView`
     property to custom sort view. 
     
     You should only use this button item when `displayContent == .downloadList`, or, 
     `displayContent == .subsection` but download manager's sort type is `manual`.
     */
    lazy public var sortButtonItem: UIBarButtonItem = {
        let titleButton = UIBarButtonItem(title: self.sortButtonItemTitle, style: .plain, target: self, action: #selector(sortDownloadList))
        let iconButton = UIBarButtonItem(image: self.sortButtonImage, style: .plain, target: self, action: #selector(sortDownloadList))
        return self.barButtonAppearanceStyle == .title ? titleButton : iconButton
    }()
    /// A Boolean value that decides whether to display sort order options(`.ascending` and `.descending`)
    /// in the sort view. The default value is `true`.
    lazy public var shouldDisplaySortOrderInSortView: Bool = true
    /// A Boolean value that decides whether to offer options for download manager to switch to the other sort 
    /// mode in sort view. The default value is `false`. It works only when `displayContent == .downloadList`.
    public var allowsSwitchingSortMode: Bool = false
    /// A UIBarButtonItem to display a view to adjust max download count.
    public lazy var adjustButtonItem: UIBarButtonItem = {
        let titleButton = UIBarButtonItem(title: self.adjustButtonItemTitle, style: .plain, target: self, action: #selector(adjustMaxDownloadCount))
        let iconButton = UIBarButtonItem(image: self.adjustButtonImage, style: .plain, target: self, action: #selector(adjustMaxDownloadCount))
        return self.barButtonAppearanceStyle == .title ? titleButton : iconButton
    }()

    // MARK: Private Property
    private lazy var unfinishedTasks: [String] = []
    // When tableView enter edit mode, it will ask tableView(_:canEditRowAtIndexPath:) to verify that
    // if the row is editable, I need it return true. And I use this property as flag.
    private var multipleSelectionEnabled: Bool = false
    private lazy var isSubsectionDeleted: Bool = false
    private var longPressGesture =  UILongPressGestureRecognizer()
    private lazy var initFromCoder: Bool = false
    private let defaultCellIdentifier: String = String(describing: DownloadTrackerCell.self)
    private var cellConfigurationClosure: ((_ tableView: UITableView, _ indexPath: IndexPath, _ URLString: String) -> UITableViewCell)?
    private var kvoContext = 0
    private let maxDownloadCountKeyPath = #keyPath(SDEDownloadManager.maxDownloadCount)
    private var isAppearedEver: Bool = false
    private var trackActivityEnabled: Bool {return allowsTrackingDownloadDetail || allowsTrackingSpeed || allowsTrackingProgress}
    
    // MARK: - URLString <-> IndexPath
    /**
     Return the URL string of download task at the location.
    
     - parameter indexPath: The download task location.
     
     - returns: The download URL string of task.
     */
    public func downloadURLString(at indexPath: IndexPath) -> String?{
        switch displayContent {
        case .downloadList:
            return downloadManager[indexPath]
        case .unfinishedList:
            return unfinishedTasks.count > indexPath.row ? unfinishedTasks[indexPath.row] : nil
        case .toDeleteList:
            let toDeleteList = downloadManager.trashList
            return toDeleteList.count > indexPath.row ? toDeleteList[indexPath.row] : nil
        case .subsection:
            return downloadManager[IndexPath(row: indexPath.row, section: subsectionIndex)]
        }
    }

    /**
     Return location of download task based on its URL string.
     
     - parameter URLString: The download URL string of task.
     
     - returns: Task location in current list.
     */
    public func indexPath(forURLString URLString: String) -> IndexPath?{
        switch displayContent {
        case .downloadList:
            return downloadManager[URLString]
        case .unfinishedList:
            if let row = unfinishedTasks.index(of: URLString){
                return IndexPath(row: row, section: 0)
            }else{
                return nil
            }
        case .toDeleteList:
            if let row = downloadManager.toDeleteList?.index(of: URLString){
                return IndexPath(row: row, section: 0)
            }else{
                return nil
            }
        case .subsection:
            if let originalIndexPath = downloadManager.indexPath(ofTask: URLString){
                return IndexPath(row: originalIndexPath.row, section: 0)
            }else{
                return nil
            }
        }
    }
    
    // MARK: Accessory Button Delegate: Handle Touch Event for Button
    /**
     Handle touch event for button in `DownloadTrackerCell`. If you want `DownloadListController` to handle
     touch event for your custom UITableViewCell, implement `assignAccessoryButtonDeletegate(_:)` in 
     protocol `DownloadActivityTrackable` and in button's action method, send this only protocol method to
     delegate object.
     
     - parameter cell: The UITableViewCell.
     - parameter button: The touched button in the cell.
     - parameter controlEvents: The touch event.
     */
    public func tableViewCell(_ cell: UITableViewCell, didTouch button: UIButton, for controlEvents: UIControlEvents){
        if accessoryButtonTouchHandler != nil && cellAccessoryButtonStyle == .custom{
            accessoryButtonTouchHandler!(tableView, cell, button)
            return
        }
        
        guard cellAccessoryButtonStyle != .custom else{return}
        guard let indexPath = tableView.indexPath(for: cell) else{return}
        guard let URLString = downloadURLString(at: indexPath) else{return}
        
        if displayContent != .toDeleteList{
            let state = downloadManager.downloadState(ofTask: URLString)
            
            switch state {
            case .pending, .stopped:
                if downloadManager.resumeTasks([URLString]) != nil{
                    if cellAccessoryButtonStyle == .title{
                        button.setTitle(pauseTitle, for: .normal)
                    }else{
                        button.setImage(pauseIcon, for: .normal)
                    }
                    if trackActivityEnabled{
                        downloadManager.beginTrackingDownloadActivity()
                    }
                }
            case .paused:
                if downloadManager.resumeTasks([URLString]) != nil{
                    if cellAccessoryButtonStyle == .title{
                        button.setTitle(pauseTitle, for: .normal)
                    }else{
                        button.setImage(pauseIcon, for: .normal)
                    }
                    if trackActivityEnabled{
                        downloadManager.beginTrackingDownloadActivity()
                    }
                }else{
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
            case .downloading:
                if downloadManager.pauseTasks([URLString]) != nil{
                    if cellAccessoryButtonStyle == .title{
                        button.setTitle(resumeTitle, for: .normal)
                    }else{
                        button.setImage(resumeIcon, for: .normal)
                    }
                }else{
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
            case .notInList, .finished: break
            }
        }else{
            if let indexPath = tableView.indexPath(for: cell){
                self.present(deleteAlertForTasks([URLString], at: {[indexPath]}), animated: true, completion: nil)
            }
        }
    }
    
    
    // MARK: - Trick with Cell imageView
    var _replacedTask: String?
    var _imageForReplaceIndex: UIImage?
    /**
     Replace index sign with an image. And If any another cell's index sign is replaced already, this method
     restores its original index sign.
     ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/ReplaceIndexWithIcon.png)
     
     - precondition: `cellImageViewStyle == .index`
     
     - parameter indexPath: Cell location.
     - parameter image: Image to replace index sign.
     */
    public func replaceIndexOfCell(at indexPath: IndexPath, withImage image: UIImage){
        guard cellImageViewStyle == .index else{return}
        
        if _replacedTask != nil, let replacedIndexPath = self.indexPath(forURLString: _replacedTask!){
            restoreIndexOfCell(at: replacedIndexPath)
        }
        
        _replacedTask = downloadURLString(at: indexPath)
        _imageForReplaceIndex = image
        
        guard let cell = tableView.cellForRow(at: indexPath) else{return}
        _replaceIndexOfCell(cell, at: indexPath, withImage: image)
    }
    
    /**
     Restore index sign if it's replaced by an image.
     
     - parameter indexPath: Cell location.
     */
    public func restoreIndexOfCell(at indexPath: IndexPath){
        guard cellImageViewStyle == .index else{return}
        guard _replacedTask == downloadURLString(at: indexPath) else {return}
        _replacedTask = nil
        
        guard let cell = tableView.cellForRow(at: indexPath) else{return}
        cell.imageView?.viewWithTag(ThumbnailViewTag)?.removeFromSuperview()
        
        if let indexLabel = cell.imageView?.viewWithTag(IndexLabelTag) as? UILabel{
            indexLabel.text = String(indexPath.row + 1)
        }else{
            addIndexLabelForCell(cell, at: indexPath)
        }
    }
    
    // MARK: - Lifecycle
    /// This method is called after the controller has loaded its view hierarchy into memory.
    /// But when the controller load its view hierarchy? Before it presents or access any view
    /// in the view hierarchy if controller isn't presented yet. Called only once.
    override open func viewDidLoad() {
        super.viewDidLoad()
        // Before view is loaded, access tableView will make tableView to load data.
        // It maybe get wrong in removing empty section, but it can't be prevent accessing
        // tableView from outer before view is loaded.
        cellClassesToRegister.forEach({
            self.tableView.register($0, forCellReuseIdentifier: String(describing: $0))
        })
        longPressGesture.addTarget(self, action: #selector(respondsToLongPressGesture(_:)))
        longPressGesture.minimumPressDuration = 0.3
        longPressGesture.isEnabled = false
        view.addGestureRecognizer(longPressGesture)

        assignDefaultCellConfigurationClosure()
        
        // If forget to add a prototype cell with identifier 'DownloadTrackerCell' in the storyboard/nib
        // file, it will rise a runtime error. And this also override cell in the storyboard/nib file, so
        // it doesn't matter whether add a prototype cell with identifier 'DownloadTrackerCell'.
        // Can't do this in init?(coder aDecoder: NSCoder), otherwise can't load from storyboard normally.
        if initFromCoder{
            self.tableView.register(DownloadTrackerCell.self, forCellReuseIdentifier: self.defaultCellIdentifier)
        }
    }

    /// Called every time the view controller is about to be presented onscreen.
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Before viewDidAppear, tableView has began to create cell
        DownloadTrackerCell.displayProgressInfo = allowsTrackingDownloadDetail
        DownloadTrackerCell.displayProgressView = allowsTrackingProgress
        DownloadTrackerCell.displaySpeedInfo    = allowsTrackingSpeed
        DownloadTrackerCell.displayAccessoryButton = cellAccessoryButtonStyle != .none
        // Issue: after view is appeared, showing toolbar is always animated.
        configureToolbarButtonItems()
        
        if displayContent == .unfinishedList || displayContent == .toDeleteList || (displayContent == .subsection && downloadManager.sortType != .manual){
            sortButtonItem.isEnabled = false
        }
        
        if allowsEditingByEditButtonItem{
            if var rightBarButtonItems = navigationItem.rightBarButtonItems{
                if rightBarButtonItems.contains(editButtonItem) == false{
                    rightBarButtonItems.insert(editButtonItem, at: 0)
                    navigationItem.rightBarButtonItems = rightBarButtonItems
                }
            }else{
                navigationItem.rightBarButtonItem = editButtonItem
            }
        }
    }
    
    lazy var activityView: UIActivityIndicatorView = {
        let _activityView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        _activityView.color = UIColor.blue
        _activityView.center = self.view.center
        return _activityView
    }()
    private func waitForDataLoad(){
        guard !downloadManager._isDataLoaded || displayContent == .unfinishedList else {
            tableView.reloadData()
            return}
        sortButtonItem.isEnabled = false
        view.addSubview(activityView)
        activityView.startAnimating()
        
        DispatchQueue.global().async(execute: {
            while !self.downloadManager._isDataLoaded{}
            if self.displayContent == .unfinishedList{
                self.unfinishedTasks = self.downloadManager.unfinishedList ?? []
            }
            
            DispatchQueue.main.async(execute: {
                self.activityView.removeFromSuperview()
                self.tableView.reloadData()
                if self.displayContent == .downloadList || (self.displayContent == .subsection && self.downloadManager.sortType == .manual){
                    self.sortButtonItem.isEnabled = true
                }
            })
        })
    }

    /// Called every time the view controller is presented onscreen.
    override open func viewDidAppear(_ animated: Bool) {
        waitForDataLoad()

        // cancel cell's swipe state when cancel and return from RestoreTaskController
        tableView.setEditing(false, animated: true)
        longPressGesture.isEnabled = allowsEditingByLongPress || allowsEditingSectionTitle
        configureClosureOfDownloadManager()
    
        if !isAppearedEver{
            isAppearedEver = true
            respondsToDownloadManagerNotification()
            // New KVO API in Swift 4: observe(_:options:changeHandler:) is nice, but there is no way to remove its observer safely before iOS 11.
            // NSKeyValueObservation.invalidate() should do this, in iOS 11, it's no need to call it explicitly, but this method doesn't work before iOS 11.
            downloadManager.addObserver(self, forKeyPath: maxDownloadCountKeyPath, options: [.new, .old], context: &kvoContext)
        }
        
        if trackActivityEnabled && downloadManager.downloadQueue.operationCount > 0{
            if displayContent == .unfinishedList{
                unfinishedTasks = downloadManager.unfinishedList ?? []
            }
            downloadManager.beginTrackingDownloadActivity()
        }
    }
    
    /// Called every time the view disappear from screen.
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        downloadManager.stopTrackingDownloadActivity()
        downloadManager.downloadActivityHandler = nil
        downloadActivityInfo.removeAll()
        if displayContent == .unfinishedList{
            unfinishedTasks.removeAll()
        }
    }
    
    deinit{
        downloadManager.objcDownloadActivityHandler = nil
        downloadManager.downloadActivityHandler = nil
        if isAppearedEver{
            downloadManager.removeObserver(self, forKeyPath: maxDownloadCountKeyPath)
            NotificationCenter.default.removeObserver(self)
        }
        debugNSLog("DownloadListController: \(downloadManager.identifier) deinit")
    }
    
    // MARK: - Display TableViewCell
    /// If this method returns 0, other data source methods won't be called.
    override open func numberOfSections(in tableView: UITableView) -> Int {
        if !downloadManager._isDataLoaded{
            return 0
        }
        switch displayContent {
        case .downloadList: return downloadManager.sectionCount
        case .unfinishedList: return 1//unfinishedList.count > 0 ? 1 : 0
        case .toDeleteList: return 1//downloadManager.toDeleteList.count > 0 ? 1 : 0
        case .subsection:
            if isSubsectionDeleted{
                return 0
            }
            return subsectionIndex < downloadManager.sectionCount ? 1 : 0
        }
    }
    
    /// Emtpy section is called preferentially.
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch displayContent {
        case .downloadList:
            let taskCount = downloadManager.taskCountInSection(section)
            if taskCount == 0 {
                if downloadManager.sortType == .manual && !emptyManualSectionSet.contains(section){
                    emptyManualSectionSet.update(with: section)
                }
            }else if emptyManualSectionSet.isEmpty == false{
                _ = emptyManualSectionSet.remove(section)
            }
            return taskCount
        case .unfinishedList:
            return unfinishedTasks.count
        case .toDeleteList:
            return downloadManager.trashList.count
        case .subsection:
            return downloadManager.taskCountInSection(subsectionIndex)
        }
    }
    
    /// Create a cell before relative row display.
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // If init from storyboard and there is no cell with identifier 'DownloadTrackerCell' in the
        // storyboard file, it will rise a runtime error. It's easy to forget to specify cell class to
        // 'DownloadTrackerCell' also, then displayed cell is just 'UITableViewCell' and features in 
        // 'DownloadTrackerCell' are not avaiable. 
        // A solution: register cell manually after view is loaded.
        // `self.tableView.register(DownloadTrackerCell.self, forCellReuseIdentifier: "DownloadTrackerCell")`
        return cellConfigurationClosure!(tableView, indexPath, downloadURLString(at: indexPath)!)
    }
    
    /// Called every time cell is moved into the screen.
    override open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if tableView.isDecelerating || tableView.isDragging{
            countOfScrolledCellInUnitTime += 1
        }
        updateContentForTableView(tableView, cell: cell, forRowAtIndexPath: indexPath)
    }
    
    // MARK: Display HeaderView
    /// If it returns empty string or nil, there is not header view.
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard shouldDisplaySectionTitle else {return nil}
        switch displayContent {
        case .downloadList: return downloadManager.titleForHeaderInSection(section)
        case .subsection: return downloadManager.titleForHeaderInSection(subsectionIndex)
        case .unfinishedList: return DMLS("HeaderViewTitle.UnfinishedList", comment: "HeaderView Title for Unfinished Tasks")
        case .toDeleteList: return DMLS("HeaderViewTitle.Trash", comment: "HeaderView Title for ToDelete Tasks")
        }
    }

    /// Provide custom header view. If it returns non-nil, tableView(_:titleForHeaderInSection:) is ignored.
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerViewProvider?(tableView, section)
    }
    
    /// Called every time header view is moved into the screen.
    override open func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if displayContent == .downloadList{
            if multipleSelectionEnabled && emptyManualSectionSet.contains(section) {
                if let removeButton = view.viewWithTag(RemoveButtonTag) as? HeaderButton{
                    removeButton.section = section
                }else{
                    if let removeButton = removeButtonQueue.popLast(){
                        removeButton.section = section
                        view.addSubview(removeButton)
                        addConstraintForHeaderButton(removeButton, with: view, toInsert: false)
                    }else{
                        addHeaderButtonForHeaderView(view, at: section, toInsert: false)
                    }
                }
            }else if let removeButton = view.viewWithTag(RemoveButtonTag) as? HeaderButton{
                removeButton.removeFromSuperview()
                removeButtonQueue.append(removeButton)
            }
            
            guard downloadManager.sortType == .manual else {return}
            if allowsInsertingSection && multipleSelectionEnabled{
                addInsertControlForHeaderView(view, at: section)
            }else if let insertButton = view.viewWithTag(InsertButtonTag) as? HeaderButton{
                insertButton.removeFromSuperview()
                insertButtonQueue.append(insertButton)
            }

        }else if displayContent == .toDeleteList{
            // If return a UITableViewHeaderFooterView in `tableView(_:viewForHeaderInSection:)` and want to make textColor is black
            // normally, use its detailTextLabel, not textLabel(textColor is grey). Text color of these two labels can't change in
            // out of this method
            if downloadManager.trashList.isEmpty{
                view.viewWithTag(1000)?.removeFromSuperview()
            }else{
                guard (view.viewWithTag(1000) as? UIButton) == nil else{return}
                let emptyButton = UIButton.init(type: .system)
                emptyButton.tag = 1000
                emptyButton.translatesAutoresizingMaskIntoConstraints = false
                emptyButton.setTitle(DMLS("Button.Empty", comment: "Clean All Deleted Tasks in the Trash"), for: .normal)
                emptyButton.setTitleColor(UIColor.red, for: .normal)
                emptyButton.addTarget(self, action: #selector(emptyTrash), for: .touchUpInside)
                
                view.addSubview(emptyButton)
                let centerYConstraint = NSLayoutConstraint(item: emptyButton, attribute: .centerYWithinMargins, relatedBy: .equal, toItem: view, attribute: .centerYWithinMargins, multiplier: 1, constant: 0)
                let trailingConstraint = NSLayoutConstraint(item: emptyButton, attribute: .trailingMargin , relatedBy: .equal, toItem: view, attribute: .trailingMargin, multiplier: 1, constant: -10)
                let widthConstraint = NSLayoutConstraint(item: emptyButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 50)
                let heightConstraint = NSLayoutConstraint(item: emptyButton, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0)
                NSLayoutConstraint.activate([centerYConstraint, trailingConstraint, widthConstraint, heightConstraint])
            }
        }
    }
    
    // MARK: Display Index Title
    /// Returns strings displayed at right side of tableView. Use UILocalizedIndexedCollation to provide alphabet.
    override open func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard displayContent == .downloadList && downloadManager.sortType == .fileName && downloadManager.indexingFileNameList else {return nil}
        let indexTitles: [String] = UILocalizedIndexedCollation.current().sectionTitles
        return downloadManager.sortOrder == .ascending ? indexTitles : indexTitles.reversed()
    }
    
    /// Returns relative section for index title you touch at right side of tableView. If title has no relative section, return NSNotFound.
    override open func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return downloadManager.sectionTitleList.index(of: title) ?? NSNotFound
    }
    
    // MARK: Allow to Edit Cell by Control and Row Action
    /// Allow to display controls(includes row action) in the cell or not. If return false, no control is displayed.
    override open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // This method is called when cell displayed, or tableView enter editing, or cell swipe.
        // Note: tableView editing and cell swipe cannot coexist.
        //
        // If tableView is not editing and not cell swipe, nothing happen even this method return true;
        //
        // When tableView enter editing, if allowsMultipleSelectionDuringEditing == false, call order:
        // 1. tableView(_:canEditRowAt:) (this method)
        // 2. tableView(_:editingStyleForRowAt:) to show an control at the left
        // 3. tableView(_:canMoveRowAt:) to decide to show a reorder control at the right
        //
        // But if allowsMultipleSelectionDuringEditing == true before tableView enter editing, just 
        // this method is called to allow to show an circle at the left to select cell.
        //
        // In cell swipe, call order:
        // 1. tableView(_:editingStyleForRowAt:) it must return .delete to show row action at the right
        // 2. tableView(_:canEditRowAt:) (this method) allow to show row action or not
        // 3. tableView(_:editActionsForRowAt:) to provide row actions.
        //
        guard multipleSelectionEnabled == false else{
            // To show an circle to select cell at the left of cell, this method must return true.
            return tableView.allowsMultipleSelectionDuringEditing
        }
        
        let state = downloadManager.downloadState(ofTask: downloadURLString(at: indexPath)!)
        
        switch displayContent {
        case .downloadList:
            return allowsDeletion || allowsStop || allowsRedownload || allowsRenamingFile || manualReordering
        case .unfinishedList:
            return allowsStop && (state == .downloading || state == .paused)
        case .toDeleteList:
            return allowsRestoration
        case .subsection:
            // It's not allowed to change file name in other mode for technical reasons
            return allowsStop || allowsRedownload || manualReordering || (allowsRenamingFile && downloadManager._sortType == .manual)
        }
    }

    /// Decide control style at the left of cell if tableView is editing and allowsMultipleSelectionDuringEditing == false.
    override open func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        // .none: prevent all controls at the left and row action in swipe.
        // .insert: insert control at the left
        // .delete: Complex.
        //
        // If this method return .insert or .delete, the follow two delegate methods(if implemented) 
        // handle it:
        // 1. tableView(_:commitEditingStyle:forRowAtIndexPath:) to handle touch on .insert and .delete
        // 2. tableView(_:editActionsForRowAtIndexPath:): only handle .delete, this method havs hight
        //    priority than tableView(_:commitEditingStyle:forRowAtIndexPath:)
        //
        // Cell swipe is disabled when tableView.isEditing == true, but to enable cell swipe, this method
        // must return .delete. And specially, even `tableView(_:editActionsForRowAtIndexPath:)` return nil,
        // a delete row action is showed at the right.
        // 
        // In DownloadListController, make tableView enter editing by editButtonItem or long press
        // return (manualReordering || tableView.isEditing) ? .none : .delete
        return manualReordering ? .none : .delete
    }
    
    // MARK: Display Reorder Control at the Right of Cell
    /// Filter cells to show reorder control at the right if tableView is editing. Reorder control and
    /// other controls at the left could coexist.
    override open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return manualReordering
    }
    
    /// Move cell and update data. This method must be implemented to show a reorder control at the right.
    /// And cell is moved correctly even this method doesn't update underlying data, of course, there will
    /// be an error in the later.
    override open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else{return}
        
        let sourceSectionCleaned: Bool = downloadManager.taskCountInSection(sourceIndexPath.section) == 1
        if displayContent == .downloadList{
            downloadManager.moveTask(at: sourceIndexPath, to: destinationIndexPath)
            _ = emptyManualSectionSet.remove(destinationIndexPath.section)
        }else{// subsection
            let fromIndexPath = IndexPath(row: sourceIndexPath.row, section: subsectionIndex)
            let toIndexPath = IndexPath(row: destinationIndexPath.row, section: subsectionIndex)
            downloadManager.moveTask(at: fromIndexPath, to: toIndexPath)
        }
        
        if sourceSectionCleaned{
            if shouldRemoveEmptySection{
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    // It's strange: if source section has more than 1 cells, everything is Ok; and if only 1 cell,
                    // can't delete source section in this delegate method, otherwise moved cell's content will be same with
                    // first cell in destination section.
                    if self.downloadManager.removeEmptySection(sourceIndexPath.section){
                        // deleteSections(_:with:) woll reload tableView(_:numberOfRowsInSection:) on all remainder sections,
                        // emptyManualSectionSet will be updated totally.
                        self.emptyManualSectionSet.removeAll()
                        tableView.deleteSections(IndexSet(integer: sourceIndexPath.section), with: .left)
                    }
                })
            }else{// Move cell don't call tableView(_:numberOfRowsInSection:)
                emptyManualSectionSet.update(with: sourceIndexPath.section)
            }
        }
        
        guard cellImageViewStyle == .index else{return}
        var indexSet = IndexSet.init()
        if sourceSectionCleaned{
            if sourceIndexPath.section < destinationIndexPath.section{
                indexSet.insert(destinationIndexPath.section - 1)
            }else{
                indexSet.insert(destinationIndexPath.section)
            }
        }else{
            indexSet.insert(sourceIndexPath.section)
            indexSet.insert(destinationIndexPath.section)
        }
    
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            // Can't reload section in this delegate method, otherwise, mix move row and reload will affect this method to recogize
            // row's move. When cellImageViewStyle == .index and sourceSectionCleaned, section to delete and section to reload are 
            // the same, so can't pack two actions in beginUpdates() and endUpdates().
            tableView.reloadSections(indexSet, with: .fade)
        })
    }

    // MARK: Row Action in Left Swipe on Cell
    /// Provide row actions at the right of cell in left swipe. Cell swipe can't be used when tableView is editing.
    override open func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let URLString = self.downloadURLString(at: indexPath) else { return nil }
        let state = downloadManager.downloadState(ofTask: URLString)
        
        switch displayContent {
        case .downloadList, .subsection:
            var availableActions: [UITableViewRowAction] = []
            switch state {
            case .notInList: return nil
            case .pending:
                if allowsDeletion{
                    availableActions.append(deleteActionForRow(at: indexPath))
                }
                if allowsRedownload{
                    availableActions.append(redownloadActionForRow(at: indexPath))
                }
                if allowsRenamingFile{
                    availableActions.append(renameActionForRow(at: indexPath))
                }
            case .downloading, .paused:
                if allowsDeletion{
                    availableActions.append(deleteActionForRow(at: indexPath))
                }
                if allowsStop{
                    availableActions.append(stopActionForRow(at: indexPath))
                }
            case .finished, .stopped:
                if allowsDeletion{
                    availableActions.append(deleteActionForRow(at: indexPath))
                }
                if allowsRedownload{
                    availableActions.append(redownloadActionForRow(at: indexPath))
                }
                if allowsRenamingFile{
                    availableActions.append(renameActionForRow(at: indexPath))
                }
            }
            return availableActions
        case .unfinishedList:
            guard allowsStop else{return nil}
            guard let _ = downloadManager.downloadOperation(ofTask: URLString) else{return nil}
            return [stopActionForRow(at: indexPath)]
        case .toDeleteList:
            return allowsRestoration ? [restoreActionForRow(at: indexPath)] : nil
        }
    }
    
    // MARK: Select And Deselect Action
    /// If tableView.isEditing == false, this method is called after you select a cell if any of
    /// allowsSelection and allowsMultipleSelection is true; If tableView.isEditing == true, this 
    /// method is called after you select a cell if any of allowsSelectionDuringEditing and 
    /// allowsMultipleSelectionDuringEditing is true.
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        editingTableViewDidSelectRowAtIndexPath(indexPath)
        didSelectCellHandler?(tableView, indexPath, downloadURLString(at: indexPath)!)
    }
    
    /// If allowsSelection == true && allowsMultipleSelection == false, this method is called after
    /// you select another cell; if allowsMultipleSelection == true(allowsSelection is ignored), 
    /// this method is called after you touch a selected cell(deselect). If tableView.isEditing == true,
    /// this method has same behaviors with edit version of these two properties: allowsSelectionDuringEditing
    /// and allowsMultipleSelectionDuringEditing.
    override open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        editingTableViewDidDeselectRowAtIndexPath(indexPath)
        didDeselectCellHandler?(tableView, indexPath, downloadURLString(at: indexPath)!)
    }
    
    private var selectedTaskSet: Set<String> = []
    private var selectedTaskIPInfo: Dictionary<String, IndexPath> = [:]
    private var isAllCellsSelected: Bool = false
    
    private func collectionSelectionInfo(at indexPath: IndexPath, task: String){
        selectedTaskSet.insert(task)
        if displayContent == .subsection{
            if subsectionIndex == 0{
                selectedTaskIPInfo[task] = indexPath
            }else{
                selectedTaskIPInfo[task] = IndexPath.init(row: indexPath.row, section: subsectionIndex)
            }
        }else{
            selectedTaskIPInfo[task] = indexPath
        }
    }
    
    private func removeSelectionInfo(about tasks: [String]){
        selectedTaskSet.subtract(tasks)
        Set(tasks).forEach({ selectedTaskIPInfo[$0] = nil })
    }
    
    private func cleanupSelectionInfo(){
        selectedTaskSet.removeAll()
        selectedTaskIPInfo.removeAll()
    }
    
    /**
     Select the specified row in edit mode(multiple selection mode). You should only set `editButtonItem`
     or `allowsEditingByLongPress` to make tableView editting.

     - parameter indexPath: Selected location in tableView.
     */
    func editingTableViewDidSelectRowAtIndexPath(_ indexPath: IndexPath){
        guard tableView.isEditing else {return}
        guard let URLString = downloadURLString(at: indexPath) else {return}
        
        collectionSelectionInfo(at: indexPath, task: URLString)
        
        let contrastSet: Set<String>
        switch displayContent {
        case .downloadList:
            contrastSet = downloadManager._downloadTaskSet
        case .unfinishedList:
            contrastSet = Set(unfinishedTasks)
        case .toDeleteList:
            contrastSet = Set(downloadManager.trashList)
        case .subsection:
            contrastSet = Set(downloadManager.sortedURLStringsList[subsectionIndex])
        }
        
        if selectedTaskSet == contrastSet{
            isAllCellsSelected = true
            if barButtonAppearanceStyle == .title{
                selectButtonItem.title = unselectAllTitle
            }else{
                selectButtonItem.image = selectedImage
            }
        }
        
        updateNavigationBarButtonItems()

    }
    
    /**
     Deselect the specified row in edit mode(multiple selection mode). You should only set `editButtonItem`
     or `allowsEditingByLongPress` to make tableView editting.

     - parameter indexPath: Deselected location in tableView.
     */
    func editingTableViewDidDeselectRowAtIndexPath(_ indexPath: IndexPath){
        guard tableView.isEditing else {return}
        isAllCellsSelected = false
        guard let URLString = downloadURLString(at: indexPath) else {return}
        if barButtonAppearanceStyle == .title{
            selectButtonItem.title = selectAllTitle
        }else{
            selectButtonItem.image = unselectedImage
        }
        
        removeSelectionInfo(about: [URLString])
        updateNavigationBarButtonItems()
    }

    // MARK: UIScrollView Delegate
    /// tableView did end scrolling.
    override open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        countOfScrolledCellInUnitTime = 0
    }
    
    // MARK: NSKeyValueObserving Protocol
    /// Responds to KVO event.
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // when downloadManager.maxDownloadCount change, and waitting list has no task, so no task start to download,
        // here need to update accessory button manually.
        if self.cellAccessoryButtonStyle != .none && downloadManager.didExecutingTasksChanged == false{
            DispatchQueue.main.async(execute: {
                self.updateEnableOfAccessoryButtonOfNonExecutingTasks()
            })
        }
        
//        #if DEBUG
//            let title: String = downloadManager.maxDownloadCount == -1 ? "∞" : String(downloadManager.maxDownloadCount)
//            DispatchQueue.main.async(execute: {
//                self.navigationItem.title = "Max: " + title
//            })
//        #endif
    }
    
    // MARK: Popover Presentation
    /// Configure popover presentation. Return .none to prevent fullScreen in popover
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    // MARK: - Default Configuration
    private func configureToolbarButtonItems(){
        if allowsManagingAllTasksOnToolBar && displayContent != .toDeleteList{
            self.setToolbarItems(toolbarButtonItems, animated: false)
            self.navigationController?.setToolbarHidden(false, animated: false)
        }
    }
    
    private func respondsToDownloadManagerNotification(){
        addObserverToNotificationName(SDEDownloadManager.NNRestoreFromAppForceQuit)
        addObserverToNotificationName(SDEDownloadManager.NNChangeFileDisplayName)
        addObserverToNotificationName(SDEDownloadManager.NNDownloadIsCompletedBeforeTrack)
        addObserverToNotificationName(SDEDownloadManager.NNTemporaryFileIsProcessing)
        addObserverToNotificationName(SDEDownloadManager.NNTemporaryFileIsProcessed)
    }
    
    private func addObserverToNotificationName(_ notificationName: NSNotification.Name){
        // Why here [weak self], not [unowned self]? Sometimes here get a issue on iOS 8.1:
        // __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ and _swift_abortRetainUnowned,
        // maybe it's a bug. 
        // A discussion: http://stackoverflow.com/questions/24177973/why-self-is-deallocated-when-calling-unowned-self
        NotificationCenter.default.addObserver(forName: notificationName, object: downloadManager, queue: nil, using: {
            [weak self]
            notification in
            
            // name tip: 
            // If you need to give a constant or variable the same name as a reserved Swift keyword, surround the keyword with backticks (`) 
            // when using it as a name. However, avoid using keywords as names unless you have absolutely no choice. 
            // - The Swift Programming Language Guide: The Basics
            if  let `self` = self, let URLString = notification.userInfo?["URLString"] as? String
                //This method is not enough to judge that the new inserted cell is onscreen
            //  let cell = 'self`.tableView.cellForRowAtIndexPath(indexPath)
                // work with fileIdentifier to identify cell at indexpath is which we need.
            //  where (cell as DownloadActivityTrackable).fileIdentifier == URLString
            {
                // Location in download list
                guard let indexPath =  (notification.userInfo?["IndexPath"] as? IndexPath) ?? `self`.indexPath(forURLString: URLString) else{
                    return
                }
                
                let tv = `self`.tableView!
                DispatchQueue.main.async(execute: {
                    switch self.displayContent{
                    case .downloadList:
                        tv.reloadRows(at: [indexPath], with: .fade)
                    case .subsection:
                        if indexPath.section == self.subsectionIndex{
                            let localIP = IndexPath.init(row: indexPath.row, section: 0)
                            tv.reloadRows(at: [localIP], with: .fade)
                        }
                    default: break
                    }
                    let dm = self.downloadManager
                    // Move cell after change its display name
                    if notificationName == SDEDownloadManager.NNChangeFileDisplayName && dm.sortType != .manual{
                        let newIP = notification.userInfo?["NewIndexPath"] as? IndexPath
                        let newSectionTitle = notification.userInfo?["NewSectionTitle"] as? String
                        
                        if newSectionTitle != nil{
                            // update data source first
                            dm.sectionTitleList.insert(newSectionTitle!, at: newIP!.section)
                            dm.sortedURLStringsList.insert([URLString], at: newIP!.section)
                            let changeSection = indexPath.section >= newIP!.section ? indexPath.section + 1 : indexPath.section
                            dm.sortedURLStringsList[changeSection].remove(at: indexPath.row)
                            let sourceSectionCleaned: Bool = dm.sortedURLStringsList[changeSection].isEmpty
                            // data source is changed, but cell/section location in tableView are not yet.
                            let insertSection: Int
                            if sourceSectionCleaned{
                                dm.sortedURLStringsList.remove(at: changeSection)
                                dm.sectionTitleList.remove(at: changeSection)
                                insertSection = newIP!.section > indexPath.section ? newIP!.section - 1 : newIP!.section
                            }else{
                                insertSection = newIP!.section
                            }

                            // if don't use beginUpdates()/endUpdates(), animations for delete and insert together are
                            // ugly. tableView.beginUpdates()/endUpdates() block handle delete first, even insert
                            // operation code is before it.
                            tv.beginUpdates()
                            switch self.displayContent{
                            case .downloadList:
                                tv.insertSections(IndexSet(integer: insertSection), with: .left)
                                if sourceSectionCleaned{
                                    tv.deleteSections(IndexSet(integer: indexPath.section), with: .left)
                                }else{
                                    tv.deleteRows(at: [indexPath], with: .left)
                                }
                            default: break
                            }

                            tv.endUpdates()
                        }else if newIP != nil{ // move between existed sections
                            dm.sortedURLStringsList[indexPath.section].remove(at: indexPath.row)
                            dm.sortedURLStringsList[newIP!.section].insert(URLString, at: newIP!.row)
                            let sourceSectionCleaned = dm.sortedURLStringsList[indexPath.section].isEmpty
                            if sourceSectionCleaned{
                                dm.sortedURLStringsList.remove(at: indexPath.section)
                                dm.sectionTitleList.remove(at: indexPath.section)
                            }

                            if self.displayContent == .downloadList{
                                tv.beginUpdates()
                                if sourceSectionCleaned{
                                    // can't mix move row and delete section
                                    tv.deleteSections(IndexSet(integer: indexPath.section), with: .left)
                                    let insertSection = newIP!.section > indexPath.section ? newIP!.section - 1 : newIP!.section
                                    tv.insertRows(at: [IndexPath.init(row: newIP!.row, section: insertSection)], with: .left)
                                }else{
                                    tv.moveRow(at: indexPath, to: newIP!)
                                }
                                tv.endUpdates()
                            }                            
                        }
                    }
                })
            }
        })

    }

    
    private func assignDefaultCellConfigurationClosure(){
        guard cellConfigurationClosure == nil else{return}
        cellConfigurationClosure = {[unowned self] tableView, indexPath, URLString in
            return tableView.dequeueReusableCell(withIdentifier: self.defaultCellIdentifier, for: indexPath)
        }
    }
    
    // MARK: Enable/Disable AccessoryButton
    private func updateEnableOfAccessoryButtonOfNonExecutingTasks(){
        guard let visibleIndexPaths = self.tableView.indexPathsForVisibleRows else{return}
        let enabled = !self.downloadManager.didReachMaxDownloadCount
        for indexPath in visibleIndexPaths{
            guard let URLString = self.downloadURLString(at: indexPath) else{continue}
            switch self.downloadManager.downloadState(ofTask: URLString){
            case .finished, .downloading, .notInList: break
            case .paused, .pending, .stopped:
                guard let cell = self.tableView.cellForRow(at: indexPath) else{continue}
                (cell as DownloadActivityTrackable).accessoryButton?.isEnabled = enabled
            }
        }
    }
    
    // MARK: Update Cell Content
    private func updateContentForTableView(_ tableView: UITableView, cell: UITableViewCell,forRowAtIndexPath indexPath: IndexPath){
        guard let URLString = downloadURLString(at: indexPath) else{
            debugNSLog("can't find URL at \(indexPath)")
            return
        }
        
        cell.contentView.clipsToBounds = true
        let downloadActivityCell = cell as DownloadActivityTrackable
        downloadActivityCell.assignAccessoryButtonDeletegate?(self)
        
        let displayName: String? = isFileNamePriorThanURL ? downloadManager.fileDisplayName(ofTask: URLString) : URLString
        cell.textLabel?.text = displayName
        //delete line
        //cell.textLabel?.attributedText = NSAttributedString.init(string: displayName!, attributes:
        //    [NSStrikethroughStyleAttributeName: 2, NSStrikethroughColorAttributeName: UIColor.grayColor()])

        let state = downloadManager.downloadState(ofTask: URLString)
        if allowsTrackingDownloadDetail{
            // If session finish all tasks when app is in the background, app is lanched in the background, NSTimer is not active when
            // app is in the background, so processTracker won't get right info from NSURLSessionTask until app enter foreground, 
            // whatever download mananger store right info at the moment, so just fetch info from download manager, not process tracker.
            let progressInfo: String
            if let fileDetail = downloadManager.downloadDetail(ofTask: URLString){
                progressInfo = fileDetail
            }else if let (receivedBytes, expectedBytes, _, detailInfo) = downloadActivityInfo[URLString]{
                progressInfo = detailInfo == nil ? self.detailFormatStringFor(URLString, receivedBytes, expectedBytes) : detailInfo!
            }else if let op = downloadManager.downloadOperation(ofTask: URLString), let sessionTask = op.downloadTask{
                // downloadOperation(ofTask:) maybe is a performance bottleneck
                let received = formatter.string(fromByteCount: sessionTask.countOfBytesReceived)
                let expected = formatter.string(fromByteCount: sessionTask.countOfBytesExpectedToReceive)
                progressInfo = "\(received)/\(expected)"
            }else{
                progressInfo = SDEPlaceHolder
            }
            
            downloadActivityCell.updateDetailInfo?(progressInfo)
        }

        if state == .downloading && allowsTrackingSpeed{
            let speedString: String?
            if let speed = downloadActivityInfo[URLString]?.speed{
                speedString = speedFormatString(forSpeedvalue: speed)
            }else{
                speedString = nil
            }
            downloadActivityCell.updateSpeedInfo?(speedString)
        }else{
            downloadActivityCell.updateSpeedInfo?(nil)
        }
        
        if allowsTrackingProgress{
            switch state {
            case .finished:
                downloadActivityCell.updateProgressValue?(1)
            case .pending:
                downloadActivityCell.updateProgressValue?(0)
            case .stopped:
                downloadActivityCell.updateProgressValue?(downloadManager.downloadProgress(ofTask: URLString))
            case .downloading, .paused:
                let progress: Float
                if let expectedBytes = downloadActivityInfo[URLString]?.expectedBytes, expectedBytes > 0{
                    progress = Float(downloadActivityInfo[URLString]!.receivedBytes) / Float(downloadActivityInfo[URLString]!.expectedBytes)
                }else{
                    progress = downloadManager.downloadProgress(ofTask: URLString)
                }
                downloadActivityCell.updateProgressValue?(progress)
            case .notInList: break
            }
        }
        
        switch cellAccessoryButtonStyle {
        case .none, .custom: break
        case .title:
            let enabled = accessoryButtonIsEnabledForTask(URLString, taskState: state, useCacheResult: true)
            let title = accessoryButtonTitle(forURLString: URLString, taskState: state)
            downloadActivityCell.updateAccessoryButtonState?(enabled, title: title)
            if displayContent == .toDeleteList{
                downloadActivityCell.accessoryButton?.setTitleColor(UIColor.red, for: .normal)
            }
        case .icon:
            let enabled = accessoryButtonIsEnabledForTask(URLString, taskState: state, useCacheResult: true)
            let iconImage = accessoryButtonIcon(forURLString: URLString, taskState: state)
            downloadActivityCell.updateAccessoryButtonState?(enabled, image: iconImage)
            if displayContent == .toDeleteList{
                downloadActivityCell.accessoryButton?.tintColor = UIColor.red
            }
        }
        
        switch cellImageViewStyle {
        case .none: break
        case .thumbnail:
            updateThumbnailForCell(cell, at: indexPath, task: URLString)
        case .index:
            updateIndexSymbolForCell(cell, at: indexPath, task: URLString)
        }
        
        if tableView.isEditing{
            if selectedTaskSet.contains(URLString){
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }else{
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    private func speedFormatString(forSpeedvalue speedValue: Int64) -> String?{
        let speed: String?
        if speedValue == EMPTYSPEED{
            speed = nil
        }else if speedValue == 0{
            speed = ZEROSPEED
        }else if speedValue > 0{
            speed = formatter.string(fromByteCount: speedValue) + "/s"
        }else{
            speed = SDEPlaceHolder
        }
        return speed
    }
    
    private func detailFormatStringFor(_ URLString: String, _ receivedBytes: Int64, _ expectedBytes: Int64) -> String{
        let receivedBytesFormatString: String = receivedBytes > 0 ? formatter.string(fromByteCount: receivedBytes) : SDEPlaceHolder
        
        var expectedBytesFormatString: String
        if expectedBytes > 0{
            expectedBytesFormatString = formatter.string(fromByteCount: expectedBytes)
        }else if let fileSize = downloadManager.downloadTaskInfo[URLString]?[TIFileByteCountInt64Key] as? Int64, fileSize > 0{
            expectedBytesFormatString = formatter.string(fromByteCount: fileSize)
        }else{
            expectedBytesFormatString = SDEPlaceHolder
        }
        
        return receivedBytesFormatString + "/" + expectedBytesFormatString
    }

    private lazy var clearBackgroundImage: UIImage = {
        let rowHeight = self.tableView.rowHeight
        let height = rowHeight > 44 ? rowHeight - 8 : 36
        UIGraphicsBeginImageContextWithOptions(CGSize(width: height, height: height), false, UIScreen.main.scale)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }()
    
    private func updateThumbnailForCell(_ cell: UITableViewCell, at indexPath: IndexPath, task: String){
        let height: CGFloat = CGFloat(Int(cell.contentView.bounds.size.height) - 8)
        let thumbnailImage: UIImage? = downloadManager.requestThumbnail(forTask: task, targetHeight: height, orLaterProvidedInHandler: {[weak self]
            thumbnail in

            // Sometimes it can't get the cell before viewDidAppear().
            // indexPath here maybe not task's original location
            DispatchQueue.main.async(execute: {
                if let cell = self?.tableView.cellForRow(at: indexPath){
                    let thumbnailView = cell.imageView?.viewWithTag(ThumbnailViewTag) as? UIImageView
                    thumbnailView?.image = thumbnail
                }else{
                    // The second chance to update thumbnail
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        if let cell = self?.tableView.cellForRow(at: indexPath){
                            let thumbnailView = cell.imageView?.viewWithTag(ThumbnailViewTag) as? UIImageView
                            thumbnailView?.image = thumbnail
                        }
                    })
                }
            })
        })
        
        // A UIImageView is opaque only when its content is opaque, properties like `opaque` and
        // `backgroundColor` don't affect it. An interesting discussion:
        // https://twitter.com/marcoarment/status/420041560185913344?lang=en
        // if you use a PNG image, UIImageView will always be not opaque.
        // If necessary, you could redraw the PNG Image in opaque core graphics contex and set a apaque 
        // background color. But if cell's background color is not single, redraw is not good way.
    
        // cell's imageView's size is determined by image size, and its location is determined by
        // UITableViewCell's layoutsSubviews(). Setting frame directly won't work as you want; layout
        // constraint has a little problem also.
        cell.imageView?.image = clearBackgroundImage
        
        if let imageView = cell.imageView?.viewWithTag(ThumbnailViewTag) as? UIImageView{
            imageView.image = thumbnailImage
        }else{
            addThumbnailViewForCell(cell, at: indexPath, withThumbnail: thumbnailImage).contentMode = .center
        }
    }
    
    private func addThumbnailViewForCell(_ cell: UITableViewCell, at indexPath: IndexPath, withThumbnail image: UIImage?) -> UIImageView{
        let thumbnailView = UIImageView(image: image)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.tag = ThumbnailViewTag
        thumbnailView.clipsToBounds = true
        cell.imageView?.addSubview(thumbnailView)
        
        NSLayoutConstraint(item: thumbnailView, attribute: .centerX, relatedBy: .equal, toItem: cell.imageView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: thumbnailView, attribute: .centerY, relatedBy: .equal, toItem: cell.imageView, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: thumbnailView, attribute: .width,  relatedBy: .equal, toItem: cell.contentView, attribute: .height, multiplier: 1, constant: -8).isActive = true
        NSLayoutConstraint(item: thumbnailView, attribute: .height, relatedBy: .equal, toItem: cell.contentView, attribute: .height, multiplier: 1, constant: -8).isActive = true
        
        return thumbnailView
    }

    private func updateIndexSymbolForCell(_ cell: UITableViewCell, at indexPath: IndexPath, task: String){
        // cell's imageView's size is determined by image size, and its location is determined by UITableViewCell's layoutsSubviews().
        // Setting frame directly won't work as you want, layout constraint, has a little problem.
        cell.imageView?.image = clearBackgroundImage
        
        if task == _replacedTask{
            if let image = _imageForReplaceIndex{
                _replaceIndexOfCell(cell, at: indexPath, withImage: image)
                return
            }
        }
        
        if _replacedTask != nil{
            cell.imageView?.viewWithTag(ThumbnailViewTag)?.removeFromSuperview()
        }
        if let indexLabel = cell.imageView?.viewWithTag(IndexLabelTag) as? UILabel{
            indexLabel.text = String(indexPath.row + 1)
        }else{
            addIndexLabelForCell(cell, at: indexPath)
        }
    }
    
    private func addIndexLabelForCell(_ cell: UITableViewCell, at indexPath: IndexPath){
        let indexLabel = UILabel()
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.textAlignment = .center
        indexLabel.text = String(indexPath.row + 1)
        indexLabel.backgroundColor = cell.backgroundColor
        indexLabel.isOpaque = true
        indexLabel.tag = IndexLabelTag
        
        cell.imageView?.addSubview(indexLabel)
        
        let height: CGFloat = clearBackgroundImage.size.height
        NSLayoutConstraint(item: indexLabel, attribute: .centerX, relatedBy: .equal, toItem: cell.imageView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: indexLabel, attribute: .centerY, relatedBy: .equal, toItem: cell.imageView, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: indexLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: height).isActive = true
        NSLayoutConstraint(item: indexLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: height).isActive = true
    }

    
    private func _replaceIndexOfCell(_ cell: UITableViewCell, at indexPath: IndexPath, withImage image: UIImage){
        (cell.imageView?.viewWithTag(IndexLabelTag) as? UILabel)?.text = nil
        
        if let thumbnailView = cell.imageView?.viewWithTag(ThumbnailViewTag) as? UIImageView{
            thumbnailView.image = image
        }else{
            let thumbnailView = addThumbnailViewForCell(cell, at: indexPath, withThumbnail: image)
            // Layout constraints doesn't work here.
            let thumbnailViewSize = CGSize(width: cell.contentView.frame.height - 8, height: cell.contentView.frame.height - 8)
            if image.size.height > thumbnailViewSize.height || image.size.width > thumbnailViewSize.width{
                thumbnailView.contentMode = .scaleAspectFit
            }else{
                thumbnailView.contentMode = .center
            }
        }
    }

    private func accessoryButtonIsEnabledForTask(_ URLString: String, taskState: DownloadState, useCacheResult: Bool = false) -> Bool{
        let enabled: Bool
        
        if displayContent != .toDeleteList{
            switch taskState {
            case .notInList, .finished:
                enabled = false
            case .downloading:
                if downloadManager.isReallyExecuting(ofTask: URLString){
                    enabled = true
                }else{
                    fallthrough
                }
            case .paused, .stopped, .pending:
                if useCacheResult && !didReachMaxDownloadCountCached{
                    didReachMaxDownloadCount = downloadManager.didReachMaxDownloadCount
                    didReachMaxDownloadCountCached = true
                }
                enabled = useCacheResult ? !didReachMaxDownloadCount : !downloadManager.didReachMaxDownloadCount
            }
        }else{
            enabled = true
        }
        
        return enabled
    }
    
    private func accessoryButtonTitle(forURLString URLString: String, taskState: DownloadState) -> String{
        let title: String
        
        if displayContent == .toDeleteList{
            return deleteTitle
        }
        
        switch taskState {
        case .notInList:
            title = DMLS("NotInList", comment: "URL is not in the download list")
        case .pending:
            title = startTitle
        case .downloading:
            if downloadManager.isReallyExecuting(ofTask: URLString){
                title = pauseTitle
            }else{
                title = resumeTitle
            }
        case .paused:
            title = resumeTitle
        case .finished:
            title = finishedTitle
        case .stopped:
            title = resumeTitle
        }
        
        return title
    }
    
    private func accessoryButtonIcon(forURLString URLString: String, taskState: DownloadState) -> UIImage?{
        var iconImage: UIImage?
        
        if displayContent == .toDeleteList{
            return smashIcon
        }
        
        switch taskState {
        case .notInList:
            iconImage = nil
        case .pending:
            iconImage = startIcon
        case .downloading:
            if downloadManager.isReallyExecuting(ofTask: URLString){
                iconImage = pauseIcon
            }else{
                iconImage = resumeIcon
            }
        case .paused:
            iconImage = resumeIcon
        case .finished:
            iconImage = finishedIcon
        case .stopped:
            iconImage = resumeIcon
        }
        
        return iconImage
    }

    
    // MARK: - Track Download Progress
    private func configureClosureOfDownloadManager(){
        // In my watch, refresh less than 20 cells need less than 10 ms, total process is less than 20 ms
        downloadManager.downloadActivityHandler = {[unowned self] activityInfo in
            self.updateCellsWithDownloadActivityInfo(activityInfo)
        }
        
        downloadManager.downloadCompletionHandler = { [unowned self] in
            self.downloadActivityInfo.removeAll()
            guard self.downloadManager.fixOperationMissedIssues() else {return}
            guard let visibleIndexPaths = self.tableView.indexPathsForVisibleRows else {return}
            DispatchQueue.main.async(execute: {
                self.tableView.reloadRows(at: visibleIndexPaths, with: .fade)
            })
        }
    }
    
    private var didReachMaxDownloadCount: Bool = false
    private var didReachMaxDownloadCountCached: Bool = false
    private var countOfScrolledCellInUnitTime: Int = 0
    lazy var formatter = ByteCountFormatter()
    lazy private var downloadActivityInfo: Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, speed: Int64, detailInfo: String?)> = [:]
    
    func updateCellsWithDownloadActivityInfo(_ info: Dictionary<String, (receivedBytes: Int64, expectedBytes: Int64, speed: Int64, detailInfo: String?)>){
        let previousDownloadActivityInfo = downloadActivityInfo
        downloadActivityInfo = info
        let scrollSpeed = countOfScrolledCellInUnitTime
        countOfScrolledCellInUnitTime = 0
        
        let dm = self.downloadManager
        let finishedTasks = Array(info.keys.filter({ info[$0]!.speed == EMPTYSPEED && dm.downloadState(ofTask: $0) == .finished }))
        
        // Remove finished tasks in .unfinishedList
        if displayContent == .unfinishedList && !finishedTasks.isEmpty{
            finishedTasks.forEach({ downloadActivityInfo[$0] = nil })
            let finishedIPs = finishedTasks.flatMap({ unfinishedTasks.index(of: $0) }).sorted(by: >).map({ IndexPath(row: $0, section: 0) })
            removeSelectionInfo(about: finishedTasks)
            DispatchQueue.main.async(execute: {
                finishedIPs.forEach({
                    if let rawCell = self.tableView.cellForRow(at: $0){
                        let cell = rawCell as DownloadActivityTrackable
                        if self.allowsTrackingSpeed{
                            cell.updateSpeedInfo?(nil)
                        }
                        
                        if self.allowsTrackingProgress{
                            cell.updateProgressValue?(1)
                        }
                        
                        if self.allowsTrackingDownloadDetail{
                            let task = self.unfinishedTasks[$0.row]
                            let detail = info[task]!.detailInfo
                            cell.updateDetailInfo?(detail)
                        }
                    }
                })
                finishedIPs.forEach({ self.unfinishedTasks.remove(at: $0.row) })
                self.tableView.deleteRows(at: finishedIPs, with: .fade)
            })
        }

        guard scrollSpeed < scrollSpeedThresholdForPerformance else {
            didReachMaxDownloadCountCached = false
            return
        }
        
        DispatchQueue.main.async(execute: {
            guard let visibleIndexPaths = self.tableView.indexPathsForVisibleRows else {return}
            let toUpdateTasks: Set<String> = Set(self.downloadActivityInfo.keys)
            var visibleToUpdateIPTasks: [(IndexPath, String)] = []
            visibleIndexPaths.forEach({
                if let URLString = self.downloadURLString(at: $0), toUpdateTasks.contains(URLString){
                    visibleToUpdateIPTasks.append(($0, URLString))
                }
            })
            
            if visibleToUpdateIPTasks.isEmpty == false{
                let finishedTaskSet: Set<String>? = self.cellImageViewStyle == .thumbnail ? Set(finishedTasks) : nil
                var finishedIPs: [IndexPath] = []
                
                visibleToUpdateIPTasks.forEach({ indexPath, URLString in
                    if finishedTaskSet?.contains(URLString) == true{
                        finishedIPs.append(indexPath)
                    }else if let rawCell = self.tableView.cellForRow(at: indexPath), let (receivedBytes, expectedBytes, speed, detailInfo) = info[URLString]{
                        let cell = rawCell as DownloadActivityTrackable
                        if self.allowsTrackingDownloadDetail{
                            let progressInfo: String = detailInfo == nil ? self.detailFormatStringFor(URLString, receivedBytes, expectedBytes) : detailInfo!
                            cell.updateDetailInfo?(progressInfo)
                        }
                        
                        if self.allowsTrackingSpeed{
                            let speedFormatString: String? = self.speedFormatString(forSpeedvalue: speed)
                            cell.updateSpeedInfo?(speedFormatString)
                        }
                        
                        if self.allowsTrackingProgress{
                            let progress = expectedBytes > 0 ? Float(receivedBytes) / Float(expectedBytes) : 0
                            cell.updateProgressValue?(progress)
                        }
                        
                        // if task is paused/stopped/finished || resume agagin || download the first time, cell need to update accessory button state
                        if speed == EMPTYSPEED || previousDownloadActivityInfo[URLString]?.speed == EMPTYSPEED || previousDownloadActivityInfo[URLString] == nil {
                            switch self.cellAccessoryButtonStyle {
                            case .title, .icon:
                                let state = self.downloadManager.downloadState(ofTask: URLString)
                                let enabled = self.accessoryButtonIsEnabledForTask(URLString, taskState: state, useCacheResult: true)
                                if self.cellAccessoryButtonStyle == .title{
                                    let title = self.accessoryButtonTitle(forURLString: URLString, taskState: state)
                                    cell.updateAccessoryButtonState?(enabled, title: title)
                                }else{
                                    let iconImage = self.accessoryButtonIcon(forURLString: URLString, taskState: state)
                                    cell.updateAccessoryButtonState?(enabled, image: iconImage)
                                }
                            case .none, .custom: break
                            }
                        }
                    }
                })
                if finishedIPs.isEmpty == false{
                    self.tableView.reloadRows(at: finishedIPs, with: .fade)
                }
            }
            
            if self.downloadManager.didExecutingTasksChanged{
                self.didReachMaxDownloadCountCached = false
                // Update Non-Executing task
                if self.cellAccessoryButtonStyle == .icon || self.cellAccessoryButtonStyle == .title{
                    self.updateEnableOfAccessoryButtonOfNonExecutingTasks()
                }
            }
        })
    }
    
    
    // MARK: - Table View Row Action
    private func stopActionForRow(at indexPath: IndexPath) -> UITableViewRowAction{
        let stopRowAction = UITableViewRowAction(style: .default, title: stopTitle, handler: {_,_ in
            self.tableView.setEditing(false, animated: true)
            if let URLString = self.downloadURLString(at: indexPath){
                _ = self.downloadManager.stopTasks([URLString])
            }
        })
        stopRowAction.backgroundColor = UIColor.orange
        return stopRowAction
    }

    private func deleteActionForRow(at indexPath: IndexPath) -> UITableViewRowAction{
        // If don't set UITableViewRowAction's backgroundColor, its backgroundColor with style:
        // case .default: red
        // case .normal: grey
        // case .destructive: red
        let deleteRowAction = UITableViewRowAction(style: .destructive, title: deleteTitle, handler: {_,_ in
            let URLString = self.downloadURLString(at: indexPath)!
            self.present(self.deleteAlertForTasks([URLString], at: {[indexPath]}, cancelHandler:{
                self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
            }), animated: true, completion: {
                self.tableView.setEditing(false, animated: true)
                // cell.selectionStyle can't be .none
                self.tableView.cellForRow(at: indexPath)?.setHighlighted(true, animated: true)
            })
        })
        
        return deleteRowAction
    }
    
    private func redownloadActionForRow(at indexPath: IndexPath) -> UITableViewRowAction{
        let restartRowAction = UITableViewRowAction(style: .default, title: restartTitle, handler: {_,_ in
            let URLString = self.downloadURLString(at: indexPath)!
            let alert = UIAlertController(title: DMLS("Redownload the File?", comment: "Alert Title: Restart Task"),
                message: self.downloadManager.completedDisplayNameOfTask(URLString)!,
                preferredStyle: .alert)
    
            let confirmAlertAction = UIAlertAction(title: self.restartTitle, style: .destructive, handler: { _ in
                _ = self.downloadManager.restartTasks([URLString])
                self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
                self.tableView.reloadRows(at: [indexPath], with: .none)
                if self.trackActivityEnabled{
                    self.downloadManager.beginTrackingDownloadActivity()
                }
            })
            
            let cancelAlertAction = UIAlertAction(title: cancelActionTitle, style: .cancel, handler: { _ in
                self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
            })
            
            alert.addAction(cancelAlertAction)
            alert.addAction(confirmAlertAction)
            
            self.present(alert, animated: true, completion: {
                self.tableView.setEditing(false, animated: true)
                self.tableView.cellForRow(at: indexPath)?.setHighlighted(true, animated: true)
            })
            
        })
        restartRowAction.backgroundColor = UIColor.orange
        return restartRowAction
    }
    
    private func restoreActionForRow(at indexPath: IndexPath) -> UITableViewRowAction{
        let URLString = self.downloadURLString(at: indexPath)!
        
        func justDeleteRowAt(_ indexPath: IndexPath){
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            self.updateCellIndexMark()
        }
        
        func restoreRowAt(_ indexPath: IndexPath){
            if downloadManager.sortType == .manual{
                let restoreVC = RestoreTaskController.init(downloadManager: downloadManager, restoreHandler: { restoreLocation in
                    if let _ = self.downloadManager.restoreToDeleteTasks(at: [indexPath.row], toLocation: restoreLocation){
                        justDeleteRowAt(indexPath)
                    }
                })
                if let nv = self.navigationController{
                    nv.pushViewController(restoreVC, animated: true)
                }else{
                    self.present(restoreVC, animated: true, completion: nil)
                }
            }else{
                let restoreAlert: UIAlertController = UIAlertController(title: DMLS("Restore to Original Location?",
                                                                                    comment: "Alert Title: ToDelete Task Restoration"),
                                                                        message: nil, preferredStyle: .alert)
                restoreAlert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: {_ in
                    self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
                }))
                restoreAlert.addAction(UIAlertAction(title: restoreTitle, style: .destructive, handler: {_ in
                    if let _ = self.downloadManager.restoreToDeleteTasks(at: [indexPath.row]){
                        justDeleteRowAt(indexPath)
                    }
                }))
                
                self.present(restoreAlert, animated: true, completion: { [unowned self] in
                    self.tableView.setEditing(false, animated: true)
                    self.tableView.cellForRow(at: indexPath)?.setHighlighted(true, animated: true)
                })
            }
        }
        
        
        let restoreAction = UITableViewRowAction(style: .normal, title: restoreTitle, handler: {_,_ in
            restoreRowAt(indexPath)
        })
        restoreAction.backgroundColor = view.tintColor
        return restoreAction
    }
    
    private func renameActionForRow(at indexPath: IndexPath) -> UITableViewRowAction{
        let editNameRowAction: UITableViewRowAction = UITableViewRowAction(style: .default, title: renameTitle, handler: {_,_ in
            self.changeDisplayNameForTask(at: indexPath)
        })
        editNameRowAction.backgroundColor = view.tintColor
        return editNameRowAction
    }

    // MARK: - Multiple Selection Mode
    /// UIBarButtonItems to use at the left of NavigationItem in edit mode(multiple selection mode). 
    /// There are some predefined UIBarButtonItems. More details in `leftNavigationItemActions`.
    internal lazy var leftButtonItemsInEditMode: [UIBarButtonItem]? = {
        if let actions = self.leftNavigationItemActionRawValues?.flatMap({NavigationBarAction(rawValue: $0)}), actions.isEmpty == false{
            return self.generateButtomItemBasedOnNavigationBarActions(actions)
        }
        return self.generateButtomItemBasedOnNavigationBarActions(self.leftNavigationItemActions)
    }()
    
    private func generateButtomItemBasedOnNavigationBarActions(_ actions: [NavigationBarAction]) -> [UIBarButtonItem]{
        var items: [UIBarButtonItem] = []
        actions.forEach({ buttonAction in
            switch buttonAction{
            case .selectAll:
                if items.contains(selectButtonItem) == false{
                    items.append(selectButtonItem)
                }
            case .resumeSelected:
                if displayContent != .toDeleteList && items.contains(resumeButtonItem) == false{
                    items.append(resumeButtonItem)
                }
            case .pauseSelected:
                if displayContent != .toDeleteList && items.contains(pauseButtonItem) == false{
                    items.append(pauseButtonItem)
                }
            case .stopSelected:
                if allowsStop && displayContent != .toDeleteList && items.contains(stopButtonItem) == false{
                    items.append(stopButtonItem)
                }
            case .deleteSelected:
                if (allowsDeletion && displayContent != .unfinishedList) || displayContent == .toDeleteList{
                    if items.contains(deleteButtonItem) == false{
                        items.append(deleteButtonItem)
                    }
                }
            case .restoreSelected:
                if allowsRestoration && displayContent == .toDeleteList && items.contains(restoreButtonItem) == false{
                    items.append(restoreButtonItem)
                }
            }
        })
        return items
    }
    
    /// UIBarButtonItems to use in the toolbar.
    internal lazy var toolbarButtonItems: [UIBarButtonItem]? = {
        if let actions = self.toolBarActionRawValues?.flatMap({ToolBarAction(rawValue: $0)}), actions.isEmpty == false{
            return self.generateButtonItemBaseOnToolBarActions(actions)
        }
        return self.generateButtonItemBaseOnToolBarActions(self.toolBarActions)
    }()
    
    private func generateButtonItemBaseOnToolBarActions(_ actions: [ToolBarAction]) -> [UIBarButtonItem]{
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        var items: [UIBarButtonItem] = []//[flexibleSpace]
        actions.forEach({ buttonAction in
            switch buttonAction{
            case .resumeAll:
                if items.contains(resumeAllButtonItem) == false{
                    items.append(resumeAllButtonItem)
                    items.append(flexibleSpace)
                }
            case .pauseAll:
                if items.contains(pauseAllButtonItem) == false{
                    items.append(pauseAllButtonItem)
                    items.append(flexibleSpace)
                }
            case .stopAll:
                if items.contains(stopAllButtonItem) == false{
                    items.append(stopAllButtonItem)
                    items.append(flexibleSpace)
                }
            case .deleteAll:
                if displayContent != .unfinishedList && items.contains(deleteAllButtonItem) == false{
                    items.append(deleteAllButtonItem)
                    items.append(flexibleSpace)
                }
            }
            
        })
        if actions.count == 1{
            items.insert(flexibleSpace, at: 0)
        }else{
            items.removeLast()
        }
        return items
    }
    
    override func activateMultiSelectionMode(){
        multipleSelectionEnabled = true
        // tableView enter editing, it will ask tableView(_:canEditRowAt:) and tableView(_:canMoveRowAt:) to display controls.
        super.activateMultiSelectionMode()
        resetNavigatonBarButtonItems()
        
        navigationController?.setToolbarHidden(true, animated: true)
        navigationItem.setLeftBarButtonItems(leftButtonItemsInEditMode, animated: true)
        navigationItem.title = nil
        
        addEditControlForVisibleSections()
    }
    
    override func exitMultiSelectionMode(){
        DispatchQueue.global().async(execute: {
            self.downloadManager.saveData()
        })

        super.exitMultiSelectionMode()
        multipleSelectionEnabled = false
        cleanupSelectionInfo()
        isAllCellsSelected = false
        resetNavigatonBarButtonItems()
        manualReordering = false
        longPressGesture.isEnabled = allowsEditingByLongPress || allowsEditingSectionTitle
        if allowsManagingAllTasksOnToolBar && displayContent != .toDeleteList{
            self.setToolbarItems(toolbarButtonItems, animated: true)
            navigationController?.setToolbarHidden(false, animated: true)
        }
        
        removeEditControlForVisibleSections()
    }
    
    @objc private func respondsToLongPressGesture(_ gesture: UILongPressGestureRecognizer){
        guard manualReordering == false else{return}
        switch gesture.state {
        case .began:
            if allowsEditingSectionTitle, downloadManager.sortType == .manual,
                displayContent == .downloadList || displayContent == .subsection
                {
                    if let indexPaths = tableView.indexPathsForVisibleRows{
                        let visibleSection: Set<Int> = Set(indexPaths.map({ $0.section }))
                        for section in visibleSection{
                            if tableView.rectForHeader(inSection: section).contains(gesture.location(in: tableView)){
                                let targetSection = displayContent == .downloadList ? section : subsectionIndex
                                changeTitleOfSection(targetSection)
                                return
                            }
                        }
                    }
                        
                    if emptyManualSectionSet.isEmpty == false{
                        for section in emptyManualSectionSet{
                            if tableView.rectForHeader(inSection: section).contains(gesture.location(in: tableView)){
                                let targetSection = displayContent == .downloadList ? section : subsectionIndex
                                changeTitleOfSection(targetSection)
                                return
                            }
                        }
                    }
                }
            
            if allowsEditingByLongPress{
                if !tableView.isEditing{
                    activateMultiSelectionMode()
                }else{
                    exitMultiSelectionMode()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - NavigationBar ButtonItem Configuration
    lazy var selectButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.selectAllTitle, style: .plain, target: self, action: #selector(selectOrUnselectAllTasks)) :
                                                         UIBarButtonItem.init(image: self.unselectedImage, style: .plain, target: self, action: #selector(selectOrUnselectAllTasks))
    }()
    lazy var resumeButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.resumeTitle, style: .plain, target: self, action: #selector(resumeSelectedTasks)) :
                                                         UIBarButtonItem.init(image: self.resumeIcon, style: .plain, target: self, action: #selector(resumeSelectedTasks))
    }()
    lazy var pauseButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.pauseTitle, style: .plain, target: self, action: #selector(pauseSelectedTasks)) :
                                                         UIBarButtonItem.init(image: self.pauseIcon, style: .plain, target: self, action: #selector(pauseSelectedTasks))
    }()
    lazy var stopButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.stopTitle, style: .plain, target: self, action: #selector(stopSelectedTasks)) :
                                                         UIBarButtonItem.init(image: self.stopIcon, style: .plain, target: self, action: #selector(stopSelectedTasks))
    }()
    
    
    lazy var deleteButtonItem: UIBarButtonItem = {
        let buttonItem: UIBarButtonItem
        if self.barButtonAppearanceStyle == .title{
            buttonItem = UIBarButtonItem.init(title: self.deleteTitle, style: .plain, target: self, action: #selector(deleteSelectedTasks))
        }else{
            if self.displayContent == .toDeleteList{
                buttonItem = UIBarButtonItem.init(image: self.smashIcon, style: .plain, target: self, action: #selector(deleteSelectedTasks))
            }else{
                buttonItem = UIBarButtonItem.init(image: self.deleteIcon, style: .plain, target: self, action: #selector(deleteSelectedTasks))
            }
        }
        buttonItem.tintColor = UIColor.red
        return buttonItem
    }()
    
    lazy var restoreButtonItem: UIBarButtonItem = {
        let buttonItem: UIBarButtonItem = self.barButtonAppearanceStyle == .title ?
            UIBarButtonItem.init(title: self.restoreTitle, style: .plain, target: self, action: #selector(restoreSelectedTasks)) :
            UIBarButtonItem.init(image: self.restoreIcon, style: .plain, target: self, action: #selector(restoreSelectedTasks))
        return buttonItem
    }()
    
    // MARK: NavigationBar ButtonItem Action Method
    @objc private func selectOrUnselectAllTasks(){
        // Don't use cell.selected = true/false to select/unselect a cell, otherwise 
        // tableView(_:didSelectRowAtIndexPath:)/tableView(_:didDeselectRowAtIndexPath:) won't work.
        if isAllCellsSelected{
            tableView.indexPathsForVisibleRows?.forEach({
                tableView.deselectRow(at: $0, animated: true)
            })
            if barButtonAppearanceStyle == .title{
                selectButtonItem.title = selectAllTitle
            }else{
                selectButtonItem.image = unselectedImage
            }
            cleanupSelectionInfo()
        }else{
            tableView.indexPathsForVisibleRows?.forEach({
                tableView.selectRow(at: $0, animated: true, scrollPosition: .none)
            })
            if barButtonAppearanceStyle == .title{
                selectButtonItem.title = unselectAllTitle
            }else{
                selectButtonItem.image = selectedImage
            }
            switch displayContent {
            case .downloadList:
                selectedTaskSet.formUnion(downloadManager._downloadTaskSet)
            case .unfinishedList:
                selectedTaskSet.formUnion(Set(unfinishedTasks))
            case .toDeleteList:
                selectedTaskSet.formUnion(Set(downloadManager.trashList))
            case .subsection:
                selectedTaskSet.formUnion(Set(downloadManager.sortedURLStringsList[subsectionIndex]))
            }
            
        }
        isAllCellsSelected = !isAllCellsSelected
        updateNavigationBarButtonItems()
    }
    
    @objc private func resumeSelectedTasks(){
        let alertTitle: String = selectedTaskSet.count == 1 ?
            DMLS("Resume the Task?", comment: "Alert Title: Resume Single Task") :
            (isAllCellsSelected ?
                DMLS("Resume All Tasks?", comment: "Alert Title: Resume All Tasks") :
                DMLS("Resume Selected Tasks?", comment: "Alert Title: Resume Multiple Tasks"))
        let alertMessage: String? = selectedTaskSet.count == 1 ? downloadManager.fileDisplayName(ofTask: selectedTaskSet.first!) : nil
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        let confirmAlertAction = UIAlertAction(title: resumeTitle, style: .default, handler: { action in
            if self.isAllCellsSelected{
                self.resumeAllTasks()
            }else{
                let unfinishedTaskSet = Set(self.selectedTaskSet.filter({
                    let taskState = self.downloadManager.downloadState(ofTask: $0)
                    return taskState != .finished && taskState != .downloading
                }))
                
                if !unfinishedTaskSet.isEmpty{
                    let unfinishedTasks: [String]
                    if self.downloadManager.maxDownloadCount != OperationQueue.defaultMaxConcurrentOperationCount{
                        unfinishedTasks = self.downloadManager.sorter.sortedTaskSet(unfinishedTaskSet,
                                                                                    byType: self.downloadManager.sortType,
                                                                                    order: self.downloadManager.sortOrder)
                    }else{
                        unfinishedTasks = Array(unfinishedTaskSet)
                    }
                    _ = self.downloadManager.resumeTasks(unfinishedTasks)
                }
            }
            
            self.deselectHighlightedCells()
        })
        
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        alert.addAction(confirmAlertAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc private func pauseSelectedTasks(){
        if downloadManager.pauseDownloadBySuspendingSessionTask{
            _ = downloadManager.pauseTasks(Array(selectedTaskSet))
            deselectHighlightedCells()
        }else{
            stopSelectedTasks()
        }
    }
    
    @objc private func stopSelectedTasks(){
        if isAllCellsSelected{
            stopAllTasks()
            return
        }
        
        let alertTitle: String = selectedTaskSet.count == 1 ?
            DMLS("Stop the Task?", comment: "Alert Title: Stop Single Task") :
            DMLS("Stop Selected Tasks?", comment: "Alert Title: Stop Multiple Tasks")
        let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)
        let confirmAlertAction = UIAlertAction(title: stopTitle, style: .default, handler: { action in
            _ = self.downloadManager.stopTasks(Array(self.selectedTaskSet))
            self.deselectHighlightedCells()
        })
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        alert.addAction(confirmAlertAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    private func deselectHighlightedCells(){
        tableView.indexPathsForSelectedRows?.forEach({
            tableView.deselectRow(at: $0, animated: true)
        })
        isAllCellsSelected = false
        cleanupSelectionInfo()
        resetNavigatonBarButtonItems()
        if multipleSelectionEnabled && shouldExitEditModeAfterConfirmAction{
            exitMultiSelectionMode()
        }
    }
    
    fileprivate func updateCellIndexMark(){
        if self.cellImageViewStyle == .index, let visibleIndexPaths = self.tableView.indexPathsForVisibleRows{
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3,execute: {
                self.tableView.reloadRows(at: visibleIndexPaths, with: .fade)
            })
        }
    }
    
    @objc private func restoreSelectedTasks(){
        guard displayContent == .toDeleteList else{return}
        guard !selectedTaskSet.isEmpty else{return}
        
        func restoreToLocation(_ location: IndexPath){
            // selectOrUnselectAllTasks() doesn't update indxPath
            let selectedTasks = Array(selectedTaskSet)
            if let indexPaths = downloadManager.restoreToDeleteTasks(selectedTasks, toLocation: location){
                removeSelectionInfo(about: selectedTasks)
                tableView.deleteRows(at: indexPaths, with: .fade)
                updateNavigationBarButtonItems()
                updateCellIndexMark()
            }
        }
        
        if downloadManager.sortType == .manual{
            let restoreVC = RestoreTaskController.init(downloadManager: downloadManager, restoreHandler: { restoreLocation in
                restoreToLocation(restoreLocation)
            })
            if let nv = self.navigationController{
                nv.pushViewController(restoreVC, animated: true)
            }else{
                self.present(restoreVC, animated: true, completion: nil)
            }
        }else{
            let restoreAlert: UIAlertController = UIAlertController(title: DMLS("Restore to Original Location?",
                                                                                comment: "Alert Title: ToDelete Task Restoration"),
                                                                                message: nil, preferredStyle: .alert)
            restoreAlert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
            restoreAlert.addAction(UIAlertAction(title: restoreTitle, style: .destructive, handler: {_ in
                restoreToLocation(IndexPath(row: 0, section: 0))
            }))

            self.present(restoreAlert, animated: true, completion: nil)
        }
    }
    
    @objc private func adjustMaxDownloadCount(){
        let sliderController = SliderAlertController.init(title: DMLS("Adjust Max Download Count",
                                                                                   comment: "Alert Title: Adjust MaxDownloadCount"),
                                                          message: DMLS("(No limit when value is 0)",
                                                                                   comment: "Alert Message: Note to Set MaxDownloadCount"),
                                                          minimumValue: 0,
                                                          maximumValue: downloadManager.maxDownloadCount <= 20 ? 20 : Float(downloadManager.maxDownloadCount) + 10,
                                                          initialValue: Float(downloadManager.maxDownloadCount),
                                                          confirmTitle: nil,
                                                          confirmClosure: { value in
                                                            DispatchQueue.global().async(execute: {
                                                                self.downloadManager.maxDownloadCount = Int(value)
                                                            })
        })
        sliderController.floatToSymbolMap[0] = "∞"
        self.present(sliderController, animated: true, completion: nil)
    }
    
    private func updateNavigationBarButtonItems(){
        if tableView.visibleCells.isEmpty{
            selectButtonItem.isEnabled = false
        }else{
            selectButtonItem.isEnabled = true
        }
        
        if leftButtonItemsInEditMode?.contains(resumeButtonItem) == true{
            let resumeableCount = selectedTaskSet.filter({
                let state = downloadManager.downloadState(ofTask: $0)
                return state != .finished && state != .downloading
            }).count
            resumeButtonItem.isEnabled = resumeableCount > 0 ? true : false
            if barButtonAppearanceStyle == .title{
                resumeButtonItem.title = resumeableCount <= 0 ? resumeTitle :
                    String.localizedStringWithFormat(DMLS("Resume(%d)", comment: "Resume BarButtonItem Action"), resumeableCount)
            }
        }
        
        if leftButtonItemsInEditMode?.contains(pauseButtonItem) == true{
            let executingCount = selectedTaskSet.filter({
                downloadManager.downloadState(ofTask: $0) == .downloading
            }).count
            pauseButtonItem.isEnabled = executingCount > 0 ? true : false
            if barButtonAppearanceStyle == .title{
                pauseButtonItem.title = executingCount <= 0 ? pauseTitle :
                    String.localizedStringWithFormat(DMLS("Pause(%d)", comment: "Pause BarButtonItem Action"), executingCount)
            }
        }
        
        if leftButtonItemsInEditMode?.contains(stopButtonItem) == true{
            let stopableCount = selectedTaskSet.filter({
                downloadManager.downloadOperation(ofTask: $0) != nil
            }).count
            stopButtonItem.isEnabled = stopableCount > 0 ? true : false
            if barButtonAppearanceStyle == .title{
                stopButtonItem.title = stopableCount <= 0 ? stopTitle :
                    String.localizedStringWithFormat(DMLS("Stop(%d)", comment: "Stop BarButtonItem Action"), stopableCount)
            }

        }
        
        if leftButtonItemsInEditMode?.contains(deleteButtonItem) == true{
            deleteButtonItem.isEnabled = selectedTaskSet.isEmpty ? false : true
            if barButtonAppearanceStyle == .title{
                deleteButtonItem.title = selectedTaskSet.isEmpty ? deleteTitle :
                    String.localizedStringWithFormat(DMLS("Delete(%d)", comment: "Delete BarButtonItem Action"), selectedTaskSet.count)
            }

        }
        
        if leftButtonItemsInEditMode?.contains(restoreButtonItem) == true{
            restoreButtonItem.isEnabled = selectedTaskSet.isEmpty ? false : true
        }
    }
    
    private func resetNavigatonBarButtonItems(){
        if barButtonAppearanceStyle == .title{
            selectButtonItem.title = selectAllTitle
            resumeButtonItem.title = resumeTitle
            pauseButtonItem.title = pauseTitle
            stopButtonItem.title = stopTitle
            deleteButtonItem.title = deleteTitle
            restoreButtonItem.title = restoreTitle
        }else{
            selectButtonItem.image = unselectedImage
        }
        
        selectButtonItem.isEnabled = tableView.visibleCells.isEmpty ? false : true
        resumeButtonItem.isEnabled = false
        pauseButtonItem.isEnabled = false
        stopButtonItem.isEnabled = false
        deleteButtonItem.isEnabled = false
        restoreButtonItem.isEnabled = false
    }
    
    // MARK: Sort Download List
    private var manualReordering: Bool = false
    private func enterManualSortMode(){
        DispatchQueue.main.async(execute: {
            self.manualReordering = true
            self.enterEditModeAndBackupButtons()
            self.longPressGesture.isEnabled = false
        })
    }
    
    @objc private func sortDownloadList(){
        let condition1 = (displayContent == .downloadList && downloadManager._downloadTaskSet.isEmpty == false)
        guard condition1 || (displayContent == .subsection && downloadManager.taskCountInSection(subsectionIndex) > 0) else{return}
        if downloadManager.sortType == .manual && !allowsSwitchingSortMode{
            enterManualSortMode()
            return
        }
        
        var sortPanelVC: SortViewController
        switch (displayContent, downloadManager.sortType) {
        case (.downloadList, .manual):
            sortPanelVC = SortViewController.init(initialType: downloadManager.sortType, initialOrder: downloadManager.sortOrder){
                type, order in
                if type == .manual{
                    self.enterManualSortMode()
                }else{
                    let message = DMLS("It will lose all section titles.", comment: "Switch Sort Mode: Manual to Predefined")
                    let alert = UIAlertController(title: "❗️", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: confirmActionTitle, style: .destructive, handler: { _ in
                        DispatchQueue.global().async(execute: {
                            var animating: Bool = false
                            if self.downloadManager._downloadTaskSet.count > 500{
                                animating = true
                                DispatchQueue.main.async {
                                    self.tableView.isScrollEnabled = false
                                    self.sortButtonItem.isEnabled = false
                                    self.view.addSubview(self.activityView)
                                    self.activityView.startAnimating()
                                }
                            }
                            self.emptyManualSectionSet.removeAll()
                            self.downloadManager.sortListBy(type: type, order: order)
                            DispatchQueue.main.async {
                                if animating{
                                    self.tableView.isScrollEnabled = true
                                    self.sortButtonItem.isEnabled = true
                                    // Don't stop activityView, remove it directly, otherwise, after a little while, 
                                    // add it again, it can't display.
                                    self.activityView.removeFromSuperview()
                                }
                                self.tableView.reloadData()
                            }
                        })
                    }))
                    DispatchQueue.main.async(execute: {
                        self.present(alert, animated: true, completion: nil)
                    })
                }
            }
            sortPanelVC.sortTypes.insert(.manual, at: 0)
        case (.downloadList, _):
            sortPanelVC = SortViewController.init(initialType: downloadManager.sortType, initialOrder: downloadManager.sortOrder){
                if $0 == .manual{
                    let order = $1
                    let message = DMLS("All files will be integrated into one section.", comment: "Switch Sort Mode: Predefined to Manual")
                    let alert = UIAlertController(title: "❗️", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: confirmActionTitle, style: .destructive, handler: { _ in
                        DispatchQueue.main.async {
                            self.emptyManualSectionSet.removeAll()
                            self.downloadManager.sortListBy(type: .manual, order: order)
                            self.changeTitleOfSection(0)
                            self.tableView.reloadData()
                            self.enterManualSortMode()
                        }
                    }))
                    DispatchQueue.main.async(execute: {
                        self.present(alert, animated: true, completion: nil)
                    })
                }else{
                    var animating: Bool = false
                    if self.downloadManager._downloadTaskSet.count > 500{
                        animating = true
                        DispatchQueue.main.async {
                            self.tableView.isScrollEnabled = false
                            self.sortButtonItem.isEnabled = false
                            self.view.addSubview(self.activityView)
                            self.activityView.startAnimating()
                        }
                    }
                    self.emptyManualSectionSet.removeAll()
                    self.downloadManager.sortListBy(type: $0, order: $1)
                    DispatchQueue.main.async {
                        if animating{
                            self.tableView.isScrollEnabled = true
                            self.sortButtonItem.isEnabled = true
                            self.activityView.removeFromSuperview()
                        }
                        self.tableView.reloadData()
                    }
                }
            }
            if allowsSwitchingSortMode{
                sortPanelVC.sortTypes.insert(.manual, at: 0)
            }
        case (.subsection, .manual):
            sortPanelVC = SortViewController.init(initialType: downloadManager.sortType, initialOrder: downloadManager.sortOrder){
                if $0 == .manual{
                    self.enterManualSortMode()
                }else{
                    var animating: Bool = false
                    if self.downloadManager.taskCountInSection(self.subsectionIndex) > 500{
                        animating = true
                        DispatchQueue.main.async {
                            self.tableView.isScrollEnabled = false
                            self.sortButtonItem.isEnabled = false
                            self.view.addSubview(self.activityView)
                            self.activityView.startAnimating()
                        }
                    }
                    _ = self.downloadManager.sortSection(self.subsectionIndex, inplace: true, byType: $0, order: $1)
                    DispatchQueue.main.async {
                        if animating{
                            self.tableView.isScrollEnabled = true
                            self.sortButtonItem.isEnabled = true
                            self.activityView.removeFromSuperview()
                        }
                        self.tableView.reloadData()
                    }
                }
            }
            sortPanelVC.sortTypes = [.manual, .addTime, .fileName, .fileSize]
        default: return
        }
        sortPanelVC.displaySortOrder = shouldDisplaySortOrderInSortView
        sortPanelVC.modalPresentationStyle = .popover
        // .popover style need a anchor, you must provide either a sourceView and sourceRect or a barButtonItem.
        sortPanelVC.popoverPresentationController?.barButtonItem = sortButtonItem
        sortPanelVC.popoverPresentationController?.delegate = self
        self.present(sortPanelVC, animated: true, completion: nil)
    }
    
    // MARK: - Change Section Title and File Name
    var textFieldContent: String?
    var originalText: String?
    var confirmAction: UIAlertAction?
    
    func resetRenameContext(){
        self.textFieldContent = nil
        self.originalText = nil
        self.confirmAction = nil
    }
    
    func changeTitleOfSection(_ section: Int){
        originalText = self.downloadManager.titleForHeaderInSection(section)
        let alert = UIAlertController.init(title: DMLS("Update Section Title", comment: "Alert Title: Update Section Title"), message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField in
            textField.text = self.originalText
            textField.adjustsFontSizeToFitWidth = true
            textField.clearButtonMode = .always
            
            // UITextField's Target-Action mode is better choice than delegate mode to handle editing and return event.
            textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(self.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
        })
        
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: {_ in
            self.resetRenameContext()
        }))
        
        confirmAction = UIAlertAction(title: confirmActionTitle, style: .default, handler: {_ in
            if let newTitle = self.textFieldContent, newTitle != self.originalText!{
                self.downloadManager.changeTitleOfSection(section, to: newTitle)
                self.tableView.reloadSections(IndexSet.init(integer: section), with: .fade)
            }
            self.resetRenameContext()
        })
        confirmAction?.isEnabled = false
        alert.addAction(confirmAction!)
        self.present(alert, animated: true, completion: nil)
    }
    
    func changeDisplayNameForTask(at indexPath: IndexPath){
        guard let URLString = downloadURLString(at: indexPath) else{return}

        let taskInfo = downloadManager.downloadTaskInfo[URLString]!
        let fileDisplayName = (taskInfo[SDEDownloadManager.TIFileDisplayNameStringKey] ?? taskInfo[TIFileNameStringKey]!) as? String
        originalText = fileDisplayName
        
        let alert = UIAlertController.init(title: DMLS("Update File Name", comment: "Alert Title: Change File Display Name"), message: fileDisplayName, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField in
            textField.text = fileDisplayName
            textField.adjustsFontSizeToFitWidth = true
            textField.clearButtonMode = .always
            
            // UITextField's Target-Action mode is better choice than delegate mode to handle editing and return event.
            textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(self.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
        })
        
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: {_ in
            self.resetRenameContext()
            self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
        }))
        
        confirmAction = UIAlertAction(title: confirmActionTitle, style: .default, handler: {[unowned self] _ in
            if let newName = self.textFieldContent{
                let dm = self.downloadManager
                let changeIP = self.displayContent == .subsection ? IndexPath(row: indexPath.row, section: self.subsectionIndex) : indexPath
                dm.indexPathToChangeName = changeIP
                dm.changeDisplayNameOfTask(URLString, to: newName)
            }

            self.resetRenameContext()
            self.tableView.cellForRow(at: indexPath)?.setHighlighted(false, animated: true)
        })
        confirmAction?.isEnabled = false
        alert.addAction(confirmAction!)
        
        self.present(alert, animated: true, completion: {
            self.tableView.setEditing(false, animated: true)
            // cell.selectionStyle can't be .None
            self.tableView.cellForRow(at: indexPath)?.setHighlighted(true, animated: true)
        })
    }
    
    // MARK: Handle UITextField's editing and return.
    @objc private func textFieldDidChange(_ textField: UITextField){
        if let text = textField.text, isNotEmptyString(text){
            textFieldContent = text
            confirmAction?.isEnabled = originalText == text ? false : true
        }else{
            textFieldContent = nil
            confirmAction?.isEnabled = false
        }

    }
    
    // .EditingDidEndOnExit is for tap 'Return' button on the keyboard. In delegate mode, there is no specifal method for tap 'Return' button.
    @objc private func textFieldDidReturn(_ textField: UITextField){
        if let text = textField.text, isNotEmptyString(text){
            textFieldContent = text
            confirmAction?.isEnabled = originalText == text ? false : true
        }else{
            textFieldContent = nil
            confirmAction?.isEnabled = false
        }
    }

    
    // MARK: - ToolBar ButtonItem Configuration
    lazy var resumeAllButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.resumeAllTitle, style: .plain, target: self, action: #selector(resumeAllTasks)) :
                                                         UIBarButtonItem.init(image: self.resumeIcon, style: .plain, target: self, action: #selector(resumeAllTasks))
    }()
    lazy var pauseAllButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.pauseAllTitle, style: .plain, target: self, action: #selector(pauseAllTasks)) :
                                                         UIBarButtonItem.init(image: self.pauseIcon, style: .plain, target: self, action: #selector(pauseAllTasks))
    }()
    lazy var stopAllButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.stopAllTitle, style: .plain, target: self, action: #selector(stopAllTasks)) :
                                                         UIBarButtonItem.init(image: self.stopIcon, style: .plain, target: self, action: #selector(stopAllTasks))
    }()
    
    lazy var deleteAllButtonItem: UIBarButtonItem = {
        return self.barButtonAppearanceStyle == .title ? UIBarButtonItem.init(title: self.deleteAllTitle, style: .plain, target: self, action: #selector(deleteAllTasks)) :
                                                         UIBarButtonItem.init(image: self.deleteIcon, style: .plain, target: self, action: #selector(deleteAllTasks))
    }()

    // MARK: Toolbar ButtonItem Action Method
    @objc private func resumeAllTasks(){
        guard downloadManager.isAnyTaskUnfinished else{return}
        switch displayContent {
        case .downloadList, .unfinishedList:
            downloadManager.resumeAllTasks()
        case .subsection:
            let tasks = downloadManager.sortedURLStringsList[subsectionIndex]
            _ = downloadManager.resumeTasks(tasks)
        case .toDeleteList: return
        }
        
        if trackActivityEnabled{
            downloadManager.beginTrackingDownloadActivity()
        }
    }
    
    @objc private func pauseAllTasks(){
        guard downloadManager.downloadQueue.operationCount > 0 else{return}
        switch displayContent {
        case .downloadList, .unfinishedList:
            downloadManager.pauseAllTasks()
        case .subsection:
            let tasks = downloadManager.sortedURLStringsList[subsectionIndex]
            _ = downloadManager.pauseTasks(tasks)
        case .toDeleteList:
            return
        }
    }
    
    @objc private func stopAllTasks(){
        guard downloadManager.downloadQueue.operationCount > 0 else{return}
        
        let alert = UIAlertController(title: DMLS("Stop All Tasks?", comment: "Alert Title: Stop All Tasks"), message: nil, preferredStyle: .alert)
        let confirmAlertAction = UIAlertAction(title: stopTitle, style: .default, handler: { action in
            guard self.downloadManager.downloadQueue.operationCount > 0 else{return}
            switch self.displayContent {
            case .downloadList, .unfinishedList:
                self.downloadManager.stopAllTasks()
            case .subsection:
                let tasks = self.downloadManager.sortedURLStringsList[self.subsectionIndex]
                _ = self.downloadManager.stopTasks(tasks)
            case .toDeleteList: return
            }
            
            self.deselectHighlightedCells()
        })
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        alert.addAction(confirmAlertAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc private func deleteAllTasks(){
        var toDeleteURLStrings: [String] = []
        
        switch displayContent {
        case .downloadList:
            toDeleteURLStrings = downloadManager.sortedURLStringsList.flatMap({$0})
        case .unfinishedList: return
        case .subsection:
            toDeleteURLStrings = downloadManager.sortedURLStringsList[subsectionIndex]
        case .toDeleteList:
            emptyTrash()
            return
        }
        guard toDeleteURLStrings.count > 0 else{return}
        let alertTitle: String = downloadManager.isTrashOpened ?
            DMLS("Move All Files to Trash?", comment: "Alert Title: Delete All Tasks") :
            DMLS("Delete All Files?", comment: "Alert Title: Delete All Tasks")
        self.present(deleteAlertForTasks(toDeleteURLStrings, alertTitle: alertTitle, at: {
            var toDeleteIPs: [IndexPath] = []
            if self.displayContent == .downloadList{
                for section in 0..<self.downloadManager.sortedURLStringsList.count{
                    for row in 0..<self.downloadManager.sortedURLStringsList[section].count{
                        toDeleteIPs.append(IndexPath(row: row, section: section))
                    }
                }
            }else{
                for row in 0..<toDeleteURLStrings.count{
                    toDeleteIPs.append(IndexPath(row: row, section: self.subsectionIndex))
                }
            }

            return toDeleteIPs
        }), animated: true, completion: nil)
    }

    // MARK: - Delete Feature
    lazy private var deleteFileOnly: Bool = false
    @objc private func deleteSelectedTasks(){
        if isAllCellsSelected{
            deleteAllTasks()
        }else{
            let deleteActionAlert: UIAlertController
            if selectedTaskSet.count == selectedTaskIPInfo.count{
                deleteActionAlert = deleteAlertForTasks(Array(selectedTaskSet), at: {Array(self.selectedTaskIPInfo.values)})
            }else{
                deleteActionAlert = deleteAlertForTasks(Array(selectedTaskSet), at: nil)
            }
            
            self.present(deleteActionAlert, animated: true, completion: nil)
        }
    }

    private func deleteAlertForTasks(_ URLStrings: [String], alertTitle: String? = nil, message: String? = nil, at ips: (() -> [IndexPath])?, cancelHandler: (() -> Void)? = nil) -> UIAlertController{
        var _alertTitle: String?
        var _message: String?
        
        let fileDisplayName: String = downloadManager.completedDisplayNameOfTask(URLStrings.first!)!
        let multiFilesToDeleteTitle: String = DMLS("Delete Selected %d Files?", comment: "Alert Title: Delete Multiple Tasks")
        let singleFileToDeleteTitle: String = DMLS("Delete This File?", comment: "Alert Title: Delete Single Task")

        if alertTitle != nil{
            _alertTitle = alertTitle
        }else if displayContent != .toDeleteList{
            let multiFilesToTrashTitle: String = DMLS("Move Selected %d Files to Trash?", comment: "Alert Title: Move Multiple Task to Trash")
            let singleFileToTrashTitle: String = DMLS("Move to Trash?", comment: "Alert Title: Move Single Task to Trash")
            switch deleteMode {
            case .fileAndRecord:
                if downloadManager.isTrashOpened{
                    _alertTitle = URLStrings.count > 1 ? String.localizedStringWithFormat(multiFilesToTrashTitle, URLStrings.count) : singleFileToTrashTitle
                }else{
                    _alertTitle = URLStrings.count > 1 ? String.localizedStringWithFormat(multiFilesToDeleteTitle, URLStrings.count) : singleFileToDeleteTitle
                }
            case .onlyFile:
                _alertTitle = URLStrings.count > 1 ? String.localizedStringWithFormat(multiFilesToDeleteTitle, URLStrings.count) : singleFileToDeleteTitle
            case .optional:
                _alertTitle = URLStrings.count > 1 ? String.localizedStringWithFormat(multiFilesToDeleteTitle, URLStrings.count) : singleFileToDeleteTitle
            }

        }else{
            _alertTitle = URLStrings.count > 1 ? String.localizedStringWithFormat(multiFilesToDeleteTitle, URLStrings.count) : singleFileToDeleteTitle
        }
        
        if message != nil{
            _message = message
        }else if displayContent != .toDeleteList{
            switch deleteMode {
            case .fileAndRecord:
                _message = URLStrings.count > 1 ? nil : fileDisplayName
            case .onlyFile:
                _message = DMLS("The record will be retained.", comment: "Alert Message: deleteMode == .onlyFile")
            case .optional:
                _message = URLStrings.count > 1 ? nil : fileDisplayName
            }
        }else{
            _message = URLStrings.count > 1 ? nil : fileDisplayName
        }
        
        let deleteAlert = UIAlertController(title: _alertTitle, message: _message, preferredStyle: .alert)
        if deleteMode == .optional && displayContent != .toDeleteList{
            // The modalPresentationStyle of a UIAlertController with .ActionSheet is UIModalPresentationPopover, 
            // which need a sourceView and sourceRect or barButtonItem. .Alert get same presentation result.
            deleteAlert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: { _ in cancelHandler?() }))
            
            let optionalActionTitle: String
            if downloadManager.isTrashOpened{
                optionalActionTitle = DMLS("Move to Trash", comment: "Alert Title: deleteMode == .optional")
            }else{
                optionalActionTitle = DMLS("Delete File and Record Both", comment: "Alert Title: deleteMode == .optional")
            }
            deleteAlert.addAction(UIAlertAction(title: optionalActionTitle, style: .destructive, handler: { _ in
                self.deleteTasks(URLStrings, at: ips?(), onlyDeleteFile: false)
            }))
            deleteAlert.addAction(UIAlertAction(title: DMLS("Delete File Only", comment: "Alert Title: deleteMode == .optional"),
                                                style: .destructive,
                                                handler: { _ in
                                                    self.deleteTasks(URLStrings, at: ips?(), onlyDeleteFile: true)
            }))

        }else{
            deleteAlert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: {_ in cancelHandler?() }))
            let confirmCondition: Bool = displayContent != .toDeleteList && downloadManager.isTrashOpened && !deleteFileOnly
            let actionTitle: String = confirmCondition ? confirmActionTitle : deleteTitle
            deleteAlert.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: {_ in
                self.deleteTasks(URLStrings, at: ips?(), onlyDeleteFile: self.deleteFileOnly)
            }))
        }
        return deleteAlert
    }
    
    
    // indexPaths are task location in downloadList
    private func deleteTasks(_ toDeleteURLStrings: [String], at indexPaths: [IndexPath]?, onlyDeleteFile: Bool){
        guard toDeleteURLStrings.count > 0 else {return}
        guard displayContent != .unfinishedList else {return}
        
        let thresholdValue = 20
        let wrapperView: UIView?
        let deletionHandler: ((String, IndexPath, Int, Int) -> Void)?
        func removeView(_ wrapperView: UIView){
            DispatchQueue.main.sync(execute: {
                UIView.animate(withDuration: 0.15, animations: {
                    wrapperView.transform = CGAffineTransform.init(scaleX: 0.1, y: 0.1)
                }, completion: {_ in
                    wrapperView.removeFromSuperview()
                })
            })
        }
        
        func deletionIsOver(){
            if self.multipleSelectionEnabled && self.shouldExitEditModeAfterConfirmAction{
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    self.exitMultiSelectionMode()
                })
            }else{
                self.downloadManager.saveData()
            }
        }
        
        func updateSelectionInfo(_ tasks: [String]){
            self.removeSelectionInfo(about: tasks)
            self.updateNavigationBarButtonItems()
            if selectedTaskSet.isEmpty{
                self.isAllCellsSelected = false
                if self.barButtonAppearanceStyle == .title{
                    self.selectButtonItem.title = self.selectAllTitle
                }
            }
        }

        if onlyDeleteFile{
            if toDeleteURLStrings.count > thresholdValue{
                let (_wrapperView, progressView, progressLabel) = deletionIndicateView()
                wrapperView = _wrapperView
                deletionHandler = { _, _, count, currentLocation in
                    DispatchQueue.main.sync(execute: {
                        progressView.progress = Float(currentLocation) / Float(count)
                        progressLabel.text = "\(currentLocation)/\(count)"
                    })
                }
            }else{
                wrapperView = nil
                deletionHandler = nil
            }
            self.downloadManager.deleteCompletionHandler = deletionHandler

            DispatchQueue.global().async(execute: {
                let deletedTasks: [String]
                if let ips = indexPaths, let deletedIndexPaths = self.downloadManager.deleteFilesOfTasks(at: ips){
                    deletedTasks = deletedIndexPaths.flatMap({ self.downloadManager[$0] })
                }else if let tasks = self.downloadManager.deleteFilesOfTasks(toDeleteURLStrings){
                    deletedTasks = tasks
                }else{
                    deletedTasks = []
                }
                
                if wrapperView != nil{
                    removeView(wrapperView!)
                }
                guard deletedTasks.isEmpty == false else{return}
        
                DispatchQueue.main.sync(execute: {
                    if self.multipleSelectionEnabled{
                        updateSelectionInfo(deletedTasks)
                    }

                    if let visibleIPs = self.tableView.indexPathsForVisibleRows{
                        // reload cell to unlock its selected state, so remove URL in selectedTaskSet first.
                        self.tableView.reloadRows(at: visibleIPs, with: .fade)
                    }
                })
                
                deletionIsOver()
            })
        }else{
            if toDeleteURLStrings.count > thresholdValue{
                let (_wrapperView, progressView, progressLabel) = deletionIndicateView()
                wrapperView = _wrapperView
                deletionHandler = {[unowned self] task, ip, count, currentLocation in
                    DispatchQueue.main.sync(execute: {
                        let indexPath = self.displayContent == .downloadList ? ip : IndexPath.init(row: ip.row, section: 0)
                        self.tableView.deleteRows(at: [indexPath], with: .left)
                        progressView.progress = Float(currentLocation) / Float(count)
                        progressLabel.text = "\(currentLocation)/\(count)"
                    })
                }
            }else{
                wrapperView = nil
                deletionHandler = nil
            }
            self.downloadManager.deleteCompletionHandler = deletionHandler
            
            DispatchQueue.global().async(execute: {
                switch self.displayContent {
                case .downloadList, .subsection:
                    let deletedTaskInfo: Dictionary<String, IndexPath>
                    if let ips = indexPaths, let info = self.downloadManager.deleteTasks(at: ips){
                        deletedTaskInfo = info
                    }else if let info = self.downloadManager.deleteTasks(toDeleteURLStrings){
                        deletedTaskInfo = info
                    }else{
                        deletedTaskInfo = [:]
                    }
                    
                    if wrapperView != nil{
                        removeView(wrapperView!)
                    }
                    
                    guard deletedTaskInfo.isEmpty == false else{return}
                    
                    if self.multipleSelectionEnabled{
                        DispatchQueue.main.sync(execute: {
                            updateSelectionInfo(Array(deletedTaskInfo.keys))
                        })
                    }
                    
                    if deletionHandler == nil{
                        DispatchQueue.main.sync(execute: {
                            let deletedIndexPaths = self.displayContent == .downloadList ? Array(deletedTaskInfo.values) : deletedTaskInfo.values.map({
                                IndexPath(row: $0.row, section: 0)
                            })
                            self.tableView.beginUpdates()
                            self.tableView.deleteRows(at: deletedIndexPaths, with: .left)
                            self.tableView.endUpdates()
                        })
                    }

                    
                    if self.displayContent == .downloadList{
                        var emptySet: IndexSet = IndexSet()
                        for section in 0..<self.downloadManager.sectionCount{
                            if self.downloadManager.taskCountInSection(section) == 0{
                                emptySet.update(with: section)
                            }
                        }
                        guard emptySet.isEmpty == false else {break}
                        
                        DispatchQueue.main.sync(execute: {
                            if self.downloadManager.sortType != .manual || self.shouldRemoveEmptySection{
                                emptySet.sorted(by: >).forEach({
                                    _ = self.downloadManager.removeEmptySection($0)
                                })
                                // Some indexs in emptyManualSectionSet maybe are invalid now, emptyManualSectionSet
                                // will be updated totally in tableView(_:numberOfRowsInSection:) after
                                // deleteSections(_:with:) is called.
                                if self.emptyManualSectionSet.isEmpty == false{
                                    self.emptyManualSectionSet.removeAll()
                                }
                                self.tableView.deleteSections(emptySet, with: .left)
                                if self.downloadManager.sortType == .manual && self.multipleSelectionEnabled{
                                    self.updateAffectedHeaderViewAfterSection(emptySet.min()!, includeIt: true)
                                }
                            }else if self.multipleSelectionEnabled{ // update insert button in header view
                                // emptyManualSectionSet will be updated totally in tableView(_:numberOfRowsInSection:)
                                self.tableView.reloadSections(emptySet, with: .left)
                            }
                        })
                    }else{//.subsection
                        let isSectionEmpty = self.downloadManager.sortedURLStringsList[self.subsectionIndex].count == 0
                        guard isSectionEmpty else{break}
                        
                        if self.downloadManager.sortType != .manual || self.shouldRemoveEmptySection{
                            self.isSubsectionDeleted = true
                            _ = self.downloadManager.removeEmptySection(self.subsectionIndex)
                            DispatchQueue.main.sync(execute: {
                                self.tableView.deleteSections(IndexSet(integer: 0), with: .left)
                            })
                        }
                    }
                    
                case .toDeleteList:
                    let toDeleteCount = self.downloadManager.trashList.count
                    let cleanedTaskIps: Dictionary<String, IndexPath>
                    if let ips = indexPaths, let taskIPs = self.downloadManager.cleanupToDeleteTasks(at: ips.map({ $0.row })){
                        cleanedTaskIps = taskIPs
                    }else if let deletedIPs = self.downloadManager.cleanupToDeleteTasks(toDeleteURLStrings){
                        cleanedTaskIps = deletedIPs
                    }else{
                        cleanedTaskIps = [:]
                    }
                    
                    if wrapperView != nil{
                        removeView(wrapperView!)
                    }
                    
                    guard cleanedTaskIps.isEmpty == false else{return}
                    
                    DispatchQueue.main.sync(execute: {
                        if self.multipleSelectionEnabled{
                            updateSelectionInfo(Array(cleanedTaskIps.keys))
                        }

                        if deletionHandler == nil{
                            self.tableView.beginUpdates()
                            self.tableView.deleteRows(at: Array(cleanedTaskIps.values), with: .fade)
                            self.tableView.endUpdates()
                        }
                        
                        if cleanedTaskIps.count == toDeleteCount{
                            self.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
                        }
                    })
                case .unfinishedList: return
                }

                deletionIsOver()
                self.updateCellIndexMark()
            })
        }
    }
    
    private func deletionIndicateView() -> (UIView, UIProgressView, UILabel){
        let wrapperView = UIView.init()
        let progressLabel: UILabel = UILabel.init()
        let progressView: UIProgressView = UIProgressView.init(progressViewStyle: .default)
        let stopButton: UIButton = UIButton(type: .system)
        
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        
        wrapperView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        wrapperView.layer.cornerRadius = 10
        wrapperView.layer.masksToBounds = true
        
        progressLabel.textAlignment = .center
        progressLabel.textColor = UIColor.white
        
        progressView.progressTintColor = UIColor.red
        
        stopButton.backgroundColor = UIColor(white: 0.5, alpha: 0.5)//view.tintColor// UIColor.init(red: 1, green: 0, blue: 0, alpha: 0.5)
        stopButton.setTitle(stopTitle, for: .normal)
        stopButton.setTitleColor(UIColor.white, for: .normal)
        stopButton.addTarget(self, action: #selector(stopDeletion), for: .touchUpInside)
        
        // view is tableView in UITableViewController
        self.view.superview?.addSubview(wrapperView)
        NSLayoutConstraint(item: wrapperView, attribute: .centerX, relatedBy: .equal, toItem: view.superview, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: wrapperView, attribute: .centerY, relatedBy: .equal, toItem: view.superview, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: wrapperView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 200).isActive = true
        NSLayoutConstraint(item: wrapperView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 100).isActive = true
        
        wrapperView.addSubview(progressLabel)
        NSLayoutConstraint(item: progressLabel, attribute: .centerX, relatedBy: .equal, toItem: wrapperView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressLabel, attribute: .centerY, relatedBy: .equal, toItem: wrapperView, attribute: .centerY, multiplier: 1, constant: -10).isActive = true
        NSLayoutConstraint(item: progressLabel, attribute: .width, relatedBy: .equal, toItem: wrapperView, attribute: .width, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 30).isActive = true
        
        wrapperView.addSubview(progressView)
        NSLayoutConstraint(item: progressView, attribute: .centerX, relatedBy: .equal, toItem: wrapperView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .bottom, relatedBy: .equal, toItem: wrapperView, attribute: .bottom, multiplier: 1, constant: -30).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .width, relatedBy: .equal, toItem: wrapperView, attribute: .width, multiplier: 1, constant: 0).isActive = true
        
        wrapperView.addSubview(stopButton)
        NSLayoutConstraint(item: stopButton, attribute: .centerX, relatedBy: .equal, toItem: wrapperView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: stopButton, attribute: .bottom, relatedBy: .equal, toItem: wrapperView, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: stopButton, attribute: .width, relatedBy: .equal, toItem: wrapperView, attribute: .width, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: stopButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 30).isActive = true
        
        wrapperView.transform = CGAffineTransform.init(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.15, animations: {
            wrapperView.transform = CGAffineTransform.identity
        })
        
        return (wrapperView, progressView, progressLabel)
    }
    
    @objc private func stopDeletion(){
        downloadManager.isDeletionCancelled = true
    }

    
    @objc private func emptyTrash(){
        guard downloadManager.trashList.count > 0 else {return}
        let alert = UIAlertController(title: DMLS("Empty Trash?", comment: "Alert Title: Empty Trash"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: confirmActionTitle, style: .destructive, handler: { action in
            let toCleanCount = self.downloadManager.trashList.count
            if let cleanedTaskIps = self.downloadManager.emptyToDeleteList(){
                DispatchQueue.global().async(execute: {
                    self.downloadManager.saveData()
                })

                if self.multipleSelectionEnabled{
                    self.removeSelectionInfo(about: Array(cleanedTaskIps.keys))
                    self.updateNavigationBarButtonItems()
                }
                
                self.tableView.deleteRows(at: Array(cleanedTaskIps.values), with: .fade)
                if cleanedTaskIps.count == toCleanCount{
                    self.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
                }
            }
            
            if self.multipleSelectionEnabled && self.shouldExitEditModeAfterConfirmAction{
                self.exitMultiSelectionMode()
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Insert and Remove Section
    @objc private func insertNewSection(after button: HeaderButton){
        let newSection = button.section + 1
        let sectionTitle = DMLS("HeaderViewTitle.PlaceHolderTitle", comment: "PlaceHolderTitle")
        if downloadManager.insertPlaceHolderSectionInManualModeAtSection(newSection, withTitle: sectionTitle){
            DispatchQueue.main.async(execute: {
                // insertSections(_:with:) will check row number and title in all sections(include this new section)
                // emptyManualSectionSet will be updated totally in tableView(_:numberOfRowsInSection:).
                self.tableView.insertSections(IndexSet(integer: newSection), with: .left)
                self.updateAffectedHeaderViewAfterSection(newSection, includeIt: false)
                if self.tableView.headerView(forSection: newSection) == nil{
                    NSLog("new section is invisible")
                    let headerRect = self.tableView.rect(forSection: newSection)
                    self.tableView.scrollRectToVisible(headerRect, animated: true)
                }
            })
        }
    }
    
    @objc private func removeEmptySection(at button: HeaderButton){
        let removedSection = button.section
        if self.downloadManager.removeEmptySection(removedSection){
            DispatchQueue.main.async(execute: {
                // deleteSections(_:with:) will reload row number and title in all remainder sections,
                // emptyManualSectionSet will be updated totally in tableView(_:numberOfRowsInSection:).
                // Index out of range now in emptyManualSectionSet won't be deleted, they must be removed.
                self.tableView.deleteSections(IndexSet.init(integer: removedSection), with: .left)
                // There is a weird bug: if IndexSet is empty, its forEach(_:) or fliter(_:).forEach(_:) gets a error
                if self.emptyManualSectionSet.isEmpty == false{
                    let sectionCount = self.downloadManager.sectionTitleList.count
                    self.emptyManualSectionSet.filter({ $0 >= sectionCount }).forEach({
                        self.emptyManualSectionSet.remove($0)
                    })
                }
                // I'm not satisfied with animation of reloadSections, update HeaderButton's section manually.
                self.updateAffectedHeaderViewAfterSection(removedSection, includeIt: true)
            })
        }
    }
    
    lazy var emptyManualSectionSet = IndexSet()
    lazy var insertButtonQueue: [HeaderButton] = []
    lazy var removeButtonQueue: [HeaderButton] = []
    func addHeaderButtonForHeaderView(_ headerView: UIView, at section: Int, toInsert: Bool){
        let controlButton = HeaderButton.init(frame: .zero)
        controlButton.section = section
        controlButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(controlButton)
        
        if toInsert{
            controlButton.tag = InsertButtonTag
            // UIButton subclass can't use init(type:), only to create .custom button, its tintColor is ignored,
            // two solutions: red icon, or use UIImage..withRenderingMode(.alwaysTemplate) and set tintColor
            controlButton.setImage(self.insertIcon, for: .normal)
            controlButton.tintColor = UIColor.green
            controlButton.addTarget(self, action: #selector(insertNewSection(after:)), for: .touchUpInside)
        }else{
            controlButton.tag = RemoveButtonTag
            // UIButton subclass can't use init(type:), only to create .custom button, its tintColor is ignored,
            // two solutions: red icon, or use UIImage..withRenderingMode(.alwaysTemplate) and set tintColor
            controlButton.setImage(self.removeIcon, for: .normal)
            controlButton.addTarget(self, action: #selector(removeEmptySection(at:)), for: .touchUpInside)
        }
        
        addConstraintForHeaderButton(controlButton, with: headerView, toInsert: toInsert)
    }
    
    func addConstraintForHeaderButton(_ controlButton: HeaderButton, with headerView: UIView, toInsert: Bool){
        let centerXConstraint: NSLayoutConstraint
        if toInsert{
            centerXConstraint = NSLayoutConstraint(item: controlButton, attribute: .leadingMargin, relatedBy: .equal, toItem: headerView, attribute: .leadingMargin, multiplier: 1, constant: -1) // -1 to keep same centerX with select control in cell
        }else{
            centerXConstraint = NSLayoutConstraint(item: controlButton, attribute: .trailingMargin , relatedBy: .equal, toItem: headerView, attribute: .trailingMargin, multiplier: 1, constant: -1)
        }
        let centerYConstraint = NSLayoutConstraint(item: controlButton, attribute: .centerYWithinMargins, relatedBy: .equal, toItem: headerView, attribute: .centerYWithinMargins, multiplier: 1, constant: 0)
        let wConstraint = NSLayoutConstraint(item: controlButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 24)
        let hConstraint = NSLayoutConstraint(item: controlButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 24)
        NSLayoutConstraint.activate([centerXConstraint, centerYConstraint, wConstraint, hConstraint])
    }
    
    lazy var placeHolderEmptyString = "     "
    func updateAffectedHeaderViewAfterSection(_ section: Int, includeIt: Bool){
        var affectedSections: [Int] = []
        if emptyManualSectionSet.isEmpty == false{
            if includeIt{
                affectedSections.append(contentsOf: emptyManualSectionSet.filter({$0 >= section}))
            }else{
                affectedSections.append(contentsOf: emptyManualSectionSet.filter({$0 > section}))
            }
        }
        
        if allowsInsertingSection, let indexPaths = self.tableView.indexPathsForVisibleRows{
            if includeIt{
                affectedSections.append(contentsOf: Set(indexPaths.map({ $0.section })).filter({ $0 >= section }))
            }else{
                affectedSections.append(contentsOf: Set(indexPaths.map({ $0.section })).filter({ $0 > section }))
            }
        }
        
        guard affectedSections.isEmpty == false else {return}
        for fixedSection in affectedSections.sorted(){
            if let headerView = tableView.headerView(forSection: fixedSection){
                (headerView.viewWithTag(InsertButtonTag) as? HeaderButton)?.section = fixedSection
                (headerView.viewWithTag(RemoveButtonTag) as? HeaderButton)?.section = fixedSection
                if allowsInsertingSection{
                    let sectionTitle = downloadManager.titleForHeaderInSection(fixedSection) ?? "??"
                    headerView.textLabel?.text = placeHolderEmptyString + sectionTitle
                }
            }else{
                break
            }
        }
    }
    
    func addEditControlForVisibleSections(){
        guard displayContent == .downloadList else {return}
        // tableView.reloadSections(_:with:) is not a safe operation: it will check data source,
        // if section is not existed, there will be a crash.
        //
        // If tableView is accessed before viewDidLoad(), tableView will load its data, emptyManualSectionSet
        // will be updated in tableView(_:numberOfRowInSection:), displayContent's default value is .downloadList,
        // if displayContent is changed to other, and emptyManualSectionSet is not empty, this gets a error.
        if emptyManualSectionSet.isEmpty == false {
            tableView.reloadSections(emptyManualSectionSet, with: .fade)
        }
        
        // Can't get empty sections from indexPathsForVisibleRows.
        if downloadManager.sortType == .manual, allowsInsertingSection, let visibleIPs = tableView.indexPathsForVisibleRows{
            var visibleSections = Set(visibleIPs.map({ $0.section }))
            if let topSection = visibleSections.min(), topSection > 0{
                visibleSections.insert(topSection - 1)
            }
            if let bottomSection = visibleSections.max(){
                visibleSections.insert(bottomSection + 1)
            }
            
            DispatchQueue.main.async(execute: {
                for section in visibleSections{
                    guard let headerView = self.tableView.headerView(forSection: section) else {continue}
                    self.addInsertControlForHeaderView(headerView, at: section)
                }
            })
        }
    }
    
    func addInsertControlForHeaderView(_ headerView: UIView, at section: Int){
        if let textLabel = (headerView as? UITableViewHeaderFooterView)?.textLabel{
            // Move textLabel location doesn't work here and tableView(_:willDisplayHeaderView:forSection:)
            let sectionTitle = self.downloadManager.titleForHeaderInSection(section) ?? "??"
            textLabel.text = placeHolderEmptyString + sectionTitle
        }
        
        if let insertButton = headerView.viewWithTag(InsertButtonTag) as? HeaderButton{
            insertButton.section = section
        }else{
            if let insertButton = insertButtonQueue.popLast(){
                insertButton.section = section
                headerView.addSubview(insertButton)
                addConstraintForHeaderButton(insertButton, with: headerView, toInsert: true)
            }else{
                addHeaderButtonForHeaderView(headerView, at: section, toInsert: true)
            }
        }
    }
    
    func removeEditControlForVisibleSections(){
        guard displayContent == .downloadList else {return}
        if emptyManualSectionSet.isEmpty == false{
            tableView.reloadSections(emptyManualSectionSet, with: .fade)
        }
        
        if allowsInsertingSection, downloadManager.sortType == .manual, let visibleIPs = tableView.indexPathsForVisibleRows{
            var visibleSections = Set(visibleIPs.map({ $0.section }))
            if let topSection = visibleSections.min(), topSection > 0{
                visibleSections.insert(topSection - 1)
            }
            if let bottomSection = visibleSections.max(){
                visibleSections.insert(bottomSection + 1)
            }
            
            DispatchQueue.main.async(execute: {
                for section in visibleSections{
                    guard let headerView = self.tableView.headerView(forSection: section) else {continue}
                    guard let insertButton = headerView.viewWithTag(InsertButtonTag) as? HeaderButton else {continue}
                    insertButton.removeFromSuperview()
                    self.insertButtonQueue.append(insertButton)
                    headerView.textLabel?.text = self.downloadManager.titleForHeaderInSection(section)
                }
            })
        }
    }

    
    // MARK: - Title and Image
    lazy var iconPostfix: String = self.buttonIconFilled == true ? "_filled" : ""
    // MARK: Button Title
    lazy var startTitle = DMLS("Button.Start", comment: "Start Download")
    lazy var pauseTitle = DMLS("Button.Pause", comment: "Pause Download")
    lazy var stopTitle = DMLS("Button.Stop", comment: "Stop Download")
    lazy var deleteTitle = DMLS("Button.Delete", comment: "Delete Task and Related File")
    lazy var restartTitle = DMLS("Button.Restart", comment: "Redownload the File")
    lazy var resumeTitle = DMLS("Button.Resume", comment: "Resume Download")
    lazy var finishedTitle = DMLS("Button.Finished", comment: "Task is Finished")
    lazy var restoreTitle = DMLS("Button.Restore", comment: "Put Deleted Task Back to Download List")
    lazy var renameTitle = DMLS("Button.Rename", comment: "Change File Display Name")

    // MARK: Button Icon
    lazy var startIcon: UIImage? = UIImage(named: "Download" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var pauseIcon: UIImage? = UIImage(named: "Pause" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var stopIcon: UIImage? = UIImage(named: "Stop" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var resumeIcon: UIImage? = UIImage(named: "Resume" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var finishedIcon: UIImage? = UIImage(named: "Finish" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var restoreIcon: UIImage? = UIImage(named: "Restore", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var deleteIcon: UIImage? = UIImage(named: "Delete" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    lazy var smashIcon: UIImage? = UIImage(named: "Smash", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var removeIcon: UIImage? = UIImage(named: "Remove", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var insertIcon: UIImage? = UIImage(named: "Insert", in: DownloadManagerBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)

    // MARK: BarButton Title
    lazy var selectAllTitle: String = DMLS("Button.SelectAll", comment: "Select All Cells")
    lazy var unselectAllTitle: String = DMLS("Button.UnselectAll", comment: "Deselect All Cells")
    lazy var resumeAllTitle: String = DMLS("Button.ResumeAll", comment: "Resume All Unfinished Tasks")
    lazy var pauseAllTitle: String = DMLS("Button.PauseAll", comment: "Pause All Downloading Tasks")
    lazy var stopAllTitle: String = DMLS("Button.StopAll", comment: "Stop All Download")
    lazy var deleteAllTitle: String = DMLS("Button.DeleteAll", comment: "Delete All Tasks")

    lazy var sortButtonItemTitle: String = DMLS("Button.Sort", comment: "Sort Download List")
    lazy var adjustButtonItemTitle: String = DMLS("Button.Adjust", comment: "Adjust MaxDownload")

    // MARK: BarButton Icon
    lazy var selectedImage: UIImage? = UIImage(named: "Selected", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var unselectedImage: UIImage? = UIImage(named: "Unselected", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var sortButtonImage: UIImage? = UIImage(named: "Sort", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var adjustButtonImage: UIImage? = UIImage(named: "PlusMinus" + self.iconPostfix, in: DownloadManagerBundle, compatibleWith: nil)
    
    // MARK: - Display notification
    private func showNotificationLabel(with infoString: String){
        if let window = UIApplication.shared.keyWindow{
            let notificationLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            notificationLabel.numberOfLines = 0
            notificationLabel.textAlignment = .center
            notificationLabel.layer.cornerRadius = 5
            notificationLabel.layer.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
            notificationLabel.text = infoString
            notificationLabel.textColor = UIColor.white
            window.addSubview(notificationLabel)
            notificationLabel.center = window.center
            self.perform(#selector(removeNotificationLabel(_:)), with: notificationLabel, afterDelay: 2)
        }
    }
    
    @objc private func removeNotificationLabel(_ label: UILabel){
        UIView.animate(withDuration: 0.25, animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }
}

extension DownloadListController{
    // MARK: - Download File in Predefined Sort Mode - Sort By AddTime
    /**
     Download a group of new files in predefined sort mode(downloadManager.sortType != .manual).
     
     - precondition: `displayContent == .downloadList` && `downloadManager.sortType != .manual`.
     
     - parameter URLStrings: The String array of download URL. Repeated or invalid URL will be filtered. 
     It's your responsibility to encode URL string if it contains Non-ASCII charater. Use
     `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` or computed property
     `percentEncodingURLQueryString` in the extension to encode string.
     */
    public func downloadFiles(atURLStrings URLStrings: [String]) {
        guard downloadManager.sortType != .manual else{return}
        
        switch displayContent {
        case .downloadList:
            let sortTypeIsAddTime: Bool = downloadManager.sortType == .addTime
            let oldSectionCount = downloadManager.sectionCount
            guard let insertedIndexPaths = downloadManager.download(URLStrings) else{return}
            
            // Actually here just need reloadData(), I want to show the process by animation, and only work in AddTime.
            if sortTypeIsAddTime == false{
                tableView.reloadData()
            }else{
                if downloadManager.sectionCount != oldSectionCount{
                    let newSection = insertedIndexPaths.first!.section
                    tableView.insertSections(IndexSet(integer: newSection), with: .top)
                }else{
                    tableView.insertRows(at: insertedIndexPaths, with: .top)
                    // After insert rows, rows which are behind insert location should update index.
                    if downloadManager.sortOrder == .descending{
                        updateCellIndexMark()
                    }
                }
            }
//        case .unfinishedList:
//            if let _ = downloadManager.download(URLStrings){
//                let oldCount = unfinishedList.count
//                unfinishedList = downloadManager.unfinishedList
//                let addCount = unfinishedList.count - oldCount
//                var insertedIndexPaths: [IndexPath] = []
//                for row in 0..<addCount {
//                    insertedIndexPaths.append(IndexPath(row: row, section: 0))
//                }
//                tableView.insertRows(at: insertedIndexPaths, with: .top)
//                tableView.reloadData()
//            }
        default: return
        }
        
        self.updateCellIndexMark()
        if trackActivityEnabled{
            downloadManager.beginTrackingDownloadActivity()
        }
    }
    
    // MARK: Download File in Manual Sort Mode - Insert Section
    /**
     Download a group of new files in manual mode and insert in the download list at the section which 
     you specify.
     
     - precondition: `displayContent == .downloadList` && `downloadManager.sortType == .manual`.
     
     - parameter URLStrings: The String array of download URL. Repeated or invalid URL will be filtered.
     - parameter section: Section location in the download list. If index is beyond bounds, nothing happen.
     - parameter sectionTitle: Title for section header view.
     */
    public func downloadFiles(atURLStrings URLStrings: [String], inManualModeAtSection section: Int, sectionTitle: String){
        guard displayContent != .toDeleteList else{return}
        guard downloadManager.sortType == .manual else{return}
        
        switch displayContent {
        case .downloadList:
            if downloadManager.download(URLStrings, inManualModeAtSection: section, withTitle: sectionTitle){
                tableView.insertSections(IndexSet(integer: section), with: .top)
            }
        default: return
        }
        
        self.updateCellIndexMark()
        if trackActivityEnabled{
            downloadManager.beginTrackingDownloadActivity()
        }
    }

    /**
     Download several groups of new files in manual mode and insert in the download list at the section
     which you specify.
     
     - precondition: `displayContent == .downloadList` && `downloadManager.sortType == .manual`.
     
     - parameter URLStringsList: A two-dimensional array of download URL string. Repeated or invalid URL
     will be filtered.
     - parameter section: Section location in the download list. If index is beyond bounds, nothing happen.
     - parameter sectionTitles: Titles for section header view. Its count must be equal to count of
     parameter `URLStringsList`, otherwise nothing happen. Tips: There is no header view in UITableView if its
     section title is empty string.
     */
    public func downloadFilesList(_ URLStringsList: [[String]], inManualModeAtSection section: Int, sectionTitles: [String]){
        guard downloadManager.sortType == .manual else{return}
        
        switch displayContent {
        case .downloadList:
            guard let indexSet = downloadManager.download(URLStringsList, inManualModeAtSection: section, withTitles: sectionTitles) else{return}
            tableView.insertSections(indexSet, with: .top)
        default: return
        }
        
        self.updateCellIndexMark()
        if trackActivityEnabled{
            downloadManager.beginTrackingDownloadActivity()
        }
    }

    // MARK: Download File in Manual Sort Mode - Insert Row
    /**
     Download a group of new files in manual mode and insert in the download list at the location which 
     you specify.
     
     - precondition: `displayContent == .downloadList` && `downloadManager.sortType == .manual`.
     
     - parameter URLStrings: The String array of download URL. Repeated or invalid URL will be filtered.
     - parameter indexPath: Insert location in the download list. If it's beyond the bounds, nothing happen.
     */
    public func downloadFiles(atURLStrings URLStrings: [String], inManualModeAt indexPath: IndexPath){
        guard downloadManager.sortType == .manual else{return}
        
        switch displayContent {
        case .downloadList:
            guard let indexPaths = downloadManager.download(URLStrings, inManualModeAt: indexPath) else{return}
            tableView.insertRows(at: indexPaths, with: .top)
        default: return
        }
        
        self.updateCellIndexMark()
        if trackActivityEnabled{
            downloadManager.beginTrackingDownloadActivity()
        }
    }
}

class HeaderButton: UIButton {
    var section: Int = -1
}
