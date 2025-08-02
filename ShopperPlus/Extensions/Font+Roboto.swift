//
//  Font+Roboto.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

extension Font {
    // MARK: - Roboto Font Family

    /// Roboto Regular
    static func roboto(size: CGFloat) -> Font {
        return Font.custom("Roboto-Regular", size: size)
    }

    /// Roboto Medium
    static func robotoMedium(size: CGFloat) -> Font {
        return Font.custom("Roboto-Medium", size: size)
    }

    /// Roboto Bold
    static func robotoBold(size: CGFloat) -> Font {
        return Font.custom("Roboto-Bold", size: size)
    }

    /// Roboto Light
    static func robotoLight(size: CGFloat) -> Font {
        return Font.custom("Roboto-Light", size: size)
    }

    /// Roboto SemiBold
    static func robotoSemiBold(size: CGFloat) -> Font {
        return Font.custom("Roboto-SemiBold", size: size)
    }

    // MARK: - App-Specific Font Styles

    /// Large title - Roboto Bold 34pt
    static var largeTitleRoboto: Font {
        return .robotoBold(size: 34)
    }

    /// Title 1 - Roboto Bold 28pt
    static var title1Roboto: Font {
        return .robotoBold(size: 28)
    }

    /// Title 2 - Roboto Bold 22pt
    static var title2Roboto: Font {
        return .robotoBold(size: 22)
    }

    /// Title 3 - Roboto SemiBold 20pt
    static var title3Roboto: Font {
        return .robotoSemiBold(size: 20)
    }

    /// Headline - Roboto SemiBold 17pt
    static var headlineRoboto: Font {
        return .robotoSemiBold(size: 17)
    }

    /// Body - Roboto Regular 17pt
    static var bodyRoboto: Font {
        return .roboto(size: 17)
    }

    /// Callout - Roboto Regular 16pt
    static var calloutRoboto: Font {
        return .roboto(size: 16)
    }

    /// Subheadline - Roboto Regular 15pt
    static var subheadlineRoboto: Font {
        return .roboto(size: 15)
    }

    /// Footnote - Roboto Regular 13pt
    static var footnoteRoboto: Font {
        return .roboto(size: 13)
    }

    /// Caption 1 - Roboto Regular 12pt
    static var caption1Roboto: Font {
        return .roboto(size: 12)
    }

    /// Caption 2 - Roboto Regular 11pt
    static var caption2Roboto: Font {
        return .roboto(size: 11)
    }
}
