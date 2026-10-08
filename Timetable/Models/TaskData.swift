//
//  TaskData.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData
import WidgetKit

func minutesSinceStartOfDay(_ date: Date = Date(), calendar: Calendar = .current) -> Int {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let hour = components.hour ?? 0
    let minute = components.minute ?? 0
    return hour * 60 + minute
}

enum DayState {
    case before
    case after
    case today
}

// MARK: - Theme

enum Theme: String, Codable, Equatable, Hashable, CaseIterable {
    case red, orange, yellow, lime, green, cyan, blue, violet
}

extension Theme {
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
    
    var next: Day {
        let calendar = Calendar(identifier: .gregorian)
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
            return self
        }
        return Day(date: nextDate)
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
    
    func date(
        at time: TimeOfDay,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute
        
        return calendar.date(from: components)
    }
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
        if self < 60 {
            return "\(self) \(String(localized: .init("minute")))"
        }
        if self % 60 == 0 {
            return "\(self / 60) \(String(localized: .init("hour")))"
        }
        return "\(self / 60) \(String(localized: .init("hour")))\(String(localized: .init("seperater"))) \(self % 60) \(String(localized: .init("minute")))"
    }
    
    var minutesShortDescription: String {
        if self < 60 {
            return "\(self)m"
        }
        if self % 60 == 0 {
            return "\(self / 60)h"
        }
        return "\(self / 60)h\(self % 60)m"
    }
}

// MARK: - ImageType
 
nonisolated enum ImageType: Codable, Hashable, Equatable {
    case system(name: String)
    case file(path: String)
}

enum NotificationSound: String, Codable {
    case `default`
    
    var sound: UNNotificationSound {
        return .default
    }
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
    
    var notificationID: String
    @Attribute(originalName: "hasScheduledNotification")
    var notification: Bool
    var notificationSound: NotificationSound?
    var isOnBadWeather: Bool
    var badWeatherAheadTime: Int
    var effort: Int
    
    var tags: [String]
    
    @Relationship(inverse: \DayTasks.tasks) var day: DayTasks?
    
    init(
        title: String = "",
        content: String = "",
        theme: Theme = .allCases.randomElement()!,
        icon: ImageType = .system(name: "star.fill"),
        startTime: Int = 0,
        endTime: Int = 0,
        preparationTime: Int = 0,
        isOnBadWeather: Bool = false,
        badWeatherAheadTime: Int = 0,
        effort: Int = 1,
        tags: [String] = [],
        notification: Bool = true,
        notificationSound: NotificationSound? = .default
    ) {
        self.title = title
        self.content = content
        self.theme = theme
        self.icon = icon
        self.startTime = startTime
        self.endTime = endTime
        self.preparationTime = preparationTime
        self.notificationID = UUID().uuidString
        self.isOnBadWeather = isOnBadWeather
        self.effort = effort
        self.id = UUID().uuidString
        self.badWeatherAheadTime = badWeatherAheadTime
        self.tags = tags
        self.notification = notification
        self.notificationSound = notificationSound
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
            isOnBadWeather: false,
            badWeatherAheadTime: other.badWeatherAheadTime,
            effort: other.effort,
            tags: other.tags,
            notification: other.notification,
            notificationSound: other.notificationSound
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
        self.notification = other.notification
        self.notificationSound = other.notificationSound
    }
    
    func equalsTo(_ other: TaskData) -> Bool {
        return self.title == other.title &&
            self.content == other.content &&
            self.theme == other.theme &&
            self.icon == other.icon &&
            self.startTime == other.startTime &&
            self.endTime == other.endTime &&
            self.preparationTime == other.preparationTime &&
            self.badWeatherAheadTime == other.badWeatherAheadTime &&
            self.effort == other.effort &&
            self.tags == other.tags &&
            self.notification == other.notification &&
            self.notificationSound == other.notificationSound
    }
    
    var startTimeOfDay: TimeOfDay {
        TimeOfDay(hour: startTime / 60, minute: startTime % 60)
    }
    
    var preparationStartTimeOfDay: TimeOfDay {
        TimeOfDay(hour: (startTime - preparationTime) / 60, minute: (startTime - preparationTime) % 60)
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
    
    func scheduleNotification() {
        guard let day = self.day else { return }
        guard notification else { return }
        
        let today = Day.today
        
        if day.dayValue >= today && day.dayValue < today.next.next.next {
            uncheckedScheduleNotification()
        }
    }
    
    private func uncheckedScheduleNotification() {
        guard let day = self.day else { return }
        cancelNotification()
        
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = preparationStartTimeOfDay.hour
        components.minute = preparationStartTimeOfDay.minute
        components.second = 0
        
        guard let date = Calendar.current.date(from: components) else { return }
        guard let date2 = Calendar.current.date(byAdding: .minute, value: -2, to: date) else { return }
        
        guard date2 > .now else { return }
        
        let newComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date2
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: newComponents, repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = notificationSound?.sound
        
        let prepare = preparationTime == 0 ? "" : "\(String(localized: .init("PreparationContentView.advance1"))) \(preparationTime.minutesDescription) \(String(localized: .init("PreparationContentView.advance2")))"
        let tagStr = tags.isEmpty ? "" : "\n" + tags.joined(separator: " ")
        content.body = "\(title) \(String(localized: "notification.1")) \(startTimeOfDay.description)\(String(localized: "notification.2"))\(prepare)\(tagStr)"
        
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
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
            
            existing.applyTemplate(use: existing.useTemplate!, template: template, in: context)
            return existing
        }
        
        let newDay: DayTasks = DayTasks(day: day, template: day.weekday)
        
        if day >= .today {
            newDay.applyTemplate(use: day.weekday, template: template, in: context)
        }
        
        context.insert(newDay)
        try? context.save()
        return newDay
    }
    
    static func scheduleNextThreeDaysNotification(template: UserTemplates, in context: ModelContext) {
        DayTasks.getOrCreate(for: .today, template: .shared(in: context), in: context)
        DayTasks.getOrCreate(for: .today.next, template: .shared(in: context), in: context)
        DayTasks.getOrCreate(for: .today.next.next, template: .shared(in: context), in: context)
    }
    
    func removeTasks(in context: ModelContext, notification: Bool = false) {
        for task in tasks {
            task.cancelNotification()
            context.delete(task)
        }
        tasks = []
        try? context.save()
        if notification && dayValue == .today {
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventsWidget")
        }
    }

    func applyTemplate(use weekday: Weekday, template: UserTemplates, in context: ModelContext) {
        useTemplate = weekday
        removeTasks(in: context)
        tasks = template.tasks(for: weekday).map { TaskData(copying: $0) }
        for task in tasks {
            task.scheduleNotification()
        }
        if dayValue == .today {
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventsWidget")
        }
    }
}
