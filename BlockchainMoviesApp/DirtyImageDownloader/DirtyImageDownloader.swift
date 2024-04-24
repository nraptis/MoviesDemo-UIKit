//
//  DirtyImageDownloader.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/9/24.
//

import UIKit

//
// The most important thing to note about this downloader
// is that it is PRIORITY based. It WILL NOT START a download
// task until the priority has been set. This is to prevent
// race conditions, such as the wrong item downloading first.
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
    @MainActor func dataDownloadDidStart(_ index: Int)
    @MainActor func dataDownloadDidSucceed(_ index: Int, image: UIImage)
    @MainActor func dataDownloadDidFail(_ index: Int)
    @MainActor func dataDownloadDidCancel(_ index: Int)
}

protocol DirtyImageDownloaderType: AnyObject, Hashable {
    var index: Int { get }
    var urlString: String? { get }
}

class DirtyImageDownloader {
    
    var isPaused = false
    var isBlocked = false
    
    weak var delegate: DirtyImageDownloaderDelegate?
    
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
        var _taskList = [DirtyImageDownloaderTask]()
        for (_, task) in taskDict {
            _taskList.append(task)
        }
        taskDict.removeAll(keepingCapacity: true)
        
        let ___taskList = _taskList
        await MainActor.run {
            if let delegate = delegate {
                for task in ___taskList {
                    delegate.dataDownloadDidCancel(task.index)
                }
            }
        }
    }
    
    @DirtyImageDownloaderActor func cancelAllRandomly() async {
        var _taskList = [DirtyImageDownloaderTask]()
        for (_, task) in taskDict {
            if Bool.random() {
                _taskList.append(task)
            }
        }
        for task in _taskList {
            taskDict.removeValue(forKey: task.index)
        }
        
        let ___taskList = _taskList
        await MainActor.run {
            if let delegate = delegate {
                for task in ___taskList {
                    delegate.dataDownloadDidCancel(task.index)
                }
            }
        }
    }
    
    @DirtyImageDownloaderActor func cancelAllOutOfIndexRange(firstIndex: Int, lastIndex: Int) async {
        var _taskList = [DirtyImageDownloaderTask]()
        for (_, task) in taskDict {
            let index = task.index
            if index >= firstIndex && index <= lastIndex {
                
            } else {
                if !task.isInvalidated {
                    _taskList.append(task)
                }
            }
        }
        for task in _taskList {
            taskDict.removeValue(forKey: task.index)
        }
        
        let ___taskList = _taskList
        await MainActor.run {
            if let delegate = delegate {
                for task in ___taskList {
                    delegate.dataDownloadDidCancel(task.index)
                }
            }
        }
    }
    
    @DirtyImageDownloaderActor private var _killList = [DirtyImageDownloaderTask]()
    @DirtyImageDownloaderActor func startTasksIfNecessary() async {
    
        if isBlocked || isPaused {
            return
        }
        
        var numberOfActiveDownloads = 0
        
        // This is where we do our tidying process.
        // We really can't accumulate billions and
        // billions of tasks. Ergo, we can just clean
        // on this part. No real right answer, it works.
        _killList.removeAll(keepingCapacity: true)
        for (_, task) in taskDict {
            if task.isInvalidated == true {
                _killList.append(task)
            } else {
                if task.isActive {
                    numberOfActiveDownloads += 1
                }
            }
        }
        for task in _killList {
            taskDict.removeValue(forKey: task.index)
        }
        
        let numberOfTasksToStart = (numberOfSimultaneousDownloads - numberOfActiveDownloads)
        if numberOfTasksToStart <= 0 { return }
        
        let tasksToStart = chooseTasksToStart(numberOfTasks: numberOfTasksToStart)
        
        // Set active early. These will be fired.
        // We are only calling this from one place
        // in code, so it's unlikely ro cause
        // any sort of race condition anyway.
        for taskToStart in tasksToStart {
            taskToStart.isActive = true
        }
        
        await MainActor.run {
            if let delegate = delegate {
                for taskToStart in tasksToStart {
                    let index = taskToStart.index
                    delegate.dataDownloadDidStart(index)
                }
            }
        }
        
        for taskToStart in tasksToStart {
            taskToStart.fire()
        }
    }
    
    @DirtyImageDownloaderActor func forceRestart(_ item: any DirtyImageDownloaderType) async {
        
        if isBlocked {
            return
        }
        
        let index = item.index
        if let previousTask = taskDict[index] {
            if !previousTask.isInvalidated {
                previousTask.invalidate()
                await MainActor.run {
                    if let delegate = delegate {
                        delegate.dataDownloadDidCancel(previousTask.index)
                    }
                }
            }
            taskDict.removeValue(forKey: index)
        }
        
        addDownloadTask(item)
        
        if isPaused {
            return
        }
        
        if let task = taskDict[item.index] {
            
            task.isActive = true
            
            await MainActor.run {
                if let delegate = delegate {
                    delegate.dataDownloadDidStart(index)
                }
            }
            
            // For the sake of user feedback, let's
            // sleep for a second here...
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            task.fire()
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
        if taskDict[item.index] === nil {
            let newTask = DirtyImageDownloaderTask(downloader: self, item: item)
            taskDict[item.index] = newTask
        }
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
    
    func handleDownloadTaskDidSucceed(task: DirtyImageDownloaderTask, image: UIImage) {
        
        let index = task.index
        Task { @DirtyImageDownloaderActor in
            // We cross asynchronous boundary. Maybe the taskDict
            // has been updated with a different value. Check again.
            if taskDict[index] === task {
                taskDict.removeValue(forKey: index)
            }
            await MainActor.run {
                delegate?.dataDownloadDidSucceed(index, image: image)
            }
        }
    }
    
    func handleDownloadTaskDidFail(task: DirtyImageDownloaderTask) {
        let index = task.index
        Task { @DirtyImageDownloaderActor in
            // We cross asynchronous boundary. Maybe the taskDict
            // has been updated with a different value. Check again.
            if taskDict[index] === task {
                taskDict.removeValue(forKey: index)
            }
            await MainActor.run {
                delegate?.dataDownloadDidFail(index)
            }
        }
    }
}
