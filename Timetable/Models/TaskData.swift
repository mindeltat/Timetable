//
//  TaskData.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData

// MARK: - Theme

enum Theme: String, Codable, Equatable, Hashable, CaseIterable {
    case red, orange, yellow, lime, green, cyan, blue, violet

    var bgColor: Color {
        switch self {
        case .red:    return .redBg.opacity(0.4)
        case .orange: return .orangeBg.opacity(0.4)
        case .yellow: return .yellowBg.opacity(0.4)
        case .lime:   return .limeBg.opacity(0.4)
        case .green:  return .greenBg.opacity(0.4)
        case .cyan:   return .cyanBg.opacity(0.4)
        case .blue:   return .blueBg.opacity(0.4)
        case .violet: return .violetBg.opacity(0.4)
        }
    }
    
    var bgColorNoOpacity: Color {
        switch self {
        case .red:    return .redBg
        case .orange: return .orangeBg
        case .yellow: return .yellowBg
        case .lime:   return .limeBg
        case .green:  return .greenBg
        case .cyan:   return .cyanBg
        case .blue:   return .blueBg
        case .violet: return .violetBg
        }
    }

    var fgColor: Color {
        switch self {
        case .red:    return .redFg
        case .orange: return .orangeFg
        case .yellow: return .yellowFg
        case .lime:   return .limeFg
        case .green:  return .greenFg
        case .cyan:   return .cyanFg
        case .blue:   return .blueFg
        case .violet: return .violetFg
        }
    }
}

// MARK: - Weekday

enum Weekday: Int, Codable, Equatable, Hashable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday:    return "Sun"
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        }
    }
}

// MARK: - Day

nonisolated struct Day: Hashable, Codable, Equatable {
    let year: Int
    let month: Int
    let day: Int

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    var localizedDescription: String {
        var calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) else { return description }
        
        return date.formatted(date: .long, time: .omitted)
    }

    var weekday: Weekday {
        var calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return .monday
        }
        
        let raw = calendar.component(.weekday, from: date)
        return Weekday(rawValue: raw) ?? .sunday
    }
    
    var weeks: [Day] {
        var calendar = Calendar(identifier: .gregorian)
        
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let startOfWeek = interval.start
        
        return (0..<7).compactMap { offset in
            return Day(date: calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? .now)
        }
    }
    
    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
    
    var date: Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
    
    init(date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1970
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    static var today: Day { Day(date: Date()) }
}

extension Day: Comparable {
    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - TimeOfDay

struct TimeOfDay: Hashable, Codable, Comparable {
    let hour: Int
    let minute: Int
    
    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
    
    init(date: Date) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    func minutes(to other: TimeOfDay, wrapAround: Bool = false) -> Int {
        let diff = other.minutesSinceMidnight - minutesSinceMidnight
        if wrapAround && diff < 0 {
            return diff + 24 * 60
        }
        return diff
    }
    
    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

extension Int {
    var minutesDescription: String {
        if self <= 60 {
            return "\(self) \(String(localized: .init("minute")))"
        }
        if self % 60 == 0 {
            return "\(self / 60) \(String(localized: .init("hour")))"
        }
        return "\(self / 60) \(String(localized: .init("hour")))\(String(localized: .init("seperater"))) \(self % 60) \(String(localized: .init("minute")))"
    }
    
    var minutesShortDescription: String {
        if self <= 60 {
            return "\(self)m"
        }
        if self % 60 == 0 {
            return "\(self / 60)h"
        }
        return "\(self / 60)h\(self % 60)m"
    }
}

// MARK: - ImageType

enum ImageType: Codable, Hashable {
    case system(name: String)
    case file(path: String)
}

// MARK: - TaskData

@Model
final class TaskData {
    @Attribute(.unique) var id: String
    
    var title: String
    var content: String
    var theme: Theme
    var icon: ImageType

    var startTime: Int
    var endTime: Int
    var preparationTime: Int

    var notificationID: String?
    var isOnBadWeather: Bool
    var badWeatherAheadTime: Int
    var effort: Int
    
    var tags: [String]

    init(
        title: String = "Untitled",
        content: String = "",
        theme: Theme = .allCases.randomElement()!,
        icon: ImageType = .system(name: "star.fill"),
        startTime: Int = 0,
        endTime: Int = 0,
        preparationTime: Int = 0,
        notificationID: String? = nil,
        isOnBadWeather: Bool = false,
        badWeatherAheadTime: Int = 0,
        effort: Int = 1,
        tags: [String] = []
    ) {
        self.title = title
        self.content = content
        self.theme = theme
        self.icon = icon
        self.startTime = startTime
        self.endTime = endTime
        self.preparationTime = preparationTime
        self.notificationID = notificationID
        self.isOnBadWeather = isOnBadWeather
        self.effort = effort
        self.id = UUID().uuidString
        self.badWeatherAheadTime = badWeatherAheadTime
        self.tags = tags
    }

    convenience init(copying other: TaskData) {
        self.init(
            title: other.title,
            content: other.content,
            theme: other.theme,
            icon: other.icon,
            startTime: other.startTime,
            endTime: other.endTime,
            preparationTime: other.preparationTime,
            notificationID: nil,
            isOnBadWeather: false,
            badWeatherAheadTime: other.badWeatherAheadTime,
            effort: other.effort,
            tags: other.tags
        )
    }
    
    func copy(_ other: TaskData) {
        self.title = other.title
        self.content = other.content
        self.theme = other.theme
        self.icon = other.icon
        self.startTime = other.startTime
        self.endTime = other.endTime
        self.preparationTime = other.preparationTime
        self.badWeatherAheadTime = other.badWeatherAheadTime
        self.effort = other.effort
        self.tags = other.tags
    }

    var startTimeOfDay: TimeOfDay {
        TimeOfDay(hour: startTime / 60, minute: startTime % 60)
    }

    var endTimeOfDay: TimeOfDay {
        TimeOfDay(hour: endTime / 60, minute: endTime % 60)
    }
    
    var durationWithoutPreparation: Int {
        endTime - startTime
    }
    
    var durationWithPreparation: Int {
        endTime - startTime + preparationTime
    }
}

extension TaskData {
    func topTime(dayState: DayState, nowMinutes: Int) -> TimeOfDay {
        let preparationIsDone: Bool
        switch dayState {
        case .before:
            preparationIsDone = true
        case .after:
            preparationIsDone = false
        case .today:
            preparationIsDone = nowMinutes >= startTime
        }

        if !preparationIsDone {
            let m = startTime - preparationTime
            return TimeOfDay(hour: m / 60, minute: m % 60)
        }
        return startTimeOfDay
    }
}

// MARK: - UserTemplates

@Model
final class UserTemplates {
    @Relationship var templateDays: [DayTasks]

    init() {
        self.templateDays = [
            DayTasks(day: .init(year: 100000, month: 1, day: 1)),
            DayTasks(day: .init(year: 100000, month: 1, day: 2)),
            DayTasks(day: .init(year: 100000, month: 1, day: 3)),
            DayTasks(day: .init(year: 100000, month: 1, day: 4)),
            DayTasks(day: .init(year: 100000, month: 1, day: 5)),
            DayTasks(day: .init(year: 100000, month: 1, day: 6)),
            DayTasks(day: .init(year: 100000, month: 1, day: 7))
        ]
    }

    func tasks(for weekday: Weekday) -> [TaskData] {
        return templateDays.sorted { $0.day < $1.day } [weekday.rawValue - 1].tasks
    }

    func setTasks(_ tasks: [TaskData], for weekday: Weekday) {
        templateDays.sorted { $0.day < $1.day } [weekday.rawValue - 1].tasks = tasks
    }

    @discardableResult
    static func shared(in context: ModelContext) -> UserTemplates {
        let descriptor = FetchDescriptor<UserTemplates>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let templates = UserTemplates()
        context.insert(templates)
        try? context.save()
        return templates
    }
}

// MARK: - DayTasks

@Model
final class DayTasks {
    @Attribute(.unique) var id: String

    var year: Int
    var month: Int
    var day: Int
    
    var useTemplate: Weekday? = nil

    @Relationship(deleteRule: .cascade) var tasks: [TaskData]

    var dayValue: Day {
        Day(year: year, month: month, day: day)
    }

    init(day: Day, tasks: [TaskData] = [], template: Weekday? = nil) {
        self.id = day.description
        self.year = day.year
        self.month = day.month
        self.day = day.day
        self.tasks = tasks
        self.useTemplate = template
    }

    convenience init(from template: UserTemplates, on day: Day) {
        let copies = template.tasks(for: day.weekday).map { TaskData(copying: $0) }
        self.init(day: day, tasks: copies, template: day.weekday)
    }

    static func fetch(for day: Day, in context: ModelContext) -> DayTasks? {
        let id = day.description
        let descriptor = FetchDescriptor<DayTasks>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func getOrCreate(
        for day: Day,
        template: UserTemplates,
        in context: ModelContext
    ) -> DayTasks {
        if let existing = fetch(for: day, in: context) {
            if day <= .today {
                return existing
            }
            if existing.useTemplate == nil {
                return existing
            }
            context.delete(existing)
        }
        let newDay = DayTasks(from: template, on: day)
        context.insert(newDay)
        try? context.save()
        return newDay
    }

    func applyTemplate(_ template: UserTemplates) {
        tasks = template.tasks(for: dayValue.weekday).map { TaskData(copying: $0) }
    }
}
