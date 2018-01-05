//
//  SDEDownloadTrackCell.swift
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
 `DownloadTrackerCell` is the default UITableViewCell used in `DownloadListController`. Its style is 
 `.subtitle`. 
  ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/CellTypeA.png)
 
 It adds three subviews:
 
 1. a UILabel to display download speed;
 2. a UIProgressView to display download progress;
 3. a UIButton to pause/resume download.
 
 These three views are customizable in `DownloadListController`:
 
 1. `allowsTrackingSpeed`: determine whether to display speed.
 2. `allowsTrackingProgress`: determine whether to display download progress bar.
 3. `cellAccessoryButtonStyle`: custom button appearance and action method.
 
 For any type UITableViewCell in `DownloadListController`, their `imageView` and `textLabel` are 
 customziable:
 
 1. `cellImageViewStyle`: display an icon, or index, or none.
 2. `isFileNamePriorThanURL`: display file name or its download URL.
 */
open class DownloadTrackerCell: UITableViewCell{
    static var removeLeftMargin: Bool = true
    static var detailLabelFontSize: CGFloat = 12 //UILabel's default font size is 17 points.
    static var displaySpeedInfo: Bool = false
    static var displayProgressInfo: Bool = false
    static var displayProgressView: Bool = false
    static var displayAccessoryButton: Bool = false
    // accessoryButton need bigger width to display title here.
    static var buttonWider: Bool = false
    
    /// A UILabel to display download speed.
    public var speedLabel: UILabel?
    /// A UIProgressView to display download progress.
    public var progressView: UIProgressView?
    /// A UIButton to be contentView's accessortView.
    public private(set) var accessoryButton: UIButton?
    private var editingAccessoryButton: UIButton?
    weak var accessoryButtonDelegate: AccessoryButtonDelegate?
//    var fileIdentifier: String = "PlaceHolderForFileIdentifier"
    
    /// Init from storyboard/nib file. You should set its style to `.subtitle` in the storyboard/nib file.
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureContent()
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        configureContent()
    }
    
    /// Change subview backgroundColor to cell backgroundColor
    override open func didMoveToSuperview() {
        detailTextLabel?.font = UIFont.systemFont(ofSize: DownloadTrackerCell.detailLabelFontSize)
        // How prevent pixel blending of view? You maybe hear about 'opaque' property. Actually, it's very limited. Here is detail (https://developer.apple.com/reference/uikit/uiview/1622622-isopaque ):
        // "You only need to set a value for the opaque property in subclasses of UIView that draw their own content using the draw(_:) method. The opaque property has no effect in system-provided classes such as UIButton, UILabel, UITableViewCell, and so on."
        // Override draw(_:)? It's not necessary in general scene. The key of an opaque view is that its content is opaque, which means its backup layer's content must be apaque. About CALayer's 'opaque' property, https://developer.apple.com/reference/quartzcore/calayer/1410763-isopaque,
        // "Setting this property affects only the backing store managed by Core Animation. If you assign an image with an alpha channel to the layer’s contents property, that image retains its alpha channel regardless of the value of this property."
        
        // After move to superView, cell's backgroundColor is not nil any more. If set backgroundColor of textLabel and detailLabel to nil 
        // before this method is called, backgroundColor of textLabel and detailLabel will be seted to cell's backgroundColor, which is 
        // a private color and opaque. Prevent pixel blending:
        textLabel?.clipsToBounds = true
        textLabel?.backgroundColor = backgroundColor
        detailTextLabel?.clipsToBounds = true
        detailTextLabel?.backgroundColor = backgroundColor
        
        if DownloadTrackerCell.displaySpeedInfo{
            speedLabel?.clipsToBounds = true
            speedLabel?.backgroundColor = backgroundColor
        }
        
        if DownloadTrackerCell.displayAccessoryButton{
            accessoryButton?.titleLabel?.clipsToBounds = true
            accessoryButton?.titleLabel?.backgroundColor = backgroundColor
            
            editingAccessoryButton?.titleLabel?.clipsToBounds = true
            editingAccessoryButton?.titleLabel?.backgroundColor = backgroundColor
        }
    }
    
    func configureContent(){
        textLabel?.lineBreakMode = .byTruncatingMiddle
        detailTextLabel?.textColor = UIColor.gray
                
        if DownloadTrackerCell.displaySpeedInfo && DownloadTrackerCell.displayProgressInfo{
            speedLabel = UILabel()
            speedLabel?.translatesAutoresizingMaskIntoConstraints = false
            speedLabel?.font = UIFont.systemFont(ofSize: DownloadTrackerCell.detailLabelFontSize)
            speedLabel?.textColor = UIColor.gray
            contentView.addSubview(speedLabel!)
            
            let toItem: Any! = detailTextLabel == nil ? textLabel : detailTextLabel
            // Contraint warning issue only on iOS 8.1 and 8.2(test on simulator):
            // Warning once only: Detected a case where constraints ambiguously suggest a height of zero for a tableview cell's content view. We're considering the collapse unintentional and using standard height instead.
            let heightConstraint = NSLayoutConstraint(item: speedLabel!, attribute: .height, relatedBy: .equal, toItem: toItem, attribute: .height, multiplier: 1, constant: 0)
            let widthConstraint = NSLayoutConstraint(item: speedLabel!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0, constant: 70)
            widthConstraint.priority = .defaultLow
            let centerYConstraint = NSLayoutConstraint(item: speedLabel!, attribute: .centerYWithinMargins, relatedBy: .equal, toItem: toItem, attribute: .centerYWithinMargins, multiplier: 1, constant: 0)
            let trailContraint = NSLayoutConstraint(item: speedLabel!, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: 0)
            trailContraint.priority = .defaultHigh
            NSLayoutConstraint.activate([heightConstraint, centerYConstraint, widthConstraint, trailContraint])
        }
        
        if DownloadTrackerCell.displayAccessoryButton{
            accessoryButton = UIButton(type: .system)
            editingAccessoryButton = UIButton(type: .system)

            let buttonWidth: CGFloat = DownloadTrackerCell.buttonWider ? 60 : 50
            
            accessoryButton?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: self.bounds.height)
            accessoryButton?.addTarget(self, action: #selector(DownloadTrackerCell.touchAccessoryButton(_:for:)), for: .touchUpInside)
            accessoryView = accessoryButton!
            
            editingAccessoryButton?.isEnabled = false
            editingAccessoryButton?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: self.bounds.height)
            editingAccessoryButton?.setTitleColor(UIColor.gray, for: .normal)
            editingAccessoryView = editingAccessoryButton!
        }
        
        if DownloadTrackerCell.displayProgressView{
            progressView = UIProgressView(progressViewStyle: .default)
            progressView?.translatesAutoresizingMaskIntoConstraints = false
            progressView?.progressTintColor = tintColor
            addSubview(progressView!)
            
            NSLayoutConstraint(item: progressView!, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: progressView!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: progressView!, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0).isActive = true
        }
        
        if DownloadTrackerCell.removeLeftMargin{
            // Remove blank space between table left edge and cell separator line.
            preservesSuperviewLayoutMargins = false //Ignore super's layout margins setting. Although the default is false, still to assign once to make it work.
            // the follow two properties must all be Zero
            layoutMargins = UIEdgeInsets.zero
            separatorInset = UIEdgeInsets.zero
        }
    }
    
    @objc func touchAccessoryButton(_ button: UIButton, for controlEvents: UIControlEvents) {
        accessoryButtonDelegate?.tableViewCell(self, didTouch: button, for: controlEvents)
    }
    
    // MARK: DownloadActivityTrackable Protocol Method
//    func assignFileIdentifier(identifier: String) {
//        self.fileIdentifier = identifier
//    }
    
    func assignAccessoryButtonDeletegate(_ delegate: AccessoryButtonDelegate) {
        if DownloadTrackerCell.displayAccessoryButton{
            accessoryButtonDelegate = delegate
        }
    }
    
    func updateDetailInfo(_ info: String?) {
        if detailTextLabel?.text != info{
            detailTextLabel?.text = info
        }
    }
    
    func updateSpeedInfo(_ info: String?) {
        if let label = speedLabel{
            if label.text != info{
                label.text = info
            }
        }else if detailTextLabel?.text != info{
            detailTextLabel?.text = info
        }
    }
        
    func updateProgressValue(_ progress: Float) {
        progressView?.setProgress(progress, animated: false)
    }
    
    func updateAccessoryButtonState(_ enabled: Bool, title: String) {
        accessoryButton?.isEnabled = enabled
        accessoryButton?.setTitle(title, for: .normal)
        editingAccessoryButton?.setTitle(title, for: .normal)
    }
    
    func updateAccessoryButtonState(_ enabled: Bool, image: UIImage?) {
        accessoryButton?.isEnabled = enabled
        accessoryButton?.setImage(image, for: .normal)
        editingAccessoryButton?.setImage(image, for: .normal)
    }
    
//    override open func willTransition(to state: UITableViewCellStateMask) {
//        super.willTransition(to: state)
//        switch state {
//        // tableView enters editing and don't show reorder control
//        case UITableViewCellStateMask.showingEditControlMask:
//            NSLog("Table view enter edit mode")
//        // Left Swipe: show a row action
//        case UITableViewCellStateMask.showingDeleteConfirmationMask:
//            NSLog("Cell will show a row action")
//        // It's complex, no rule.
//        default:
//            break
//        }
//    }

}

