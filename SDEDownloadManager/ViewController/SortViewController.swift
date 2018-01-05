//
//  SortViewController.swift
//  SDEDownloadManager
//
//  Created by seedante on 8/1/17.
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

/// SortViewController offers sort options when you touch `sortButtonItem` in `DownloadListController`. 
/// It support five sort types and you could custom their order in list.
internal class SortViewController: SDETableViewController {
    /// A Boolean value indicating whether to display sort order options(.Ascending and .Descending) at the bottom.
    var displaySortOrder: Bool = true
    /// The preferred width for the view when it's displayed in a popover.
    var preferredWidth: Int = 220
    var panelHeight: Int = 364//6 * 44 + 2 * 30 + 40
    let headerHeight: Int = 30
    let buttonHeight: Int = 40
    let cellHeight: Int = 44
    let cellIdentifier = String(describing: UITableViewCell.self)
    var sortTypes: [ComparisonType] = [.addTime, .fileName, .fileSize, .fileType]
    var sortTypeAtCellIndex: Dictionary<Int, ComparisonType> = [:]
    
    let stringForSortTypeRawValue: Dictionary<Int, String> = [
       -1: "↕️  " + DMLS("SortType.Manual",  comment: "Switch to Manual Mode"),
        0: "🕒  " + DMLS("SortType.AddTime",  comment: "Sort by Add Time"),
        1: "🔠  " + DMLS("SortType.FileName", comment: "Sort by File Name"),
        2: "💤  " + DMLS("SortType.FileSize", comment: "Sort by File Size"),
        3: "📦  " + DMLS("SortType.FileType", comment: "Sort by File Type"),
    ]
    var sortListClosure: (ComparisonType, ComparisonOrder) -> Void = {_, _ in}
    var currentType: ComparisonType = .addTime
    var currentOrder: ComparisonOrder = .ascending
    var initialType: ComparisonType = .addTime
    var initialOrder: ComparisonOrder = .ascending
    var previousType: ComparisonType = .addTime
    let actionButton: UIButton = UIButton(type: .custom)
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    init(initialType: ComparisonType, initialOrder: ComparisonOrder, sortClosure: @escaping (ComparisonType, ComparisonOrder) -> ()) {
        super.init(style: .plain)
        self.currentType = initialType
        self.currentOrder = initialOrder
        self.initialType = initialType
        self.initialOrder = initialOrder
        self.previousType = initialType
        self.sortListClosure = sortClosure
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isScrollEnabled = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.allowsMultipleSelection = false
        tableView.sectionHeaderHeight = CGFloat(headerHeight)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // filter sortTypes
        var sortTypeSet = Set<Int>()
        let sortTypesCopy = sortTypes
        sortTypes.removeAll()
        sortTypesCopy.forEach({ type in
            if !sortTypeSet.contains(type.rawValue){
                sortTypeSet.insert(type.rawValue)
                sortTypes.append(type)
            }
        })
        
        for (index, type) in sortTypes.enumerated() {
            sortTypeAtCellIndex[index] = type
        }
        
        let titlesHeight = (initialType == .manual || !displaySortOrder) ? headerHeight : headerHeight * 2
        let cellsHeight = (initialType == .manual || !displaySortOrder) ? cellHeight * sortTypes.count : cellHeight * (sortTypes.count + 2)
        panelHeight = displaySortOrder ? titlesHeight + cellsHeight + buttonHeight : titlesHeight + cellsHeight
        self.preferredContentSize = CGSize(width: preferredWidth, height: panelHeight)
        
        if displaySortOrder{
            actionButton.frame = CGRect(x: 0, y: 0, width: preferredWidth, height: buttonHeight)
            actionButton.addTarget(self, action: #selector(dismissSortView), for: .touchUpInside)
            let buttonTitle: String = DMLS("Button.Sort", comment: "Sort Download List")
            actionButton.setTitle(buttonTitle, for: .normal)
            actionButton.backgroundColor = UIColor.gray//initialType == .manual ? view.tintColor : UIColor.gray
            actionButton.isEnabled = false//initialType == .manual ? true : false
            tableView.tableFooterView = actionButton
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return currentType == .manual ? 1 : (displaySortOrder ? 2 : 1)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? sortTypes.count : 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0{
            return DMLS("SortType", comment: "SortType Header Title")
        }else if currentType == .fileType{
            return DMLS("SortOrderInGroup", comment: "FileType SortOrder Header Title")
        }else{
            return DMLS("SortOrder", comment: "SortOrder Header Title")
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat(headerHeight)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        if indexPath.section == 0{
            let sortTypeInCell = sortTypeAtCellIndex[indexPath.row]!
            if sortTypeInCell == .manual && initialType == .manual{
                cell.accessoryType = .none
            }else if sortTypeInCell == currentType{
                cell.accessoryType = .checkmark
            }else{
                cell.accessoryType = .none
            }
            cell.textLabel?.text = stringForSortTypeRawValue[sortTypeInCell.rawValue]
        }else{
            cell.accessoryType = indexPath.row == currentOrder.rawValue ? .checkmark : .none

            var AscendingTitle: String
            var DescendingTitle: String

            switch currentType{
            case .addTime:
                AscendingTitle  = DMLS("AddTime Order: Old -> New", comment: "AddTime Ascending Order")
                DescendingTitle = DMLS("AddTime Order: New -> Old", comment: "AddTime Descending Order")
            case .fileName:
                AscendingTitle  = DMLS("FileName Order: A -> Z", comment: "FileName Ascending Order")
                DescendingTitle = DMLS("FileName Order: Z -> A", comment: "FileName Descending Order")
            case .fileSize:
                AscendingTitle  = DMLS("FileSize Order: Small -> Big", comment: "FileSize Ascending Order")
                DescendingTitle = DMLS("FileSize Order: Big -> Small", comment: "FileSize Descending Order")
            case .fileType:
                AscendingTitle  = DMLS("Inner Order: FileName: A -> Z", comment: "FileName Ascending Order in Section")
                DescendingTitle = DMLS("Inner Order: FileName: Z -> A", comment: "FileName Descending Order in Section")
            default:
                AscendingTitle = DMLS("Ascending", comment: "Ascending Order")
                DescendingTitle = DMLS("Descending", comment: "Descending Order")
            }
            cell.textLabel?.text = indexPath.row == 0 ? AscendingTitle :  DescendingTitle
        }
        
        // Remove black space between table left edge and cell separator line. 
        cell.preservesSuperviewLayoutMargins = false //Ignore super's layout margins setting. Although the default is false, still to assign once to make it work.
        // the follow two properties must all be Zero
        cell.layoutMargins = UIEdgeInsets.zero
        cell.separatorInset = UIEdgeInsets.zero

        return cell
    }
    
    // MARK: UITabelView Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0{
            currentType = sortTypeAtCellIndex[indexPath.row]!
            if displaySortOrder{
                if currentType == .manual{
                    if previousType != .manual{
                        tableView.deleteSections(IndexSet(integer: 1), with: .fade)
                    }
                    hiddenSortOderPart()
                }else{
                    if previousType == .manual{
                        tableView.insertSections(IndexSet(integer: 1), with: .fade)
                    }else{
                        tableView.reloadSections(IndexSet(integer: 1), with: .fade)
                    }
                    expendSortOrderPart()
                }
            }else{
                dismissSortView()
            }
            previousType = currentType
        }else{
            currentOrder = ComparisonOrder(rawValue: indexPath.row)!
        }
        
        if displaySortOrder{
            actionButton.isEnabled = initialType != .manual && currentType == initialType && currentOrder == initialOrder ? false : true
            
            UIView.animate(withDuration: 0.3, animations: {
                if self.actionButton.isEnabled{
                    self.actionButton.backgroundColor = self.view.tintColor!
                }else{
                    self.actionButton.backgroundColor = UIColor.gray
                }
            })
        }
        
        tableView.visibleCells.forEach({ cell in
            let cellIndexPath = tableView.indexPath(for: cell)!
            if cellIndexPath == indexPath{
                cell.accessoryType = .checkmark
            }else if cellIndexPath.section == indexPath.section{
                cell.accessoryType = .none
            }
        })
    }
    
    func hiddenSortOderPart(){
        panelHeight = headerHeight + cellHeight * sortTypes.count + buttonHeight
        UIView.animate(withDuration: 0.3, animations: {
            self.preferredContentSize = CGSize(width: self.preferredWidth, height: self.panelHeight)
        })
    }
    
    func expendSortOrderPart(){
        panelHeight = headerHeight * (displaySortOrder ? 2 : 1) + cellHeight * (sortTypes.count + 2) + buttonHeight
        UIView.animate(withDuration: 0.3, animations: {
            self.preferredContentSize = CGSize(width: self.preferredWidth, height: self.panelHeight)
        })
    }
    
    // MARK: Sort Action
    @objc func dismissSortView(){
        dismiss(animated: true, completion: {
            DispatchQueue.global().async(execute: {
                self.sortListClosure(self.currentType, self.currentOrder)
            })
        })
    }
}
