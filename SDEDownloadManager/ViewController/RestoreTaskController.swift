//
//  RestoreTaskController.swift
//  SDEDownloadManager
//
//  Created by seedante on 7/4/17.
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

internal class RestoreTaskController: UITableViewController, UITextFieldDelegate {
    var downloadManager: SDEDownloadManager
    var downloadList: [[String]] = []
    var sectionTitleList: [String] = []
    var confirmClosure: ((_ restoreLocation: IndexPath) -> Void)?
    let cellIdentifier: String = String(describing: UITableViewCell.self)
    var targetLocation: IndexPath = IndexPath(row: -1, section: -1){
        didSet{
            if targetLocation.section < 0{
                navigationItem.rightBarButtonItem?.isEnabled = false
            }else{
                navigationItem.rightBarButtonItem?.isEnabled = true
            }
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.downloadManager = SDEDownloadManager.placeHolderManager
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.downloadManager = SDEDownloadManager.placeHolderManager
        super.init(coder: aDecoder)
    }

    lazy var placeHolderFileName = DMLS("Restore to Here!", comment: "Content for Cell in Restore Location")
    var placeHolderSectionTitle: String?
    
    init(downloadManager: SDEDownloadManager, restoreHandler: @escaping (_ location: IndexPath) -> Void){
        self.downloadManager = downloadManager
        super.init(style: .plain)
        
        self.confirmClosure = restoreHandler
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        if ProcessInfo().operatingSystemVersion.majorVersion == 8{
            self.downloadManager = downloadManager
        }
        
        self.downloadList = downloadManager.sortedURLStringsList
        self.sectionTitleList = downloadManager.sectionTitleList
        
        if downloadList.count > 0{
            var sectionHead = downloadList[0]
            sectionHead.insert(placeHolderFileName, at: 0)
            downloadList[0] = sectionHead
            targetLocation = IndexPath(row: 0, section: 0)
        }
    }
    
    override func viewDidLoad() {
        tableView.setEditing(true, animated: false)
        if #available(iOS 9.0, *) {
            // Coordinate with cell-level margin setting to remove blank space between table left edge and cell separator line.
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
        // Hide Blank Cell
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        navigationItem.rightBarButtonItem = restoreButtonItem
    }
    
    var isPresented: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        if targetLocation.section == -1{
            restoreButtonItem.isEnabled = false
        }
        isPresented = isBeingPresented
    }
    
    // MARK: Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return downloadList.count > 0 ? downloadList.count : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section < downloadList.count ? downloadList[section].count : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        // Remove left blank space
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets.zero
        cell.separatorInset = UIEdgeInsets.zero

        if indexPath == targetLocation{
            cell.textLabel?.text = placeHolderFileName
            cell.contentView.addSubview(restoreButton)
            restoreButton.frame = cell.contentView.bounds
        }else{
            cell.textLabel?.text = downloadManager.fileDisplayName(ofTask: downloadList[indexPath.section][indexPath.row])
        }
        return cell
    }
    
    // MARK: Highlight Cell
    // isHighlighted is not valid in `tableView(_:cellForRowAtIndexPath:)`
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath == targetLocation{
            // Mock highlight color. And must disable selection color to custom highlight color
            // But there is a bug if have to add a placeholder section and tap "Return" key to end input:
            // contentView's color is not same with other part and color is gray.
            cell.selectionStyle = .none
            cell.backgroundColor = view.tintColor
            // Above code is not enough, when you drag cell, cell.backgroundColoe change to transparent,
            // if want to keep highlight color in moving, it's necessary to enable isHighlighted. And if
            // cell.selectionStyle != .None, highlight color alwaya be grey, so need to disable
            // cell's selectionColor by setting cell.selectionStyle = .None.
            cell.setHighlighted(true, animated: false)
        }
        else{
            cell.setHighlighted(false, animated: true)
        }
    }
    
    // MARK: HeaderView
    // If 'func tableView(tableView: UITableView, viewForHeaderInSection section: Int)' return a view, title which returned by this method will be ignored.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitleList.count > section ? sectionTitleList[section] : nil
    }
    
    // height must > 0, otherwise no header view.
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Header/Footer view's default height is 28
        return downloadList.count > 0 ? 28 : 40
    }

    // UITableView's headerViewForSection: won't return view in this delegate method, just return nil.
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if sectionTitleList.count > 0{
            return nil
        }else{
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 40))
            headerView.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1)
            headerView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
            
            let actionButton = UIButton.init(type: UIButtonType.roundedRect)
            actionButton.addTarget(self, action: #selector(insertPlaceHolderSection), for: .touchUpInside)
            actionButton.setTitle(DMLS("Add New Section", comment: "PlaceHolder Section Title for Empty DownloadList in Manual Mode"), for: .normal)
            actionButton.frame = headerView.bounds
            actionButton.center = headerView.center
            headerView.addSubview(actionButton)
            return headerView
        }
    }
    
    // MARK: Display Reorder Control at the Right of Cell
    // filter cell to display reorder control
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if indexPath == targetLocation{
            return true
        }else{
            return false
        }
    }
    
    // Two conditions:
    // 1. tableView's editing = true
    // 2. implement 'func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath)'
    // You can move cell even this method do nothing, it's different with tableView's 'func moveRow(at: IndexPath, to: IndexPath)', which must update data source before move cell.
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else{return}
        targetLocation = destinationIndexPath
        // It's OK even data is not updated. Er, there is a little display problem if any cell is out of screen.
        if sourceIndexPath.section == destinationIndexPath.section{
            var section = downloadList[sourceIndexPath.section]
            let fileName = section.remove(at: sourceIndexPath.row)
            section.insert(fileName, at: destinationIndexPath.row)
            downloadList[sourceIndexPath.section] = section
        }else{
            var sourceSection = downloadList[sourceIndexPath.section]
            let fileName = sourceSection.remove(at: sourceIndexPath.row)
            
            var destinationSection = downloadList[destinationIndexPath.section]
            destinationSection.insert(fileName, at: destinationIndexPath.row)
            
            downloadList[sourceIndexPath.section] = sourceSection
            downloadList[destinationIndexPath.section] = destinationSection
        }
    }

    //  remove the control view displayed on the left of cell.
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
    // MARK: Restore Action
    lazy var restoreButtonItem: UIBarButtonItem = UIBarButtonItem.init(title: DMLS("Button.Restore", comment: "Put Deleted Task Back to Download List"), style: .done, target: self, action: #selector(restore))
    lazy var restoreButton: UIButton = {
        let button = UIButton.init(type: UIButtonType.system)
        button.addTarget(self, action: #selector(restore), for: .touchUpInside)
        return button
    }()
    
    @objc func restore(){
        guard targetLocation.section >= 0 else{return}
        
        let alert = UIAlertController(title: DMLS("Restore to Highlighted Location?", comment: "Alert Title: Restore a Task"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmActionTitle, style: .default, handler: { _ in
            self.restoreToSpecifiedLocation()
        }))
        if isPresented{
            alert.addAction(UIAlertAction(title: cancelActionTitle, style: .default, handler: { _ in
                alert.dismiss(animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction.init(title: DMLS("Cancel and Return",
                                                           comment: "Alert Action Title: Cancel to Restore a Task and Return"),
                                               style: .default, handler: { _ in
                                                self.dismiss(animated: true, completion: nil)
            }))
        }else{
            alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        }
        self.present(alert, animated: true, completion: nil)
    }

    func restoreToSpecifiedLocation(){
        let toDeleteListCount = downloadManager.trashList.count
        if let sectionTitle = placeHolderSectionTitle{
            _ = downloadManager.insertPlaceHolderSectionInManualModeAtSection(0, withTitle: sectionTitle)
        }
        confirmClosure?(targetLocation)
        let restoreCount = toDeleteListCount - downloadManager.trashList.count
        downloadList = downloadManager.sortedURLStringsList
        sectionTitleList = downloadManager.sectionTitleList
        let restoreLocation = targetLocation
        targetLocation = IndexPath(row: -1, section: -1)
        if restoreCount > 1{
            var insertedIndexPaths: [IndexPath] = []
            (1..<restoreCount).forEach({ index in
                insertedIndexPaths.append(IndexPath(row: restoreLocation.row + index, section: restoreLocation.section))
            })
            tableView.insertRows(at: insertedIndexPaths, with: .left)
        }
        // reload should after insert
        tableView.reloadRows(at: [restoreLocation], with: .right)
        
        DispatchQueue.global().async(execute: {
            self.downloadManager.saveData()
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
            if let nv = self.navigationController{
                nv.popViewController(animated: true)
            }else{
                self.dismiss(animated: true, completion: nil)
            }
        })
    }
    
    // MARK: Insert New Section
    @objc func insertPlaceHolderSection(){
        let alert = UIAlertController.init(title: DMLS("Input Title for The Section", comment: "Alert Title: Input Section Title"), message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = DMLS("Section Title", comment: "PlaceHolder for UITextField to Input a Section Title")
            textField.clearButtonMode = .always
            // UITextField's Target-Action mode is better choice than delegate mode to handle editing and return event.
            textField.addTarget(self, action: #selector(RestoreTaskController.textFieldDidChange(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(RestoreTaskController.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
        })
        
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        
        confirmAction.isEnabled = false
        alert.addAction(confirmAction)
        self.present(alert, animated: true, completion: nil)
    }

    lazy var confirmAction: UIAlertAction = {
        return UIAlertAction(title: confirmActionTitle, style: .default, handler: { [unowned self] alertAction in
            if let sectionTitle = self.placeHolderSectionTitle{
                self.createMockDataWithTitle(sectionTitle)
            }
        })
    }()

    // if "Return" key is tapped, comfirmAction will be triggered.
    func createMockDataWithTitle(_ sectionTitle: String){
        if sectionTitleList.isEmpty{
            sectionTitleList.append(sectionTitle)
            downloadList.append([placeHolderFileName])
            targetLocation = IndexPath(row: 0, section: 0)
            tableView.reloadSections(IndexSet(integer: 0), with: .left)
        }
    }
    
    // MARK: Handle UITextField's editing and return.
    @objc func textFieldDidChange(_ textField: UITextField){
        if let text = textField.text, isNotEmptyString(text){
            confirmAction.isEnabled = true
            placeHolderSectionTitle = textField.text
        }else{
            confirmAction.isEnabled = false
            placeHolderSectionTitle = nil
        }
        
    }

    // .EditingDidEndOnExit is for tap 'Return' button on the keyboard. In delegate mode, there is no specifal method for tap 'Return' button.
    @objc func textFieldDidReturn(_ textField: UITextField){
        if let title = textField.text, isNotEmptyString(title){
            createMockDataWithTitle(title)
        }
    }
}
