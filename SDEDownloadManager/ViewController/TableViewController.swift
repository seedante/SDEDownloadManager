//
//  TableViewController.swift
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

/**
 A UITableViewController subclass which could enter multiple selection mode by editButtonItem. 
 `DownloadListController` is its subclass.
 */
open class SDETableViewController: UITableViewController{
    /// Overrided to enter edit mode, also multiple selection mode.
    override open var editButtonItem : UIBarButtonItem {return UIBarButtonItem(title: self.editButtonItemTitle, style: .plain, target: self, action: #selector(activateMultiSelectionMode))}
    
    /// Called after the controller has loaded its view hierarchy into memory.
    override open func viewDidLoad() {
        configureTableView()
    }
    
    private func configureTableView(){
        // Hide Blank Cell
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        if #available(iOS 9.0, *) {
            self.tableView.cellLayoutMarginsFollowReadableWidth = false
        }
    }

    
    /// On iOS 8, implement this method to [enable swipe feature](http://stackoverflow.com/questions/32270533/editactionsforrowatindexpath-not-executing-on-ios-8-with-xcode-7).
    override open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {}
    
    private lazy var editButtonItemTitle = DMLS("Button.Edit", comment: "Enter Edit Mode")
    private lazy var doneButtonItemTitle = DMLS("Button.Done", comment: "Exit Edit Mode")
    private lazy var _doneButtonItem: UIBarButtonItem = {UIBarButtonItem(title: self.doneButtonItemTitle, style: .plain, target: self, action: #selector(exitMultiSelectionMode))}()
    
    var previousRightBarButtonItems: [UIBarButtonItem]?
    var previousLeftBarButtonItems: [UIBarButtonItem]?
    var previousTitle: String?
    var previousTitleView: UIView?
    
    private func backupNavigationBarButtonItems(){
        previousRightBarButtonItems = navigationItem.rightBarButtonItems
        previousLeftBarButtonItems = navigationItem.leftBarButtonItems
        previousTitle = navigationItem.title
        previousTitleView = navigationItem.titleView
    }
    
    func restoreNavigationBarButtonItems(){
        navigationItem.setLeftBarButtonItems(previousLeftBarButtonItems, animated: true)
        navigationItem.setRightBarButtonItems(previousRightBarButtonItems, animated: true)
        
        if previousTitle != nil{
            navigationItem.title = previousTitle
        }else if previousTitleView != nil{
            navigationItem.titleView = previousTitleView
        }
    }
    
    func enterEditModeAndBackupButtons(){
        backupNavigationBarButtonItems()
        tableView.setEditing(true, animated: true)
        navigationItem.setRightBarButtonItems([_doneButtonItem], animated: true)
    }
    
    @objc func activateMultiSelectionMode(){
        // if allowsMultipleSelectionDuringEditing is false before tableView enter editing, cell left show delete or 
        // insert control, decided by tableView(_:editingStyleForRowAt:); if want to show a select control to select 
        // cell, this value must be true before tableView enter editing.
        tableView.allowsMultipleSelectionDuringEditing = true
        enterEditModeAndBackupButtons()
    }
    
    @objc func exitMultiSelectionMode(){
        tableView.allowsMultipleSelectionDuringEditing = false
        tableView.setEditing(false, animated: true)
        restoreNavigationBarButtonItems()
    }
}

/**
 A UIViewController subclass which mock `UITableViewController` and could enter multiple selection mode by editButtonItem
 */
class CustomTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    init(style: UITableViewStyle = .plain){
        super.init(nibName: nil, bundle: nil)
        let localTableView = UITableView(frame: CGRect.zero, style: style)
        self.tableView = localTableView
        configureTableView()
    }
    
    private func configureTableView(){
        view.addSubview(tableView)
        tableView.frame = view.frame
        tableView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        if #available(iOS 9.0, *) {
            // Coordinate with cell-level margin setting to remove black space between table left edge and cell separator line. 
            // Look DownloadTrackerCell's margin setting in configureContent().
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
        // Hide Blank Cell
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    

    // MARK: UITableView DataSoure - Configuring a Table View
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {return UITableViewCell()}
    func numberOfSections(in tableView: UITableView) -> Int {return 1}
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {return 0}
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {return nil}
    
    // MARK: UITableView DataSource - Inserting or Deleting Table Rows
    // On iOS 8, implement this method to enable Swipe feature: http://stackoverflow.com/questions/32270533/editactionsforrowatindexpath-not-executing-on-ios-8-with-xcode-7
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {}
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {return false}
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle{return .none}
    
    // MARK: UITableView DataSource - Reordering Table Rows
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {return false}
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {}

    // MARK: UITableView Delegate - Configuring Rows for the Table View
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {return 44}
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {}

    // MARK: UITableView Delegate - Managaing Accessory Views
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {return nil}

    // MARK: UITableView Delegate - Managing Selections
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {}
    
    // MARK: UITableView Delegate - Modifying the Header and Footer of Sections
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {return nil}
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {return 0} // Returned value must > 0, otherwise no header view. Default is 28 in UITableViewController.

    // MARK: UIScrollView Delegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {}

    // MARK: Edit/Normal Mode Switch
    private lazy var editButtonItemTitle = DMLS("Button.Edit", comment: "Enter Edit Mode")
    override var editButtonItem : UIBarButtonItem {return UIBarButtonItem(title: self.editButtonItemTitle, style: .plain, target: self, action: #selector(activateMultiSelectionMode))}
    private lazy var doneButtonItemTitle = DMLS("Button.Done", comment: "Exit Edit Mode")
    private lazy var _doneButtonItem: UIBarButtonItem = {UIBarButtonItem(title: self.doneButtonItemTitle, style: .plain, target: self, action: #selector(exitMultiSelectionMode))}()
    
    var previousRightBarButtonItems: [UIBarButtonItem]?
    var previousLeftBarButtonItems: [UIBarButtonItem]?
    var previousTitle: String?
    var previousTitleView: UIView?
    
    func backupNavigationBarButtonItems(){
        previousRightBarButtonItems = navigationItem.rightBarButtonItems
        previousLeftBarButtonItems = navigationItem.leftBarButtonItems
        previousTitle = navigationItem.title
        previousTitleView = navigationItem.titleView
    }
    
    func restoreNavigationBarButtonItems(){
        navigationItem.setLeftBarButtonItems(previousLeftBarButtonItems, animated: true)
        navigationItem.setRightBarButtonItems(previousRightBarButtonItems, animated: true)
        
        if previousTitle != nil{
            navigationItem.title = previousTitle
        }else if previousTitleView != nil{
            navigationItem.titleView = previousTitleView
        }
    }
    
    func enterEditModeAndBackupButtons(){
        backupNavigationBarButtonItems()
        tableView.setEditing(true, animated: true)
        navigationItem.setRightBarButtonItems([_doneButtonItem], animated: true)
    }
    
    @objc func activateMultiSelectionMode(){
        tableView.allowsMultipleSelectionDuringEditing = true
        enterEditModeAndBackupButtons()
    }
    
    @objc func exitMultiSelectionMode(){
        tableView.setEditing(false, animated: true)
        restoreNavigationBarButtonItems()
    }
}
