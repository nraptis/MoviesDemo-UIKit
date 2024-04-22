//
//  CommunityViewModel.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/9/24.
//

import SwiftUI
import BlockChainNetworking
import BlockChainDatabase
import Combine

class CommunityViewModel {
    
    private static let DEBUG_STATE_CHANGES = true
    
    typealias NWMovie = BlockChainNetworking.NWMovie
    typealias DBMovie = BlockChainDatabase.DBMovie
    
    @MainActor func debugInvalidateState() async {
        
        imageCache.DISABLED = Bool.random()
        let cacheAction = Int.random(in: 0...2)
        if cacheAction == 0 {
            await imageCache.purge()
        } else if cacheAction == 1 {
            await imageCache.purgeRandomly()
        } else {
            // Leave the cache as is...
        }
        
        let downloaderAction = Int.random(in: 0...2)
        if downloaderAction == 0 {
            await downloader.cancelAll()
        } else if downloaderAction == 1 {
            await downloader.cancelAllRandomly()
        } else {
            // Leave the downloader as is...
        }
        
        if Bool.random() {
            // Punch random holes in the data
            for index in communityCellDatas.indices {
                if Int.random(in: 0...5) == 3 {
                    communityCellDatas[index] = nil
                }
            }
        }
        
        if Bool.random() {
            
            for index in communityCellDatas.indices {
                // Blank out random keys in the data
                if Int.random(in: 0...8) == 3 {
                    if let communityCellData = communityCellDatas[index] {
                        communityCellData.poster_path = nil
                        communityCellData.urlString = nil
                    }
                }
                
                // Make wrong random keys in the data
                if Int.random(in: 0...8) == 6 {
                    if let communityCellData = communityCellDatas[index] {
                        communityCellData.poster_path = "abc"
                        communityCellData.urlString = "abc"
                    }
                }
            }
        }
        
        let imageDictionaryAction = Int.random(in: 0...2)
        if imageDictionaryAction == 0 {
            _imageDict.removeAll(keepingCapacity: true)
        } else if imageDictionaryAction == 1 {
            
            var _newImageDict = [String: UIImage]()
            
            for (key, value) in _imageDict {
                if Bool.random() {
                    _newImageDict[key] = value
                }
            }
            _imageDict.removeAll(keepingCapacity: true)
            for (key, value) in _newImageDict {
                 _newImageDict[key] = value
            }
        } else {
            // leave the image dict alone
        }
        
        let failDictionaryAction = Int.random(in: 0...2)
        if failDictionaryAction == 0 {
            _imageFailedSet.removeAll(keepingCapacity: true)
        } else if failDictionaryAction == 1 {
            var newList = [Int]()
            for number in _imageFailedSet {
                if Bool.random() {
                    newList.append(number)
                }
            }
            _imageFailedSet.removeAll(keepingCapacity: true)
            for number in newList {
                _imageFailedSet.insert(number)
            }
        }
        
        // We will always blank out _imageDidCheckCacheSet.
        // Otherwise, deleting random elements from the
        // cache and here is not going to jibe...
        _imageDidCheckCacheSet.removeAll(keepingCapacity: true)
        
    }
    
    @MainActor let cellNeedsUpdatePublisher = PassthroughSubject<CommunityCellModel, Never>()
    @MainActor let layoutContainerSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let layoutContentsSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let visibleCellsUpdatePublisher = PassthroughSubject<Void, Never>()
    
    private static let probeAheadOrBehindRangeForDownloads = 8
    
    private var databaseController = BlockChainDatabase.DBDatabaseController()
    private let downloader = DirtyImageDownloader(numberOfSimultaneousDownloads: 3)
    
    @MainActor fileprivate var _imageDict  = [String: UIImage]()
    @MainActor fileprivate var _imageFailedSet = Set<Int>()
    @MainActor fileprivate var _imageDidCheckCacheSet = Set<Int>()
    
    @MainActor private var _checkCacheKeys = [KeyIndex]()
    @MainActor private var _cacheContents = [KeyIndexImage]()
    
    @MainActor private(set) var visibleCommunityCellModels = [CommunityCellModel]()
    @MainActor private(set) var communityCellModels = [CommunityCellModel]()
    
    @MainActor private(set) var _downloadCommunityCellDatas = [CommunityCellData]()
    
    var pageSize = 0
    
    var numberOfItems = 0
    
    var numberOfCells = 0
    var numberOfPages = 0
    
    var highestPageFetchedSoFar = 0
    
    @MainActor private var _priorityCommunityCellDatas = [CommunityCellData]()
    @MainActor private var _priorityList = [Int]()
    
    @MainActor let gridLayout = CommunityGridLayout()
    private let imageCache = DirtyImageCache(name: "dirty_cache")
    
    @MainActor private(set) var isRefreshing = false
    @MainActor private(set) var isFetching = false
    @MainActor private(set) var isNetworkErrorPresent = false
    @MainActor var isAnyItemPresent = false
    
    @MainActor let router: Router
    
    
    @MainActor init(router: Router) {
        
        self.router = router
        
        downloader.delegate = self
        downloader.isBlocked = true
        
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil, queue: nil) { notification in
            Task { @MainActor in
                self._imageDict.removeAll(keepingCapacity: true)
                self._imageFailedSet.removeAll(keepingCapacity: true)
                self._imageDidCheckCacheSet.removeAll(keepingCapacity: true)
            }
        }

        Task { @MainActor in
            await self.heartbeat()
        }
        
        // In this case, it doesn't matter the order that the imageCache and dataBase load,
        // however, we want them to both load before the network call fires.
        Task { @MainActor in
            gridLayout.delegate = self

            await withTaskGroup(of: Void.self) { group in
                group.addTask { @DirtyImageCacheActor in
                    self.imageCache.load()
                }
                group.addTask { @MainActor in
                    await self.databaseController.loadPersistentStores()
                }
            }
            downloader.isBlocked = false
            await fetchPopularMovies(page: 1)
        }
    }
    
    //
    // This is more or less a tidying process.
    // Sometimes, with async and await, though no
    // data races occur, the state will not elegantly
    // transfer.
    //
    // As an example, in one async function, we are doing an
    // await before we set the cell to "downloading state"
    // ...
    // but on another async function, we have already set
    // the cell to the "success" state.
    // ...
    // Now the cell, which was just set to the "success" state
    // is very quickly overwritten with the downloading state.
    // So, it becomes stuck in this downloading state.
    //...
    // We can either check ALL of the conditions after each
    // and every possibly de-synchronizing await, or we can
    // just have this heartbeat process (oldschool) which
    // will identify anything out of sync and try to fix it.
    //
    // It should be noted that things can fall out of sync during
    // the heartbeat process. However, they will be fixed on the
    // very next heart beat. In practice, this is rare to occur.
    //
    
    @MainActor func heartbeat() async {
        await pulse()
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000)
            Task { @MainActor [weak self] in
                if let self = self {
                    await self.heartbeat()
                }
            }
        }
    }
    
    @MainActor private var _batchUpdateCommunityCellModels = [CommunityCellModel]()
    @MainActor private func getBatchUpdateChunkNumberOfCells() -> Int {
        var result = gridLayout.getNumberOfCols()
        if result < 4 {
            result = 4
        }
        if result > 8 {
            result = 8
        }
        return result
    }
    
    @MainActor private func getBatchUpdateChunkSleepDuration() -> UInt64 {
        //0.01 seconds
        return 10_000_000
        
        // 0.5 seconds
        //return 500_000_000
    }
    
    @MainActor private var isOnPulse = false
    @MainActor private var pulseNumber = 0
    @MainActor func pulse() async {
        
        if isRefreshing {
            return
        }
        
        isOnPulse = true
        
        pulseNumber += 1
        if pulseNumber >= 100 {
            pulseNumber = 1
        }
        
        await refreshAllCellStatesAndReconcile()
        
        fetchMorePagesIfNecessary()
        
        isOnPulse = false
    }
    
    //
    // This will be 100% synchronous, essentially a simple check.
    // For example, if the image is in the image dictionary, we will
    // update the states appropriately. We should *NOT* add anything
    // to the downloader, let the heart beat process take care of it.
    //
    // There will be some duplicate work between
    // "refreshAllCellStatesForVisibleCellsChanged" and
    // "refreshAllCellStatesAndReconcile". However, this
    // funtion should *NOT* be called by the latter. It is
    // only a quick check, we would have to rule things out
    // yet again in the other function...
    //
    @MainActor func refreshAllCellStatesForVisibleCellsChanged() {
        
        // We are going to immediately update all the cells, we are only
        // checking the visible cells. So, this is a bit of a nombo breaker
        // in that, we just use an empty set of visible cells.
        //_visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
        _refreshVisibleCommunityCellModelIndices()
        
        for communityCellModel in visibleCommunityCellModels {
            let index = communityCellModel.index
            if let communityCellData = getCommunityCellData(at: index) {
                if let key = communityCellData.key {
                    if let image = _imageDict[key] {
                        _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                          communityCellData: communityCellData,
                                                          visibleCellIndices: _visibleCommunityCellModelIndices, 
                                                          isFromRefresh: false,
                                                          key: key,
                                                          image: image,
                                                          debug: "VisibleCellsChanged, Have Image", 
                                                          emoji: "🧰")
                    } else if _imageFailedSet.contains(index) {
                        _ = attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                        communityCellData: communityCellData,
                                                        visibleCellIndices: _visibleCommunityCellModelIndices,
                                                        isFromRefresh: false,
                                                        key: key,
                                                        debug: "VisibleCellsChanged, FailSet", 
                                                        emoji: "🧰")
                    } else {
                        
                        // If we are downloading, let's stay there, otherwise go downloading...
                        switch communityCellModel.cellModelState {
                        case .downloading, .downloadingActively:
                            // We are already in a downloading state
                            break
                        default:
                            // We are already in the idle state, this is
                            // an illegal configuration.
                            _ = attemptUpdateCellStateDownloading(communityCellModel: communityCellModel,
                                                                  communityCellData: communityCellData,
                                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                  isFromRefresh: false,
                                                                  key: key,
                                                                  debug: "VisibleCellsChanged, Mock Downloading",
                                                                  emoji: "🧰")
                        }
                    }
                } else {
                    _ = attemptUpdateCellStateMissingKey(communityCellModel: communityCellModel,
                                                         communityCellData: communityCellData,
                                                         visibleCellIndices: _visibleCommunityCellModelIndices,
                                                         isFromRefresh: false,
                                                         debug: "Key Not Found",
                                                         emoji: "🧰")
                }
            } else {
                _ = attemptUpdateCellStateMisingModel(communityCellModel: communityCellModel,
                                                      visibleCellIndices: _visibleCommunityCellModelIndices,
                                                      isFromRefresh: false,
                                                      debug: "Model Not Found",
                                                      emoji: "🧰")
            }
        }
    }
    
    // This is expected to be called often, controlled by heart
    // beat process. This is a bit of a watchdog process, which
    // will check for anything that can be fixed.
    //
    // We are not going to account for every possible change
    // that can occur as we cross asynchronous boundaries, as
    // this creates an infinite churn. For example, we can
    // asynchronously check the image cache, then asynchronously
    // check the downloader. After checking the downloader, we
    // would need to again asynchronously check the image cache,
    // and so on, to infinity...
    //
    // Therefore, this is more of a semi-linear process.
    // We will do 1 sweep through the existing images.
    // We will do 1 sweep through the cache.
    // We will do 1 sweep through the downloader.
    //
    // Then, we will do a more rigorous "let's rule stuff out"
    // pass, which will be accurate enough. It's completely possible
    // that during the "let's rule stuff out" portion, the image cache
    // became satiated with the image and we will briefly flicker
    // into a wrong state. In practice, this should be rare.
    //
    // Assigning to the download and prioritizing the downloads
    // will be 100% managed by this function. No other function
    // should add anything to the downloader.
    //
    
    @MainActor private func refreshAllCellStatesAndReconcile() async {
        
        let batchUpdateChunkNumberOfCells = getBatchUpdateChunkNumberOfCells()
        let batchUpdateChunkSleepDuration = getBatchUpdateChunkSleepDuration()
        
        
        // See if we have images in dictionary with wrong
        // state on the cell model. This can happen in between
        // awaits. Since we are not checking every single cell
        // after every single await (not practical), we do this.
        if true {
            
            // This loop, which is repeated several times, ensures that only
            // "batchUpdateChunkNumberOfCells" cells are updated between each
            // sleep. If we update ALL of the cells, this can cause a lag spike.
            // We leverage "attemptUpdate..." which will return true if, both the
            // a.) state changed
            // b.) combine publisher updated a cell
            // In this case, we consider this an "update"... Once we get
            // "batchUpdateChunkNumberOfCells" "updates" then we sleep, to
            // allow UI to catch up, to not interrupt the scrolling.
            var waveUpdateIndex = 0
            while waveUpdateIndex < visibleCommunityCellModels.count {
                
                // After each sleep, we need to reconcile this state.
                // This is a little overboard, though techncally correct.
                _refreshVisibleCommunityCellModelIndices()
                
                var waveNumberOfUpdatesTriggered = 0
                while waveUpdateIndex < visibleCommunityCellModels.count && waveNumberOfUpdatesTriggered < batchUpdateChunkNumberOfCells {
                    let communityCellModel = visibleCommunityCellModels[waveUpdateIndex]
                    switch communityCellModel.cellModelState {
                    case .success:
                        // No need to check again.
                        break
                    default:
                        let index = communityCellModel.index
                        if let communityCellData = getCommunityCellData(at: index) {
                            if let key = communityCellData.key {
                                if let image = _imageDict[key] {
                                    // Try to update the cell. Only if we cause a UI
                                    // update do we consider that an update is triggered.
                                    if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                                     communityCellData: communityCellData,
                                                                     visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                     isFromRefresh: false,
                                                                     key: key,
                                                                     image: image,
                                                                     debug: "Reconcile, Recovered From Master Dict",
                                                                     emoji: "🎰") {
                                        waveNumberOfUpdatesTriggered += 1
                                    }
                                }
                            }
                        }
                    }
                    waveUpdateIndex += 1
                }
                if waveNumberOfUpdatesTriggered > 0 {
                    try? await Task.sleep(nanoseconds: batchUpdateChunkSleepDuration)
                }
            }
        }
        
        // See if anything can be checked from the image cache.
        // We store the KeyIndex pairs in _checkCacheKeys.
        // We only want to do this once per each cell (until refresh)
        // So, we store in _imageDidCheckCacheSet which ones we check.
        _checkCacheKeys.removeAll(keepingCapacity: true)
        for communityCellModel in visibleCommunityCellModels {
            let index = communityCellModel.index
            if _imageFailedSet.contains(index) { continue }
            if _imageDidCheckCacheSet.contains(index) { continue }
            if let communityCellData = getCommunityCellData(at: index) {
                if let key = communityCellData.key {
                    _imageDidCheckCacheSet.insert(index)
                    _checkCacheKeys.append(KeyIndex(key: key, index: index))
                }
            }
        }
        
        if _checkCacheKeys.count > 0 {
            
            print("🔧 Reconcile Process: We check \(_checkCacheKeys.count) key/index pairs in image cache.")
            
            // Batch fetch these "need to check cache". This batch fetch
            // automatically will sleep after loading several images, so
            // we are not starving the processor. When this finishes,
            // we'll have the whole dictionary of [KeyIndex: UIImage]
            // from the cache, so we can inject.
            let keyIndexImageDict = await imageCache.retrieveBatch(_checkCacheKeys)
            
            
            // This loop, which is repeated several times, ensures that only
            // "batchUpdateChunkNumberOfCells" cells are updated between each
            // sleep. If we update ALL of the cells, this can cause a lag spike.
            // We leverage "attemptUpdate..." which will return true if, both the
            // a.) state changed
            // b.) combine publisher updated a cell
            // In this case, we consider this an "update"... Once we get
            // "batchUpdateChunkNumberOfCells" "updates" then we sleep, to
            // allow UI to catch up, to not interrupt the scrolling.
            var waveUpdateIndex = 0
            while waveUpdateIndex < visibleCommunityCellModels.count {
                
                // After each sleep, we need to reconcile this state.
                // This is a little overboard, though techncally correct.
                _refreshVisibleCommunityCellModelIndices()
                
                var waveNumberOfUpdatesTriggered = 0
                while waveUpdateIndex < visibleCommunityCellModels.count && waveNumberOfUpdatesTriggered < batchUpdateChunkNumberOfCells {
                    let communityCellModel = visibleCommunityCellModels[waveUpdateIndex]
                    let index = communityCellModel.index
                    if let communityCellData = getCommunityCellData(at: index) {
                        if let key = communityCellData.key {
                            let keyIndex = KeyIndex(key: key, index: index)
                            if let image = keyIndexImageDict[keyIndex] {
                                
                                // Insert this image into our master dictionary.
                                _imageDict[key] = image
                                
                                if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                                 communityCellData: communityCellData,
                                                                 visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                 isFromRefresh: false,
                                                                 key: key,
                                                                 image: image,
                                                                 debug: "Reconcile, Batch Cache Hit",
                                                                 emoji: "🎰") {
                                    waveNumberOfUpdatesTriggered += 1
                                }
                            }
                        }
                    }
                    waveUpdateIndex += 1
                }
                if waveNumberOfUpdatesTriggered > 0 {
                    try? await Task.sleep(nanoseconds: batchUpdateChunkSleepDuration)
                }
            }
        }
        
        // Now we will add everything to the downloader, which should be downloaded.
        // This is the ONLY point in code which will add tasks to the downloader,
        // so we do not need to worry about asynchronous boundaries in checking
        // whether an item is downloading or not... So, first, we load up everything
        // that needs to be downloaded into a big list...
        
        _downloadCommunityCellDatas.removeAll(keepingCapacity: true)
        if true {
            var firstCellIndexOnScreen = gridLayout.getFirstCellIndexOnScreen() - Self.probeAheadOrBehindRangeForDownloads
            if firstCellIndexOnScreen < 0 {
                firstCellIndexOnScreen = 0
            }
            
            var lastCellIndexOnScreen = gridLayout.getLastCellIndexOnScreen() + Self.probeAheadOrBehindRangeForDownloads
            if lastCellIndexOnScreen >= numberOfCells {
                lastCellIndexOnScreen = numberOfCells - 1
            }
            
            var communityCellModelIndex = firstCellIndexOnScreen
            while communityCellModelIndex <= lastCellIndexOnScreen {
                if communityCellModelIndex >= 0 && communityCellModelIndex < communityCellModels.count {
                    let communityCellModel = communityCellModels[communityCellModelIndex]
                    let index = communityCellModel.index
                    if !_imageFailedSet.contains(index) {
                        if let communityCellData = getCommunityCellData(at: index) {
                            if let key = communityCellData.key {
                                if _imageDict[key] === nil {
                                    if await downloader.isDownloading(communityCellData) {
                                        // We are already downloading this...
                                    } else {
                                        // This we should add to the downloader.
                                        _downloadCommunityCellDatas.append(communityCellData)
                                    }
                                }
                            }
                        }
                    }
                }
                communityCellModelIndex += 1
            }
        }
        
        // Now, we hand them off to the downloader...
        if _downloadCommunityCellDatas.count > 0 {
            print("🔧 Reconcile Process: We hand \(_downloadCommunityCellDatas.count) cell models to downloader.")
            await downloader.addDownloadTaskBatch(_downloadCommunityCellDatas)
        }
        
        // Before we start the download tasks, compute the
        // priorities. In our current scheme, we can ONLY
        // start a download task if the priority is set.
        await _computeDownloadPriorities()
        
        // This will be the ONLY place we start the download
        // tasks. So, the priorities should always be set ahead of time.
        await downloader.startTasksIfNecessary()
        
        // Now, we are going to see if cell model states
        // should be updated, or are out of sync.
        // We do this in a single pass. We do not re-check
        // each and every relevant state update after each
        // await. Instead, we allow the next heartbeat pass
        // to correct the state.
        if true {
            
            // This loop, which is repeated several times, ensures that only
            // "batchUpdateChunkNumberOfCells" cells are updated between each
            // sleep. If we update ALL of the cells, this can cause a lag spike.
            // We leverage "attemptUpdate..." which will return true if, both the
            // a.) state changed
            // b.) combine publisher updated a cell
            // In this case, we consider this an "update"... Once we get
            // "batchUpdateChunkNumberOfCells" "updates" then we sleep, to
            // allow UI to catch up, to not interrupt the scrolling.
            var waveUpdateIndex = 0
            while waveUpdateIndex < visibleCommunityCellModels.count {
                
                var waveNumberOfUpdatesTriggered = 0
                while waveUpdateIndex < visibleCommunityCellModels.count && waveNumberOfUpdatesTriggered < batchUpdateChunkNumberOfCells {
                    let communityCellModel = visibleCommunityCellModels[waveUpdateIndex]
                    if await _refreshAllCellStatesAndReconcile_ExhaustiveCheck(communityCellModel: communityCellModel) {
                        waveNumberOfUpdatesTriggered += 1
                    }
                    waveUpdateIndex += 1
                }
                
                if waveNumberOfUpdatesTriggered > 0 {
                    try? await Task.sleep(nanoseconds: batchUpdateChunkSleepDuration)
                }
            }
        }
    }
    
    // This returns true if state was changed.
    @MainActor private func _refreshAllCellStatesAndReconcile_ExhaustiveCheck(communityCellModel: CommunityCellModel) async -> Bool {
        
        guard let communityCellData = getCommunityCellData(at: communityCellModel.index) else {
            switch communityCellModel.cellModelState {
            case .missingModel:
                return false
            default:
                _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                if attemptUpdateCellStateMisingModel(communityCellModel: communityCellModel,
                                                     visibleCellIndices: _visibleCommunityCellModelIndices,
                                                     isFromRefresh: false,
                                                     debug: "ExhaustiveCheck, Missing Model",
                                                     emoji: "📚") {
                    return true
                } else {
                    return false
                }
            }
        }
        
        guard let key = communityCellData.key else {
            switch communityCellModel.cellModelState {
            case .missingKey:
                return false
            default:
                _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                if attemptUpdateCellStateMissingKey(communityCellModel: communityCellModel,
                                                    communityCellData: communityCellData,
                                                    visibleCellIndices: _visibleCommunityCellModelIndices,
                                                    isFromRefresh: false,
                                                    debug: "ExhaustiveCheck, Missing Key",
                                                    emoji: "📚") {
                    return true
                } else {
                    return false
                }
            }
        }
        
        if let image = _imageDict[key] {
            // We *DO* have an image in _imageDict.
            
            switch communityCellModel.cellModelState {
            case .success:
                // This is the expected state.
                // We have an image, we are already
                // in the success state.
                return false
            default:
                _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                 communityCellData: communityCellData,
                                                 visibleCellIndices: _visibleCommunityCellModelIndices,
                                                 isFromRefresh: false,
                                                 key: key,
                                                 image: image,
                                                 debug: "ExhaustiveCheck, Image From Dict (Normal)",
                                                 emoji: "📚") {
                    return true
                } else {
                    return false
                }
            }
        } else {
            // We *DO NOT* have an image in _imageDict.
            
            switch communityCellModel.cellModelState {
            case .success:
                // This is the oddball state. The cell
                // has an image, but we do not have one
                // in the dictionary. This is an illegal state.
                
                switch communityCellModel.cellModelState {
                case .idle:
                    // We are already in the idle state.
                    return false
                default:
                    // Update to idle state.
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                  isFromRefresh: false,
                                                  key: key,
                                                  debug: "ExhaustiveCheck, Oddball Image State",
                                                  emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                }
            default:
                if await _refreshAllCellStatesAndReconcile_ExhaustiveCheck_A(communityCellModel: communityCellModel,
                                                                             communityCellData: communityCellData,
                                                                             key: key) {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    @MainActor private func _refreshAllCellStatesAndReconcile_ExhaustiveCheck_A(communityCellModel: CommunityCellModel,
                                                                                communityCellData: CommunityCellData,
                                                                                key: String) async -> Bool {
        
        // It could be that we are incorrectly in the download state...
        switch communityCellModel.cellModelState {
        case .downloading, .downloadingActively:
            if await downloader.isDownloading(communityCellData) {
                // This is the expected case,
                // we will stay in this state
                return false
            } else {
                // This is an illegal state.
                // Let's see if we can reconcile
                // either a success or failure.
                // then if we can't, it will be
                // in the illegal (idle) state.
                
                if let image = _imageDict[key] {
                    // Update to idle state.
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                     communityCellData: communityCellData,
                                                     visibleCellIndices: _visibleCommunityCellModelIndices,
                                                     isFromRefresh: false,
                                                     key: key,
                                                     image: image,
                                                     debug: "ExhaustiveCheck, Downloading Oddball Image State",
                                                     emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                } else if _imageFailedSet.contains(communityCellModel.index) {
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                   communityCellData: communityCellData,
                                                   visibleCellIndices: _visibleCommunityCellModelIndices,
                                                   isFromRefresh: false,
                                                   key: key,
                                                   debug: "ExhaustiveCheck, Downloading Oddball Error State",
                                                   emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                } else {
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                  isFromRefresh: false,
                                                  key: key,
                                                  debug: "ExhaustiveCheck, Downloading Oddball Idle State",
                                                  emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                }
            }
        default:
            if await _refreshAllCellStatesAndReconcile_ExhaustiveCheck_B(communityCellModel: communityCellModel,
                                                                         communityCellData: communityCellData,
                                                                         key: key) {
                return true
            } else {
                return false
            }
        }
    }
    @MainActor private func _refreshAllCellStatesAndReconcile_ExhaustiveCheck_B(communityCellModel: CommunityCellModel,
                                                                                communityCellData: CommunityCellData,
                                                                                key: String) async -> Bool {
        if await downloader.isDownloading(communityCellData) {
            if await downloader.isDownloadingActively(communityCellData) {
                print("Cell # \(communityCellData.index) downloading ACTIVELY")
                switch communityCellModel.cellModelState {
                case .downloadingActively:
                    // We are already in the downloading actively state
                    return false
                default:
                    // Update to downloading actively state.
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateDownloadingActively(communityCellModel: communityCellModel,
                                                                 communityCellData: communityCellData,
                                                                 visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                 isFromRefresh: false,
                                                                 key: key,
                                                                 debug: "ExhaustiveCheck, Downloading Actively",
                                                                 emoji: "📚") {
                        return true
                    } else {
                        return false
                    }
                }
            } else {
                switch communityCellModel.cellModelState {
                case .downloading:
                    // We are already in the downloading state
                    return false
                default:
                    // Update to downloading state.
                    _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                    _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                    if attemptUpdateCellStateDownloading(communityCellModel: communityCellModel,
                                                         communityCellData: communityCellData,
                                                         visibleCellIndices: _visibleCommunityCellModelIndices,
                                                         isFromRefresh: false,
                                                         key: key,
                                                         debug: "ExhaustiveCheck, Downloading Pasively",
                                                         emoji: "📚") {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
        
        return _refreshAllCellStatesAndReconcile_ExhaustiveCheck_C(communityCellModel: communityCellModel,
                                                                   communityCellData: communityCellData,
                                                                   key: key)
    }
    
    @MainActor private func _refreshAllCellStatesAndReconcile_ExhaustiveCheck_C(communityCellModel: CommunityCellModel,
                                                                                communityCellData: CommunityCellData,
                                                                                key: String) -> Bool {
        if _imageFailedSet.contains(communityCellModel.index) {
            switch communityCellModel.cellModelState {
            case .error:
                // We are already in the error state
                return false
            default:
                // Update to error state.
                _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                if attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                               communityCellData: communityCellData,
                                               visibleCellIndices: _visibleCommunityCellModelIndices,
                                               isFromRefresh: false,
                                               key: key,
                                               debug: "ExhaustiveCheck, Oddball Image State",
                                               emoji: "📚") {
                    return true
                } else {
                    return false
                }
            }
        } else {
            
            // This is the oddball state. We likely
            // had circumstances update during an
            // await. This is a rare event.
            // Temporary illegal state.
            switch communityCellModel.cellModelState {
            case .idle:
                // We are already in the idle state.
                return false
            default:
                // Update to idle state.
                _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                _visibleCommunityCellModelIndices.insert(communityCellModel.index)
                if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                              communityCellData: communityCellData,
                                              visibleCellIndices: _visibleCommunityCellModelIndices,
                                              isFromRefresh: false,
                                              key: key,
                                              debug: "ExhaustiveCheck, Oddball Exhausted State",
                                              emoji: "🎱") {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    @MainActor private var _visibleCommunityCellModelIndices = Set<Int>()
    
    @MainActor private func _refreshVisibleCommunityCellModelIndices() {
        _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
        for communityCellModel in visibleCommunityCellModels {
            _visibleCommunityCellModelIndices.insert(communityCellModel.index)
        }
    }
    
    
    @MainActor func refresh() async {
        
        if isRefreshing {
            print("🧚🏽 We are already refreshing... No double refreshing...!!!")
            return
        }
        
        isRefreshing = true
        
        recentFetches.removeAll(keepingCapacity: true)
        
        downloader.isBlocked = true
        await downloader.cancelAll()
        
        if isOnPulse {
            var fudge = 0
            while isOnPulse {
                try? await Task.sleep(nanoseconds: 1_000_000)
                fudge += 1
                if fudge >= 2048 {
                    print("🧛🏻‍♂️ Terminating refresh, we are pulse-locked.")
                    downloader.isBlocked = false
                    isRefreshing = false
                    return
                }
            }
        }
        
        // If there is an active fetch, wait for it to stop.
        // Likewise, fetch will not trigger during a refresh.
        if isFetching {
            var fudge = 0
            while isFetching {
                try? await Task.sleep(nanoseconds: 1_000_000)
                fudge += 1
                if fudge >= 2048 {
                    print("🧛🏻‍♂️ Terminating refresh, we are fetch-locked.")
                    downloader.isBlocked = false
                    isRefreshing = false
                    return
                }
            }
        }
        
        // For the sake of UX, let's throw everything into the
        // "missing model" state and sleep for 1s.
        let batchUpdateChunkNumberOfCells = getBatchUpdateChunkNumberOfCells()
        let batchUpdateChunkSleepDuration = getBatchUpdateChunkSleepDuration()
        var waveUpdateIndex = 0
        while waveUpdateIndex < communityCellModels.count {
            
            // After each sleep, we need to reconcile this state.
            // This is a little overboard, though techncally correct.
            _refreshVisibleCommunityCellModelIndices()
            
            var waveNumberOfUpdatesTriggered = 0
            while waveUpdateIndex < communityCellModels.count && waveNumberOfUpdatesTriggered < batchUpdateChunkNumberOfCells {
                let communityCellModel = communityCellModels[waveUpdateIndex]
                if attemptUpdateCellStateMisingModel(communityCellModel: communityCellModel,
                                                     visibleCellIndices: _visibleCommunityCellModelIndices,
                                                     isFromRefresh: true,
                                                     debug: "Refresh, Set All Missing Model",
                                                     emoji: "🔩") {
                    waveNumberOfUpdatesTriggered += 1
                }
                waveUpdateIndex += 1
            }
            if waveNumberOfUpdatesTriggered > 0 {
                try? await Task.sleep(nanoseconds: batchUpdateChunkSleepDuration)
            }
        }
        
        // This is mainly just for user feedback; the refresh feels
        // more natural if it takes a couple seconds...
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let nwMovies = await _fetchPopularMoviesWithNetwork(page: 1)
        
        // This is mainly just for user feedback; the refresh feels
        // more natural if it takes a couple seconds...
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if nwMovies.count <= 0 {
            print("🧟‍♀️ Bad Refresh! We got no items from the network...")
            let dbMovies = await _fetchPopularMoviesWithDatabase()
            if dbMovies.count <= 0 {
                print("🧟‍♀️ Bad Refresh! We got no items from the database...")
                downloader.isBlocked = false
                isRefreshing = false
                isAnyItemPresent = false
            } else {
                // A refresh where there are no network items,
                // but we do have items from the database...
                pageSize = -1
                numberOfItems = dbMovies.count
                numberOfCells = dbMovies.count
                numberOfPages = -1
                highestPageFetchedSoFar = -1
                _clearForRefresh()
                fetchPopularMovies_synchronize(dbMovies: dbMovies)
                downloader.isBlocked = false
                isRefreshing = false
                gridLayout.registerNumberOfCells(numberOfCells)
                handleVisibleCellsMayHaveChanged()
            }
        } else {
            // A "happy path" refresh where we do
            // have the network models. Be careful,
            // URL caching can cause this to succeed
            // even without an active connection.
            _clearForRefresh()
            fetchPopularMovies_synchronize(nwMovies: nwMovies, page: 0)
            downloader.isBlocked = false
            isRefreshing = false
            gridLayout.registerNumberOfCells(numberOfCells)
            handleVisibleCellsMayHaveChanged()
        }
    }
    
    @MainActor private func _clearCommunityCellDatas() {
        for communityCellData in communityCellDatas {
            if let communityCellData = communityCellData {
                _depositCommunityCellData(communityCellData)
            }
        }
        communityCellDatas.removeAll(keepingCapacity: true)
    }
    
    @MainActor func _clearForRefresh() {
        
        // Empty out all the internal storage crap...!!!
        _imageDict.removeAll()
        _imageFailedSet.removeAll()
        _imageDidCheckCacheSet.removeAll()
        
        gridLayout.clear()
        
        visibleCommunityCellModels.removeAll(keepingCapacity: true)
        communityCellModels.removeAll(keepingCapacity: true)
        
        _clearCommunityCellDatas()
    }
    
    @MainActor func fetchPopularMovies(page: Int) async {
        
        if isFetching {
            
            // Optionally, we could "enqueue" another fetch. However,
            // we are already doing another "should fetch more pages"
            // call on successful fetches. This is, then, not needed.
            
            print("⚓️ Stopping \"fetchPopularMovies\" @ page \(page), already fetching.")
            return
        }
        
        if isRefreshing { 
            print("⚓️ Stopping \"fetchPopularMovies\" @ page \(page), in the middle of refresh.")
            return
        }
        
        print("📺 \"fetchPopularMovies\" @ page \(page).")
        
        isFetching = true
        
        let nwMovies = await _fetchPopularMoviesWithNetwork(page: page)
        
        // We either fetched nothing, or got an error.
        if nwMovies.count <= 0 {
            if communityCellDatas.count > 0 {
                // We will just keep what we have...
                
                print("📺 \"fetchPopularMovies\" failed to fetch from the internet, but we have some data to display.")
            } else {
                
                // We will fetch from the database!!!
                let dbMovies = await _fetchPopularMoviesWithDatabase()
                if dbMovies.count <= 0 {
                    
                    print("💿 \"_fetchPopularMoviesWithDatabase\" failed, there were no items returned.")
                    
                    isAnyItemPresent = false
                
                } else {
                    print("📀 \"_fetchPopularMoviesWithDatabase\" successfully fetched \(dbMovies.count) items from CoreData.")
                    pageSize = -1
                    numberOfItems = dbMovies.count
                    numberOfCells = dbMovies.count
                    numberOfPages = -1
                    highestPageFetchedSoFar = -1
                    fetchPopularMovies_synchronize(dbMovies: dbMovies)
                    isAnyItemPresent = true
                }
            }

        } else {
            print("📡 \"fetchPopularMovies\" successfully fetched \(nwMovies.count) items from the internet.")
            fetchPopularMovies_synchronize(nwMovies: nwMovies, page: page)
            isAnyItemPresent = true
        }
        
        isFetching = false
        gridLayout.registerNumberOfCells(numberOfCells)
        
        handleVisibleCellsMayHaveChanged()
    }
    
    @MainActor private func fetchPopularMovies_synchronize(nwMovies: [NWMovie], page: Int) {
        
        if pageSize <= 0 {
            print("🧌 \"fetchPopularMovies_synchronize\" pageSize = \(pageSize), this seems wrong.")
            return
        }
        if page <= 0 {
            print("🧌 \"fetchPopularMovies_synchronize\" page = \(page), this seems wrong. We expect the pages to start at 1, and number up.")
            return
        }
        
        // The first index of the cells, in the master list.
        let startCellIndex = (page - 1) * pageSize
        var cellModelIndex = startCellIndex
        
        var newCommunityCellDatas = [CommunityCellData]()
        newCommunityCellDatas.reserveCapacity(nwMovies.count)
        for nwMovie in nwMovies {
            let cellModel = _withdrawCommunityCellData(index: cellModelIndex, nwMovie: nwMovie)
            newCommunityCellDatas.append(cellModel)
            cellModelIndex += 1
        }
        
        fetchPopularMovies_overwriteCells(newCommunityCellDatas, at: startCellIndex)
    }
    
    @MainActor private func fetchPopularMovies_synchronize(dbMovies: [DBMovie]) {
        
        // The first index of the cells, here it's always 0.
        let startCellIndex = 0
        var cellModelIndex = startCellIndex
        
        var newCommunityCellDatas = [CommunityCellData]()
        newCommunityCellDatas.reserveCapacity(dbMovies.count)
        for dbMovie in dbMovies {
            let cellModel = _withdrawCommunityCellData(index: cellModelIndex, dbMovie: dbMovie)
            newCommunityCellDatas.append(cellModel)
            cellModelIndex += 1
        }
        
        fetchPopularMovies_magnetizeCells()
        
        fetchPopularMovies_overwriteCells(newCommunityCellDatas, at: startCellIndex)
    }
    
    // Put all the cells which were in the communityCellDatas
    // list into the queue, blank them all out to nil.
    @MainActor private func fetchPopularMovies_magnetizeCells() {
        var cellModelIndex = 0
        while cellModelIndex < communityCellDatas.count {
            if let communityCellData = communityCellDatas[cellModelIndex] {
                _depositCommunityCellData(communityCellData)
                communityCellDatas[cellModelIndex] = nil
            }
            cellModelIndex += 1
        }
    }
    
    @MainActor private func fetchPopularMovies_overwriteCells(_ newCommunityCellDatas: [CommunityCellData], at index: Int) {
        
        if index < 0 {
            print("🧌 \"fetchPopularMovies_overwriteCells\" index = \(index), this seems wrong.")
            return
        }
        
        let ceiling = index + newCommunityCellDatas.count
        
        // Fill in with blank up to the ceiling
        while communityCellDatas.count < ceiling {
            communityCellDatas.append(nil)
        }
        
        // What we do here is flush out anything in the range
        // we are "writing" to... In case we have overlap, etc.
        var itemIndex = 0
        var cellModelIndex = index
        while itemIndex < newCommunityCellDatas.count {
            if let communityCellData = communityCellDatas[cellModelIndex] {
                _depositCommunityCellData(communityCellData)
                communityCellDatas[cellModelIndex] = nil
            }
            
            itemIndex += 1
            cellModelIndex += 1
        }
        
        // Write the new cells over this range. Everything
        // which was in the range should have been cleaned
        // out by the previous step. Similar to memcpy.
        itemIndex = 0
        cellModelIndex = index
        while itemIndex < newCommunityCellDatas.count {
            
            let communityCellData = newCommunityCellDatas[itemIndex]
            communityCellDatas[cellModelIndex] = communityCellData
            
            itemIndex += 1
            cellModelIndex += 1
        }
    }
    
    struct RecentNetworkFetch {
        let date: Date
        let page: Int
    }
    
    @MainActor private var recentFetches = [RecentNetworkFetch]()
    @MainActor private var recentFetchesTemp = [RecentNetworkFetch]()
    
    @MainActor private func _fetchPopularMoviesWithNetwork(page: Int) async -> [NWMovie] {
        
        //
        // Let's keep peace with the network. If for some reason, we are
        // stuck in a fetch loop, we will throttle it to every 120 seconds.
        //
        if recentFetches.count >= 3 {
            
            var areLastThreeSamePage = true
            for index in 1...3 {
                if recentFetches[recentFetches.count - index].page != page {
                    areLastThreeSamePage = false
                }
            }
            
            if areLastThreeSamePage {
                
                let lastFetch = recentFetches[recentFetches.count - 1]
                let timeElapsed = Date().timeIntervalSince(lastFetch.date)
                print("🛍️ [NtWrK] The last 3 fetches were all page \(page)... \(timeElapsed) seconds since last attempt...")
                if timeElapsed <= 120 {
                    print("💭 Stalling fetch. Only \(timeElapsed) seconds went by since last fetch of page \(page)")
                    isNetworkErrorPresent = true
                    return []
                }
            }
        }
        
        recentFetches.append(RecentNetworkFetch(date: Date(), page: page))
        if recentFetches.count >= 100 {
            recentFetchesTemp.removeAll(keepingCapacity: true)
            var index = 50
            while index < recentFetches.count {
                recentFetchesTemp.append(recentFetches[index])
                index += 1
            }
            recentFetches.removeAll(keepingCapacity: true)
            recentFetches.append(contentsOf: recentFetchesTemp)
        }
        
        var _isNetworkErrorPresent = false
        
        var result = [NWMovie]()
        do {
            let response = try await BlockChainNetworking.NWNetworkController.fetchPopularMovies(page: page)
            result.append(contentsOf: response.results)
            do {
                try await databaseController.sync(nwMovies: response.results)
                print("💾 We did sync Movies to database.")
            } catch {
                print("🧌 Could not sync Movies to database.")
                print("\(error.localizedDescription)")
            }
            
            numberOfItems = response.total_results
            numberOfPages = response.total_pages
            
            if response.results.count > pageSize { pageSize = response.results.count }
            
            if page > highestPageFetchedSoFar { highestPageFetchedSoFar = page }
            
            var _numberOfCells = (highestPageFetchedSoFar) * pageSize
            if _numberOfCells > numberOfItems { _numberOfCells = numberOfItems }
            
            numberOfCells = _numberOfCells
            
        } catch let error {
            print("🧌 Unable to fetch popular movies (Network): \(error.localizedDescription)")
            _isNetworkErrorPresent = true
        }
        
        let __isNetworkErrorPresent = _isNetworkErrorPresent
        await MainActor.run {
            isNetworkErrorPresent = __isNetworkErrorPresent
        }
        
        return result
    }
    
    private func _fetchPopularMoviesWithDatabase() async -> [DBMovie] {
        var result = [DBMovie]()
        do {
            let dbMovies = try await databaseController.fetchMovies()
            result.append(contentsOf: dbMovies)
            
        } catch let error {
            print("🧌 Unable to fetch (Database): \(error.localizedDescription)")
        }
        return result
    }
    
    @MainActor func registerScrollContent(frame: CGRect) {
        // Here we could update the download priorities.
        // This is called SUPER OFTEN. Becuase of race
        // conditions in downloading the wrong item
        // out of order, we are restricting the priority
        // updates to ONLY happedn on heart beat / reconcile
    }
    
    @MainActor var communityCellDatas = [CommunityCellData?]()
    @MainActor var communityCellDataQueue = [CommunityCellData]()
    @MainActor func _withdrawCommunityCellData(index: Int, nwMovie: BlockChainNetworking.NWMovie) -> CommunityCellData {
        if communityCellDataQueue.count > 0 {
            let result = communityCellDataQueue.removeLast()
            result.inject(index: index, nwMovie: nwMovie)
            return result
        } else {
            let result = CommunityCellData(index: index, nwMovie: nwMovie)
            return result
        }
    }
    
    @MainActor private func _withdrawCommunityCellData(index: Int, dbMovie: BlockChainDatabase.DBMovie) -> CommunityCellData {
        if communityCellDataQueue.count > 0 {
            let result = communityCellDataQueue.removeLast()
            result.inject(index: index, dbMovie: dbMovie)
            return result
        } else {
            let result = CommunityCellData(index: index, dbMovie: dbMovie)
            return result
        }
    }
    
    @MainActor private func _depositCommunityCellData(_ cellModel: CommunityCellData) {
        communityCellDataQueue.append(cellModel)
    }
    
    @MainActor func getCommunityCellData(at index: Int) -> CommunityCellData? {
        if index >= 0 && index < communityCellDatas.count {
            return communityCellDatas[index]
        }
        return nil
    }
    
    @MainActor private var _fetchMorePagesPagesToCheck = [Int]()
    @MainActor func fetchMorePagesIfNecessary() {
        
        if isFetching { return }
        if isRefreshing { return }
        
        // They have to pull-to-refresh when the network comes back on...
        if isNetworkErrorPresent { return }
        
        if pageSize < 1 { return }
        
        let numberOfCols = gridLayout.getNumberOfCols()
        let firstCellIndexToConsider = gridLayout.getFirstCellIndexOnScreen() - numberOfCols
        let lastCellIndexToConsider = gridLayout.getLastCellIndexOnScreenNotClamped() + (numberOfCols * 2)
        
        let firstPageIndexToCheck = (firstCellIndexToConsider / pageSize)
        var firstPageToCheck = firstPageIndexToCheck + 1
        if firstPageToCheck < 1 {
            firstPageToCheck = 1
        }
        if firstPageToCheck > numberOfPages {
            return
        }
        
        let lastPageIndexToCheck = (lastCellIndexToConsider / pageSize)
        var lastPageToCheck = lastPageIndexToCheck + 1
        if lastPageToCheck < 1 {
            lastPageToCheck = 1
        }
        if lastPageToCheck > numberOfPages {
            lastPageToCheck = numberOfPages
        }
        
        //print("🧻 [FMP] Searching from \(firstPageToCheck) to \(lastPageToCheck) for possible page to fetch...")
        
        var pageIndexOfLastTwoRecentFetches = -1
        if recentFetches.count >= 2 {
            if recentFetches[recentFetches.count - 1].page == recentFetches[recentFetches.count - 2].page {
                let timeElapsed = Date().timeIntervalSince(recentFetches[recentFetches.count - 1].date)
                if timeElapsed <= 120 {
                    pageIndexOfLastTwoRecentFetches = recentFetches[recentFetches.count - 1].page
                    //print("🖼️ [FMP] Within last \(timeElapsed) seconds, page \(pageIndexOfLastTwoRecentFetches) fetched twice...")
                }
            }
        }
        
        // First let's do a semi-optimistic pass. If everything on the page is missing,
        // then we should fetch that page... Unless pageIndexOfLastTwoRecentFetches is
        // that page. If pageIndexOfLastTwoRecentFetches is that page, we should simply
        // exit out of the process, something is seriously wrong with the web results.
        
        var pageToCheck = firstPageToCheck
        while pageToCheck <= lastPageToCheck {
            
            var isEveryCellMissing = true
            
            let firstCellIndex = (pageToCheck - 1) * pageSize
            let ceiling = firstCellIndex + pageSize
            
            var cellIndex = firstCellIndex
            while cellIndex < ceiling {
                if getCommunityCellData(at: cellIndex) !== nil {
                    isEveryCellMissing = false
                    //print("🖼️ [FMP] It looks \(cellIndex) is not blank, so this page is not all blank...")
                    break
                }
                cellIndex += 1
            }
            
            if isEveryCellMissing {
                //print("🖼️ [FMP] Every cell is missing on page \(pageToCheck), we can fetch... pageIndexOfLastTwoRecentFetches = \(pageIndexOfLastTwoRecentFetches)")
                if pageIndexOfLastTwoRecentFetches == pageToCheck {
                    
                } else {
                    //print("🖼️ [FMP] Executing [A] On \(pageToCheck)")
                    Task {
                        await fetchPopularMovies(page: pageToCheck)
                    }
                }
                return
            }
            pageToCheck += 1
        }
        
        //print("🧻 [FMP] No \"All Cell Missing\" \(firstPageToCheck) to \(lastPageToCheck) for possible page to fetch...")
        
        // Last, let's do a pessimistic pass. If *anything* on the page is missing,
        // then we should fetch that page... Unless pageIndexOfLastTwoRecentFetches is
        // that page. If pageIndexOfLastTwoRecentFetches is that page, we should simply
        // exit out of the process, something is seriously wrong with the web results.
        pageToCheck = firstPageToCheck
        while pageToCheck <= lastPageToCheck {
            
            var isAnyCellMissing = false
            
            let firstCellIndex = (pageToCheck - 1) * pageSize
            let ceiling = firstCellIndex + pageSize
            
            var cellIndex = firstCellIndex
            while cellIndex < ceiling {
                if getCommunityCellData(at: cellIndex) === nil {
                    isAnyCellMissing = true
                    //print("🖼️ [FMP] It looks \(cellIndex) *is* blank, so this page is not all filled...")
                    break
                }
                cellIndex += 1
            }
            
            if isAnyCellMissing {
                //print("🖼️ [FMP] At least one cell is missing on page \(pageToCheck), we can fetch... pageIndexOfLastTwoRecentFetches = \(pageIndexOfLastTwoRecentFetches)")
                if pageIndexOfLastTwoRecentFetches == pageToCheck {
                    
                } else {
                    //print("🖼️ [FMP] Executing [B] On \(pageToCheck)")
                    Task {
                        await fetchPopularMovies(page: pageToCheck)
                    }
                }
                return
            }
            pageToCheck += 1
        }
    }
    
    private var _isFetchingDetails = false
    @MainActor func handleCellClicked(at index: Int) async {
        
        if _isFetchingDetails {
            print("🪚 [STOPPED] Attempted to queue up fetch details twice.")
            return
        }
        
        _isFetchingDetails = true
        
        if let communityCellData = getCommunityCellData(at: index) {
            do {
                let id = communityCellData.id
                let nwMovieDetails = try await BlockChainNetworking.NWNetworkController.fetchMovieDetails(id: id)
                print("🎥 Movie fetched! For \(communityCellData.title) [\(communityCellData.id)]")
                print(nwMovieDetails)
                router.pushMovieDetails(nwMovieDetails: nwMovieDetails)
            } catch {
                print("🧌 Unable to fetch movie details (Network): \(error.localizedDescription)")
                router.rootViewModel.showError("Oops!", "Looks like we couldn't fetch the data! Check your connection!")
            }
            _isFetchingDetails = false
        }
    }
    
    @MainActor func handleCellForceRetryDownload(at index: Int) async {
        if let communityCellData = getCommunityCellData(at: index) {
            print("🚦 Force download restart @ \(index)")
            _imageFailedSet.remove(index)
            await downloader.forceRestart(communityCellData)
            if index >= 0 && index < communityCellModels.count {
                let communityCellModel = communityCellModels[index]
                switch communityCellModel.cellModelState {
                case .downloadingActively:
                    // We are already downloding actively
                    break
                default:
                    // We jump straight to downloading actively
                    if let communityCellData = getCommunityCellData(at: index) {
                        if let key = communityCellData.key {
                            _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
                            _visibleCommunityCellModelIndices.insert(index)
                            _ = attemptUpdateCellStateDownloadingActively(communityCellModel: communityCellModel,
                                                                          communityCellData: communityCellData,
                                                                          visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                          isFromRefresh: false,
                                                                          key: key,
                                                                          debug: "Force Retry",
                                                                          emoji: "🍩")
                        }
                    }
                }
            }
        }
    }
    
    @MainActor func getFirstAndLastCellIndexOnScreen() -> FirstAndLastIndex {
        @MainActor func getFirstCellIndexOnScreen() -> Int {
            var result = gridLayout.getFirstCellIndexOnScreen()
            if result < 0 {
                result = 0
            }
            return result
        }
        @MainActor func getLastCellIndexOnScreen() -> Int {
            var result = gridLayout.getLastCellIndexOnScreen()
            if result >= numberOfCells {
                result = numberOfCells - 1
            }
            return result
        }
        let firstCellIndexOnScreen = getFirstCellIndexOnScreen()
        let lastCellIndexOnScreen = getLastCellIndexOnScreen()
        let isValid = firstCellIndexOnScreen <= lastCellIndexOnScreen
        return FirstAndLastIndex(firstIndex: firstCellIndexOnScreen,
                                 lastIndex: lastCellIndexOnScreen,
                                 isValid: isValid)
    }
    
    @MainActor func handleVisibleCellsMayHaveChanged() {
        
        if gridLayout.isAnyItemPresent {
            isAnyItemPresent = true
        }
        
        visibleCommunityCellModels.removeAll(keepingCapacity: true)
        
        let onScreen = getFirstAndLastCellIndexOnScreen()
        guard onScreen.isValid else {
            return
        }
        
        while communityCellModels.count <= onScreen.lastIndex {
            let communityCellModel = CommunityCellModel()
            communityCellModel.index = communityCellModels.count
            communityCellModels.append(communityCellModel)
        }
        
        var index = onScreen.firstIndex
        while index <= onScreen.lastIndex {
            let communityCellModel = communityCellModels[index]
            visibleCommunityCellModels.append(communityCellModel)
            index += 1
        }
        
        visibleCellsUpdatePublisher.send()
        refreshAllCellStatesForVisibleCellsChanged()
        
        Task {
            
            var firstCellIndexOnScreen = gridLayout.getFirstCellIndexOnScreen() - Self.probeAheadOrBehindRangeForDownloads
            if firstCellIndexOnScreen < 0 {
                firstCellIndexOnScreen = 0
            }
            
            var lastCellIndexOnScreen = gridLayout.getLastCellIndexOnScreen() + Self.probeAheadOrBehindRangeForDownloads
            if lastCellIndexOnScreen >= numberOfCells {
                lastCellIndexOnScreen = numberOfCells - 1
            }
            
            await downloader.cancelAllOutOfIndexRange(firstIndex: firstCellIndexOnScreen, lastIndex: lastCellIndexOnScreen)
        }
        
        fetchMorePagesIfNecessary()
    }
    
    // Distance from the left of the container / screen.
    // Distance from the top of the container / screen.
    private func priority(distX: Int, distY: Int) -> Int {
        let px = (-distX)
        let py = (8192 * 8192) - (8192 * distY)
        return (px + py)
    }
    
    @MainActor private func _computeDownloadPriorities() async {
        
        //_isComputingDownloadPrioritiesEnqueued
        
        let containerTopY = gridLayout.getContainerTop()
        let containerBottomY = gridLayout.getContainerBottom()
        if containerBottomY <= containerTopY {
            return
        }
        
        let onScreen = getFirstAndLastCellIndexOnScreen()
        guard onScreen.isValid else {
            return
        }
        
        //if _isComputingDownloadPriorities {
        //    _isComputingDownloadPrioritiesEnqueued = true
        //    return
        //}
        
        let containerRangeY = containerTopY...containerBottomY
        //_isComputingDownloadPriorities = true
        
        let taskList = await downloader.taskList
        
        _priorityCommunityCellDatas.removeAll(keepingCapacity: true)
        _priorityList.removeAll(keepingCapacity: true)
        
        for task in taskList {
            let cellIndex = task.index
            if let communityCellData = getCommunityCellData(at: cellIndex) {
                
                let cellLeftX = gridLayout.getCellLeft(cellIndex: cellIndex)
                let cellTopY = gridLayout.getCellTop(cellIndex: cellIndex)
                let cellBottomY = gridLayout.getCellBottom(cellIndex: cellIndex)
                let cellRangeY = cellTopY...cellBottomY
                
                let overlap = containerRangeY.overlaps(cellRangeY)
                
                if overlap {
                    let distX = cellLeftX
                    let distY = max(cellTopY - containerTopY, 0)
                    let priority = priority(distX: distX, distY: distY)
                    
                    _priorityCommunityCellDatas.append(communityCellData)
                    _priorityList.append(priority)
                } else {
                    _priorityCommunityCellDatas.append(communityCellData)
                    _priorityList.append(0)
                }
            }
        }
        await downloader.setPriorityBatchAndSetAllOtherPrioritiesToZero(_priorityCommunityCellDatas, _priorityList)
    }
}

extension CommunityViewModel: CommunityGridLayoutDelegate {
    func layoutContentsDidChangeSize(size: CGSize) {
        layoutContentsSizeUpdatePublisher.send(size)
    }
    
    func layoutContainerDidChangeSize(size: CGSize) {
        layoutContainerSizeUpdatePublisher.send(size)
    }
    
    @MainActor func layoutDidChangeVisibleCells() {
        handleVisibleCellsMayHaveChanged()
    }
}

extension CommunityViewModel: DirtyImageDownloaderDelegate {
    @MainActor func dataDownloadDidStart(_ index: Int) {
        
    }
    
    @MainActor func dataDownloadDidSucceed(_ index: Int, image: UIImage) {
        _imageFailedSet.remove(index)
        if let communityCellData = getCommunityCellData(at: index) {
            if let key = communityCellData.key {
                _imageDict[key] = image
                Task {
                    await imageCache.cacheImage(image, key)
                }
            }
        }
    }
    
    @MainActor func dataDownloadDidCancel(_ index: Int) {
        print("🧩 We had an image cancel its download @ \(index)")
        //_imageFailedSet.remove(index)
    }
    
    @MainActor func dataDownloadDidFail(_ index: Int) {
        print("🎲 We had an image fail to download @ \(index)")
        _imageFailedSet.insert(index)
    }
}
