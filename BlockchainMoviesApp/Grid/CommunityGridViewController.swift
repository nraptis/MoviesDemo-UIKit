//
//  CommunityGridViewController.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import UIKit
import Combine

class CommunityGridViewController: UIViewController {
    let communityViewModel: CommunityViewModel
    var size: CGSize
    lazy var communityGridView: CommunityGridView = {
        let result = CommunityGridView(communityViewModel: communityViewModel,
                                       communityGridViewController: self,
                                       containerSize: size)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    required init(communityViewModel: CommunityViewModel,
                  size: CGSize) {
        self.communityViewModel = communityViewModel
        self.size = size
        super.init(nibName: nil, bundle: nil)
        
        loadViewIfNeeded()
        if let view = view {
            view.addSubview(communityGridView)
            view.addConstraints([
                NSLayoutConstraint(item: communityGridView, attribute: .left, relatedBy: .equal, toItem: view,
                                   attribute: .left, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: communityGridView, attribute: .right, relatedBy: .equal, toItem: view,
                                   attribute: .right, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: communityGridView, attribute: .top, relatedBy: .equal, toItem: view,
                                   attribute: .top, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: communityGridView, attribute: .bottom, relatedBy: .equal, toItem: view,
                                   attribute: .bottom, multiplier: 1.0, constant: 0.0),
            ])
        }
        
        linkUpSubscribers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = DarkwingDuckTheme._gray100
    }
    
    func notifySizeMayHaveChanged(_ size: CGSize) {
        print("notifySizeMayHaveChanged from [\(self.size.width) x \(self.size.height)] to [\(size.width) x \(size.height)]")
        self.size = size
        communityGridView.worldNotifyContainerSizeMayHaveChanged(size)
    }
    
    var cellNeedsUpdateSubscriber: AnyCancellable?
    var layoutContainerSizeUpdateSubscriber: AnyCancellable?
    var layoutContentsSizeUpdateSubscriber: AnyCancellable?
    var visibleCellsUpdateSubscriber: AnyCancellable?
    
    func linkUpSubscribers() {
        
        // Note: If we use:
        //            .receive(on: OperationQueue.main)
        //
        //       This will cause an asynchronous boundary,
        //       leap, even if we .send() from the main thread.
        //
        //       Therefore, we should not use:
        //             .receive(on: OperationQueue.main)
        //                  unless we don't need instant trigger.
        //
        
        cellNeedsUpdateSubscriber = communityViewModel.cellNeedsUpdatePublisher
            .sink { [weak self] communityCellModel in
                if let self = self {
                    self.communityGridView.notifyCellStateChange(communityCellModel)
                }
            }
        
        layoutContainerSizeUpdateSubscriber = communityViewModel.layoutContainerSizeUpdatePublisher
            .sink { [weak self] newContentSize in
                if let self = self {
                    self.communityGridView.layoutNotifyContainerSizeDidChange(newContentSize)
                }
            }
        
        layoutContentsSizeUpdateSubscriber = communityViewModel.layoutContentsSizeUpdatePublisher
            .sink { [weak self] newContentSize in
                if let self = self {
                    self.communityGridView.layoutNotifyotifyContentSizeMayHaveChanged(newContentSize)
                }
            }
        
        
        visibleCellsUpdateSubscriber = communityViewModel.visibleCellsUpdatePublisher
            .sink { [weak self] in
                if let self = self {
                    self.communityGridView.layoutNotifyotifyVisibleCellsMayHaveChanged()
                }
            }
    }
}
