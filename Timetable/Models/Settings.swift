//
//  Settings.swift
//  Timetable
//
//  Created by Zack on 2026/9/30.
//

import SwiftUI

enum Appearance: String, Codable {
    case light
    case dark
    case system
    
    func colorScheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return system
        }
    }
    
    static let allCases: [Appearance] = [.light, .dark, .system]
}

enum FontDesign: String, Codable {
    case `default`
    case serif
    case monospaced
    case rounded
    
    var font: Font.Design {
        switch self {
        case .default:
            return .default
        case .serif:
            return .serif
        case .monospaced:
            return .monospaced
        case .rounded:
            return .rounded
        }
    }
    
    static let allCases: [FontDesign] = [.default, .serif, .monospaced, .rounded]
}

struct Settings: Codable {
    var minutesPerPt: CGFloat = 0.8
    var defaultDurations: [Int] = [1, 5, 20, 45, 95, 145]
    var recentSymbols: [String] = []
    var appearance: Appearance = .system
    var fontDeisgn: FontDesign = .default
    var defaultNotification: Bool = true
    var defaultNotificationSound: NotificationSound? = .default
}

@propertyWrapper
struct CodableStorage<T: Codable>: DynamicProperty {
    private let key: String
    private let defaultValue: T

    @AppStorage private var data: Data

    init(wrappedValue defaultValue: T, _ key: String) {
        self.key = key
        self.defaultValue = defaultValue
        self._data = AppStorage(wrappedValue: Data(), key)
    }

    var wrappedValue: T {
        get {
            guard !data.isEmpty,
                  let value = try? JSONDecoder().decode(T.self, from: data)
            else {
                return defaultValue
            }
            return value
        }
        nonmutating set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            data = encoded
        }
    }
}
