//
//  CommunityGridView.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/21/24.
//

import UIKit

class CommunityGridView: UIView {
    
    enum GridState {
        case noItems
        case yesItems
    }
    
    private var gridState = GridState.noItems
    
    lazy var scrollView: UIScrollView = {
        let result = UIScrollView(frame: .zero)
        result.translatesAutoresizingMaskIntoConstraints = false
        result.delegate = self
        return result
    }()
    
    lazy var scrollContent: UIView = {
        let result = UIView(frame: .zero)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var cellContainer: UIView = {
        let result = UIView(frame: .zero)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var noContentView: CommunityGridNoContentView = {
        let result = CommunityGridNoContentView(frame: CGRect(x: 0.0, y: 0.0, width: 512.0, height: 512.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var scrollContentHeightConstraint: NSLayoutConstraint = {
        NSLayoutConstraint(item: scrollContent,
                           attribute: .height,
                           relatedBy: .equal,
                           toItem: nil,
                           attribute: .notAnAttribute,
                           multiplier: 1.0,
                           constant: containerSize.height)
    }()
    
    let communityViewModel: CommunityViewModel
    let communityGridViewController: CommunityGridViewController
    let gridLayout: CommunityGridLayout
    var containerSize: CGSize
    var contentSize: CGSize
    required init(communityViewModel: CommunityViewModel,
                  communityGridViewController: CommunityGridViewController,
                  containerSize: CGSize) {
        self.communityViewModel = communityViewModel
        self.communityGridViewController = communityGridViewController
        self.gridLayout = communityViewModel.gridLayout
        self.containerSize = containerSize
        self.contentSize = containerSize
        super.init(frame: .zero)
        
        addSubview(scrollView)
        addConstraints([
            NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0.0),
        ])
        
        scrollView.addSubview(scrollContent)
        scrollView.backgroundColor = DarkwingDuckTheme._gray050
        scrollView.indicatorStyle = .white
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh(refreshControl:)), for: .valueChanged)
        refreshControl.tintColor = DarkwingDuckTheme._gray700
        scrollView.refreshControl = refreshControl
        
        scrollView.addConstraints([
            NSLayoutConstraint(item: scrollContent, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollContent, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollContent, attribute: .centerX, relatedBy: .equal, toItem: scrollView, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: scrollContent, attribute: .width, relatedBy: .equal, toItem: scrollView, attribute: .width, multiplier: 1.0, constant: 0.0),
        ])
        
        scrollContent.addConstraint(scrollContentHeightConstraint)
        scrollContent.backgroundColor = DarkwingDuckTheme._gray050
        
        scrollContent.addSubview(cellContainer)
        scrollContent.addConstraints([
            NSLayoutConstraint(item: cellContainer, attribute: .top, relatedBy: .equal, toItem: scrollContent, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: cellContainer, attribute: .bottom, relatedBy: .equal, toItem: scrollContent, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: cellContainer, attribute: .left, relatedBy: .equal, toItem: scrollContent, attribute: .left, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: cellContainer, attribute: .right, relatedBy: .equal, toItem: scrollContent, attribute: .right, multiplier: 1.0, constant: 0.0),
        ])
        cellContainer.isHidden = true
        cellContainer.isUserInteractionEnabled = false
        
        scrollContent.addSubview(noContentView)
        scrollContent.addConstraints([
            NSLayoutConstraint(item: noContentView, attribute: .top, relatedBy: .equal, toItem: scrollContent, attribute: .top,
                               multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: noContentView, attribute: .left, relatedBy: .equal, toItem: scrollContent, attribute: .left,
                               multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: noContentView, attribute: .right, relatedBy: .equal, toItem: scrollContent, attribute: .right,
                               multiplier: 1.0, constant: 0.0),
        ])
        addConstraint(NSLayoutConstraint(item: noContentView, attribute: .height, relatedBy: .equal, toItem: self,
                                         attribute: .height, multiplier: 1.0, constant: 0.0))
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func refresh(refreshControl: UIRefreshControl) {
        Task {
            await communityViewModel.refresh()
            refreshControl.endRefreshing()
        }
    }
    
    private func _updateContentHeightConstraint() {
        switch gridState {
        case .noItems:
            scrollContentHeightConstraint.constant = containerSize.height
        case .yesItems:
            scrollContentHeightConstraint.constant = contentSize.height
        }
    }
    
    private func _calculateGridState() {
        
        if _storedAnyItemPresent {
            gridState = .yesItems
        } else {
            gridState = .noItems
        }
        
        _updateContentHeightConstraint()
        
        switch gridState {
        case .noItems:
            if noContentView.isHidden == true {
                noContentView.show()
            }
            if cellContainer.isHidden == false {
                cellContainer.isHidden = true
                cellContainer.isUserInteractionEnabled = false
                for communityGridCellView in communityGridCellViews {
                    if communityGridCellView.isActive {
                        communityGridCellView.isHidden = true
                        communityGridCellView.isUserInteractionEnabled = false
                    }
                }
            }
        case .yesItems:
            if noContentView.isHidden == false {
                noContentView.hide()
            }
            if cellContainer.isHidden == true {
                cellContainer.isHidden = false
                cellContainer.isUserInteractionEnabled = true
                for communityGridCellView in communityGridCellViews {
                    if communityGridCellView.isActive {
                        communityGridCellView.isHidden = false
                        communityGridCellView.isUserInteractionEnabled = true
                    }
                }
            }
        }
    }
    
    func worldNotifyContainerSizeMayHaveChanged(_ newContainerSize: CGSize) {
        
        // This is going to create a wild feedback cycle.
        // The parent view changed sizes. So, we will update
        // the layout. Then the layout will do some calcultions
        // and post an update here for us in "layoutNotifyContainerSizeDidChange"
        
        if newContainerSize.width != containerSize.width || newContainerSize.height != containerSize.height {
            containerSize = newContainerSize
            gridLayout.registerContainer(containerSize, communityViewModel.numberOfCells)
            refreshAllActiveFrames()
        }
    }
    
    // In practice, this is not even used. It's mainly just
    // to precent a hypthetical data race. It is called one
    // time after the view controller finished linking
    // up the combine publishers to subscribers.
    func viewControllerDidLinkSubscribers() {
        notifyAnyItemPresentChanged(communityViewModel.isAnyItemPresent)
    }
    
    // This is REALLY dumb. The value in the view model will
    // *NOT* be updated. Only the value passed in here. Therefore
    // we will need 2 sources of truth to manage proper like.
    private var _storedAnyItemPresent = false
    func notifyAnyItemPresentChanged(_ isAnyItemPresent: Bool) {
        if isAnyItemPresent != _storedAnyItemPresent {
            _storedAnyItemPresent = isAnyItemPresent
            _calculateGridState()
        }
    }
    
    func layoutNotifyContainerSizeDidChange(_ newContainerSize: CGSize) {
        
    }
    
    func layoutNotifyotifyContentSizeMayHaveChanged(_ newContentSize: CGSize) {
        let newContentSize = CGSize(width: containerSize.width,
                                    height: max(containerSize.height, newContentSize.height))
        if newContentSize.width != contentSize.width || newContentSize.height != contentSize.height {
            contentSize = newContentSize
            _updateContentHeightConstraint()
            handleScrollContentOffsetMayHaveChanged()
            refreshAllActiveFrames()
        }
    }
    
    // @PreCondition: _visibleCommunityCellModelSet is populated. This should
    //                happen in layoutNotifyotifyVisibleCellsMayHaveChanged
    private func _reconcileNumberOfViewsWithMaximum() {
        let maximumNumberOfVisibleCells = gridLayout.getMaximumNumberOfVisibleCells()
        
        if maximumNumberOfVisibleCells < communityGridCellViews.count {
            let numberToDestroy = communityGridCellViews.count - maximumNumberOfVisibleCells
            for _ in 0..<numberToDestroy {
                
                // Destroy one that is not visible...
                var communityGridCellViewToDestroy: CommunityGridCellView?
                for communityGridCellView in communityGridCellViews {
                    let index = communityGridCellView.communityCellModel.index
                    if !_visibleCommunityCellModelSet.contains(index) {
                        communityGridCellViewToDestroy = communityGridCellView
                        break
                    }
                }
                
                if let communityGridCellViewToDestroy = communityGridCellViewToDestroy {
                    destroyCommunityGridCellView(communityGridCellViewToDestroy)
                } else {
                    print("💣 [GCCM] [HARD FAIL] We need to destroy \(numberToDestroy) cells, but cannot find candidates...")
                }
                
            }
            
        } else if maximumNumberOfVisibleCells > communityGridCellViews.count {
            let numberToCreate = maximumNumberOfVisibleCells - communityGridCellViews.count
            for _ in 0..<numberToCreate {
                createCommunityGridCellView()
            }
            
            if communityGridCellViews.count < maximumNumberOfVisibleCells {
                print("💣 [GCCM] [HARD FAIL] We needed to create \(numberToCreate) cells, but we only have \(communityGridCellViews.count), and we needed \(maximumNumberOfVisibleCells)...")
            }
        }
    }
    
    private var _visibleCommunityCellModelSet = Set<Int>()
    private var _visibleCommunityGridCellViewSet = Set<Int>()
    
    private var _communityGridCellViewsToRecycle = [CommunityGridCellView]()
    private var _communityGridCellViewsToRefresh = [CommunityGridCellView]()
    
    private var _communityCellModelsToAdd = [CommunityCellModel]()
    
    var communityGridCellViews = [CommunityGridCellView]()
    
    func layoutNotifyotifyVisibleCellsMayHaveChanged() {
        
        let visibleCommunityCellModels = communityViewModel.visibleCommunityCellModels
        _visibleCommunityCellModelSet.removeAll(keepingCapacity: true)
        for communityCellModel in visibleCommunityCellModels {
            if _visibleCommunityCellModelSet.contains(communityCellModel.index) {
                print("💣 [GCCM] [HARD FAIL] \"layoutNotifyotifyVisibleCellsMayHaveChanged\" we have duplicate \(communityCellModel.index) in visible cells.")
            } else {
                _visibleCommunityCellModelSet.insert(communityCellModel.index)
            }
        }
        
        _reconcileNumberOfViewsWithMaximum()
        
        _visibleCommunityGridCellViewSet.removeAll(keepingCapacity: true)
        _communityGridCellViewsToRecycle.removeAll(keepingCapacity: true)
        for communityGridCellView in communityGridCellViews {
            
            let index = communityGridCellView.communityCellModel.index
            
            if communityGridCellView.isActive {
                
                if _visibleCommunityCellModelSet.contains(index) {
                    // We shouldn't need to touch this cell.
                    
                    _visibleCommunityGridCellViewSet.insert(index)
                    
                } else {
                    communityGridCellView.communityCellModel = placeholderCommunityCellModel
                    communityGridCellView.hide()
                    _communityGridCellViewsToRecycle.append(communityGridCellView)
                }
            } else {
                _communityGridCellViewsToRecycle.append(communityGridCellView)
            }
        }
        
        _communityCellModelsToAdd.removeAll(keepingCapacity: true)
        for communityCellModel in visibleCommunityCellModels {
            let index = communityCellModel.index
            if !_visibleCommunityGridCellViewSet.contains(index) {
                _communityCellModelsToAdd.append(communityCellModel)
            }
        }
        
        _communityGridCellViewsToRefresh.removeAll(keepingCapacity: true)
        
        var loopIndex = 0
        while (loopIndex < _communityCellModelsToAdd.count) && (loopIndex < _communityGridCellViewsToRecycle.count) {
            let communityGridCellView = _communityGridCellViewsToRecycle[loopIndex]
            let communityCellModel = _communityCellModelsToAdd[loopIndex]
            
            communityGridCellView.show(communityCellModel: communityCellModel)
            _communityGridCellViewsToRefresh.append(communityGridCellView)
            
            loopIndex += 1
        }
        
        refreshAllActiveFrames()
        
        for communityGridCellView in _communityGridCellViewsToRefresh {
            notifyCellStateChange(communityGridCellView)
        }
    }
    
    func notifyCellStateChange(_ communityCellModel: CommunityCellModel) {
        for communityGridCellView in communityGridCellViews {
            if communityGridCellView.isActive {
                // The model may have swapped, so we may need to re-assign.
                // We do everything based on index here, so just check index.
                if communityGridCellView.communityCellModel.index == communityCellModel.index {
                    communityGridCellView.communityCellModel = communityCellModel
                    notifyCellStateChange(communityGridCellView)
                }
            }
        }
    }
    
    func notifyCellStateChange(_ communityGridCellView: CommunityGridCellView) {
        communityGridCellView.updateState()
    }
    
    func refreshCommunityGridCellViewFrame(_ communityGridCellView: CommunityGridCellView) {
        let index = communityGridCellView.communityCellModel.index
        let layoutX = communityViewModel.gridLayout.getCellX(cellIndex: index)
        let layoutY = communityViewModel.gridLayout.getCellY(cellIndex: index)
        let layoutWidth = communityViewModel.gridLayout.getCellWidth()
        let layoutHeight = communityViewModel.gridLayout.getCellHeight()
        communityGridCellView.updateFrame(x: layoutX, y: layoutY, width: layoutWidth, height: layoutHeight)
    }
    
    // Note that this function will often result
    // in the visible cells changing. The visible
    // cells should be updated and registered
    // by the time we finish this function
    func handleScrollContentOffsetMayHaveChanged() {
        gridLayout.registerScrollContent(scrollView.contentOffset)
    }
    
    func refreshAllActiveFrames() {
        for communityGridCellView in communityGridCellViews {
            if communityGridCellView.isActive {
                refreshCommunityGridCellViewFrame(communityGridCellView)
            }
        }
        
        for communityGridCellView in communityGridCellViews {
            if communityGridCellView.isActive {
                communityGridCellView.bottomContentView.button1.setTitle("\(communityGridCellView.communityCellModel.index)", for: .normal)
            }
        }
    }
    
    lazy private var placeholderCommunityCellModel: CommunityCellModel = {
        let result = CommunityCellModel()
        result.index = -999
        result.cellModelState = .missingModel
        return result
    }()
    
    func createCommunityGridCellView() {
        
        let communityGridCellView = CommunityGridCellView(communityViewModel: communityViewModel, 
                                                          communityCellModel: placeholderCommunityCellModel)
        cellContainer.addSubview(communityGridCellView)
        communityGridCellView.translatesAutoresizingMaskIntoConstraints = false
        let constraintLeft = NSLayoutConstraint(item: communityGridCellView, attribute: .left, relatedBy: .equal,
                                                toItem: cellContainer, attribute: .left, multiplier: 1.0, constant: 0.0)
        let constraintTop = NSLayoutConstraint(item: communityGridCellView, attribute: .top, relatedBy: .equal,
                                               toItem: cellContainer, attribute: .top, multiplier: 1.0, constant: 0.0)
        let constraintWidth = NSLayoutConstraint(item: communityGridCellView, attribute: .width, relatedBy: .equal,
                                                 toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 256.0)
        let constraintHeight = NSLayoutConstraint(item: communityGridCellView, attribute: .height, relatedBy: .equal,
                                                  toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 256.0)
        
        communityGridCellView.constraintLeft = constraintLeft
        communityGridCellView.constraintTop = constraintTop
        communityGridCellView.constraintWidth = constraintWidth
        communityGridCellView.constraintHeight = constraintHeight
        
        cellContainer.addConstraints([
            constraintLeft,
            constraintTop])
        
        communityGridCellView.addConstraints([constraintWidth,
                                      constraintHeight])
        
        // Note: We hide the cell on creation. This may
        //       seem a little weird if you're debugging
        //       this sometime in the future. It in 1987.
        communityGridCellView.hide()
        
        communityGridCellViews.append(communityGridCellView)
    }
    
    func destroyCommunityGridCellView(_ communityGridCellView: CommunityGridCellView) {
        
        var destroyIndex = -1
        
        for index in 0..<communityGridCellViews.count {
            if communityGridCellViews[index] === communityGridCellView {
                destroyIndex = index
                break
            }
        }
        
        communityGridCellView.layer.removeAllAnimations()
        communityGridCellView.removeFromSuperview()
        
        if destroyIndex != -1 {
            communityGridCellViews.remove(at: destroyIndex)
        } else {
            print("💣 [GCCM] [HARD FAIL] Expected to be able to destroy \(communityGridCellView.communityCellModel.index)... Not in list...")
        }
    }
}

extension CommunityGridView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleScrollContentOffsetMayHaveChanged()
    }
}
