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
    static func dayTasks(from templates: UserTemplates, daysBack: Int = 1, daysForward: Int = 3) -> [DayTasks] {
        var result: [DayTasks] = []
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())

        for offset in (-daysBack)...daysForward {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            let day = Day(year: comps.year ?? 2025,
                          month: comps.month ?? 1,
                          day: comps.day ?? 1)

            let dayTasks = DayTasks(from: templates, on: day)

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

        let days = SampleData.dayTasks(from: templates)
        days.forEach { context.insert($0) }

        try? context.save()
    }
}
