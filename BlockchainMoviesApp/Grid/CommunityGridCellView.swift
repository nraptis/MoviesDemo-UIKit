//
//  CommunityGridCellView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import UIKit
import SwiftUI

class CommunityGridCellView: UIView {
    
    var updates = 0
    
    lazy var imageView: UIImageView = {
        let result = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 512.0, height: 512.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.contentMode = .scaleAspectFill
        return result
    }()
    
    
    lazy var fillView: UIView = {
        let result = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.backgroundColor = DarkwingDuckTheme._gray200
        return result
    }()
    
    lazy var frameView: CommunityCellFrameView = {
        let result = CommunityCellFrameView(frame: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var loadingView: CommunityCellLoadingView = {
        let result = CommunityCellLoadingView(isShowing: false)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var bottomContentView: CommunityGridCellBottomContentView = {
        let result = CommunityGridCellBottomContentView(a: 1000)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var errorHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: CommunityCellErrorView(retryHandler: { [weak self] in
            if let self = self {
                let communityViewModel = self.communityViewModel
                let index = communityCellModel.index
                Task { @MainActor in
                    await communityViewModel.handleCellForceRetryDownload(at: index)
                }
            }
        }))
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = UIColor.clear
        return result
    }()
    
    lazy var missingContentHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: CommunityCellMissingContentView())
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = UIColor.clear
        return result
    }()
    
    lazy var nullImageHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: CommunityCellNullImageView())
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = UIColor.clear
        return result
    }()
    
    
    
    
    lazy var button: ColoredButton = {
        let result = ColoredButton(upColor: UIColor.clear, downColor: UIColor.black.withAlphaComponent(0.4))
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    var constraintLeft: NSLayoutConstraint?
    var constraintTop: NSLayoutConstraint?
    var constraintWidth: NSLayoutConstraint?
    var constraintHeight: NSLayoutConstraint?
    
    var isActive = false
    
    let communityViewModel: CommunityViewModel
    var communityCellModel: CommunityCellModel
    required init(communityViewModel: CommunityViewModel, communityCellModel: CommunityCellModel) {
        self.communityViewModel = communityViewModel
        self.communityCellModel = communityCellModel
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        self.translatesAutoresizingMaskIntoConstraints = false
        //self.backgroundColor = DarkwingDuckTheme._gray900
        
        self.backgroundColor = UIColor(red: CGFloat.random(in: 0.0...1.0),
                                       green: CGFloat.random(in: 0.0...1.0),
                                       blue: CGFloat.random(in: 0.0...1.0),
                                       alpha: 1.0)
        
        layer.cornerRadius = CommunityCellConstants.outerRadius
        clipsToBounds = true
        
        let frameFillLeft = CommunityCellConstants.outlineThickness + CommunityCellConstants.frameThickness
        let frameFillTop = CommunityCellConstants.outlineThickness + CommunityCellConstants.frameThickness
        let frameFillRight = -(CommunityCellConstants.outlineThickness + CommunityCellConstants.frameThickness)
        let frameFillBottom = -(CommunityCellConstants.outlineThickness + CommunityCellConstants.bottomAreaHeight - CommunityCellConstants.outlineThickness)
        
        addSubview(fillView)
        fillView.layer.cornerRadius = CommunityCellConstants.innerRadius
        fillView.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: fillView, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: fillView, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: fillView, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: fillView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
        addSubview(imageView)
        imageView.layer.cornerRadius = CommunityCellConstants.innerRadius
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.red
        addConstraints([
            NSLayoutConstraint(item: imageView, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: imageView, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: imageView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
        addSubview(frameView)
        frameView.layer.cornerRadius = CommunityCellConstants.innerRadius
        frameView.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: frameView, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: frameView, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: frameView, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: frameView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
        if let errorView = errorHostingViewController.view {
            addSubview(errorView)
            addConstraints([
                NSLayoutConstraint(item: errorView, attribute: .left, relatedBy: .equal, toItem: self,
                                   attribute: .left, multiplier: 1.0, constant: frameFillLeft),
                NSLayoutConstraint(item: errorView, attribute: .top, relatedBy: .equal, toItem: self,
                                   attribute: .top, multiplier: 1.0, constant: frameFillTop),
                NSLayoutConstraint(item: errorView, attribute: .right, relatedBy: .equal, toItem: self,
                                   attribute: .right, multiplier: 1.0, constant: frameFillRight),
                NSLayoutConstraint(item: errorView, attribute: .bottom, relatedBy: .equal, toItem: self,
                                   attribute: .bottom, multiplier: 1.0, constant: frameFillBottom)
            ])
        }
        
        if let missingContentView = missingContentHostingViewController.view {
            addSubview(missingContentView)
            addConstraints([
                NSLayoutConstraint(item: missingContentView, attribute: .left, relatedBy: .equal, toItem: self,
                                   attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
                NSLayoutConstraint(item: missingContentView, attribute: .top, relatedBy: .equal, toItem: self,
                                   attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
                NSLayoutConstraint(item: missingContentView, attribute: .right, relatedBy: .equal, toItem: self,
                                   attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
                NSLayoutConstraint(item: missingContentView, attribute: .bottom, relatedBy: .equal, toItem: self,
                                   attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
            ])
        }
        
        if let nullImageView = nullImageHostingViewController.view {
            addSubview(nullImageView)
            addConstraints([
                NSLayoutConstraint(item: nullImageView, attribute: .left, relatedBy: .equal, toItem: self,
                                   attribute: .left, multiplier: 1.0, constant: frameFillLeft),
                NSLayoutConstraint(item: nullImageView, attribute: .top, relatedBy: .equal, toItem: self,
                                   attribute: .top, multiplier: 1.0, constant: frameFillTop),
                NSLayoutConstraint(item: nullImageView, attribute: .right, relatedBy: .equal, toItem: self,
                                   attribute: .right, multiplier: 1.0, constant: frameFillRight),
                NSLayoutConstraint(item: nullImageView, attribute: .bottom, relatedBy: .equal, toItem: self,
                                   attribute: .bottom, multiplier: 1.0, constant: frameFillBottom)
            ])
        }
        
        addSubview(loadingView)
        addConstraints([
            NSLayoutConstraint(item: loadingView, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: loadingView, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: loadingView, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: loadingView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
        addSubview(button)
        button.layer.cornerRadius = CommunityCellConstants.innerRadius
        button.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: button, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: button, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
        button.addTarget(self, action: #selector(clickButton), for: .touchUpInside)
        
        addSubview(bottomContentView)
        addConstraints([
            NSLayoutConstraint(item: bottomContentView, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: bottomContentView, attribute: .height, relatedBy: .equal, toItem: nil,
                               attribute: .notAnAttribute, multiplier: 1.0, constant: CommunityCellConstants.bottomAreaHeight),
            NSLayoutConstraint(item: bottomContentView, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness),
            NSLayoutConstraint(item: bottomContentView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -CommunityCellConstants.outlineThickness)
        ])
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func clickButton() {
        Task { @MainActor in
            await communityViewModel.handleCellClicked(at: communityCellModel.index)
        }
    }
    
    func hide() {
        isHidden = true
        isUserInteractionEnabled = false
        isActive = false
        imageView.image = nil
    }
    
    func show(communityCellModel: CommunityCellModel) {
        self.communityCellModel = communityCellModel
        isHidden = false
        isUserInteractionEnabled = true
        isActive = true
        updateState()
    }
    
    private var _x = CGFloat(0.0)
    private var _y = CGFloat(0.0)
    private var _width = CGFloat(0.0)
    private var _height = CGFloat(0.0)
    func updateFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        
        if x != _x {
            _x = x
            if let constraintLeft = constraintLeft {
                constraintLeft.constant = _x
            }
        }
        
        if y != _y {
            _y = y
            if let constraintTop = constraintTop {
                constraintTop.constant = _y
            }
        }
        
        if width != _width {
            _width = width
            if let constraintWidth = constraintWidth {
                constraintWidth.constant = _width
            }
        }
        
        if height != _height {
            _height = height
            if let constraintHeight = constraintHeight {
                constraintHeight.constant = _height
            }
        }
    }
    
    func updateState() {
        
        let cellModelState = communityCellModel.cellModelState
        
        self.backgroundColor = UIColor(red: CGFloat.random(in: 0.0...1.0),
                                       green: CGFloat.random(in: 0.0...1.0),
                                       blue: CGFloat.random(in: 0.0...1.0),
                                       alpha: 1.0)
        
        switch cellModelState {
        case .downloading, .downloadingActively:
            
            switch cellModelState {
            case .downloadingActively:
                fillView.backgroundColor = DarkwingDuckTheme._gray400
            default:
                fillView.backgroundColor = DarkwingDuckTheme._gray200
            }
            
            if imageView.isHidden == false {
                imageView.isHidden = true
                imageView.isUserInteractionEnabled = false
            }
            if frameView.isHidden == false {
                frameView.isHidden = true
                frameView.isUserInteractionEnabled = false
                frameView.setNeedsDisplay()
            }
            if loadingView.isHidden == true {
                loadingView.show()
            }
            if bottomContentView.isHidden == false {
                bottomContentView.isHidden = true
                bottomContentView.isUserInteractionEnabled = false
            }
            if let errorView = errorHostingViewController.view {
                if errorView.isHidden == false {
                    errorView.isHidden = true
                    errorView.isUserInteractionEnabled = false
                }
            }
            if let missingContentView = missingContentHostingViewController.view {
                if missingContentView.isHidden == false {
                    missingContentView.isHidden = true
                    missingContentView.isUserInteractionEnabled = false
                }
            }
            if let nullImageView = nullImageHostingViewController.view {
                if nullImageView.isHidden == false {
                    nullImageView.isHidden = true
                    nullImageView.isUserInteractionEnabled = false
                }
            }
            if button.isHidden == false {
                button.isHidden = true
                button.isUserInteractionEnabled = false
            }
        case .success(_, _, let image):
            fillView.backgroundColor = DarkwingDuckTheme._gray200
            imageView.image = image
            if (imageView.isHidden == true) || (imageView.image !== image) {
                imageView.isHidden = false
                imageView.isUserInteractionEnabled = true
            }
            if frameView.isHidden == true {
                frameView.isHidden = false
                frameView.isUserInteractionEnabled = true
                frameView.setNeedsDisplay()
            }
            if loadingView.isHidden == false {
                loadingView.hide()
            }
            if bottomContentView.isHidden == true {
                bottomContentView.isHidden = false
                bottomContentView.isUserInteractionEnabled = true
            }
            if let errorView = errorHostingViewController.view {
                if errorView.isHidden == false {
                    errorView.isHidden = true
                    errorView.isUserInteractionEnabled = false
                }
            }
            if let missingContentView = missingContentHostingViewController.view {
                if missingContentView.isHidden == false {
                    missingContentView.isHidden = true
                    missingContentView.isUserInteractionEnabled = false
                }
            }
            if let nullImageView = nullImageHostingViewController.view {
                if nullImageView.isHidden == false {
                    nullImageView.isHidden = true
                    nullImageView.isUserInteractionEnabled = false
                }
            }
            if button.isHidden == true {
                button.isHidden = false
                button.isUserInteractionEnabled = true
            }
        case .error:
            fillView.backgroundColor = DarkwingDuckTheme._gray200
            if imageView.isHidden == false {
                imageView.isHidden = true
                imageView.isUserInteractionEnabled = false
            }
            if frameView.isHidden == true {
                frameView.isHidden = false
                frameView.isUserInteractionEnabled = true
                frameView.setNeedsDisplay()
            }
            if loadingView.isHidden == false {
                loadingView.hide()
            }
            if bottomContentView.isHidden == true {
                bottomContentView.isHidden = false
                bottomContentView.isUserInteractionEnabled = true
            }
            if let errorView = errorHostingViewController.view {
                if errorView.isHidden == true {
                    errorView.isHidden = false
                    errorView.isUserInteractionEnabled = true
                }
            }
            if let missingContentView = missingContentHostingViewController.view {
                if missingContentView.isHidden == false {
                    missingContentView.isHidden = true
                    missingContentView.isUserInteractionEnabled = false
                }
            }
            if let nullImageView = nullImageHostingViewController.view {
                if nullImageView.isHidden == false {
                    nullImageView.isHidden = true
                    nullImageView.isUserInteractionEnabled = false
                }
            }
            if button.isHidden == false {
                button.isHidden = true
                button.isUserInteractionEnabled = false
            }
        case .missingKey, .idle:
            fillView.backgroundColor = DarkwingDuckTheme._gray200
            if imageView.isHidden == false {
                imageView.isHidden = true
                imageView.isUserInteractionEnabled = false
            }
            if frameView.isHidden == true {
                frameView.isHidden = false
                frameView.isUserInteractionEnabled = true
                frameView.setNeedsDisplay()
            }
            if loadingView.isHidden == false {
                loadingView.hide()
            }
            if bottomContentView.isHidden == true {
                bottomContentView.isHidden = false
                bottomContentView.isUserInteractionEnabled = true
            }
            if let errorView = errorHostingViewController.view {
                if errorView.isHidden == false {
                    errorView.isHidden = true
                    errorView.isUserInteractionEnabled = false
                }
            }
            if let missingContentView = missingContentHostingViewController.view {
                if missingContentView.isHidden == false {
                    missingContentView.isHidden = true
                    missingContentView.isUserInteractionEnabled = false
                }
            }
            if let nullImageView = nullImageHostingViewController.view {
                if nullImageView.isHidden == true {
                    nullImageView.isHidden = false
                    nullImageView.isUserInteractionEnabled = true
                }
            }
            if button.isHidden == true {
                button.isHidden = false
                button.isUserInteractionEnabled = true
            }
        case .missingModel:
            fillView.backgroundColor = DarkwingDuckTheme._gray200
            if imageView.isHidden == false {
                imageView.isHidden = true
                imageView.isUserInteractionEnabled = false
            }
            if frameView.isHidden == false {
                frameView.isHidden = true
                frameView.isUserInteractionEnabled = false
            }
            if loadingView.isHidden == false {
                loadingView.hide()
            }
            if bottomContentView.isHidden == false {
                bottomContentView.isHidden = true
                bottomContentView.isUserInteractionEnabled = false
            }
            if let errorView = errorHostingViewController.view {
                if errorView.isHidden == false {
                    errorView.isHidden = true
                    errorView.isUserInteractionEnabled = false
                }
            }
            if let missingContentView = missingContentHostingViewController.view {
                if missingContentView.isHidden == true {
                    missingContentView.isHidden = false
                    missingContentView.isUserInteractionEnabled = true
                }
            }
            if let nullImageView = nullImageHostingViewController.view {
                if nullImageView.isHidden == false {
                    nullImageView.isHidden = true
                    nullImageView.isUserInteractionEnabled = false
                }
            }
            if button.isHidden == false {
                button.isHidden = true
                button.isUserInteractionEnabled = false
            }
        }
    }
}
