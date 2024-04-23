//
//  CommunityViewModel+Debug.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/23/24.
//

import UIKit

extension CommunityViewModel {
    
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
}
