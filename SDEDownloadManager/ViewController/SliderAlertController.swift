//
//  SliderAlertController.swift
//  SDEDownloadManager
//
//  Created by seedante on 8/12/17.
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
 A UIViewController subclass like UIAlertController to display a slider.
 ![](https://raw.githubusercontent.com/seedante/iOS-Note/master/SDEDownloadManager/PresentSliderAlertController.png)
 */
@objcMembers
public class SliderAlertController: UIViewController, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {
    let preferredWidth: CGFloat = 270
    let preferredHeight: CGFloat = 140
    let actionButtonHeight: CGFloat = 44
    let sliderValueViewWidth: CGFloat = 31
    let splitlineWidth: CGFloat
    
    let bodyView: UIView = UIView()
    let titleLabel: UILabel = UILabel()
    let messageLabel: UILabel = UILabel()
    let currentValueLabel: UILabel = UILabel()
    let slider: UISlider = UISlider()
    let minValueLabel: UILabel = UILabel()
    let maxValueLabel: UILabel = UILabel()
    let cancelButton: UIButton = UIButton(type: .system)
    let confirmButton: UIButton = UIButton(type: .system)
    var confirmClosure: (_ sliderValue: Float) -> Void
    
    var message: String?
    var confirmTitle: String?
    
    // MARK: Initializer
    /// SliderAlertController's designated init method.
    ///
    /// - Parameters:
    ///   - title: The title of the slider view.
    ///   - message: Additional information for the slider view. The default value is nil.
    ///   - minimumValue: The slider's minimum value. If this value is not small than maximumValue, 
    ///   this value will be 0 and slider's maximum value will be 20.
    ///   - maximumValue: The slider's maximum value. If this value is not larger than minimumValue, 
    ///   this value will be 20 and slider's minimum value will be 0.
    ///   - initialValue: The slider's initial value.
    ///   - confirmTitle: The custom title for confirm button. The default is nil. If this value is nil,
    ///   the title of confirm button is "Confirm".
    ///   - confirmClosure: A closure to execute after user touch confirm button.
    ///   - sliderValue: The current value of slider. If `allowsDecimal == false`, its decimal will be moved and just `x.0`.
    public init(title: String, message: String? = nil, minimumValue: Float, maximumValue: Float, initialValue: Float, confirmTitle: String? = nil, confirmClosure: @escaping (_ sliderValue: Float) -> Void){
        self.confirmClosure = confirmClosure
        // If simulator's window scale is not 100%, sometimes split line can't be distinguished.
        splitlineWidth = 1 / UIScreen.main.scale
        super.init(nibName: nil, bundle: nil)
        
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        
        if minimumValue < maximumValue{
            slider.minimumValue = minimumValue
            slider.maximumValue = maximumValue
        }else{
            slider.minimumValue = 0
            slider.maximumValue = 20
        }
        
        if initialValue >= slider.minimumValue && initialValue <= slider.maximumValue{
            slider.value = initialValue
        }
        
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    /// Not implemented. Don't init from storyboard/nib file.
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) for SliderAlertController is not implemented.")
    }
    
    // MARK: Custom Options
    /// A Boolean value that decides whether remove slider value's decimal part in view and confirmClosure.
    /// The default value is false.
    public var allowsDecimal: Bool = false
    /// A Dictionary which store the symbol to replace slider value to display on the slider block.
    /// For example: I want to express no limit when it's 0, set a symbol: `floatToSymbolMap[0] = "∞"`.
    public var floatToSymbolMap: Dictionary<Float, String> = [:]

    // MARK: Lifecycle
    /// This method is called after the controller has loaded its view hierarchy into memory.
    /// But when the controller load its view hierarchy? Before it presents or access any view
    /// in the view hierarchy if controller isn't presented yet. Called only once.
    override public func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        configureAlertBody()
        configureActionButtons()
        updateValueLabel()
    }
    
    /// Called every time the view controller is about to be presented. Layout is not finished yet.
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // presentingView go into grayscale mode, just like a UIAlertController presented.
        self.presentingViewController?.view.tintAdjustmentMode = .dimmed
    }
    
    /// Configure layout of subViews.
    override public func viewWillLayoutSubviews() {
        view.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: preferredWidth, height: preferredHeight + splitlineWidth))
        view.center = view.superview!.center
    }
    
    /// Called every time the view controller is presented.
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // currentValueLabel's location is based on slider's block, and here view's layout is finished.
        let width: CGFloat = allowsDecimal ? sliderValueViewWidth + 50.0 : sliderValueViewWidth
        currentValueLabel.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: 21))
        currentValueLabel.center = CGPoint(x: (slider.subviews[2].center.x + sliderValueViewWidth), y: 50)
        
        currentValueLabel.alpha = 0
        UIView.animate(withDuration: 0.25, animations: {
            self.currentValueLabel.alpha = 1
        })
    }
    
    private func configureAlertBody(){
        let bodyViewHeight = preferredHeight - actionButtonHeight - splitlineWidth
        bodyView.frame = CGRect(x: 0, y: 0, width: preferredWidth, height: bodyViewHeight)
        bodyView.backgroundColor = UIColor.white

        let titleHeight: CGFloat = 30
        titleLabel.frame = CGRect(x: 0, y: 0, width: preferredWidth, height: titleHeight)
        titleLabel.text = title
        titleLabel.textAlignment = .center
        
        messageLabel.frame = CGRect(x: 0, y: 19, width: preferredWidth, height: 21)
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 10)
        messageLabel.text = message
        
        // currentValueLabel's frame must be calculated after slider's subviews appear
        currentValueLabel.textAlignment = .center
        
        let sliderOriginY: CGFloat = bodyViewHeight - 35
        let valueViewSize: CGSize = CGSize(width: sliderValueViewWidth, height: sliderValueViewWidth)
        
        minValueLabel.frame = CGRect(origin: CGPoint(x: 0, y: sliderOriginY), size: valueViewSize)
        minValueLabel.text = String(Int(slider.minimumValue))
        minValueLabel.textAlignment = .center
        maxValueLabel.frame = CGRect(origin: CGPoint(x: preferredWidth - sliderValueViewWidth, y: sliderOriginY), size: valueViewSize)
        maxValueLabel.text = String(Int(slider.maximumValue))
        maxValueLabel.textAlignment = .center
        
        // UISlider has a fixed height: 31
        slider.frame = CGRect(x: sliderValueViewWidth, y: sliderOriginY, width: preferredWidth - sliderValueViewWidth * 2, height: sliderValueViewWidth)
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        bodyView.addSubview(titleLabel)
        bodyView.addSubview(messageLabel)
        bodyView.addSubview(currentValueLabel)
        bodyView.addSubview(minValueLabel)
        bodyView.addSubview(slider)
        bodyView.addSubview(maxValueLabel)

        view.addSubview(bodyView)
    }
    
    @objc private func sliderValueChanged(){
        // move with slider's block
        currentValueLabel.center.x = slider.subviews[2].center.x + sliderValueViewWidth
        updateValueLabel()
    }
    
    private func updateValueLabel(){
        let sliderValue: Float = allowsDecimal ? slider.value : Float(Int(slider.value))
        if let specialText = floatToSymbolMap[sliderValue]{
            currentValueLabel.text = specialText
        }else{
            currentValueLabel.text = allowsDecimal ? String(sliderValue) : String(Int(slider.value))
        }
    }

    private func configureActionButtons(){
        cancelButton.addTarget(self, action: #selector(dismissAlert), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        
        let titleColor: UIColor = view.tintColor
        let actionButtonY = (preferredHeight - actionButtonHeight)
        
        cancelButton.frame = CGRect(x: 0, y: actionButtonY, width: (preferredWidth - splitlineWidth) / 2, height: actionButtonHeight)
        cancelButton.backgroundColor = UIColor.white
        cancelButton.setTitle(cancelActionTitle, for: .normal)
        cancelButton.setTitleColor(titleColor, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        
        confirmButton.frame = CGRect(x: (preferredWidth + splitlineWidth) / 2, y: actionButtonY, width: (preferredWidth - splitlineWidth) / 2, height: actionButtonHeight)
        confirmButton.backgroundColor = UIColor.white
        if confirmTitle != nil{
            confirmButton.setTitle(confirmTitle, for: .normal)
        }else{
            confirmButton.setTitle(confirmActionTitle, for: .normal)
        }
        confirmButton.setTitleColor(titleColor, for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        
        view.addSubview(cancelButton)
        view.addSubview(confirmButton)
    }
    
    // MARK: Alert Action
    @objc private func dismissAlert(){
        let presentingView = self.presentingViewController?.view
        dismiss(animated: true, completion: {
            // Recovery presentingView's color from grayscale mode
            presentingView?.tintAdjustmentMode = .normal
        })
    }

    @objc private func confirmAction(){
        let sliderValue: Float = allowsDecimal ? slider.value : Float(Int(slider.value))
        confirmClosure(sliderValue)
        dismissAlert()
    }
    
    // MARK: UIViewControllerTransitioningDelegate
    /// Return animation delegate to provide presentation animation.
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    /// Return animation delegate to provide dismiss animation.
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }

    // MARK: UIViewControllerAnimatedTransitioning
    /// Time of transition animation.
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    private let dimmingView = UIView()
    /// Commit transition animation here.
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from), let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else{
            return
        }
        
        let duration = self.transitionDuration(using: transitionContext)
        
        // Present Alert
        if toVC.isBeingPresented{
            containerView.addSubview(toVC.view)
            containerView.insertSubview(dimmingView, belowSubview: toVC.view)
            dimmingView.center = containerView.center
            dimmingView.bounds = containerView.frame
            dimmingView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
            dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            dimmingView.alpha = 0
            
            toVC.view.transform = CGAffineTransform(scaleX: 1, y: 0.8)
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 3, options: UIViewAnimationOptions.allowAnimatedContent, animations: {
                self.dimmingView.alpha = 1
                toVC.view.transform = CGAffineTransform.identity
                }, completion: {_ in
                    let isCancelled = transitionContext.transitionWasCancelled
                    transitionContext.completeTransition(!isCancelled)
            })
            
        }
        // Dismiss Alert
        if fromVC.isBeingDismissed{
            UIView.animate(withDuration: duration, animations: {
                fromVC.view.alpha = 0
                self.dimmingView.alpha = 0
                }, completion: { _ in
                    let isCancelled = transitionContext.transitionWasCancelled
                    transitionContext.completeTransition(!isCancelled)
            })
        }
    }

}
