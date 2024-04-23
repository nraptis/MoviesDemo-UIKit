//
//  CommunityViewModel+FetchMorePages.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/23/24.
//

import UIKit

extension CommunityViewModel {
    
    @MainActor func fetchMorePagesIfNecessary() {
        
        if isFetching { 
            return
        }
        
        if isRefreshing {
            return
        }
        
        if ReachabilityMonitor.shared.isReachable == false {
            return
        }
        
        if pageSize < 1 { 
            return
        }
        
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
        
        var pageIndexOfLastTwoRecentFetches = -1
        if recentFetches.count >= 2 {
            if recentFetches[recentFetches.count - 1].page == recentFetches[recentFetches.count - 2].page {
                let timeElapsed = Date().timeIntervalSince(recentFetches[recentFetches.count - 1].date)
                if timeElapsed <= 10 {
                    pageIndexOfLastTwoRecentFetches = recentFetches[recentFetches.count - 1].page
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
                    break
                }
                cellIndex += 1
            }
            
            if isEveryCellMissing {
                if pageIndexOfLastTwoRecentFetches != pageToCheck {
                    Task {
                        await fetchPopularMovies(page: pageToCheck)
                    }
                }
                return
            }
            pageToCheck += 1
        }
        
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
                    break
                }
                cellIndex += 1
            }
            
            if isAnyCellMissing {
                if pageIndexOfLastTwoRecentFetches != pageToCheck {
                    Task {
                        await fetchPopularMovies(page: pageToCheck)
                    }
                }
                return
            }
            pageToCheck += 1
        }
    }
}
