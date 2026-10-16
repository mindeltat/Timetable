//
//  TaskData.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData
import WidgetKit
import Observation

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
    
    var localizedCustomizedDescription: String {
        if self == .today {
            return .init(localized: .init("today"))
        }
        if self == .today.last {
            return .init(localized: .init("yesterday"))
        }
        if self == .today.next {
            return .init(localized: .init("tomorrow"))
        }
        if self.year == Day.today.year {
            return shortLocalizedDescription
        }
        return localizedDescription
    }
    
    var localizedDescription: String {
        var calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) else { return description }
        
        return date.formatted(date: .long, time: .omitted)
    }
    
    var shortLocalizedDescription: String {
        var calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) else { return description }
        
        return date.formatted(.dateTime.month(.wide).day())
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
    
    func next(byAdding: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        guard let nextDate = calendar.date(byAdding: .day, value: byAdding, to: date) else {
            return date
        }
        return nextDate
    }
    
    var last: Day {
        let calendar = Calendar(identifier: .gregorian)
        guard let nextDate = calendar.date(byAdding: .day, value: -1, to: date) else {
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
    
    init(_ num: Int) {
        self.hour = num / 60
        self.minute = num % 60
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

enum TaskPriority: Int, Codable {
    case urgent = 0
    case normal = 1
    case optional = 2
    
    var text: String {
        .init(localized: .init("Priority.\(rawValue)"))
    }
    
    var icon: String {
        switch self {
        case .urgent:
            "exclamationmark.3"
        case .normal:
            "exclamationmark"
        case .optional:
            "questionmark"
        }
    }
}

// MARK: - Useful Functions

func firstAvailableTime(scheduled: [ClosedRange<Int>], after time: Int) -> Int? {
    if scheduled.isEmpty {
        return time
    }
    
    for i in scheduled.indices {
        if scheduled[i].contains(time) {
            if i == scheduled.count - 1 {
                if scheduled[i].upperBound != 1440 {
                    return scheduled[i].upperBound
                } else {
                    return nil
                }
            }
            
            for j in i..<(scheduled.count - 1) {
                if scheduled[i].upperBound != scheduled[i + 1].lowerBound {
                    return scheduled[i].upperBound
                }
            }
            
            if scheduled.last!.upperBound != 1440 {
                return scheduled.last!.upperBound
            } else {
                return nil
            }
        }
    }
        
    return time
}

let allIndexes: [Int] = {
    var rv: [Int] = []
    for i in 0..<288 {
        rv.append(i)
    }
    return rv
}()

func availableIndexes(scheduled: [ClosedRange<Int>]) -> [Int] {
    if scheduled.isEmpty {
        return allIndexes
    }
    
    var rv: [Int] = []
    
    for i in 0..<scheduled.first!.lowerBound {
        if i % 5 == 0 { rv.append(i / 5) }
    }
    for i in 0..<scheduled.count - 1 {
        for j in scheduled[i].upperBound..<scheduled[i + 1].lowerBound {
            if j % 5 == 0 { rv.append(j / 5) }
        }
    }
    for i in scheduled.last!.upperBound..<1440 {
        if i % 5 == 0 { rv.append(i / 5) }
    }
    return rv
}

func availableDuration(scheduled: [ClosedRange<Int>], after time: Int) -> Int {
    for r in scheduled {
        if time < r.lowerBound {
            return r.lowerBound - time
        }
    }
    
    return 1440 - time
}

func availableDuration(scheduled: [ClosedRange<Int>], before time: Int) -> Int {
    if scheduled.isEmpty {
        return time
    }
    
    if time < scheduled.first!.upperBound {
        return time
    }
    
    for i in 0..<(scheduled.count - 1) {
        if time < scheduled[i + 1].upperBound {
            return time - scheduled[i].upperBound
        }
    }
    
    return time - scheduled.last!.upperBound
}

let allHoursAndMinutes: [Int: [Int]] = {
    var rv: [Int: [Int]] = [:]
    for i in 0...23 {
        var temp: [Int] = []
        for j in 0...59 {
            temp.append(j)
        }
        rv.updateValue(temp, forKey: i)
    }
    return rv
}()

func availableHoursAndMinutes(scheduled: [ClosedRange<Int>]) -> [Int: [Int]] {
    if scheduled.isEmpty {
        return allHoursAndMinutes
    }
    
    var rv: [Int: [Int]] = [:]
    
    for i in 0..<scheduled.first!.lowerBound {
        let hour = i / 60
        let minute = i % 60
        if rv[hour] != nil {
            rv[hour]!.append(minute)
        } else {
            rv.updateValue([minute], forKey: hour)
        }
    }
    for i in 0..<scheduled.count - 1 {
        for j in scheduled[i].upperBound..<scheduled[i + 1].lowerBound {
            let hour = j / 60
            let minute = j % 60
            if rv[hour] != nil {
                rv[hour]!.append(minute)
            } else {
                rv.updateValue([minute], forKey: hour)
            }
        }
    }
    for i in scheduled.last!.upperBound..<1440 {
        let hour = i / 60
        let minute = i % 60
        if rv[hour] != nil {
            rv[hour]!.append(minute)
        } else {
            rv.updateValue([minute], forKey: hour)
        }
    }
    
    return rv
}

func availableHoursAndMinutes(scheduled: [ClosedRange<Int>], after: Int) -> [Int: [Int]] {
    let max = availableDuration(scheduled: scheduled, after: after)
    
    var rv: [Int: [Int]] = [:]
    
    for i in (after + 1)...(after + max) {
        let hour = i / 60
        let minute = i % 60
        if rv[hour] != nil {
            rv[hour]!.append(minute)
        } else {
            rv.updateValue([minute], forKey: hour)
        }
    }
    
    return rv
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
    
    var priorityNum: Int = 1
    var deadline: Date? = nil
    var deadineDayOnly: Bool = true
    var isDone: Bool = false
    
    var displayedDeadline: Date? {
        guard let deadline else { return nil }
        if deadineDayOnly {
            return deadline.advanced(by: .init(integerLiteral: -1))
        }
        return deadline
    }
    
    var deadlineDescription: String {
        if let deadline {
            if deadineDayOnly {
                return Day(date: deadline).last.localizedCustomizedDescription
            }
            return Day(date: deadline).localizedCustomizedDescription + " \(deadline.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))"
        }
        return ""
    }
    
    var deadlineShortDescription: String {
        if let deadline {
            if deadineDayOnly {
                return Day(date: deadline).last.date.formatted(date: .abbreviated, time: .omitted)
            }
            return Day(date: deadline).date.formatted(date: .abbreviated, time: .omitted) + " \(deadline.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))"
        }
        return ""
    }
    
    var priority: TaskPriority {
        .init(rawValue: priorityNum)!
    }
    
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
        notificationSound: NotificationSound? = .default,
        day: DayTasks? = nil,
        priorityNum: Int = 1,
        deadline: Date? = nil,
        deadlineDayOnly: Bool = true,
        isDone: Bool = false
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
        self.day = day
        self.priorityNum = priorityNum
        self.deadline = deadline
        self.deadineDayOnly = deadlineDayOnly
        self.isDone = isDone
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
            notificationSound: other.notificationSound,
            priorityNum: other.priorityNum,
            deadline: other.deadline,
            deadlineDayOnly: other.deadineDayOnly,
            isDone: other.isDone
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
        self.priorityNum = other.priorityNum
        self.deadline = other.deadline
        self.deadineDayOnly = other.deadineDayOnly
        self.isDone = other.isDone
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
        self.notificationSound == other.notificationSound &&
        self.priorityNum == other.priorityNum &&
        self.deadline == other.deadline &&
        self.deadineDayOnly == other.deadineDayOnly &&
        self.isDone == other.isDone
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
    
    var startTimeIncludingPreparation: Int {
        startTime - preparationTime
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
        cancelNotification()
        
        guard let day = self.day else {
            uncheckedScheduleUnscheduledNotification()
            return
        }
        guard notification else { return }
        
        let today = Day.today
        
        if day.dayValue >= today && day.dayValue < today.next.next.next {
            uncheckedScheduleNotification()
        }
    }
    
    private func uncheckedScheduleUnscheduledNotification() {
        guard !isDone else { return }
        guard let deadline = self.deadline else { return }
        guard let date = Calendar.current.date(byAdding: .minute, value: -2 - durationWithoutPreparation, to: deadline) else { return }
        guard date > .now else { return }
        
        let newComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: newComponents, repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = notificationSound?.sound
        
        let tagStr = tags.isEmpty ? "" : "\n" + tags.joined(separator: " ")
        content.body = "\(title) \(String(localized: "notification.unscheduled.1")) \(deadline.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))\(String(localized: "notification.unscheduled.2")) \(durationWithoutPreparation.minutesDescription)\(String(localized: "notification.unscheduled.3"))\(tagStr)"
        
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func uncheckedScheduleNotification() {
        guard let day = self.day else { return }
    
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
    
    func applyToDay(day: DayTasks, in context: ModelContext, hasAddToTimeline addToTimeline: Bool) {
        let originalDuration = max(durationWithoutPreparation, 1)
        
        if !addToTimeline {
            // MARK: 未加入时间轴
            preparationTime = 0
            let scheduled = day.scheduled()
            
            if day.dayValue == .today {
                let now = minutesSinceStartOfDay()
                let remainingFree = freeIntervals(scheduled: scheduled, from: now, to: 1439)
                let otherFree = freeIntervals(scheduled: scheduled, from: 0, to: now - 1)
                
                // 1. 剩余时间中找第一个可用时长 >= 任务时长的区间
                if let interval = remainingFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                    startTime = interval.lowerBound
                    endTime = startTime + originalDuration
                    return
                }
                // 2. 其他时间中找第一个可用时长 >= 任务时长的区间
                if let interval = otherFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                    startTime = interval.lowerBound
                    endTime = startTime + originalDuration
                    return
                }
                // 3. 剩余时间中第一个空闲区间，缩短任务时长以 fit in
                if let interval = remainingFree.first {
                    let available = interval.upperBound - interval.lowerBound + 1
                    let newDuration = max(min(originalDuration, available), 1)
                    startTime = interval.lowerBound
                    endTime = startTime + newDuration
                    return
                }
                // 4. 其他时间中第一个空闲区间，缩短任务时长以 fit in
                if let interval = otherFree.first {
                    let available = interval.upperBound - interval.lowerBound + 1
                    let newDuration = max(min(originalDuration, available), 1)
                    startTime = interval.lowerBound
                    endTime = startTime + newDuration
                    return
                }
                // 5. 今天全满，顺延到下一天
                let nextDay = DayTasks.getOrCreate(for: day.dayValue.next, template: .shared(in: context), in: context)
                applyToDay(day: nextDay, in: context, hasAddToTimeline: addToTimeline)
                return
            } else {
                // 日期不为今天
                if scheduled.isEmpty {
                    startTime = 0
                    endTime = originalDuration
                    return
                }
                
                let firstTaskEnd = scheduled.first!.upperBound
                let firstTaskStart = scheduled.first!.lowerBound
                
                // 1. 第一个任务结束之后，找可用时长 >= 任务时长的区间
                let afterFree = freeIntervals(scheduled: scheduled, from: firstTaskEnd, to: 1439)
                if let interval = afterFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                    startTime = interval.lowerBound
                    endTime = startTime + originalDuration
                    return
                }
                // 2. 第一个任务开始之前，找可用时长 >= 任务时长的区间
                let beforeFree = freeIntervals(scheduled: scheduled, from: 0, to: firstTaskStart - 1)
                if let interval = beforeFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                    startTime = interval.lowerBound
                    endTime = startTime + originalDuration
                    return
                }
                // 3. 第一个任务结束之后，第一个空闲区间，缩短任务时长
                if let interval = afterFree.first {
                    let available = interval.upperBound - interval.lowerBound + 1
                    let newDuration = max(min(originalDuration, available), 1)
                    startTime = interval.lowerBound
                    endTime = startTime + newDuration
                    return
                }
                // 4. 第一个任务开始之前，第一个空闲区间，缩短任务时长
                if let interval = beforeFree.first {
                    let available = interval.upperBound - interval.lowerBound + 1
                    let newDuration = max(min(originalDuration, available), 1)
                    startTime = interval.lowerBound
                    endTime = startTime + newDuration
                    return
                }
                // 5. 全天被占用，顺延到下一天
                let nextDay = DayTasks.getOrCreate(for: day.dayValue.next, template: .shared(in: context), in: context)
                applyToDay(day: nextDay, in: context, hasAddToTimeline: addToTimeline)
                return
            }
        } else {
            // MARK: 已加入时间轴
            let scheduled = day.scheduled()
            let originalPreparation = preparationTime
            let allFree = freeIntervals(scheduled: scheduled)
            
            // 1. 优先保持开始时间不变
            if let interval = allFree.first(where: { $0.lowerBound <= startTime && startTime <= $0.upperBound }) {
                let freeStart = interval.lowerBound
                let freeEnd = interval.upperBound
                // 至少能放下 1 分钟任务
                if freeEnd >= startTime {
                    let newPrep = min(originalPreparation, startTime - freeStart)
                    preparationTime = max(newPrep, 0)
                    let maxDuration = freeEnd - startTime + 1
                    let newDuration = min(originalDuration, maxDuration)
                    endTime = startTime + max(newDuration, 1)
                    return
                }
            }
            
            // 2. 开始时间不可用：先尝试放置在开始时间之后
            let afterFree = freeIntervals(scheduled: scheduled, from: startTime + 1, to: 1439)
            // 2a. 之后找能容纳原时长的区间
            if let interval = afterFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                startTime = interval.lowerBound
                endTime = startTime + originalDuration
                preparationTime = 0
                return
            }
            // 2b. 之后第一个空闲区间，缩短时长
            if let interval = afterFree.first {
                let available = interval.upperBound - interval.lowerBound + 1
                let newDuration = max(min(originalDuration, available), 1)
                startTime = interval.lowerBound
                endTime = startTime + newDuration
                preparationTime = 0
                return
            }
            
            // 3. 尝试放置在开始时间之前
            let beforeFree = freeIntervals(scheduled: scheduled, from: 0, to: startTime - 1)
            // 3a. 之前找能容纳原时长的区间
            if let interval = beforeFree.first(where: { $0.upperBound - $0.lowerBound + 1 >= originalDuration }) {
                startTime = interval.lowerBound
                endTime = startTime + originalDuration
                preparationTime = 0
                return
            }
            // 3b. 之前第一个空闲区间，缩短时长
            if let interval = beforeFree.first {
                let available = interval.upperBound - interval.lowerBound + 1
                let newDuration = max(min(originalDuration, available), 1)
                startTime = interval.lowerBound
                endTime = startTime + newDuration
                preparationTime = 0
                return
            }
            
            // 4. 全天被占用，顺延到下一天
            let nextDay = DayTasks.getOrCreate(for: day.dayValue.next, template: .shared(in: context), in: context)
            applyToDay(day: nextDay, in: context, hasAddToTimeline: addToTimeline)
            return
        }
    }
    
    /// 根据已占用区间计算空闲区间。
    /// - 注意：`scheduled` 中的每个区间为 `start...end`，实际占用 `start...(end-1)`，
    ///   因此下一个任务可以从 `end` 开始，无需间隔。
    private func freeIntervals(scheduled: [ClosedRange<Int>], from: Int = 0, to: Int = 1439) -> [ClosedRange<Int>] {
        // 将 scheduled 转换为实际占用的闭区间 [lower, upper-1]
        var occupied: [ClosedRange<Int>] = []
        for r in scheduled {
            let lower = r.lowerBound
            let upper = r.upperBound - 1
            if lower <= upper {
                occupied.append(lower...upper)
            }
        }
        // 合并重叠或相邻的占用区间
        occupied.sort { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Int>] = []
        for interval in occupied {
            if let last = merged.last, last.upperBound + 1 >= interval.lowerBound {
                let newUpper = max(last.upperBound, interval.upperBound)
                merged[merged.count - 1] = last.lowerBound...newUpper
            } else {
                merged.append(interval)
            }
        }
        
        // 生成空闲区间
        var all: [ClosedRange<Int>] = []
        var current = 0
        for r in merged {
            if current < r.lowerBound {
                all.append(current...(r.lowerBound - 1))
            }
            current = max(current, r.upperBound + 1)
        }
        if current <= 1439 {
            all.append(current...1439)
        }
        
        // 裁剪到 [from, to]
        return all.compactMap { interval in
            let start = max(interval.lowerBound, from)
            let end = min(interval.upperBound, to)
            if start <= end {
                return start...end
            }
            return nil
        }
    }
    
    private func adjustTo(startTime: Int, duration: Int) {
        self.endTime = duration + startTime
        self.startTime = startTime
    }
    
    func clearDay() {
        self.preparationTime = 0
        self.endTime = self.durationWithoutPreparation
        self.startTime = 0
        self.day?.tasks.removeAll { $0.id == id }
    }
}

// MARK: - UserTemplates

@Model
final class UserTemplates {
    @Relationship var templateDays: [DayTasks]
    var templatesId = UUID()

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
    var templatesId: UUID? = nil

    @Relationship(deleteRule: .cascade) var tasks: [TaskData]

    var dayValue: Day {
        Day(year: year, month: month, day: day)
    }
    
    func scheduled(exclude: Int? = nil) -> [ClosedRange<Int>] {
        let sortedTasks = tasks.sorted { $0.startTime < $1.startTime }
        var scheduled = sortedTasks.map { ($0.startTime - $0.preparationTime)...$0.endTime }
        if let exclude {
            scheduled.remove(at: exclude)
        }
        return scheduled
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
            
            if existing.templatesId != template.templatesId {
                existing.applyTemplate(use: existing.useTemplate!, template: template, in: context)
            }
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
        let d1 = DayTasks.getOrCreate(for: .today, template: .shared(in: context), in: context)
        let d2 = DayTasks.getOrCreate(for: .today.next, template: .shared(in: context), in: context)
        let d3 = DayTasks.getOrCreate(for: .today.next.next, template: .shared(in: context), in: context)
        for d in [d1, d2, d3] {
            for t in d.tasks {
                t.scheduleNotification()
            }
        }
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
        templatesId = template.templatesId
    }
}
