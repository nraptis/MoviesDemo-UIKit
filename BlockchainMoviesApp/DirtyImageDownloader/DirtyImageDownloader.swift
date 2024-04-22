//
//  DirtyImageDownloader.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/9/24.
//

import UIKit

//
// The most important thing to note about this downloader
// is that it is PRIORITY based. It WILL NOT START a download
// task until the priority has been set. This is to prevent
// race conditions, such as the wrong item downloading first.
//

//
// Note: This "DirtyImageDownloaderActor" is a high speed
//       actor, it is only for protecting the mutable state
//       of the internal dictionary. So all awaits are
//       going to be lightning quick.
//
@globalActor actor DirtyImageDownloaderActor {
    static let shared = DirtyImageDownloaderActor()
}

protocol DirtyImageDownloaderDelegate: AnyObject {
    func dataDownloadDidStart(_ index: Int)
    func dataDownloadDidSucceed(_ index: Int, image: UIImage)
    func dataDownloadDidFail(_ index: Int)
    func dataDownloadDidCancel(_ index: Int)
}

protocol DirtyImageDownloaderType: AnyObject, Hashable {
    var index: Int { get }
    var urlString: String? { get }
}

class DirtyImageDownloader {
    
    var isPaused = false
    var isBlocked = false
    
    @MainActor weak var delegate: DirtyImageDownloaderDelegate?
    
    private let numberOfSimultaneousDownloads: Int
    init(numberOfSimultaneousDownloads: Int) {
        self.numberOfSimultaneousDownloads = numberOfSimultaneousDownloads
    }
    
    @DirtyImageDownloaderActor private(set) var taskDict = [Int: DirtyImageDownloaderTask]()
    
    @DirtyImageDownloaderActor var taskList: [DirtyImageDownloaderTask] {
        var result = [DirtyImageDownloaderTask]()
        for (_, task) in taskDict {
            result.append(task)
        }
        return result
    }
    
    @DirtyImageDownloaderActor func cancelAll() async {
        for (_, task) in taskDict {
            await task.invalidate()
        }
        taskDict.removeAll(keepingCapacity: true)
    }
    
    @DirtyImageDownloaderActor func cancelAllRandomly() async {
        for (_, task) in taskDict {
            if Bool.random() {
                await task.invalidate()
            }
        }
        taskDict.removeAll(keepingCapacity: true)
    }
    
    @DirtyImageDownloaderActor private var _purgeList = [Int]()
    
    @DirtyImageDownloaderActor func cancelAllOutOfIndexRange(firstIndex: Int, lastIndex: Int) async {
        for (index, task) in taskDict {
            if index >= firstIndex && index <= lastIndex {
                
            } else {
                await task.invalidate()
            }
        }
    }
    
    @DirtyImageDownloaderActor func startTasksIfNecessary() async {
    
        if isBlocked || isPaused {
            return
        }
        
        var numberOfActiveDownloads = 0
        
        for (key, task) in taskDict {
            if task.item === nil ||
                task.downloader === nil ||
                task.isInvalidated == true {
                _purgeList.append(key)
            } else {
                if task.isActive {
                    numberOfActiveDownloads += 1
                }
            }
        }
        
        if _purgeList.count > 0 {
            for key in _purgeList {
                if let task = taskDict[key] {
                    await task.invalidate()
                }
                taskDict.removeValue(forKey: key)
            }
            _purgeList.removeAll(keepingCapacity: true)
        }
        
        let numberOfTasksToStart = (numberOfSimultaneousDownloads - numberOfActiveDownloads)
        if numberOfTasksToStart <= 0 { return }
        
        let tasksToStart = chooseTasksToStart(numberOfTasks: numberOfTasksToStart)
        
        for taskToStart in tasksToStart {
            let index = taskToStart.index
            taskToStart.isActive = true
            await MainActor.run {
                delegate?.dataDownloadDidStart(index)
            }
        }
        
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                for taskToStart in tasksToStart {
                    taskGroup.addTask {
                        await taskToStart.fire()
                    }
                }
            }
        }
    }
    
    @DirtyImageDownloaderActor func forceRestart(_ item: any DirtyImageDownloaderType) async {
        
        if isBlocked {
            return
        }
        
        let index = item.index
        await removeDownloadTask(item)
        addDownloadTask(item)
        
        if isPaused {
            return
        }
        
        if let task = taskDict[item.index] {
            
            task.isActive = true
            
            await MainActor.run {
                delegate?.dataDownloadDidStart(index)
            }
            
            // For the sake of user feedback, let's
            // sleep for a second here...
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await task.fire()
        }
    }
    
    @DirtyImageDownloaderActor func addDownloadTaskBatch(_ items: [any DirtyImageDownloaderType]) {
        
        if isBlocked {
            return
        }
        
        for item in items {
            addDownloadTask(item)
        }
    }
    
    @DirtyImageDownloaderActor func addDownloadTask(_ item: any DirtyImageDownloaderType) {
        
        if isBlocked {
            return
        }
        
        var shouldCreate = true
        if taskDict[item.index] !== nil {
            shouldCreate = false
        }
        
        if shouldCreate {
            let newTask = DirtyImageDownloaderTask(downloader: self, item: item)
            taskDict[item.index] = newTask
        }
    }
    
    @DirtyImageDownloaderActor func removeDownloadTask(_ item: any DirtyImageDownloaderType) async {
        if let task = taskDict[item.index] {
            await task.invalidate()
        }
        taskDict.removeValue(forKey: item.index)
    }
    
    @DirtyImageDownloaderActor func setPriorityBatch(_ items: [any DirtyImageDownloaderType], _ priorities: [Int]) {
        var index = 0
        while index < items.count && index < priorities.count {
            let item = items[index]
            let priority = priorities[index]
            if let task = taskDict[item.index] {
                task.setPriority(priority)
            }
            index += 1
        }
    }
    
    @DirtyImageDownloaderActor private var _setPriorityBatchUpdateSet = Set<Int>()
    @DirtyImageDownloaderActor func setPriorityBatchAndSetAllOtherPrioritiesToZero(_ items: [any DirtyImageDownloaderType], _ priorities: [Int]) {
        var index = 0
        while index < items.count && index < priorities.count {
            let item = items[index]
            let priority = priorities[index]
            if let task = taskDict[item.index] {
                task.setPriority(priority)
            }
            _setPriorityBatchUpdateSet.insert(item.index)
            index += 1
        }
        
        for (key, task) in taskDict {
            if !_setPriorityBatchUpdateSet.contains(key) {
                task.setPriority(0)
            }
        }
    }
    
    @DirtyImageDownloaderActor func setPriority(_ item: any DirtyImageDownloaderType, _ priority: Int) {
        if let task = taskDict[item.index] {
            task.setPriority(priority)
        }
    }
    
    @DirtyImageDownloaderActor private func chooseTasksToStart(numberOfTasks: Int) -> [DirtyImageDownloaderTask] {
        
        var result = [DirtyImageDownloaderTask]()
        
        for (_, task) in taskDict {
            task.isVisited = false
        }
        
        var loopIndex = 0
        while loopIndex < numberOfTasks {
            
            var highestPriority = Int.min
            var chosenTask: DirtyImageDownloaderTask?
            for (_, task) in taskDict {
                if !task.isActive && !task.isVisited && task.priorityHasBeenSetAtLeastOnce {
                    if (chosenTask == nil) || (task.priority > highestPriority) {
                        highestPriority = task.priority
                        chosenTask = task
                    }
                }
            }
            if let task = chosenTask {
                task.isVisited = true
                result.append(task)
            } else {
                break
            }
            
            loopIndex += 1
        }
        return result
    }
    
    @DirtyImageDownloaderActor func isDownloading(_ item: any DirtyImageDownloaderType) -> Bool {
        var result = false
        if let task = taskDict[item.index] {
            if !task.isInvalidated {
                result = true
            }
        }
        return result
    }
    
    @DirtyImageDownloaderActor func isDownloadingActively(_ item: any DirtyImageDownloaderType) -> Bool {
        var result = false
        if let task = taskDict[item.index] {
            if !task.isInvalidated {
                if task.isActive {
                    result = true
                }
            }
        }
        return result
    }
}

extension DirtyImageDownloader {
    @MainActor func handleDownloadTaskDidInvalidate(task: DirtyImageDownloaderTask) {
        let index = task.index
        delegate?.dataDownloadDidCancel(index)
    }
    
    @MainActor func handleDownloadTaskDidSucceed(task: DirtyImageDownloaderTask, image: UIImage) {
        let index = task.index
        delegate?.dataDownloadDidSucceed(index, image: image)
    }
    
    @MainActor func handleDownloadTaskDidFail(task: DirtyImageDownloaderTask) {
        let index = task.index
        delegate?.dataDownloadDidFail(index)
    }
}
