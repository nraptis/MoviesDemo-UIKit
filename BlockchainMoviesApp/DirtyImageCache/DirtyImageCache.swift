//
//  DirtyImageCache.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/9/24.
//

import UIKit

@globalActor actor DirtyImageCacheActor {
    static let shared = DirtyImageDownloaderActor()
}

struct KeyIndex {
    let key: String
    let index: Int
}

struct KeyIndexImage {
    let image: UIImage
    let key: String
    let index: Int
}

extension KeyIndex: Equatable {
    static func == (lhs: KeyIndex, rhs: KeyIndex) -> Bool {
        lhs.index == rhs.index
    }
}

extension KeyIndex: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(index)
    }
}

class DirtyImageCache {
    
    private let name: String
    
    var DISABLED = false
    
    @DirtyImageCacheActor
    private var fileRecycler = DirtyImageCacheFileRecycler(capacity: 4096)
    
    
    /// Creates a unique file cache object.
    /// - Parameters:
    ///   - name: should be unique for each instance of DirtyImageCache (only numbers, letters, and _)
    ///   - fileCapacity: number of images stored on disk (should be prime number somewhere close to 1,000)
    ///   - ramCapacity: number of images stored in RAM (should be prime number somewhere between 30 and 200,
    ///                  larger than the max number of image displayed on any given screen  (will be flushed on memory warning)
    init(name: String) {
        self.name = name
    }
    
    @DirtyImageCacheActor func purge() async {
        try? await Task.sleep(nanoseconds: 100_000)
        fileRecycler.clear()
    }
    
    @DirtyImageCacheActor func purgeRandomly() async {
        try? await Task.sleep(nanoseconds: 100_000)
        fileRecycler.clearRandomly()
    }
    
    @DirtyImageCacheActor func cacheImage(_ image: UIImage, _ key: String) async {
        
        if DISABLED { return }
        
        if let node = self.fileRecycler.get(key) {
            try? await Task.sleep(nanoseconds: 100_000)
            node.updateImage(image)
        } else {
            let numberList = self.fileRecycler.dumpToNumberList()
            let imageNumber = self.firstMissingPositive(numberList)
            var numberString = "\(imageNumber)"
            let numberDigits = 4
            if numberString.count < numberDigits {
                let zeroArray = [Character](repeating: "0", count: (numberDigits - numberString.count))
                numberString = String(zeroArray) + numberString
            }
            let imagePath = "_cached_image_\(self.name)_\(numberString).png"
            self.fileRecycler.put(key, imageNumber, imagePath)
            if let node = self.fileRecycler.get(key) {
                try? await Task.sleep(nanoseconds: 100_000)
                node.updateImage(image)
                Task {
                    await save()
                }
            }
        }
    }
    
    @DirtyImageCacheActor func retrieveBatch(_ keyIndexList: [KeyIndex]) async -> [Int: UIImage] {
        var result = [Int: UIImage]()
        
        if DISABLED { return result }
        
        // We load 4 images, then sleep for a short time
        // repeating the process. If we load all the images
        // at once, this can cause a lag thud. So, it's
        // better to do them in little snips.
        
        var waveUpdateIndex = 0
        while waveUpdateIndex < keyIndexList.count {
            
            var waveNumberOfUpdatesTriggered = 0
            while waveUpdateIndex < keyIndexList.count && waveNumberOfUpdatesTriggered < 4 {
                let keyIndex = keyIndexList[waveUpdateIndex]
                
                if let node = self.fileRecycler.get(keyIndex.key) {
                    
                    result[keyIndex.index] = node.loadImage()
                    waveNumberOfUpdatesTriggered += 1
                }
                waveUpdateIndex += 1
            }
            
            if waveNumberOfUpdatesTriggered > 0 {
                // The sleep should be a meaningful amount
                // of time for a UI update to trickle through
                // or there is no use for it. (0.015 seconds)
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
        }
        
        return result
    }
    
    // This really shouldn't be used unless it is
    // for something like a banner or immutable
    // content. For many thumbnails, use batchRetrieve.
    @DirtyImageCacheActor func retrieve(_ keyIndex: KeyIndex) -> UIImage? {
        if DISABLED { return nil }
        if let node = self.fileRecycler.get(keyIndex.key) {
            return node.loadImage()
        }
        return nil
    }
    
    private func firstMissingPositive(_ nums: [Int]) -> Int {
        var nums = nums
        for i in nums.indices {
            while nums[i] >= 1 && nums[i] < nums.count && nums[nums[i] - 1] != nums[i] {
                nums.swapAt(i, nums[i] - 1)
            }
        }
        for i in nums.indices {
            if nums[i] != (i + 1) {
                return (i + 1)
            }
        }
        return nums.count + 1
    }
    
    lazy private var filePath: String = {
        let fileName = "image_cache_" + name + ".cache"
        return FileUtils.shared.getDocumentPath(fileName: fileName)
    }()
    
    @DirtyImageCacheActor private var _isSaving = false
    @DirtyImageCacheActor private var _isSavingEnqueued = false
    @DirtyImageCacheActor private func save() async {
        if _isSaving {
            _isSavingEnqueued = true
            return
        }
        let filePath = filePath
        _isSaving = true
        let fileBuffer = FileBuffer()
        fileRecycler.save(fileBuffer: fileBuffer)
        fileBuffer.save(filePath: filePath)
        
        // Sleep for 3 seconds...
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        _isSaving = false
        
        if _isSavingEnqueued {
            Task { @DirtyImageCacheActor in
                _isSavingEnqueued = false
                await save()
            }
        }
    }
    
    @DirtyImageCacheActor func load() {
        let filePath = filePath
        let fileBuffer = FileBuffer()
        fileBuffer.load(filePath: filePath)
        fileRecycler.load(fileBuffer: fileBuffer)
    }
}
