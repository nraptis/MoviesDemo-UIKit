//
//  CommunityGridViewControllerRepresentable.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/21/24.
//

import UIKit
import SwiftUI

struct CommunityGridViewControllerRepresentable: UIViewControllerRepresentable {
    let communityViewModel: CommunityViewModel
    let width: CGFloat
    let height: CGFloat
    public func makeUIViewController(context: Context) -> CommunityGridViewController {
        let size = CGSize(width: width, height: height)
        let uiViewController = CommunityGridViewController(communityViewModel: communityViewModel, size: size)
        uiViewController.notifySizeMayHaveChanged(size)
        return uiViewController
    }

    public func updateUIViewController(_ uiViewController: CommunityGridViewController, context: Context) {
        let size = CGSize(width: width, height: height)
        uiViewController.notifySizeMayHaveChanged(size)
    }
}
