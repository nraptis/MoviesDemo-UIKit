//
//  CommunityViewModel+Reconcile.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/23/24.
//

import UIKit

extension CommunityViewModel {
    
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
    @MainActor func refreshAllCellStatesAndReconcile() async {
        
        let batchUpdateChunkNumberOfCells = getBatchUpdateChunkNumberOfCells()
        let batchUpdateChunkSleepDuration = getBatchUpdateChunkSleepDuration()
        
        // It's possible to have the downloading item be in the
        // fail set. There's only two lines where we can trip the
        // asynchronous boundary. Which are these:
        // if await downloader.isDownloading(communityCellData) {
        // if _downloadCommunityCellDatas.count > 0 {
        //
        // In our stress test function, it's possible to remove items
        // from the fail set. The only other place that the fail set
        // updates is when a download fails (as notified by delegate method)
        //
        // Long story short, this is the safe way to handle
        // this synchronization issue. It should happen at the
        // asynchronous boundary though. The other option is
        // to do separate checks every time we check if we are
        // downloading and can possibly change state...
        
        if true {
            
            // Note the visibleCommunityCellModels can CHANGE during this loop...
            // for communityCellModel in visibleCommunityCellModels {
            
            var loopIndex = 0
            while loopIndex < visibleCommunityCellModels.count {
                let communityCellModel = visibleCommunityCellModels[loopIndex]
                let index = communityCellModel.index
                if let communityCellData = getCommunityCellData(at: index) {
                    if await downloader.isDownloading(communityCellData) {
                        if _imageFailedSet.contains(index) {
                            print("{{🍔}} Trap case. @ \(index) The downloader and failure dict are out of sync...")
                            _imageFailedSet.remove(index)
                        }
                    }
                }
                loopIndex += 1
            }
        }
        
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
                
                if Task.isCancelled {
                    return
                }
                
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
                                                                     visibleCellIndices: nil,
                                                                     isFromRefresh: false,
                                                                     isFromHeartBeat: true,
                                                                     key: key,
                                                                     image: image,
                                                                     debug: "Reconcile, Recovered From Master Dict",
                                                                     emoji: "🎰") {
                                        waveNumberOfUpdatesTriggered += 1
                                    }
                                } else if _imageFailedSet.contains(index) {
                                    if attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                                   communityCellData: communityCellData,
                                                                   visibleCellIndices: nil,
                                                                   isFromRefresh: false,
                                                                   isFromHeartBeat: true,
                                                                   key: key,
                                                                   debug: "Reconcile, Front Loaded Error State",
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
            if _imageDidCheckCacheSet.contains(index) { continue }
            if let communityCellData = getCommunityCellData(at: index) {
                if let key = communityCellData.key {
                    _imageDidCheckCacheSet.insert(index)
                    _checkCacheKeys.append(KeyIndex(key: key, index: index))
                }
            }
        }
        
        if _checkCacheKeys.count > 0 {
            
            // Batch fetch these "need to check cache". This batch fetch
            // automatically will sleep after loading several images, so
            // we are not starving the processor. When this finishes,
            // we'll have the whole dictionary of [KeyIndex: UIImage]
            // from the cache, so we can inject.
            let indexImageDict = await imageCache.retrieveBatch(_checkCacheKeys)
            
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
            while waveUpdateIndex < communityCellModels.count {
                
                // Do not return if task is cancelled, we need to transfer
                // state, the attempted cache hits must finish syncing
                
                var waveNumberOfUpdatesTriggered = 0
                while waveUpdateIndex < communityCellModels.count && waveNumberOfUpdatesTriggered < batchUpdateChunkNumberOfCells {
                    let communityCellModel = communityCellModels[waveUpdateIndex]
                    let index = communityCellModel.index
                    
                    if let image = indexImageDict[index] {
                        if let communityCellData = getCommunityCellData(at: index) {
                            if let key = communityCellData.key {
                                // Insert this image into our master dictionary.
                                _imageDict[key] = image
                                
                                if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                                 communityCellData: communityCellData,
                                                                 visibleCellIndices: nil,
                                                                 isFromRefresh: false,
                                                                 isFromHeartBeat: true,
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
        
        if Task.isCancelled {
            return
        }
        
        // There is now a race condition. Since we did await, it's
        // possible that the internal state required for these cells
        // has changed.
        //
        // So, we do another pass through the visible cells and handle
        // updates accounting for the "fail" state and "has image"
        // state. Since this is rare, we will not batch chunk this
        // process, as the batch chunk process would cause additional
        // boundary conditions. So, a one-shot pass, no awaits...
        //
        // There are some potential data races we will not account for,
        // such as "missing key" and "missing model". There just isn't
        // much advantage to having these rare states handled correct
        // down to the nanosecond level. At worst, they could flicker.
        // In practice, I do not think these unaccounted states will
        // be the real culprit for any flickering...
        //
        if true {
            for communityCellModel in visibleCommunityCellModels {
                let index = communityCellModel.index
                if let communityCellData = getCommunityCellData(at: index) {
                    if let key = communityCellData.key {
                        if let image = _imageDict[key] {
                            switch communityCellModel.cellModelState {
                                // We are already in the success state
                            case .success:
                                break
                            default:
                                // Update to the success state
                                _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                                  communityCellData: communityCellData,
                                                                  visibleCellIndices: nil,
                                                                  isFromRefresh: false,
                                                                  isFromHeartBeat: true,
                                                                  key: key,
                                                                  image: image,
                                                                  debug: "Post Cache Scrape Check-Up, Image Now Exists",
                                                                  emoji: "🌚")
                            }
                        } else if _imageFailedSet.contains(index) {
                            // We no longer need to download the image.
                            switch communityCellModel.cellModelState {
                            case .error:
                                // We are already in the error state
                                break
                            default:
                                // Update to error state.
                                _ = attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                                communityCellData: communityCellData,
                                                                visibleCellIndices: nil,
                                                                isFromRefresh: false,
                                                                isFromHeartBeat: true,
                                                                key: key,
                                                                debug: "Post Cache Scrape Check-Up, Error State Now Exists",
                                                                emoji: "🌚")
                            }
                        }
                    }
                }
            }
        }
        
        // Now we will add everything to the downloader, which should be downloaded.
        // This is the ONLY point in code which will add tasks to the downloader,
        // so we do not need to worry about asynchronous boundaries in checking
        // whether an item is downloading or not... So, first, we load up everything
        // that needs to be downloaded into a big list...
        _downloadCommunityCellModelsUnsafe.removeAll(keepingCapacity: true)
        
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
                                        _downloadCommunityCellModelsUnsafe.append(communityCellModel)
                                    }
                                }
                            }
                        }
                    }
                }
                communityCellModelIndex += 1
            }
        }
        
        if Task.isCancelled {
            return
        }
        
        // There is now a race condition. Since we did await, it's
        // possible that the internal state required for these cells
        // has changed. One race condition we will not account for
        // is that the image has appeared in the cache, but not the
        // download dict. This can only happen as the result of a
        // memory warning (or debug tampering...) Since they run
        // on two separate actors (download and cache), we cannot
        // have any way to guarantee integrity between the two.
        // One simple answer would be to put them both on the same
        // actor. Instead, I am allowing for a very rare transient
        // state. With the heartbeat process, the state will only
        // last for a very short time. Practically, it does not happen.
        //
        // So, the process is to clean up this list of download
        // candidates, accounting for the "fail" state and "has image"
        // state. Since this is rare, we will not batch chunk this
        // process, as the batch chunk process would cause additional
        // boundary conditions. So, a one-shot pass, no awaits...
        
        if _downloadCommunityCellModelsUnsafe.count > 0 {
            
            _downloadCommunityCellDatas.removeAll(keepingCapacity: true)
            
            // Find out if we should REALLY, for super realz
            // add it to the list. This is not a game.
            var loopIndex = 0
            while loopIndex < _downloadCommunityCellModelsUnsafe.count {
                
                if Task.isCancelled {
                    return
                }
                
                let communityCellModel = _downloadCommunityCellModelsUnsafe[loopIndex]
                let index = communityCellModel.index
                if let communityCellData = getCommunityCellData(at: index) {
                    if let key = communityCellData.key {
                        if let image = _imageDict[key] {
                            // We no longer need to download the image.
                            switch communityCellModel.cellModelState {
                                // We are already in the success state
                            case .success:
                                break
                            default:
                                // Update to the success state
                                _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                                  communityCellData: communityCellData,
                                                                  visibleCellIndices: nil,
                                                                  isFromRefresh: false,
                                                                  isFromHeartBeat: true,
                                                                  key: key,
                                                                  image: image,
                                                                  debug: "PostDownloadQueue-Up Check, Image Now Exists",
                                                                  emoji: "☃️")
                            }
                        } else if _imageFailedSet.contains(index) {
                            // We no longer need to download the image.
                            switch communityCellModel.cellModelState {
                            case .error:
                                // We are already in the error state
                                break
                            default:
                                // Update to error state.
                                _ = attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                                communityCellData: communityCellData,
                                                                visibleCellIndices: nil,
                                                                isFromRefresh: false,
                                                                isFromHeartBeat: true,
                                                                key: key,
                                                                debug: "PostDownloadQueue-Up Check, Error State Now Exists",
                                                                emoji: "☃️")
                            }
                        } else {
                            // We still to download the image.
                            _downloadCommunityCellDatas.append(communityCellData)
                        }
                        
                    }
                }
                loopIndex += 1
            }
            
            // Now, we hand them off to the downloader...
            if _downloadCommunityCellDatas.count > 0 {
                await downloader.addDownloadTaskBatch(_downloadCommunityCellDatas)
            }
        }
        
        // Before we start the download tasks, compute the
        // priorities. In our current scheme, we can ONLY
        // start a download task if the priority is set.
        await _computeDownloadPriorities()
        
        if Task.isCancelled {
            return
        }
        
        // This will be the ONLY place we start the download
        // tasks. So, the priorities should always be set ahead of time.
        await downloader.startTasksIfNecessary()
        
        if Task.isCancelled {
            return
        }
        
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
                
                if Task.isCancelled {
                    return
                }
                
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
                if attemptUpdateCellStateMisingModel(communityCellModel: communityCellModel,
                                                     visibleCellIndices: nil,
                                                     isFromRefresh: false,
                                                     isFromHeartBeat: true,
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
                if attemptUpdateCellStateMissingKey(communityCellModel: communityCellModel,
                                                    communityCellData: communityCellData,
                                                    visibleCellIndices: nil,
                                                    isFromRefresh: false,
                                                    isFromHeartBeat: true,
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
                if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                 communityCellData: communityCellData,
                                                 visibleCellIndices: nil,
                                                 isFromRefresh: false,
                                                 isFromHeartBeat: true,
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
                    if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: nil,
                                                  isFromRefresh: false,
                                                  isFromHeartBeat: true,
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
                    if attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                     communityCellData: communityCellData,
                                                     visibleCellIndices: nil,
                                                     isFromRefresh: false,
                                                     isFromHeartBeat: true,
                                                     key: key,
                                                     image: image,
                                                     debug: "ExhaustiveCheck, Downloading Oddball Image State",
                                                     emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                } else if _imageFailedSet.contains(communityCellModel.index) {
                    if attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                   communityCellData: communityCellData,
                                                   visibleCellIndices: nil,
                                                   isFromRefresh: false,
                                                   isFromHeartBeat: true,
                                                   key: key,
                                                   debug: "ExhaustiveCheck, Downloading Oddball Error State",
                                                   emoji: "🎱") {
                        return true
                    } else {
                        return false
                    }
                } else {
                    if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: nil,
                                                  isFromRefresh: false,
                                                  isFromHeartBeat: true,
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
            _imageFailedSet.remove(communityCellModel.index)
            if await downloader.isDownloadingActively(communityCellData) {
                switch communityCellModel.cellModelState {
                case .downloadingActively:
                    // We are already in the downloading actively state
                    return false
                default:
                    // Update to downloading actively state.
                    if attemptUpdateCellStateDownloadingActively(communityCellModel: communityCellModel,
                                                                 communityCellData: communityCellData,
                                                                 visibleCellIndices: nil,
                                                                 isFromRefresh: false,
                                                                 isFromHeartBeat: true,
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
                    if attemptUpdateCellStateDownloading(communityCellModel: communityCellModel,
                                                         communityCellData: communityCellData,
                                                         visibleCellIndices: nil,
                                                         isFromRefresh: false,
                                                         isFromHeartBeat: true,
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
                if attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                               communityCellData: communityCellData,
                                               visibleCellIndices: nil,
                                               isFromRefresh: false,
                                               isFromHeartBeat: true,
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
                if attemptUpdateCellStateIdle(communityCellModel: communityCellModel,
                                              communityCellData: communityCellData,
                                              visibleCellIndices: nil,
                                              isFromRefresh: false,
                                              isFromHeartBeat: true,
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
}
