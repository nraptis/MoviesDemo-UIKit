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
    
    typealias NWMovie = BlockChainNetworking.NWMovie
    typealias DBMovie = BlockChainDatabase.DBMovie
    
    static let probeAheadOrBehindRangeForDownloads = Device.isPad ? 12 : 8
    
    static let DEBUG_STATE_CHANGES = false
    
    @MainActor let cellNeedsUpdatePublisher = PassthroughSubject<CommunityCellModel, Never>()
    @MainActor let layoutContainerSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let layoutContentsSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let visibleCellsUpdatePublisher = PassthroughSubject<Void, Never>()
    
    @MainActor private var _reachabilityDidUpdateSunscriber: AnyCancellable?
    
    private var databaseController = BlockChainDatabase.DBDatabaseController()
    let downloader = DirtyImageDownloader(numberOfSimultaneousDownloads: 3)
    @MainActor let gridLayout = CommunityGridLayout()
    let imageCache = DirtyImageCache(name: "dirty_cache")
    
    @MainActor var _imageDict  = [String: UIImage]()
    @MainActor var _imageFailedSet = Set<Int>()
    @MainActor var _imageDidCheckCacheSet = Set<Int>()
    
    @MainActor var _checkCacheKeys = [KeyIndex]()
    @MainActor var _cacheContents = [KeyIndexImage]()
    
    @MainActor private(set) var visibleCommunityCellModels = [CommunityCellModel]()
    @MainActor private(set) var communityCellModels = [CommunityCellModel]()
    
    var _downloadCommunityCellDatas = [CommunityCellData]()
    var _downloadCommunityCellModelsUnsafe = [CommunityCellModel]()
    
    @MainActor var numberOfItems = 0
    
    @MainActor var numberOfCells = 0
    @MainActor var numberOfPages = 100_000_000
    
    @MainActor var highestPageFetchedSoFar = 0
    
    private var _priorityCommunityCellDatas = [CommunityCellData]()
    private var _priorityList = [Int]()
    
    private var _isAppInBackground = false
    
    private var isOnPulse = false
    var _visibleCommunityCellModelIndices = Set<Int>()
    
    @MainActor private(set) var isRefreshing = false
    
    // These are sort of the UI driving variables
    // only "isFetching" and "isFetchingDetails" and "isNetworkErrorPresent" are used internally.
    
    @Published @MainActor private(set) var isFetchingUserInitiated = false
    @Published @MainActor private(set) var isFetching = false
    @Published @MainActor var isFetchingDetails = false
    @Published @MainActor private(set) var isNetworkErrorPresent = false
    @Published @MainActor var isAnyItemPresent = false
    @Published @MainActor var isFirstFetchComplete = false
    
    // The recent network fetches we made. In some cases,
    // we alter our business logic based on what the
    // previous 3 or 4 fetches were, as to not get locked.
    struct RecentNetworkFetch {
        let date: Date
        let page: Int
    }
    
    var recentFetches = [RecentNetworkFetch]()
    var recentFetchesTemp = [RecentNetworkFetch]()
    
    @MainActor private var _fetchMorePagesPagesToCheck = [Int]()
    @MainActor var communityCellDatas = [CommunityCellData?]()
    @MainActor var communityCellDataQueue = [CommunityCellData]()
    
    private var _heartBeatTask: Task<Void, Never>?
    
    @MainActor let router: Router
    @MainActor init(router: Router) {
        
        self.router = router
        
        downloader.delegate = self
        downloader.isBlocked = true
        gridLayout.delegate = self
        
        // In this case, it doesn't matter the order that the imageCache and dataBase load,
        // however, we want them to both load before the network call fires.
        Task { @MainActor in
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
        
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { notification in
            Task { @MainActor [weak self] in
                if let self = self {
                    self._handleMemoryWarning()
                }
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationDidEnterBackground(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                       selector: #selector(handleApplicationWillEnterForeground(_:)),
                                       name: UIApplication.willEnterForegroundNotification,
                                       object: nil)
        
        _reachabilityDidUpdateSunscriber = ReachabilityMonitor.shared.reachabilityDidUpdatePublisher
            .sink { [weak self] in
                if let self = self {
                    self._handleReachabilityChanged()
                }
            }
        
        _heartBeatTask = Task { @MainActor in
            await self.heartbeat()
        }
        
    }
    
    @objc @MainActor private func handleApplicationDidEnterBackground(_ notification: Notification) {
        print("{{🚔}} App Did Enter Background ==> Snap!")
        
        isFetching = false
        isRefreshing = false
        isNetworkErrorPresent = false
        
        _isAppInBackground = true
        if let ___heartBeatTask = _heartBeatTask {
            ___heartBeatTask.cancel()
            print("_heartBeatTask = nil (e-back)")
            self._heartBeatTask = nil
        }
    }
    
    @objc @MainActor private func handleApplicationWillEnterForeground(_ notification: Notification) {
        
        print("{{🚔}} App Will Enter Foreground ==> Woot!")
        _isAppInBackground = false
        
        // Let's try to re-fetch all the fails...
        _imageFailedSet.removeAll(keepingCapacity: true)
        
        print("_heartBeatTask = ... (enter force ground, alt)")
        _heartBeatTask = Task { @MainActor in
            await self.heartbeat()
        }
        
        recentFetches.removeAll(keepingCapacity: true)
        
        // There is a weird bug where the visible cells change.
        // So, let's tell the UI that we have updated visible cells.
        visibleCellsUpdatePublisher.send(())
        handleVisibleCellsMayHaveChanged()
        
        if isFirstFetchComplete {
            if ReachabilityMonitor.shared.isReachable {
                if self.isFirstFetchComplete && !self.isFetching && !self.isRefreshing {
                    isNetworkErrorPresent = false
                    self.fetchMorePagesIfNecessary()
                } else {
                    isNetworkErrorPresent = true
                }
            } else {
                isNetworkErrorPresent = true
            }
        } else {
            isNetworkErrorPresent = true
        }
    }
    
    @MainActor private func _handleReachabilityChanged() {
        recentFetches.removeAll(keepingCapacity: true)
        if ReachabilityMonitor.shared.isReachable {
            if !_isAppInBackground {
                
                // Let's try to re-fetch all the fails...
                _imageFailedSet.removeAll(keepingCapacity: true)
                
                if self.isFirstFetchComplete && !self.isFetching && !self.isRefreshing {
                    self.fetchMorePagesIfNecessary()
                }
            }
        }
    }
    
    @MainActor private func _handleMemoryWarning() {
        _imageDict.removeAll(keepingCapacity: true)
        _imageFailedSet.removeAll(keepingCapacity: true)
        _imageDidCheckCacheSet.removeAll(keepingCapacity: true)
    }
    
    @MainActor func getBatchUpdateChunkNumberOfCells() -> Int {
        var result = gridLayout.getNumberOfCols()
        if result < 4 {
            result = 4
        }
        if result > 8 {
            result = 8
        }
        return result
    }
    
    @MainActor func getBatchUpdateChunkSleepDuration() -> UInt64 {
        //0.015 seconds
        return 15_000_000
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
            try? await Task.sleep(nanoseconds: 25_000_000)
            if !_isAppInBackground {
                _heartBeatTask = Task { @MainActor [weak self] in
                    if let self = self {
                        await self.heartbeat()
                    }
                }
            }
        }
    }
    
    @MainActor func pulse() async {
        if isRefreshing {
            return
        }
        isOnPulse = true
        await refreshAllCellStatesAndReconcile()
        fetchMorePagesIfNecessary()
        isOnPulse = false
    }
    
    @MainActor func _refreshVisibleCommunityCellModelIndices() {
        _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
        for communityCellModel in visibleCommunityCellModels {
            _visibleCommunityCellModelIndices.insert(communityCellModel.index)
        }
    }
    
    @MainActor func refresh() async {
        @MainActor func _clearForRefresh() {
            _imageDict.removeAll()
            _imageFailedSet.removeAll()
            _imageDidCheckCacheSet.removeAll()
            gridLayout.clear()
            _visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
            visibleCommunityCellModels.removeAll(keepingCapacity: true)
            communityCellModels.removeAll(keepingCapacity: true)
            _clearCommunityCellDatas()
        }
        
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
                try? await Task.sleep(nanoseconds: 2_000_000)
                fudge += 1
                if fudge >= 100_000 {
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
                try? await Task.sleep(nanoseconds: 2_000_000)
                fudge += 1
                if fudge >= 100_000 {
                    print("🧛🏻‍♂️ Terminating refresh, we are fetch-locked.")
                    downloader.isBlocked = false
                    isRefreshing = false
                    return
                }
            }
        }
        
        //
        // For the sake of UX, let's throw everything into the
        // "missing model" state and sleep for 1s.
        //
        // We can get a lag blip on refresh when ALL the cells change
        // state. So, we stagger this process to not starve the thread.
        // Note: It really only lags with tons of cells, so it's a
        // little bit overboard.
        //
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
                                                     isFromHeartBeat: false,
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
            } else {
                // A refresh where there are no network items,
                // but we do have items from the database...
                numberOfItems = dbMovies.count
                numberOfCells = dbMovies.count
                numberOfPages = 100_000_000
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
            fetchPopularMovies_synchronize(nwMovies: nwMovies, page: 1)
            
            // We should reset the number of cells here.
            // When the scroll content shrinks like this,
            // it causes a hop. Better to only grow the
            // scroll content size...
            
            downloader.isBlocked = false
            isRefreshing = false
            
            gridLayout.registerNumberOfCells(numberOfCells)
            handleVisibleCellsMayHaveChanged()
        }
        _updateAnyItemPresent()
    }
    
    @MainActor private func _updateAnyItemPresent() {
        if gridLayout.isAnyItemPresent {
            if isAnyItemPresent == false {
                isAnyItemPresent = true
            }
        } else {
            if isAnyItemPresent == true {
                isAnyItemPresent = false
            }
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
    
    @MainActor func forceFetchPopularMovies() async {
        isFetchingUserInitiated = true
        
        // If there is an active fetch, wait for it to stop.
        if isFetching {
            var fudge = 0
            while isFetching {
                try? await Task.sleep(nanoseconds: 2_000_000)
                fudge += 1
                if fudge >= 100_000 {
                    print("🧛🏻‍♂️ Terminating user initiated fetch, we are fetch-locked.")
                    isFetchingUserInitiated = false
                    return
                }
            }
        }
        
        if isRefreshing {
            var fudge = 0
            while isRefreshing {
                try? await Task.sleep(nanoseconds: 2_000_000)
                fudge += 1
                if fudge >= 100_000 {
                    print("🧛🏻‍♂️ Terminating user initiated fetch, we are refresh-locked.")
                    isFetchingUserInitiated = false
                    return
                }
            }
        }
        
        var chosenPageIndexToFetch = -1
        
        let numberOfCols = gridLayout.getNumberOfCols()
        let firstCellIndexToConsider = gridLayout.getFirstCellIndexOnScreen() - numberOfCols
        let lastCellIndexToConsider = gridLayout.getLastCellIndexOnScreenNotClamped() + (numberOfCols * 2)
        
        var index = firstCellIndexToConsider
        while index < lastCellIndexToConsider {
            if getCommunityCellData(at: index) === nil {
                chosenPageIndexToFetch = index
                break
            }
            index += 1
        }
        
        print("🚨 forceFetchPopularMovies, chosenPageIndexToFetch = \(chosenPageIndexToFetch)")
        
        let pageIndexToCheck = (chosenPageIndexToFetch / NWNetworkController.page_size)
        let pageToCheck = pageIndexToCheck + 1
        
        print("🚨 forceFetchPopularMovies, pageToCheck = \(pageToCheck)")
        
        recentFetches.removeAll(keepingCapacity: true)
        
        await fetchPopularMovies(page: pageToCheck)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isFetchingUserInitiated = false
    }
    
    @MainActor func fetchPopularMovies(page: Int) async {
        
        if isFetching {
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
                } else {
                    print("📀 \"_fetchPopularMoviesWithDatabase\" successfully fetched \(dbMovies.count) items from CoreData.")
                    numberOfItems = dbMovies.count
                    numberOfCells = dbMovies.count
                    numberOfPages = 100_000_000
                    highestPageFetchedSoFar = -1
                    fetchPopularMovies_synchronize(dbMovies: dbMovies)
                }
            }
        } else {
            print("📡 \"fetchPopularMovies\" successfully fetched \(nwMovies.count) items from the internet.")
            fetchPopularMovies_synchronize(nwMovies: nwMovies, page: page)
        }
        
        // On the very first fetch, we want to wait a minute.
        // We will use this value to drive UI state..
        if isFirstFetchComplete == false {
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            isFetching = false
            isFirstFetchComplete = true
        } else {
            isFetching = false
        }
        
        gridLayout.registerNumberOfCells(numberOfCells)
        handleVisibleCellsMayHaveChanged()
        
        _updateAnyItemPresent()
    }
    
    @MainActor private func fetchPopularMovies_synchronize(nwMovies: [NWMovie], page: Int) {
        
        if page <= 0 {
            print("🧌 \"fetchPopularMovies_synchronize\" page = \(page), this seems wrong. We expect the pages to start at 1, and number up.")
            return
        }
        
        // The first index of the cells, in the master list.
        let startCellIndex = (page - 1) * NWNetworkController.page_size
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
        
        //
        // Write the new cells over this range. Everything
        // which was in the range should have been cleaned
        // out by the previous step. Similar to memcpy.
        //
        itemIndex = 0
        cellModelIndex = index
        while itemIndex < newCommunityCellDatas.count {
            let communityCellData = newCommunityCellDatas[itemIndex]
            communityCellDatas[cellModelIndex] = communityCellData
            itemIndex += 1
            cellModelIndex += 1
        }
    }
    
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
                if timeElapsed <= 10 {
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
            
            if page > highestPageFetchedSoFar {
                highestPageFetchedSoFar = page
            }
            
            var _numberOfCells = (highestPageFetchedSoFar) * NWNetworkController.page_size
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
    
    @MainActor func handleCellClicked(at index: Int) async {
        
        if isFetchingDetails {
            print("🪚 [STOPPED] Attempted to queue up fetch details twice.")
            return
        }
        
        isFetchingDetails = true
        
        // Sleep to see the UI
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        if let communityCellData = getCommunityCellData(at: index) {
            do {
                let id = communityCellData.id
                let nwMovieDetails = try await BlockChainNetworking.NWNetworkController.fetchMovieDetails(id: id)
                print("🎥 Movie fetched! For \(communityCellData.title) [\(communityCellData.id)]")
                print(nwMovieDetails)
                router.pushMovieDetails(nwMovieDetails: nwMovieDetails)
                
                // Here we want the load spinner to not flicker...
                try? await Task.sleep(nanoseconds: 1_250_000_000)
                isFetchingDetails = false
                
            } catch {
                print("🧌 Unable to fetch movie details (Network): \(error.localizedDescription)")
                router.rootViewModel.showError("Oops!", "Looks like we couldn't fetch the data! Check your connection!")
                isFetchingDetails = false
            }
        } else {
            print("🧌 Unable to fetch movie details (No Model)")
            router.rootViewModel.showError("Oops!", "Looks like we couldn't fetch the data! Check your connection!")
            isFetchingDetails = false
        }
    }
    
    @MainActor func handleCellForceRetryDownload(at index: Int) async {
        print("🚦 Force download restart @ \(index)")
        
        guard (index >= 0 && index < communityCellModels.count) else {
            return
        }
        
        let communityCellModel = communityCellModels[index]
        
        guard let communityCellData = getCommunityCellData(at: index) else {
            return
        }
        
        guard let key = communityCellData.key else {
            return
        }
        
        communityCellModel.isBlockedFromHeartBeat = true
        
        switch communityCellModel.cellModelState {
        case .downloadingActively:
            // We are already downloding actively
            break
        default:
            _ = attemptUpdateCellStateDownloadingActively(communityCellModel: communityCellModel,
                                                          communityCellData: communityCellData,
                                                          visibleCellIndices: _visibleCommunityCellModelIndices,
                                                          isFromRefresh: false,
                                                          isFromHeartBeat: false,
                                                          key: key,
                                                          debug: "Force Retry, Mock Downloading",
                                                          emoji: "🍩")
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if let image = _imageDict[key] {
            _imageFailedSet.remove(index)
            switch communityCellModel.cellModelState {
            case .success:
                // We are already downloding actively
                break
            default:
                _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                  isFromRefresh: false,
                                                  isFromHeartBeat: false,
                                                  key: key,
                                                  image: image,
                                                  debug: "Force Retry, Had Image (Local)",
                                                  emoji: "🍩")
            }
            communityCellModel.isBlockedFromHeartBeat = false
            return
        }
        
        let keyIndex = KeyIndex(key: key, index: index)
        if let image = await imageCache.retrieve(keyIndex) {
            _imageDict[key] = image
            _imageFailedSet.remove(index)
            switch communityCellModel.cellModelState {
            case .success:
                // We are already downloding actively
                break
            default:
                _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                  communityCellData: communityCellData,
                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                  isFromRefresh: false,
                                                  isFromHeartBeat: false,
                                                  key: key,
                                                  image: image,
                                                  debug: "Force Retry, Had Image (Cache)",
                                                  emoji: "🍩")
            }
            communityCellModel.isBlockedFromHeartBeat = false
            return
        }
        
        await downloader.forceRestart(communityCellData)
        
        _imageFailedSet.remove(index)
        
        switch communityCellModel.cellModelState {
        case .downloadingActively:
            // We are already downloding actively
            break
        default:
            _ = attemptUpdateCellStateDownloadingActively(communityCellModel: communityCellModel,
                                                          communityCellData: communityCellData,
                                                          visibleCellIndices: _visibleCommunityCellModelIndices,
                                                          isFromRefresh: false,
                                                          isFromHeartBeat: false,
                                                          key: key,
                                                          debug: "Force Retry (We re-Download)",
                                                          emoji: "🍩")
        }
        
        communityCellModel.isBlockedFromHeartBeat = false
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
        _updateAnyItemPresent()
        
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
    
    @MainActor func _computeDownloadPriorities() async {
        
        func priority(distX: Int, distY: Int) -> Int {
            // Distance from the left of the container / screen.
            // Distance from the top of the container / screen.
            let px = (-distX)
            let py = (8192 * 8192) - (8192 * distY)
            return (px + py)
        }
        
        let containerTopY = gridLayout.getContainerTop()
        let containerBottomY = gridLayout.getContainerBottom()
        if containerBottomY <= containerTopY {
            return
        }
        
        let onScreen = getFirstAndLastCellIndexOnScreen()
        guard onScreen.isValid else {
            return
        }
        
        let containerRangeY = containerTopY...containerBottomY
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
    
    @MainActor func layoutContentsDidChangeSize(size: CGSize) {
        layoutContentsSizeUpdatePublisher.send(size)
    }
    
    @MainActor func layoutContainerDidChangeSize(size: CGSize) {
        handleVisibleCellsMayHaveChanged()
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
        _imageFailedSet.remove(index)
    }
    
    @MainActor func dataDownloadDidFail(_ index: Int) {
        _imageFailedSet.insert(index)
    }
}
