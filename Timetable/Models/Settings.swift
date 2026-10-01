//
//  Settings.swift
//  Timetable
//
//  Created by Zack on 2026/9/30.
//

import SwiftUI

struct Settings: Codable {
    var minutesPerPt: CGFloat = 0.8
    var defaultDurations: [Int] = [1, 5, 20, 45, 95, 145]
}

@propertyWrapper
struct CodableStorage<T: Codable> {
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
