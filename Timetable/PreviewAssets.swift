//
//  PreviewAssets.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//
import SwiftData
import Foundation

enum SampleData {
    static func task(
        title: String,
        content: String = "",
        theme: Theme,
        icon: String = "star",
        start: Int,
        end: Int,
        prep: Int = 0,
        badWeather: Bool = false
    ) -> TaskData {
        TaskData(
            title: title,
            content: content,
            theme: theme,
            icon: .system(name: icon),
            startTime: start,
            endTime: end,
            preparationTime: prep,
            isOnBadWeather: badWeather
        )
    }

    static func weekdayTemplate() -> [TaskData] {
        [
            task(title: "Morning Jogging", theme: .lime, icon: "figure.run",
                 start: 6 * 60 + 30, end: 7 * 60 + 10, prep: 10),
            task(title: "Breakfast", theme: .orange, icon: "fork.knife",
                 start: 7 * 60 + 15, end: 7 * 60 + 45),
            task(title: "Work", theme: .cyan,   icon: "tram.fill",
                 start: 8 * 60, end: 8 * 60 + 40,
                 badWeather: true),
            task(title: "Work", theme: .blue,   icon: "brain.head.profile",
                 start: 9 * 60,      end: 12 * 60, prep: 5),
            task(title: "Lunch", theme: .yellow, icon: "takeoutbag.and.cup.and.straw.fill",
                 start: 12 * 60,     end: 13 * 60),
            task(title: "Meetings", theme: .violet, icon: "person.2.wave.2.fill",
                 start: 14 * 60,     end: 15 * 60, prep: 5),
            task(title: "Work Out", theme: .red,    icon: "dumbbell.fill",
                 start: 19 * 60,     end: 20 * 60, prep: 15),
            task(title: "Reading", theme: .green,  icon: "book.fill",
                 start: 21 * 60, end: 22 * 60),
        ]
    }

    static func weekendTemplate() -> [TaskData] {
        [
            task(title: "Get Up", theme: .cyan, icon: "bed.double.fill",
                 start: 9 * 60,  end: 10 * 60),
            task(title: "Brunch", theme: .orange, icon: "cup.and.saucer.fill",
                 start: 11 * 60, end: 12 * 60, prep: 30),
            task(title: "Wandering", theme: .green, icon: "leaf.fill",
                 start: 15 * 60, end: 16 * 60 + 30,
                 badWeather: true),
            task(title: "Watching Movie", theme: .violet, icon: "film.fill",
                 start: 20 * 60, end: 22 * 60),
        ]
    }

    @MainActor
    static func userTemplates() -> UserTemplates {
        let templates = UserTemplates()

        let weekday = weekdayTemplate()
        templates.setTasks(weekday.map { TaskData(copying: $0) }, for: .monday)
        templates.setTasks(weekday.map { TaskData(copying: $0) }, for: .tuesday)
        templates.setTasks(weekday.map { TaskData(copying: $0) }, for: .wednesday)
        templates.setTasks(weekday.map { TaskData(copying: $0) }, for: .thursday)
        templates.setTasks(weekday.map { TaskData(copying: $0) }, for: .friday)

        templates.setTasks(weekendTemplate(), for: .saturday)
        templates.setTasks(weekendTemplate(), for: .sunday)

        return templates
    }

    @MainActor
    static func dayTasks(from templates: UserTemplates, daysBack: Int = 1, daysForward: Int = 3, in context: ModelContext) -> [DayTasks] {
        var result: [DayTasks] = []
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())

        for offset in (-daysBack)...daysForward {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            let day = Day(year: comps.year ?? 2025,
                          month: comps.month ?? 1,
                          day: comps.day ?? 1)

            let dayTasks = DayTasks(day: day, template: day.weekday)
            dayTasks.applyTemplate(use: day.weekday, template: templates, in: context)

            if offset == 0, let first = dayTasks.tasks.first {
                first.title = "Rest"
                first.isOnBadWeather = true
            }
            
            if offset == 1 {
                dayTasks.tasks.removeAll { $0.title == "Meetings" }
            }

            result.append(dayTasks)
        }
        return result
    }
}

@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            TaskData.self,
            UserTemplates.self,
            DayTasks.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()

    static let empty: ModelContainer = {
        let schema = Schema([
            TaskData.self,
            UserTemplates.self,
            DayTasks.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    @MainActor
    private static func seed(into context: ModelContext) {
        let templates = SampleData.userTemplates()
        context.insert(templates)

        let days = SampleData.dayTasks(from: templates, in: context)
        days.forEach { context.insert($0) }
        
        context.insert(TaskData(title: "Sample Unscheduled Task", content: "Content", startTime: 0, endTime: 30, tags: ["tag1", "tag2"]))
        context.insert(TaskData(title: "Sample Unscheduled Task 2", content: "Content", startTime: 0, endTime: 30, tags: ["tag1", "tag2"]))
        
        try? context.save()
    }
}

let previewTasks: [TaskData] = [
    TaskData(
        title: "Morning Routine",
        content: "Stretch, shower, and review today's top 3 priorities.",
        theme: .cyan,
        icon: .system(name: "sun.max.fill"),
        startTime: 420,   // 07:00
        endTime: 450,     // 07:30
        preparationTime: 0,
        tags: ["Home", "Personal"]
    ),
    TaskData(
        title: "Breakfast with Alex",
        content: "Make coffee, catch up on the week, and enjoy a slow breakfast.",
        theme: .orange,
        icon: .system(name: "cup.and.saucer.fill"),
        startTime: 480,   // 08:00
        endTime: 525,     // 08:45
        preparationTime: 10,
        tags: ["Home Kitchen", "Alex", "Personal"]
    ),
    TaskData(
        title: "Team Standup",
        content: "Quick sync on blockers, priorities, and today's handoffs.",
        theme: .blue,
        icon: .system(name: "person.3.fill"),
        startTime: 570,   // 09:30
        endTime: 585,     // 09:45
        preparationTime: 20,
        tags: ["Office / Zoom", "Maya", "Chris", "Dev Team", "Work"]
    ),
    TaskData(
        title: "Deep Work: Q3 Roadmap",
        content: "Focus block for roadmap drafting, estimates, and priority sorting.",
        theme: .violet,
        icon: .system(name: "briefcase.fill"),
        startTime: 600,   // 10:00
        endTime: 720,     // 12:00
        preparationTime: 5,
        tags: ["Focus Room", "Work"]
    ),
    TaskData(
        title: "Lunch with Sarah",
        content: "Try the new seasonal bowl and talk through the upcoming launch.",
        theme: .yellow,
        icon: .system(name: "fork.knife"),
        startTime: 750,   // 12:30
        endTime: 795,     // 13:15
        preparationTime: 10,
        tags: ["Green Bowl Cafe", "Sarah", "Social"]
    ),
    TaskData(
        title: "Client Call: Acme",
        content: "Review feedback, confirm scope, and align on next milestones.",
        theme: .blue,
        icon: .system(name: "video.fill"),
        startTime: 840,   // 14:00
        endTime: 900,     // 15:00
        preparationTime: 15,
        tags: ["Zoom", "Emma", "David", "Work"]
    ),
    TaskData(
        title: "Gym Session",
        content: "Strength training: lower body, core, and a short cooldown.",
        theme: .green,
        icon: .system(name: "figure.run"),
        startTime: 930,   // 15:30
        endTime: 975,     // 16:15
        preparationTime: 20,
        tags: ["FitLife Gym", "Health"]
    ),
    TaskData(
        title: "Grocery Pickup",
        content: "Pick up weekly groceries and fresh ingredients for dinner.",
        theme: .orange,
        icon: .system(name: "cart.fill"),
        startTime: 1020,  // 17:00
        endTime: 1050,    // 17:30
        preparationTime: 10,
        tags: ["Whole Foods", "Errands"]
    ),
    TaskData(
        title: "Family Dinner",
        content: "Cook pasta, set the table, and share highlights from the day.",
        theme: .red,
        icon: .system(name: "person.3.fill"),
        startTime: 1110,  // 18:30
        endTime: 1170,    // 19:30
        preparationTime: 30,
        tags: ["Home", "Mom", "Dad", "Family"]
    ),
    TaskData(
        title: "Movie Night",
        content: "Watch the new sci-fi movie with snacks and lights dimmed.",
        theme: .violet,
        icon: .system(name: "film.fill"),
        startTime: 1200,  // 20:00
        endTime: 1290,    // 21:30
        preparationTime: 10,
        tags: ["Living Room", "Alex", "Leisure"]
    ),
    TaskData(
        title: "Journal & Plan Tomorrow",
        content: "Write a short reflection and choose tomorrow's top 3 tasks.",
        theme: .cyan,
        icon: .system(name: "book.fill"),
        startTime: 1320,  // 22:00
        endTime: 1340,    // 22:20
        preparationTime: 0,
        tags: ["Bedroom", "Personal"]
    )
]

private func unscheduledPreviewDate(
    daysFromToday: Int,
    hour: Int,
    minute: Int = 0
) -> Date {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let targetDay = calendar.date(
        byAdding: .day,
        value: daysFromToday,
        to: startOfToday
    ) ?? startOfToday

    return calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: targetDay
    ) ?? targetDay
}

// 保证“今天”的 deadline 仍然在今天内，且晚于当前时间
private func todayDeadline(hoursFromNow: Int) -> Date {
    let calendar = Calendar.current
    let target = Date().addingTimeInterval(TimeInterval(hoursFromNow * 3600))
    let endOfToday = calendar.date(
        bySettingHour: 23,
        minute: 59,
        second: 59,
        of: Date()
    ) ?? target

    return min(target, endOfToday)
}

let unscheduledPreviewTasks: [TaskData] = [
    // MARK: - 1 Overdue
    TaskData(
        title: "Submit expense report",
        content: "Upload receipts and send the March expense report to finance.",
        theme: .red,
        icon: .system(name: "doc.text.fill"),
        startTime: 0,
        endTime: 30,
        preparationTime: 0,
        tags: ["Finance", "Admin"],
        priorityNum: 0, // urgent
        deadline: unscheduledPreviewDate(daysFromToday: -2, hour: 18),
        deadlineDayOnly: false,
        isDone: false
    ),

    // MARK: - 2 Today
    TaskData(
        title: "Call dentist",
        content: "Reschedule the cleaning appointment for next week.",
        theme: .orange,
        icon: .system(name: "phone.fill"),
        startTime: 0,
        endTime: 15,
        preparationTime: 0,
        tags: ["Health", "Personal"],
        priorityNum: 1, // normal
        deadline: todayDeadline(hoursFromNow: 2),
        deadlineDayOnly: false,
        isDone: false
    ),
    TaskData(
        title: "Finish design draft",
        content: "Polish the onboarding screens and share the Figma link with the team.",
        theme: .violet,
        icon: .system(name: "paintbrush.fill"),
        startTime: 0,
        endTime: 90,
        preparationTime: 0,
        tags: ["Design", "Work", "Maya"],
        priorityNum: 0, // urgent
        deadline: todayDeadline(hoursFromNow: 5),
        deadlineDayOnly: false,
        isDone: false
    ),

    // MARK: - 2 Within One Week
    TaskData(
        title: "Book train tickets",
        content: "Book round-trip tickets for the weekend trip to Brighton.",
        theme: .blue,
        icon: .system(name: "tram.fill"),
        startTime: 0,
        endTime: 25,
        preparationTime: 0,
        tags: ["Travel", "Personal"],
        priorityNum: 1,
        deadline: unscheduledPreviewDate(daysFromToday: 3, hour: 12),
        deadlineDayOnly: false,
        isDone: false
    ),
    TaskData(
        title: "Prepare weekly report",
        content: "Summarize progress, blockers, and next week's plan for the Monday sync.",
        theme: .cyan,
        icon: .system(name: "chart.bar.fill"),
        startTime: 0,
        endTime: 60,
        preparationTime: 0,
        tags: ["Work", "Reporting"],
        priorityNum: 1,
        deadline: unscheduledPreviewDate(daysFromToday: 5, hour: 18),
        deadlineDayOnly: false,
        isDone: false
    ),

    // MARK: - 3 Within Six Months
    TaskData(
        title: "Renew passport",
        content: "Fill out the application, take a photo, and mail the renewal packet.",
        theme: .green,
        icon: .system(name: "airplane"),
        startTime: 0,
        endTime: 45,
        preparationTime: 0,
        tags: ["Travel", "Admin"],
        priorityNum: 2, // optional
        deadline: unscheduledPreviewDate(daysFromToday: 60, hour: 17),
        deadlineDayOnly: false,
        isDone: false
    ),
    TaskData(
        title: "Plan summer holiday",
        content: "Compare destinations, set a budget, and book accommodation.",
        theme: .yellow,
        icon: .system(name: "sun.max.fill"),
        startTime: 0,
        endTime: 120,
        preparationTime: 0,
        tags: ["Travel", "Family", "Alex"],
        priorityNum: 2,
        deadline: unscheduledPreviewDate(daysFromToday: 120, hour: 20),
        deadlineDayOnly: false,
        isDone: false
    ),
    TaskData(
        title: "Learn SwiftUI animation",
        content: "Complete the advanced animation course and build a small demo.",
        theme: .lime,
        icon: .system(name: "chevron.left.forwardslash.chevron.right"),
        startTime: 0,
        endTime: 180,
        preparationTime: 0,
        tags: ["Study", "Develop", "Personal"],
        priorityNum: 2,
        deadline: unscheduledPreviewDate(daysFromToday: 170, hour: 22),
        deadlineDayOnly: false,
        isDone: false
    ),

    // MARK: - 1 Distant Future / No Deadline
    TaskData(
        title: "Write a book outline",
        content: "Collect notes, define chapters, and draft a one-page outline.",
        theme: .violet,
        icon: .system(name: "book.fill"),
        startTime: 0,
        endTime: 120,
        preparationTime: 0,
        tags: ["Personal", "Read & Write"],
        priorityNum: 2,
        deadline: nil, // 没有 deadline 也会归入 Distant Future 分组
        deadlineDayOnly: true,
        isDone: false
    )
]
