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
    
    private static let DEBUG_STATE_CHANGES = false
    
    typealias NWMovie = BlockChainNetworking.NWMovie
    typealias DBMovie = BlockChainDatabase.DBMovie
    
    @MainActor let cellNeedsUpdatePublisher = PassthroughSubject<CommunityCellModel, Never>()
    @MainActor let layoutContainerSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let layoutContentsSizeUpdatePublisher = PassthroughSubject<CGSize, Never>()
    @MainActor let visibleCellsUpdatePublisher = PassthroughSubject<Void, Never>()
    
    private static let probeAheadOrBehindRangeForDownloads = 8
    
    private var databaseController = BlockChainDatabase.DBDatabaseController()
    private let downloader = DirtyImageDownloader(numberOfSimultaneousDownloads: 2)
    
    @MainActor fileprivate var _imageDict  = [String: UIImage]()
    @MainActor fileprivate var _imageFailedSet = Set<Int>()
    @MainActor fileprivate var _imageDidCheckCacheSet = Set<Int>()
    
    @MainActor private var _checkCacheKeys = [KeyIndex]()
    @MainActor private var _cacheContents = [KeyIndexImage]()
    
    @MainActor private(set) var visibleCommunityCellModels = [CommunityCellModel]()
    
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
        
        Task { [weak self] in
            
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            Task { @MainActor in
                if let self = self {
                    await self.heartbeat()
                }
            }
        }
    }
    
    @ObservationIgnored private var isOnPulse = false
    @ObservationIgnored private var pulseNumber = 0
    
    @MainActor func pulse() async {
        
        if isRefreshing {
            return
        }
        
        isOnPulse = true
        
        pulseNumber += 1
        if pulseNumber >= 100 {
            pulseNumber = 1
        }
        
        // 1.) Get the cells which are currently displayed.
        var firstCellIndexOnScreen = gridLayout.getFirstCellIndexOnScreen() - Self.probeAheadOrBehindRangeForDownloads
        if firstCellIndexOnScreen < 0 {
            firstCellIndexOnScreen = 0
        }
        
        var lastCellIndexOnScreen = gridLayout.getLastCellIndexOnScreen() + Self.probeAheadOrBehindRangeForDownloads
        if lastCellIndexOnScreen >= numberOfCells {
            lastCellIndexOnScreen = numberOfCells - 1
        }
        
        // 2.) Make sure we talking about a valid range of cells.
        if (numberOfCells <= 0) || (firstCellIndexOnScreen > lastCellIndexOnScreen) {
            isOnPulse = false
            return
        }
        
        
        for visibleCommunityCellModel in visibleCommunityCellModels {
            
            if let communityCellData = getCommunityCellData(at: visibleCommunityCellModel.index) {
                if let key = communityCellData.key {
                    if _imageDict[key] === nil {
                        await downloader.addDownloadTask(communityCellData)
                    }
                }
            }
        }
        
        await _computeDownloadPriorities()
        await downloader.startTasksIfNecessary()
        
        for communityCellModel in visibleCommunityCellModels {
            if let communityCellData = getCommunityCellData(at: communityCellModel.index) {
             
                if let key = communityCellData.key {
                    
                    if let image = _imageDict[key] {
                        
                        //if visibleCommunityCellModel.
                        if communityCellModel.attemptUpdateStateToSuccess(communityCellData, key, image) {
                            cellNeedsUpdatePublisher.send(communityCellModel)
                        }
                    }
                }
            }
        }
        
        
        isOnPulse = false
    }
    
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
        for communityCellModel in visibleCommunityCellModels {
            let index = communityCellModel.index
            if let communityCellData = getCommunityCellData(at: index) {
                if let key = communityCellData.key {
                    if let image = _imageDict[key] {
                        if communityCellModel.attemptUpdateStateToSuccess(communityCellData, key, image) {
                            if Self.DEBUG_STATE_CHANGES {
                                print("🧰 @{\(communityCellModel.index)} State => .Success (\(image.size.width) x \(image.size.height)) [Refresh VisibleCellsChanged]")
                            }
                        }
                    } else if _imageFailedSet.contains(index) {
                        if communityCellModel.attemptUpdateStateToError(communityCellData, key) {
                            if Self.DEBUG_STATE_CHANGES {
                                print("🧰 @{\(communityCellModel.index)} State => .Error [Refresh VisibleCellsChanged]")
                            }
                        }
                    } else {
                        
                        // If we are downloading, let's stay there, otherwise go idle...
                        switch communityCellModel.cellModelState {
                        case .downloading, .downloadingActively:
                            break
                        default:
                            if communityCellModel.attemptUpdateStateToIdle(communityCellData, key) {
                                if Self.DEBUG_STATE_CHANGES {
                                    print("🧰 @{\(communityCellModel.index)} State => .Idle [Refresh VisibleCellsChanged]")
                                }
                            }
                        }
                    }
                } else {
                    if communityCellModel.attemptUpdateStateToMisingKey(communityCellData) {
                        if Self.DEBUG_STATE_CHANGES {
                            print("🧰 @{\(communityCellModel.index)} State => .MisingKey [Refresh VisibleCellsChanged]")
                        }
                    }
                }
            } else {
                if communityCellModel.attemptUpdateStateToMisingModel() {
                    if Self.DEBUG_STATE_CHANGES {
                        print("🧰 @{\(communityCellModel.index)} State => .MisingModel [Refresh VisibleCellsChanged]")
                    }
                }
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
    @MainActor func refreshAllCellStatesAndReconcile() async {
        
        
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
            
            // After we block the downloader, we cancel the tasks.
            // Supposing "block" works as expected, even the pulse
            // process should *NOT* be able to add a new download.
            //
            // It wouldn't hurt anything to cancel it again. However,
            // it shouldn't be required. That would be misunderstood.
            //
            // await downloader.cancelAll()
        }
        
        // handleVisibleCellsMayHaveChanged is not asynchronounous;
        // we are asynchronous. So, the visible cells could change
        // after every single await statement. This function should
        // be invulnerable against visible cells changing.
        /*
        if isOnVisibleCellsMayHaveChanged {
            
            var fudge = 0
            while isOnVisibleCellsMayHaveChanged {
                try? await Task.sleep(nanoseconds: 1_000_000)
                fudge += 1
                if fudge >= 2048 {
                    print("🧛🏻‍♂️ Terminating refresh, we are visible cells-locked.")
                    downloader.isBlocked = false
                    isRefreshing = false
                    return
                }
            }
        }
        */
        
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
        for communityCellModel in visibleCommunityCellModels {
            switch communityCellModel.cellModelState {
            case .missingModel:
                break
            default:
                if Self.DEBUG_STATE_CHANGES {
                    print("🧰 @{\(communityCellModel.index)} State => .missingModel [Refresh, Initial Setting]")
                }
                communityCellModel.cellModelState = .missingModel
                cellNeedsUpdatePublisher.send(communityCellModel)
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
    
    @MainActor private func _clearVisibleCommunityCellModels() {
        for communityCellModel in visibleCommunityCellModels {
            _depositCommunityCellModel(communityCellModel)
        }
        visibleCommunityCellModels.removeAll(keepingCapacity: true)
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
        
        _clearVisibleCommunityCellModels()
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
    
    @ObservationIgnored @MainActor private var recentFetches = [RecentNetworkFetch]()
    @MainActor private func _fetchPopularMoviesWithNetwork(page: Int) async -> [NWMovie] {
        
        //
        // Let's keep peace with the network. If for some reason, we are
        // stuck in a fetch loop, we will throttle it to every 120 seconds.
        //
        if recentFetches.count >= 3 {
            let lastFetch = recentFetches[recentFetches.count - 1]
            if lastFetch.page == page {
                let timeElapsed = Date().timeIntervalSince(lastFetch.date)
                if timeElapsed <= 120 {
                    print("💭 Stalling fetch. Only \(timeElapsed) seconds went by since last fetch of page \(page)")
                    isNetworkErrorPresent = true
                    return []
                }
            }
        }
        
        recentFetches.append(RecentNetworkFetch(date: Date(), page: page))
        if recentFetches.count > 3 {
            _ = recentFetches.removeFirst()
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
        /*
        Task { @MainActor in
            await _computeDownloadPriorities()
        }
        */
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
    
    
    @MainActor var communityCellModelQueue = [CommunityCellModel]()
    @MainActor func _withdrawCommunityCellModel(index: Int) -> CommunityCellModel {
        if communityCellModelQueue.count > 0 {
            let result = communityCellModelQueue.removeLast()
            result.index = index
            return result
        } else {
            let result = CommunityCellModel()
            return result
        }
    }
    
    @MainActor private func _depositCommunityCellModel(_ cellModel: CommunityCellModel) {
        cellModel.index = -1
        cellModel.cellModelState = .missingModel
        communityCellModelQueue.append(cellModel)
    }
    
    @MainActor func fetchMorePagesIfNecessary() {
        
        if isFetching { return }
        if isRefreshing { return }
        
        // They have to pull-to-refresh when the network comes back on...
        if isNetworkErrorPresent { return }
        
        //
        // This needs a valid page size...
        // It sucks they chose "page" instead of (index, limit)
        //
        if pageSize < 1 { return }
        
        let firstCellIndexOnScreen = gridLayout.getFirstCellIndexOnScreen()
        let lastCellIndexOnScreen = gridLayout.getLastCellIndexOnScreen()
        if firstCellIndexOnScreen >= lastCellIndexOnScreen { return }
        
        let numberOfCols = gridLayout.getNumberOfCols()
        
        var _lowest = firstCellIndexOnScreen
        var _highest = lastCellIndexOnScreen
        
        _lowest -= numberOfCols
        _highest += (numberOfCols * 2)
        
        if _lowest < 0 {
            _lowest = 0
        }
        
        // These don't change after these lines. Indicated as such with grace.
        let lowest = _lowest
        let highest = _highest
        
        var checkIndex = lowest
        while checkIndex < highest {
            if getCommunityCellData(at: checkIndex) === nil {
                let pageIndexToFetch = (checkIndex / pageSize)
                let pageToFetch = pageIndexToFetch + 1
                if pageToFetch < numberOfPages {
                    Task {
                        await fetchPopularMovies(page: pageToFetch)
                    }
                    return
                }
            }
            checkIndex += 1
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
        
        _clearVisibleCommunityCellModels()
        
        let onScreen = getFirstAndLastCellIndexOnScreen()
        guard onScreen.isValid else {
            return
        }
        
        var index = onScreen.firstIndex
        while index <= onScreen.lastIndex {
            let communityCellModel = _withdrawCommunityCellModel(index: index)
            visibleCommunityCellModels.append(communityCellModel)
            index += 1
        }
        
        visibleCellsUpdatePublisher.send()
        refreshAllCellStatesForVisibleCellsChanged()
        
        Task {
            await downloader.cancelAllOutOfIndexRange(firstIndex: onScreen.firstIndex, lastIndex: onScreen.lastIndex)
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
        await downloader.setPriorityBatch(_priorityCommunityCellDatas, _priorityList)
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
    }
    
    @MainActor func dataDownloadDidFail(_ index: Int) {
        print("🎲 We had an image fail to download @ \(index)")
        _imageFailedSet.insert(index)
    }
}
