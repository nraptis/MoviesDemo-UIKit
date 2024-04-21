//
//  DirtyImageDownloaderType.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/9/24.
//

import Foundation

protocol DirtyImageDownloaderType: AnyObject, Hashable {
    var index: Int { get }
    var urlString: String? { get }
}
