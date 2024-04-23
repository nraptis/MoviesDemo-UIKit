//
//  CommunityGridLayout.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/19/24.
//

import UIKit
import SwiftUI

protocol CommunityGridLayoutDelegate: AnyObject {
    func layoutDidChangeVisibleCells()
    func layoutContentsDidChangeSize(size: CGSize)
    func layoutContainerDidChangeSize(size: CGSize)
}

class CommunityGridLayout {
    
    init() {

    }
    
    @MainActor weak var delegate: CommunityGridLayoutDelegate?
    
    // The content (grid) entire width and height
    private(set) var width: CGFloat = 255
    private(set) var height: CGFloat = 255
    
    // cell grid layout parameters
    //private let cellMaximumWidth = Device.isPad ? 170 : 100
    private let cellMaximumWidth = Device.isPad ? 90 : 70
    
    private var cellWidth = 100
    private var cellHeight = 100
    
    private let cellSpacingH = 9
    private let cellPaddingLeft = 24
    private let cellPaddingRight = 24
    
    private let cellSpacingV = 9
    private let cellPaddingTop = 24
    private let cellPaddingBottom = 128
    
    private var _numberOfCells = 0
    private var _numberOfRows = 0
    private var _numberOfCols = 0
    
    private var _maximumNumberOfVisibleCells = 0
    private var _cellXArray = [Int]()
    
    private var _containerSize = CGSize.zero
    private var _scrollContentOffset = CGPoint.zero
    
    func clear() {
        _numberOfCells = 0
        _numberOfRows = 0
        _numberOfCols = 0 // needs to be computed BEFORE _numberOfRows
        _cellXArray = [Int]()
    }
    
    func getNumberOfCols() -> Int {
        _numberOfCols
    }
    
    func getNumberOfRows() -> Int {
        _numberOfRows
    }
    
    @MainActor func registerNumberOfCells(_ numberOfCells: Int) {
        if numberOfCells != _numberOfCells {
            _numberOfCells = numberOfCells
            layoutGrid()
            refreshVisibleCells()
        }
    }
    
    @MainActor func registerContainer(_ newContainerSize: CGSize, _ numberOfCells: Int) {
        if newContainerSize != _containerSize || numberOfCells != _numberOfCells {
            print("🤡 [CommunityGridLayout] registerContainer [\(newContainerSize.width) x \(newContainerSize.height)], #\(numberOfCells) cells.")
            _containerSize = newContainerSize
            _numberOfCells = numberOfCells
            layoutGrid()
            calculateMaximumNumberOfVisibleCells()
            
            // There isn't a "right" order to do these 2 things...
            delegate?.layoutContainerDidChangeSize(size: newContainerSize)
            refreshVisibleCells()
        }
    }
    
    @MainActor func registerScrollContent(_ newScrollContentOffset: CGPoint) {
        _scrollContentOffset = newScrollContentOffset
        refreshVisibleCells()
    }
    
    func getTopRowIndex() -> Int {
        let containerTop = getContainerTop()
        var row = containerTop - cellPaddingTop
        row = (row / (cellHeight + cellSpacingV))
        if row >= _numberOfRows { row = _numberOfRows - 1 }
        if row < 0 { row = 0 }
        return row
    }
    
    func getBottomRowIndex() -> Int {
        let containerBottom = getContainerBottom()
        var row = containerBottom - cellPaddingTop
        row = (row / (cellHeight + cellSpacingV))
        if row >= _numberOfRows { row = _numberOfRows - 1 }
        if row < 0 { row = 0 }
        return row
    }
    
    func getBottomRowIndexNotClamped() -> Int {
        let containerBottom = getContainerBottom()
        var row = containerBottom - cellPaddingTop
        row = (row / (cellHeight + cellSpacingV))
        return row
    }
    
    var isAnyItemPresent: Bool {
        _numberOfCells > 0
    }
    
    private var _previousFirstCellIndexOnScreen = -1
    private var _previousLastCellIndexOnScreen = -1
    @MainActor func refreshVisibleCells() {
        _calculateLastCellIndexOnScreen()
        _calculateLastCellIndexOnScreenNotClamped()
        _calculateFirstCellIndexOnScreen()
        if (_previousFirstCellIndexOnScreen != _firstCellIndexOnScreen) ||
            (_previousLastCellIndexOnScreen != _lastCellIndexOnScreen) {
            _previousFirstCellIndexOnScreen = _firstCellIndexOnScreen
            _previousLastCellIndexOnScreen = _lastCellIndexOnScreen
            delegate?.layoutDidChangeVisibleCells()
        }
    }
    
    @MainActor private func layoutGrid() {
        
        calculateNumberOfCols()
        calculateNumberOfRows()
        calculateCellWidth()
        calculateCellXArray()
        
        cellHeight = (cellWidth) + (cellWidth >> 1)
        
        let previousWidth = width
        let previousHeight = height
        
        width = _containerSize.width
        height = CGFloat(_numberOfRows * cellHeight + (cellPaddingTop + cellPaddingBottom))
        //add the space between each cell vertically
        if _numberOfRows > 1 {
            height += CGFloat((_numberOfRows - 1) * cellSpacingV)
        }
        
        print("previousWidth = \(previousWidth), width = \(width)")
        print("previousHeight = \(previousHeight), height = \(height)")
        
        if (previousWidth != width) || (previousHeight != height) {
            delegate?.layoutContentsDidChangeSize(size: CGSize(width: width,
                                                               height: height))
        }
    }
    
    func getCellIndex(rowIndex: Int, colIndex: Int) -> Int {
        return (_numberOfCols * rowIndex) + colIndex
    }
    
    func getColIndex(cellIndex: Int) -> Int {
        if _numberOfCols > 0 {
            return cellIndex % _numberOfCols
        }
        return 0
    }
    
    func getRowIndex(cellIndex: Int) -> Int {
        if _numberOfCols > 0 {
            return cellIndex / _numberOfCols
        }
        return 0
    }
    
    private func getFirstCellIndex(rowIndex: Int) -> Int {
        _numberOfCols * rowIndex
    }
    
    private func getLastCellIndex(rowIndex: Int) -> Int {
        (_numberOfCols * rowIndex) + (_numberOfCols - 1)
    }
    
    private var _firstCellIndexOnScreen = -1
    func getFirstCellIndexOnScreen() -> Int {
        _firstCellIndexOnScreen
    }
    
    private func _calculateFirstCellIndexOnScreen() {
        let topRowIndex = getTopRowIndex()
        _firstCellIndexOnScreen = getFirstCellIndex(rowIndex: topRowIndex)
    }
    
    private var _lastCellIndexOnScreen = -1
    func getLastCellIndexOnScreen() -> Int {
        _lastCellIndexOnScreen
    }
    
    func _calculateLastCellIndexOnScreen() {
        let bottomRowIndex = getBottomRowIndex()
        _lastCellIndexOnScreen = getLastCellIndex(rowIndex: bottomRowIndex)
    }
    
    
    private var _lastCellIndexOnScreenNotClamped = -1
    func getLastCellIndexOnScreenNotClamped() -> Int {
        _lastCellIndexOnScreenNotClamped
    }
    
    func _calculateLastCellIndexOnScreenNotClamped() {
        let bottomRowIndex = getBottomRowIndexNotClamped()
        _lastCellIndexOnScreenNotClamped = getLastCellIndex(rowIndex: bottomRowIndex)
    }
    
    func getNumberOfCells() -> Int {
        _numberOfCells
    }
    
    func getMaximumNumberOfVisibleCells() -> Int {
        return _maximumNumberOfVisibleCells
    }
}

// clipping helpers
extension CommunityGridLayout {
    
    func getContainerTop() -> Int {
        let value = _scrollContentOffset.y
        if value > 0.0 {
            return Int(value + 0.5)
        } else {
            return Int(value - 0.5)
        }
    }
    
    func getContainerBottom() -> Int {
        let value = _scrollContentOffset.y + _containerSize.height
        if value > 0.0 {
            return Int(value + 0.5)
        } else {
            return Int(value - 0.5)
        }
    }
    
    // cell top
    func getCellTop(cellIndex: Int) -> Int {
        let rowIndex = getRowIndex(cellIndex: cellIndex)
        return getCellTop(rowIndex: rowIndex)
    }
    
    func getCellTop(rowIndex: Int) -> Int {
        cellPaddingTop + rowIndex * (cellHeight + cellSpacingV)
    }
    
    // cell bottom
    func getCellBottom(cellIndex: Int) -> Int {
        let rowIndex = getRowIndex(cellIndex: cellIndex)
        return getCellBottom(rowIndex: rowIndex)
    }
    
    func getCellBottom(rowIndex: Int) -> Int {
        getCellTop(rowIndex: rowIndex) + cellHeight
    }
    
    // cell left
    func getCellLeft(cellIndex: Int) -> Int {
        let colIndex = getColIndex(cellIndex: cellIndex)
        return getCellLeft(colIndex: colIndex)
    }
    
    func getCellLeft(colIndex: Int) -> Int {
        if _cellXArray.count > 0 {
            var colIndex = min(colIndex, _cellXArray.count - 1)
            colIndex = max(colIndex, 0)
            return _cellXArray[colIndex]
        }
        return 0
    }
}

// cell frame helpers
extension CommunityGridLayout {
    
    func getCellX(cellIndex: Int) -> CGFloat {
        var colIndex = getColIndex(cellIndex: cellIndex)
        if _cellXArray.count > 0 {
            colIndex = min(colIndex, _cellXArray.count - 1)
            colIndex = max(colIndex, 0)
            return CGFloat(_cellXArray[colIndex])
        }
        return 0
    }
    
    func getCellY(cellIndex: Int) -> CGFloat {
        let rowIndex = getRowIndex(cellIndex: cellIndex)
        return CGFloat(getCellTop(rowIndex: rowIndex))
    }
    
    func getCellWidth() -> CGFloat {
        return CGFloat(cellWidth)
    }
    
    func getCellHeight() -> CGFloat {
        return CGFloat(cellHeight)
    }
}

// grid layout helpers (internal)
extension CommunityGridLayout {
    
    private func calculateNumberOfRows() {
        if _numberOfCols > 0 {
            _numberOfRows = _numberOfCells / _numberOfCols
            if (_numberOfCells % _numberOfCols) != 0 {
                _numberOfRows += 1
            }
        } else {
            _numberOfRows = 0
        }
    }
    
    private func calculateNumberOfCols() {
        
        //if _numberOfCells <= 0 { return 0 }
        
        _numberOfCols = 1
        let availableWidth = _containerSize.width - CGFloat(cellPaddingLeft + cellPaddingRight)
        
        //try out horizontal counts until the cells would be
        //smaller than the maximum width
        
        var horizontalCount = 2
        while horizontalCount < 1024 {
            
            //the amount of space between the cells for this horizontal count
            let totalSpaceWidth = CGFloat((horizontalCount - 1) * cellSpacingH)
            
            let availableWidthForCells = availableWidth - totalSpaceWidth
            let expectedCellWidth = availableWidthForCells / CGFloat(horizontalCount)
            
            if expectedCellWidth < CGFloat(cellMaximumWidth) {
                break
            } else {
                _numberOfCols = horizontalCount
                horizontalCount += 1
            }
        }
    }
    
    private func calculateCellWidth() {
        if _numberOfCols <= 0 {
            cellWidth = 16
            return
        }
        
        var totalSpace = Int(_containerSize.width)
        totalSpace -= cellPaddingLeft
        totalSpace -= cellPaddingRight
        
        //subtract out the space between cells!
        if _numberOfCols > 1 {
            totalSpace -= (_numberOfCols - 1) * cellSpacingH
        }
        
        cellWidth = totalSpace / _numberOfCols
        
        if cellWidth < 16 {
            cellWidth = 16
        }
    }
    
    private func calculateCellXArray() {
        
        _cellXArray.removeAll(keepingCapacity: true)
        
        // We are doing all same width, so we may need to make a slight adjustment.
        var spaceConsumed = cellPaddingLeft + cellPaddingRight
        
        spaceConsumed += cellWidth * _numberOfCols
        if _numberOfCols > 1 {
            spaceConsumed += cellSpacingH * (_numberOfCols - 1)
        }
        
        let realWidth = Int(_containerSize.width + 0.5)
        let extraOffset = (realWidth - spaceConsumed) / 2
        
        var cellX = cellPaddingLeft + extraOffset
        for _ in 0..<_numberOfCols {
            _cellXArray.append(cellX)
            cellX += cellWidth + cellSpacingH
        }
    }
    
    private func calculateMaximumNumberOfVisibleCells() {
        
        let totalSpace = Int(_containerSize.height + 0.5)
        
        if totalSpace <= 0 {
            _maximumNumberOfVisibleCells = 0
            return
        }
        
        if _numberOfCols <= 0 {
            _maximumNumberOfVisibleCells = 0
            return
        }
        
        if cellHeight <= 0 {
            _maximumNumberOfVisibleCells = 0
            return
        }
        
        var y = -(cellHeight)
        var numberOfRows = 1
        
        y += cellHeight
        y += cellSpacingV
        while y < totalSpace {
            numberOfRows += 1
            y += cellHeight
            y += cellSpacingV
        }
        _maximumNumberOfVisibleCells = _numberOfCols * numberOfRows
    }
}
