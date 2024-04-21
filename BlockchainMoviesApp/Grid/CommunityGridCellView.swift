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
        let result = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.contentMode = .scaleAspectFill
        return result
    }()
    
    lazy var loadingView: CellLoadingView = {
        let result = CellLoadingView(isShowing: false)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var errorHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: CommunityCellErrorView(retryHandler: {
            print("retry")
        }))
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = DarkwingDuckTheme._gray200
        return result
    }()
    
    lazy var missingContentHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: CommunityCellMissingContentView())
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = DarkwingDuckTheme._gray200
        return result
    }()
    
    lazy var button: ColoredButton = {
        let result = ColoredButton(upColor: UIColor.clear, downColor: UIColor.black.withAlphaComponent(0.4))
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var indexLabel: UILabel = {
        let result = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        result.textColor = UIColor.white
        result.font = UIFont.systemFont(ofSize: 22.0, weight: .semibold)
        result.textAlignment = .center
        result.layer.cornerRadius = 4.0
        result.clipsToBounds = true
        
        //TODO:
        //result.isHidden = true
        
        return result
    }()
    
    lazy var statusLabel: UILabel = {
        let result = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        result.textColor = UIColor.red
        result.font = UIFont.systemFont(ofSize: 22.0, weight: .semibold)
        result.textAlignment = .center
        result.layer.cornerRadius = 12.0
        result.clipsToBounds = true
        
        //TODO:
        //result.isHidden = true
        
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
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = DarkwingDuckTheme._gray900
        layer.cornerRadius = CommunityCellConstants.outerRadius
        clipsToBounds = true
        
        addSubview(imageView)
        imageView.backgroundColor = DarkwingDuckTheme._gray200
        imageView.layer.cornerRadius = CommunityCellConstants.innerRadius
        imageView.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: imageView,
                               attribute: .left,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .left,
                               multiplier: 1.0,
                               constant: 2.0),
            NSLayoutConstraint(item: imageView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .top,
                               multiplier: 1.0,
                               constant: 2.0),
            NSLayoutConstraint(item: imageView,
                               attribute: .right,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .right,
                               multiplier: 1.0,
                               constant: -2.0),
            NSLayoutConstraint(item: imageView,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: -2.0)
        ])
        
        addSubview(loadingView)
        loadingView.layer.cornerRadius = CommunityCellConstants.innerRadius
        loadingView.clipsToBounds = true
        //loadingView.show()
        addConstraints([
            NSLayoutConstraint(item: loadingView,
                               attribute: .left,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .left,
                               multiplier: 1.0,
                               constant: 2.0),
            
            NSLayoutConstraint(item: loadingView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .top,
                               multiplier: 1.0,
                               constant: 2.0),
            
            NSLayoutConstraint(item: loadingView,
                               attribute: .right,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .right,
                               multiplier: 1.0,
                               constant: -2.0),
            NSLayoutConstraint(item: loadingView,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: -2.0)
        ])
        
        /*
        if let errorView = errorHostingViewController.view {
            
            addSubview(errorView)
            errorView.clipsToBounds = true
            errorView.layer.cornerRadius = CommunityCellConstants.innerRadius
            
            addConstraints([
                NSLayoutConstraint(item: errorView,
                                   attribute: .left,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .left,
                                   multiplier: 1.0,
                                   constant: 2.0),
                
                NSLayoutConstraint(item: errorView,
                                   attribute: .top,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .top,
                                   multiplier: 1.0,
                                   constant: 2.0),
                
                NSLayoutConstraint(item: errorView,
                                   attribute: .right,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .right,
                                   multiplier: 1.0,
                                   constant: -2.0),
                NSLayoutConstraint(item: errorView,
                                   attribute: .bottom,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .bottom,
                                   multiplier: 1.0,
                                   constant: -2.0)
            ])
        }
        
        if let missingContentView = missingContentHostingViewController.view {
            
            addSubview(missingContentView)
            missingContentView.clipsToBounds = true
            missingContentView.layer.cornerRadius = CommunityCellConstants.innerRadius
            addConstraints([
                NSLayoutConstraint(item: missingContentView,
                                   attribute: .left,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .left,
                                   multiplier: 1.0,
                                   constant: CommunityCellConstants.lineThickness),
                
                NSLayoutConstraint(item: missingContentView,
                                   attribute: .top,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .top,
                                   multiplier: 1.0,
                                   constant: CommunityCellConstants.lineThickness),
                
                NSLayoutConstraint(item: missingContentView,
                                   attribute: .right,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .right,
                                   multiplier: 1.0,
                                   constant: -(CommunityCellConstants.lineThickness)),
                NSLayoutConstraint(item: missingContentView,
                                   attribute: .bottom,
                                   relatedBy: .equal,
                                   toItem: self,
                                   attribute: .bottom,
                                   multiplier: 1.0,
                                   constant: -(CommunityCellConstants.lineThickness))
            ])
        }
        */
        
        addSubview(button)
        button.layer.cornerRadius = CommunityCellConstants.innerRadius
        button.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: button,
                               attribute: .left,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .left,
                               multiplier: 1.0,
                               constant: 2.0),
            NSLayoutConstraint(item: button,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .top,
                               multiplier: 1.0,
                               constant: 2.0),
            NSLayoutConstraint(item: button,
                               attribute: .right,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .right,
                               multiplier: 1.0,
                               constant: -2.0),
            NSLayoutConstraint(item: button,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: -2.0)
        ])
        
        button.addTarget(self, action: #selector(clickButton), for: .touchUpInside)
        
        addSubview(indexLabel)
        addConstraints([
            NSLayoutConstraint(item: indexLabel,
                               attribute: .left,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .left,
                               multiplier: 1.0,
                               constant: 8.0),
            NSLayoutConstraint(item: indexLabel,
                               attribute: .right,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .right,
                               multiplier: 1.0,
                               constant: -8.0),
            NSLayoutConstraint(item: indexLabel,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: -8.0),
            NSLayoutConstraint(item: indexLabel,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: nil,
                               attribute: .notAnAttribute,
                               multiplier: 1.0,
                               constant: 36.0)
        ])
        
        
        addSubview(statusLabel)
        addConstraints([
            NSLayoutConstraint(item: statusLabel,
                               attribute: .left,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .left,
                               multiplier: 1.0,
                               constant: 8.0),
            NSLayoutConstraint(item: statusLabel,
                               attribute: .right,
                               relatedBy: .equal,
                               toItem: self,
                               attribute: .right,
                               multiplier: 1.0,
                               constant: -8.0),
            NSLayoutConstraint(item: statusLabel,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: indexLabel,
                               attribute: .top,
                               multiplier: 1.0,
                               constant: -8.0),
            NSLayoutConstraint(item: statusLabel,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: nil,
                               attribute: .notAnAttribute,
                               multiplier: 1.0,
                               constant: 36.0)
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
        
        switch cellModelState {
        case .missingModel:
            statusLabel.text = "No Model"
            statusLabel.textColor = UIColor.yellow
        case .idle:
            statusLabel.text = "Idle"
            statusLabel.textColor = UIColor.systemMint
        case .success(_, _, let image):
            statusLabel.text = "Success"
            statusLabel.textColor = UIColor.green
            imageView.image = image
        case .downloading:
            statusLabel.text = "D-Load (Q)"
            statusLabel.textColor = UIColor.gray
        case .downloadingActively:
            statusLabel.text = "D-Load (A)"
            statusLabel.textColor = UIColor.white
        case .error:
            statusLabel.text = "Error"
            statusLabel.textColor = UIColor.red
        case .missingKey:
            statusLabel.text = "No Key"
            statusLabel.textColor = UIColor.red
        }
        
        
        
        /*
        switch state {
        case .uninitialized, .error, .missingKey:
            
            imageView.isHidden = true
            imageView.isUserInteractionEnabled = false
            
            button.isHidden = true
            button.isUserInteractionEnabled = false
            
            errorView.isHidden = false
            errorView.isUserInteractionEnabled = true
            
            loadingView.isHidden = true
            loadingView.isUserInteractionEnabled = false
        case .missingModel:
            
            imageView.isHidden = true
            imageView.isUserInteractionEnabled = false
            
            button.isHidden = true
            button.isUserInteractionEnabled = false
            
            errorView.isHidden = false
            errorView.isUserInteractionEnabled = true
            
            loadingView.isHidden = true
            loadingView.isUserInteractionEnabled = false
            
        case .success(let image):
            imageView.image = image
            
            imageView.isHidden = false
            imageView.isUserInteractionEnabled = true
            
            button.isHidden = false
            button.isUserInteractionEnabled = true
            
            errorView.isHidden = true
            errorView.isUserInteractionEnabled = false
            
            loadingView.isHidden = true
            loadingView.isUserInteractionEnabled = false
        case .downloading, .downloadingActively, .hittingCache, .illegal:
            
            imageView.isHidden = true
            imageView.isUserInteractionEnabled = false
            
            button.isHidden = true
            button.isUserInteractionEnabled = false
            
            errorView.isHidden = true
            errorView.isUserInteractionEnabled = false
            
            loadingView.isHidden = false
            loadingView.isUserInteractionEnabled = true
            
            switch state {
            case .downloading:
                loadingView.backgroundColor = DarkwingDuckTheme._gray400
            case .downloadingActively:
                loadingView.backgroundColor = DarkwingDuckTheme._gray200
            case .hittingCache:
                loadingView.backgroundColor = DarkwingDuckTheme._gray300
            default:
                loadingView.backgroundColor = UIColor.red
            }
            
            loadingView.backgroundColor = DarkwingDuckTheme._gray300
        }
        */
        
    }

}
