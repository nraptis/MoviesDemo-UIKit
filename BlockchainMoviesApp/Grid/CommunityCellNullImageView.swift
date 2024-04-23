//
//  CommunityCellNullImageView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/21/24.
//

import SwiftUI

struct CommunityCellNullImageView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    Image(systemName: "photo")
                        .font(.system(size: Device.isPad ? 32 : 24))
                        .foregroundStyle(DarkwingDuckTheme.gray700)
                }
                .frame(width: Device.isPad ? 56.0 : 44.0,
                       height: Device.isPad ? 56.0 : 44.0)
                .background(RoundedRectangle(cornerRadius: CommunityCellConstants.buttonRadius).foregroundStyle(DarkwingDuckTheme.gray300))
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height)
        }
    }
}
