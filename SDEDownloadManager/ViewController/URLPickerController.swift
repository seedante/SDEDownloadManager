//
//  URLPickerController.swift
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

import UIKit

/**
 `URLPickerController` is just a UITableViewController subclass which allows multiple selection and execute
 a closure with selected strings. If string is not a valid URL, it won't be displayed in the list.
 
 Sometimes URL link is too long to display completedly in the cell, there are some options to improve it:
 
 1. `adjustsCellFontSizeToFitWidth`: The simplest way.
 2. `isFileNamePriorThanURL`: Only file name is enough sometimes.
 3. `shouldDisplayTinyURLAtCellTop`: File name loose its location info, fix it by a not very conspicuous way.
 */
@objcMembers open class URLPickerController: SDETableViewController {
    var candidateURLStringList: [String] = []
    var fileNameList: [String] = []
    var URLQueryEncodedFileNameList: [String] = []
    var asteriskURLStringList: [String] = []
    let cellIdentifier = String(describing: UITableViewCell.self)
    var dismissClosure: (_ selectedURLStrings: [String]) -> () = {_ in}
    var confirmTitle: String?
    
    // MARK: Initializer
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    /**
     The designated init method.
     
     - parameter URLStrings:            String Array. If string is not a valid URL, it will be filtered.
     - parameter pickCompletionHandler: The closure to execute after tap confirm button in the header view.
     - parameter selectedURLStrings:    It's sure that its count >= 1.
     - parameter pickButtonTitle:       Title for confirm and `nil` by default. The default title for confirm
     is "Pick".
     */
    public init(URLStrings: [String], pickCompletionHandler: @escaping (_ selectedURLStrings:[String]) -> (), pickButtonTitle: String? = nil) {
        super.init(style: .plain)
        self.dismissClosure = pickCompletionHandler
        self.confirmTitle = pickButtonTitle

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        self.tableView.allowsMultipleSelection = true
        
        self.candidateURLStringList = URLStrings.filter({URL(string: $0) != nil})
        self.fileNameList = self.candidateURLStringList.map({
            if let fileName = URL(string: $0)?.lastPathComponent{
                return fileName
            }else{
                return $0
            }
        })
        self.URLQueryEncodedFileNameList = self.candidateURLStringList.map({
            let components = $0.components(separatedBy: "/")
            if components.count > 1{
                return components.last!
            }else{
                return $0
            }
        })

        for (index, originalFileName) in self.URLQueryEncodedFileNameList.enumerated(){
            let components = originalFileName.components(separatedBy: ".")
            let replaceString: String
            if components.count > 1{
                replaceString = "***." + components.last!
            }else{
                replaceString = "***"
            }
            asteriskURLStringList.append(candidateURLStringList[index].replacingOccurrences(of: originalFileName, with: replaceString))
        }
    }
    
    /// No implemented. Don't init from storyboard/nib file.
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) for URLPickerController is not implemented.")
    }
    
    // MARK: Custom Option
    /**
     A Boolean value that determines to adjust font size in cell's textLabel to fit width. The default value
     is `false`. If URL link is not very long, this option is suitable, otherwise, it's better to use 
     `isFileNamePriorThanURL` and `shouldDisplayTinyURLAtCellTop`.
     */
    public var adjustsCellFontSizeToFitWidth: Bool = false
    /**
     A Boolean value that determines to display file name or URL link. The default value is `false`.
     When URL link is too long to display it completely, you could just display file name. If it's
     difficult to know where these files come from, you could display a tiny URL link, which is replaced
     with file name by "***", at the top of cell by `shouldDisplayTinyURLAtCellTop`.
     */
    public var isFileNamePriorThanURL: Bool = false
    /**
     A Boolean value that determines to display a tiny URL link, which is replaced with file name by "***",
     at the top of cell to tell where file comes from. The default value is `false`. It's better to enable
     `isFileNamePriorThanURL` if you want to enable this property.
     ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/LinkAtCellTop.png)
     */
    public var shouldDisplayTinyURLAtCellTop: Bool = false
    
    // MARK: - Table View Data Source
    /// Header view height: 40
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    /// Number of URL to pick.
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return candidateURLStringList.count
    }
    
    /// Create a cell before relative row display.
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.adjustsFontSizeToFitWidth = adjustsCellFontSizeToFitWidth
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
        if isFileNamePriorThanURL{
            cell.textLabel?.text = fileNameList[indexPath.row]
            if shouldDisplayTinyURLAtCellTop{
                let linkThumbnailLabel: UILabel
                if let label = cell.viewWithTag(1000) as? UILabel{
                    linkThumbnailLabel = label
                }else{
                    linkThumbnailLabel = UILabel(frame: CGRect(x: 5, y: 0, width: cell.frame.width - 5, height: 12))
                    // just adjustsFontSizeToFitWidth is not enough if frame is small, plus tiny font size is enough.
                    linkThumbnailLabel.adjustsFontSizeToFitWidth = true
                    linkThumbnailLabel.font = UIFont.systemFont(ofSize: 8)
                    linkThumbnailLabel.textColor = UIColor.gray
                    linkThumbnailLabel.tag = 1000
                    cell.addSubview(linkThumbnailLabel)
                }
                linkThumbnailLabel.text = asteriskURLStringList[indexPath.row]
            }
        }else{
            cell.textLabel?.text = candidateURLStringList[indexPath.row]
        }
        
        // Remove black space between table left edge and cell separator line. 
        // In iOS 9.x, must set tableView.cellLayoutMarginsFollowReadableWidth = false.
        cell.preservesSuperviewLayoutMargins = false //Ignore super's layout margins setting
        // the follow two properties must all be Zero
        cell.layoutMargins = UIEdgeInsets.zero
        cell.separatorInset = UIEdgeInsets.zero

        return cell
    }
    /// Provide custom header view. If it returns non-nil, tableView(_:titleForHeaderInSection:) is ignored.
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 40))
        headerView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        actionButton.frame = headerView.bounds
        actionButton.center = headerView.center
        headerView.addSubview(actionButton)
        return headerView
    }
    

    private var selectedIndexPathSet: Set<IndexPath> = []
    // MARK: UITableView Delegate
    /// If tableView.isEditing == false, this method is called after you select a cell if any of
    /// allowsSelection and allowsMultipleSelection is true; If tableView.isEditing == true, this
    /// method is called after you select a cell if any of allowsSelectionDuringEditing and
    /// allowsMultipleSelectionDuringEditing is true.
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndexPathSet.insert(indexPath)
        let title = self.confirmTitle != nil ? confirmTitle! : DMLS("Button.Pick", comment: "Pick Selected URLs")
        actionButton.setTitle(title, for: .normal)
    }
    /// If allowsSelection == true && allowsMultipleSelection == false, this method is called after
    /// you select another cell; if allowsMultipleSelection == true(allowsSelection is ignored),
    /// this method is called after you touch a selected cell(deselect). If tableView.isEditing == true,
    /// this method has same behaviors with edit version of these two properties: allowsSelectionDuringEditing
    /// and allowsMultipleSelectionDuringEditing.
    override open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectedIndexPathSet.remove(indexPath)
        if selectedIndexPathSet.isEmpty{
            actionButton.setTitle(cancelActionTitle, for: .normal)
        }
    }
    
    // MARK: - Button Action
    lazy var actionButton: UIButton = {
        let button = UIButton(type: UIButtonType.roundedRect)
        button.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        button.setTitle(cancelActionTitle, for: .normal)
        button.backgroundColor = self.view.tintColor
        button.setTitleColor(UIColor.white, for: .normal)
        button.addTarget(self, action: #selector(handleSelectedURLStrings), for: .touchUpInside)
        return button
    }()

    @objc func handleSelectedURLStrings(){
        var selectedURLStrings: [String] = []
        if self.selectedIndexPathSet.count > 0{
            selectedIndexPathSet.sorted(by: {$0.row > $1.row}).forEach({
                selectedURLStrings.append(candidateURLStringList.remove(at: $0.row))
                fileNameList.remove(at: $0.row)
                URLQueryEncodedFileNameList.remove(at: $0.row)
                asteriskURLStringList.remove(at: $0.row)
            })
            self.tableView.deleteRows(at: Array(selectedIndexPathSet), with: .fade)
            selectedIndexPathSet.removeAll()
            actionButton.setTitle(cancelActionTitle, for: .normal)
        }
        dismiss(animated: true, completion: {
            if selectedURLStrings.count > 0{
                self.dismissClosure(selectedURLStrings.reversed())
            }
        })
    }
}
