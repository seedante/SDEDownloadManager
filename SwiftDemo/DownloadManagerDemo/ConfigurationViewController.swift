//
//  ConfigurationViewController.swift
//  SwiftDMDemo
//
//  Created by seedante on 7/25/17.
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
import SDEDownloadManager

/*
 The follow URL strings are too long to display completely in the iPhone device, so I suggest that you build server to test.
 
 It's easy to setup a apache server in your mac to test:
 1. Put whatever files you want to test in /Library/WebServer/Documents/
 2. Lanch server: open Terminal and input command: "sudo apachectl start"
 3. Visit server by: http://localhost/ (just on your simulator) or your mac local IP like 192.168.1.xxx
 
 Actually, everytime you put file in /Library/WebServer/Documents/, system ask you for admin password, that's annoying.
 /Library/WebServer/Documents/ is the default root directory of Apache server for request, change it in file: /etc/apache2/httpd.conf. 
 General softwares can't edit this file. You could edit it in terminal by vi or emacs, like: "sudo vi /etc/apache2/httpd.conf".
 
 Find the line: DocumentRoot "/Library/WebServer/Documents/", change content in "" to any directory which you want.
 If the follow content is existed, change it also:
 <Directory "/Library/WebServer/Documents/">
 xxxx
 </Directory>

 If apache server is lanched already, restart it: "sudo apachectl restart".
 */
var candidateTaskURLStringList: [String] = [
    "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8",
    
    // Auth: ServerTrust
    "https://developer.apple.com/sample-code/wwdc/2015/downloads/Advanced-NSOperations.zip",
    "https://codeload.github.com/seedante/OptimizationForOffscreenRender/zip/master",
        
    // WWDC 2016
    "http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/images/402_734x413.jpg",
    "http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
    "http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_hd_whats_new_in_swift.mp4?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_sd_whats_new_in_swift.mp4?dl=1",

    "http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/images/711_734x413.jpg",
    "http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_nsurlsession_new_features_and_best_practices.pdf",
    "http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_hd_nsurlsession_new_features_and_best_practices.mp4?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_sd_nsurlsession_new_features_and_best_practices.mp4?dl=1",
    
    // WWDC 2015
    "http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/images/106_734x413.jpg",
    "http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_whats_new_in_swift.pdf?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_hd_whats_new_in_swift.mp4?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_sd_whats_new_in_swift.mp4?dl=1",
    
    "http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/images/711_734x413.jpg",
    "http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_networking_with_nsurlsession.pdf?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_hd_networking_with_nsurlsession.mp4?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_sd_networking_with_nsurlsession.mp4?dl=1",
    
    "http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/images/226_734x413.jpg",
    "http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_advanced_nsoperations.pdf?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_hd_advanced_nsoperations.mp4?dl=1",
    "http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_sd_advanced_nsoperations.mp4?dl=1",
    "https://developer.apple.com/sample-code/wwdc/2015/downloads/Advanced-NSOperations.zip",

    // WWDC 2014
    "http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_introduction_to_swift.pdf",
    "http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_hd_introduction_to_swift.mov",
    "http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_sd_introduction_to_swift.mov",
    
    "http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_whats_new_in_foundation_networking.pdf",
    "http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_hd_whats_new_in_foundation_networking.mov",
    "http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_sd_whats_new_in_foundation_networking.mov",
]

extension DeleteMode{
    public var description: String{
        switch self {
        case .fileAndRecord:
            return "FileAndRecord"
        case .onlyFile:
            return "OnlyFile"
        case .optional:
            return "Optional"
        }
    }
}

extension CellImageViewStyle{
    public var description: String{
        switch self {
        case .thumbnail:
            return "Thumbnail"
        case .index:
            return "Index"
        case .none:
            return "None"
        }
    }
}

extension ThumbnailShape{
    public var description: String{
        switch self {
        case .original:
            return "Original"
        case .square:
            return "Square"
        }
    }
}

extension AccessoryButtonStyle{
    public var description: String{
        switch self {
        case .icon:
            return "Icon"
        case .title:
            return "Title"
        case .none:
            return "None"
        case .custom:
            return "Custom"
        }
    }
}


class ConfigurationViewController: UIViewController {

    override func viewDidLoad() {
//        let appDocumentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
//        let appDirectory = appDocumentDirectory.replacingOccurrences(of: "Documents", with: "")
//        print("App directory location: \(appDirectory)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.navigationController?.setToolbarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        downloadManager.reproduceDataToCount(500)
        
//        let destroyed = SDEDownloadManager.destoryManager("TTTT")
//        NSLog("Destoryed: \(destroyed)")
//
//        let qos: [DispatchQoS.QoSClass] = [.userInteractive, .userInitiated, .`default`, .utility, .background, .unspecified]
//        NSLog("Test thread safe of init")
//        for _ in 1...100{
//            let randomIndex = Int(arc4random_uniform(6))
//            let currentQoS = qos[randomIndex]
//            DispatchQueue.global(qos: currentQoS).async(execute: {
//                let dm = SDEDownloadManager.manager(identifier: "TTTT")
//                NSLog("DM: \(dm)")
//            })
//        }
        
//        let dm = downloadManager
//        let qos: [DispatchQoS.QoSClass] = [.userInteractive, .userInitiated, .`default`, .utility, .background, .unspecified]
//        NSLog("Test thread safe of saveData()")
//        for i in 1...1000 {
//            let randomIndex = Int(arc4random_uniform(6))
//            let currentQoS = qos[randomIndex]
//            DispatchQueue.global(qos: currentQoS).async(execute: {
//                NSLog("Iterate \(i) begin: \(currentQoS)")
//                dm.saveData()
//                NSLog("Iterate \(i) end: \(currentQoS)")
//            })
//        }

    }
    
    // MARK: Download Manager
    lazy var downloadManager: SDEDownloadManager = SDEDownloadManager.manager(identifier: "DM-Swift-Demo")
    
    // MARK: Present Download List
    var listVC: DownloadListController?
    var listVCInitedFromStoryboard: Bool = false
    @IBAction func displayDownloadActivity(_ sender: AnyObject) {
        if listVCInitedFromStoryboard{
            self.performSegue(withIdentifier: "Segue0", sender: self)
        }else{
            presentListVCProgrammatically()
        }
    }
    
    func presentListVCProgrammatically(){
        listVC = DownloadListController.init(downloadManager: downloadManager)
        configurateListVC()
        self.navigationController?.pushViewController(listVC!, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        listVC = segue.destination as? DownloadListController
        listVC?.downloadManager = downloadManager
        // If vc is inited from storyboard, here its view is not loaded.
        // We can access root view to load views by force(trigger loadView() and viewDidLoad()).
        _ = listVC?.view
        configurateListVC()
    }
    
    func configurateListVC(){
        let dm = listVC!.downloadManager
        
        // other options not listed
        downloadManager.sectioningAddTimeList = true
        downloadManager.indexingFileNameList = false
        downloadManager.sectioningFileSizeList = true
        listVC?.allowsEditingSectionTitle = true
        listVC?.allowsInsertingSection = true
        listVC?.allowsRenamingFile = true
        listVC?.shouldExitEditModeAfterConfirmAction = true
        listVC?.shouldRemoveEmptySection = false
        
        // select display content
        listVC?.displayContent = displayContent
        if listVC!.downloadManager.isDataLoaded{
//            let title: String = listVC?.downloadManager.maxDownloadCount == -1 ? "Max: ∞" : "Max: \(dm.maxDownloadCount)"
//            listVC?.title = title
            
            if displayContent == .subsection{
                listVC?.subsectionIndex = Int(arc4random_uniform(UInt32(dm.sectionCount)))
            }
        }
        
        // cell appearance
        listVC?.cellImageViewStyle = cellImageViewStyle
        listVC?.fileThumbnailShape = fileThumbnailShape
        listVC?.cellAccessoryButtonStyle = actionButtonStyle
        
        // track download activity
        listVC?.allowsTrackingSpeed = allowsTrackingSpeed
        listVC?.allowsTrackingDownloadDetail = allowsTrackingDownloadDetail
        listVC?.allowsTrackingProgress = allowsTrackingProgress
        
        // button appearance
        listVC?.barButtonAppearanceStyle = barButtonAppearanceStyle
        listVC?.buttonIconFilled = buttonIconFilled
        
        // features in swipe gesture
        listVC?.allowsStop = allowsStop
        listVC?.allowsRedownload = allowsRedownload
        listVC?.allowsDeletion = allowsDeletion
        listVC?.allowsRestoration = allowsRestoration
        listVC?.deleteMode = deleteMode
        
        // multiple task management
        listVC?.allowsEditingByEditButtonItem = allowsEditingByEditButtonItem
        listVC?.allowsEditingByLongPress = allowsEditingByLongPress
        listVC?.allowsManagingAllTasksOnToolBar = allowsManagingAllTasksOnToolBar
        
        // sort view
        listVC?.allowsSwitchingSortMode = allowsSwitchingSortMode
        listVC?.shouldDisplaySortOrderInSortView = shouldDisplaySortOrderInSortView
        
        // scroll perfermance
        listVC?.tableView.rowHeight = cellHeight
        listVC?.scrollSpeedThresholdForPerformance = scrollSpeedThreshold
        
        // custom download manager
        listVC?.downloadManager.downloadNewFileImmediately = startToDownloadImmediately
        listVC?.downloadManager.isTrashOpened = isTrashOpened
        
        
        // handle background launch. Don't test on simulator.
        listVC?.downloadManager.backgroundSessionDidFinishEventsHandler = { session in
            let finishNotification = UILocalNotification()
            finishNotification.alertBody = "Download is over."
            if #available(iOS 8.2, *) {
                finishNotification.alertTitle = "SwiftDMDemo"
            } else {
                // Fallback on earlier versions
            }
            
            UIApplication.shared.presentLocalNotificationNow(finishNotification)
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            if let updateScreenshotHandler = appDelegate.updateScreenshotHandler{
                OperationQueue.main.addOperation({ [weak self] in
                    NSLog("refresh screen in background and update screenshot")
                    // refresh screen in backgroud
                    self?.listVC?.tableView.reloadData()
                    // update screenshot
                    updateScreenshotHandler()
                })
            }
        }
        
        listVC?.toolBarActions = [.resumeAll, .pauseAll, .stopAll, .deleteAll]
        listVC?.navigationItem.rightBarButtonItems = [listVC!.sortButtonItem]//, listVC!.adjustButtonItem, addTaskButtonItem]
    }
    
    // MARK: Add Download Task
    lazy var addTaskButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDownloadTask(_:)))
    @objc func addDownloadTask(_ buttonItem: UIBarButtonItem){
        URLPickerVC.preferredContentSize = CGSize(width: Int(UIScreen.main.bounds.width - 20), height: Int(UIScreen.main.bounds.height - 50))
        URLPickerVC.modalPresentationStyle = .popover
        URLPickerVC.popoverPresentationController?.barButtonItem = buttonItem
        URLPickerVC.popoverPresentationController?.delegate = listVC
        
        URLPickerVC.adjustsCellFontSizeToFitWidth = true
        URLPickerVC.isFileNamePriorThanURL = true
        URLPickerVC.shouldDisplayTinyURLAtCellTop = true
        
        listVC?.present(URLPickerVC, animated: true, completion: nil)
    }
    
    let sectionTitles: [String] = ["Metal Gear Solid ", "TitanFall ", "Halo ", "Call of Duty ", "Uncharted ",  "Tomb Raider ",  "Final Fantasy ", "Grand Theft Auto ", "Assassin's Creed ", "龍が如く ",]
    func splitIntoTwoArrayWithURLStrings(_ URLStrings:[String]) -> (URLStrings: [[String]], titles: [String]){
        let randomTitle = "RandomTitle: "
        
        if URLStrings.count <= 1{
            return ([URLStrings, []], [randomTitle + sectionTitles[Int(arc4random_uniform(10))] + String(arc4random_uniform(UInt32(sectionTitles.count))), ""])
        }else{
            let splitIndex = Int(arc4random_uniform(UInt32(URLStrings.count)))
            let title1 = randomTitle + sectionTitles[Int(arc4random_uniform(10))] + String(arc4random_uniform(UInt32(sectionTitles.count)))
            let title2 = randomTitle + sectionTitles[Int(arc4random_uniform(10))] + String(arc4random_uniform(UInt32(sectionTitles.count)))
            return ([Array(URLStrings[0..<splitIndex]), Array(URLStrings[splitIndex..<URLStrings.count])], [title1, title2])
        }
    }
    
    lazy var URLPickerVC: URLPickerController = URLPickerController.init(URLStrings: candidateTaskURLStringList, pickCompletionHandler: { selectedURLStrings in
        if self.downloadManager.sortType == .manual{
            if self.downloadManager.sectionCount == 0{
                let title = "RandomTitle: " + self.sectionTitles[Int(arc4random_uniform(10))] + String(arc4random_uniform(20))
                self.listVC?.downloadFiles(atURLStrings: selectedURLStrings, inManualModeAtSection: 0, sectionTitle: title)
                return
            }
            
            let randomInt = arc4random_uniform(100)
            let insertSection: Int = Int(arc4random_uniform(UInt32(self.downloadManager.sectionCount)))
            switch randomInt % 2{
            case 0: // insert sections
                NSLog("Add A New Section")
                let tasksAndTitles = self.splitIntoTwoArrayWithURLStrings(selectedURLStrings)
                let insertSectionSeed = arc4random_uniform(3)
                self.listVC?.downloadFilesList(tasksAndTitles.URLStrings, inManualModeAtSection: insertSection, sectionTitles: tasksAndTitles.titles)
            case 1: // insert rows
                NSLog("Insert into a existed section")
                let rowSeed = self.downloadManager.taskCountInSection(insertSection)
                let insertRow = Int(arc4random_uniform(UInt32(rowSeed)))
                self.listVC?.downloadFiles(atURLStrings: selectedURLStrings, inManualModeAt: IndexPath(row: insertRow, section: insertSection))
            default: break
            }
        }else{
            self.listVC?.downloadFiles(atURLStrings: selectedURLStrings)
        }
    })


    // MARK: - Custom DownloadListController
    // MARK: Select Display Content
    var displayContent: ListContent = .downloadList
    @IBAction func selectDisplayContent(_ segmenter: UISegmentedControl) {
        displayContent = ListContent.init(rawValue: segmenter.selectedSegmentIndex)!
    }

    // MARK: Cell Appearance: imageView, accessoryView
    var cellImageViewStyle: CellImageViewStyle = .thumbnail
    @IBAction func selectImageViewStyle(_ segmenter: UISegmentedControl) {
        cellImageViewStyle = CellImageViewStyle(rawValue: segmenter.selectedSegmentIndex)!
        NSLog("ImageViewStyle: \(cellImageViewStyle.description)")
    }
    
    
    var fileThumbnailShape: ThumbnailShape = .original
    @IBAction func selectThumbnailShape(_ segmenter: UISegmentedControl) {
        fileThumbnailShape = ThumbnailShape(rawValue: segmenter.selectedSegmentIndex)!
        NSLog("thumbnailShape: \(fileThumbnailShape.description)")
    }
    
    var actionButtonStyle: AccessoryButtonStyle = .icon
    @IBAction func switchActionButtonStyle(_ segmenter: UISegmentedControl) {
        actionButtonStyle = AccessoryButtonStyle(rawValue: segmenter.selectedSegmentIndex)!
        NSLog("ButtonStyle: \(actionButtonStyle.description)")
    }

    
    // MARK: Track Download Activity in Cell
    var allowsTrackingSpeed: Bool = true
    @IBAction func switchTrackSpeedFeature(_ switcher: UISwitch) {
        NSLog("allowsTrackingSpeed: \(switcher.isOn)")
        allowsTrackingSpeed = switcher.isOn
    }
 
    var allowsTrackingDownloadDetail: Bool = true
    @IBAction func switchTrackProgressTextFeature(_ switcher: UISwitch) {
        NSLog("trackProgressTextEnabled: \(switcher.isOn)")
        allowsTrackingDownloadDetail = switcher.isOn
    }
    
    var allowsTrackingProgress: Bool = true
    @IBAction func switchProgressValueFeature(_ switcher: UISwitch) {
        NSLog("allowsTrackingProgress: \(switcher.isOn)")
        allowsTrackingProgress = switcher.isOn
        
    }
    
    // MARK: Button Appearance
    var barButtonAppearanceStyle: BarButtonAppearanceStyle = .title
    @IBAction func selectBarButtonItemStyle(_ segmenter: UISegmentedControl) {
        barButtonAppearanceStyle = segmenter.selectedSegmentIndex == 0 ? .icon : .title
    }
    
    var buttonIconFilled: Bool = true
    @IBAction func selectButtonIconStyle(_ segmenter: UISegmentedControl) {
        buttonIconFilled = Bool(truncating: segmenter.selectedSegmentIndex as NSNumber)
    }
    
    // MARK: Features in Swipe Gesture
    var allowsStop: Bool = false
    @IBAction func SwitchStopFeatureInCellSwipe(_ switcher: UISwitch) {
        NSLog("allowsStop: \(switcher.isOn)")
        allowsStop = switcher.isOn
    }
    
    var allowsRedownload: Bool = false
    @IBAction func switchRedownloadFeatureInCellSwipe(_ switcher: UISwitch) {
        NSLog("allowsRedownload: \(switcher.isOn)")
        allowsRedownload = switcher.isOn
    }

    var allowsRestoration: Bool = false
    @IBAction func switchRestorationInCellSwipe(_ switcher: UISwitch) {
        NSLog("allowsRestoration: \(switcher.isOn)")
        allowsRestoration = switcher.isOn
    }
    
    var allowsDeletion: Bool = false
    @IBAction func switchDeleteFeatureInCellSwipe(_ switcher: UISwitch) {
        NSLog("allowsDelete: \(switcher.isOn)")
        allowsDeletion = switcher.isOn
    }
    
    var deleteMode: DeleteMode = .fileAndRecord
    @IBAction func selectDeleteTaskType(_ segmenter: UISegmentedControl) {
        deleteMode = DeleteMode(rawValue: segmenter.selectedSegmentIndex)!
        NSLog("deleteMode: \(deleteMode.description)")
    }
    
    // MARK: Multiple Task Management
    var allowsEditingByEditButtonItem: Bool = false
    @IBAction func switchMultipleSelectModeByEditButtonItem(_ switcher: UISwitch) {
        NSLog("MultipleSelectMode: \(switcher.isOn)")
        allowsEditingByEditButtonItem = switcher.isOn
    }
    
    var allowsEditingByLongPress: Bool = false
    @IBAction func switchMultipleSelectModeByLongPressFeature(_ switcher: UISwitch) {
        NSLog("MultipleSelectModeByLongPress: \(switcher.isOn)")
        allowsEditingByLongPress = switcher.isOn
    }
    
    var allowsManagingAllTasksOnToolBar: Bool = false
    @IBAction func switchToolBarFeature(_ switcher: UISwitch) {
        NSLog("allowsManagingAllTasksOnToolBar: \(switcher.isOn)")
        allowsManagingAllTasksOnToolBar = switcher.isOn
    }
    
    var allowsSwitchingSortMode: Bool = false
    @IBAction func switchSortMode(_ switcher: UISwitch) {
        NSLog("allowsSwitchingSortMode: \(switcher.isOn)")
        allowsSwitchingSortMode = switcher.isOn
    }
    
    var shouldDisplaySortOrderInSortView: Bool = false
    @IBAction func switchSortOrder(_ switcher: UISwitch) {
        NSLog("shouldDisplaySortOrderInSortView: \(switcher.isOn)")
        shouldDisplaySortOrderInSortView = switcher.isOn
    }
    

    // MARK: Scroll Performance
    @IBOutlet weak var cellHeightLabel: UILabel!
    var cellHeight: CGFloat = 44
    @IBAction func changeCellHeight(_ slider: UISlider) {
        let slideValue = Int(slider.value)
        cellHeight = CGFloat(slideValue)
        cellHeightLabel.text = "CellHeight: \(slideValue)"
    }
    
    @IBOutlet weak var scrollSpeedThresholdLabel: UILabel!
    var scrollSpeedThreshold: Int = 10
    @IBAction func changeScrollSpeedThreshold(_ slider: UISlider) {
        scrollSpeedThreshold = Int(slider.value)
        scrollSpeedThresholdLabel.text = "ScrollThreshold: \(scrollSpeedThreshold)"
    }


    // MARK: - DownloadManager Settings
    var startToDownloadImmediately: Bool = true
    @IBAction func downloadImmediatelyOrNot(_ segmenter: UISegmentedControl) {
        startToDownloadImmediately = Bool(truncating: segmenter.selectedSegmentIndex as NSNumber)
    }
    
    var isTrashOpened: Bool = false
    @IBAction func switchTrashCan(_ segmenter: UISegmentedControl) {
        isTrashOpened = Bool(truncating: segmenter.selectedSegmentIndex as NSNumber)
    }
    
}
