//
//  View+.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension CGFloat {
    static func adapted(iOS: CGFloat, macOS: CGFloat) -> CGFloat {
#if os(macOS)
        return macOS
#else
        return iOS
#endif
    }
    
    static let largeControl = adapted(iOS: 44, macOS: 36)
    static let regularControl = adapted(iOS: 36, macOS: 28)
    static let smallControl = adapted(iOS: 28, macOS: 20)
    
    static let horizontalTextPadding: CGFloat = 16
    static let verticalTextPadding: CGFloat = 8
    
    static let calendarFontSize: CGFloat = 18
    static let calendarCircleSize: CGFloat = 32
    
#if canImport(UIKit)
    static let bodyFontSize: CGFloat = UIFont.preferredFont(forTextStyle: .body).pointSize
#else
    static let bodyFontSize: CGFloat = 13
#endif
}

extension RoundedRectangle {
    static let largeControl = RoundedRectangle(cornerRadius: .adapted(iOS: 22, macOS: 18))
}

extension View {
    func safeSetNavigationTitleDisplayModeToInline() -> some View {
#if os(macOS)
        return self
#else
        return self.navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private struct CurrentTaskIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var currentTaskIndex: Int? {
        get { self[CurrentTaskIndexKey.self] }
        set { self[CurrentTaskIndexKey.self] = newValue }
    }
}

private struct IsTemplateKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isTemplate: Bool {
        get { self[IsTemplateKey.self] }
        set { self[IsTemplateKey.self] = newValue }
    }
}
