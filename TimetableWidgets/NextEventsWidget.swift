//
//  NextEventsWidget.swift
//  NextEventsWidget
//
//  Created by Zack on 2026/10/7.
//

import WidgetKit
import SwiftUI
import SwiftData

enum WidgetModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            TaskData.self,
            DayTasks.self,
            UserTemplates.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.mindeltat.Timetable"))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

struct NextEventsProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextEventsEntry {
        NextEventsEntry(date: Date(), tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEventsEntry) -> ()) {
        let entry = NextEventsEntry(date: Date(), tasks: SampleData.weekdayTemplate())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            var entries: [NextEventsEntry] = []
            
            // Generate a timeline consisting of five entries an hour apart, starting from the current date.
            let currentDate = Date()
            let today = Day.today
            let currentMinutes = minutesSinceStartOfDay(currentDate)
            let data = await loadData()
            let index = getCurrentIndex(data: data, now: currentMinutes)
            
            if let index {
                entries.append(.init(date: currentDate, tasks: Array(data[index...])))
                for i in index...(data.count - 1) {
                    entries.append(.init(date: today.date(at: data[i].endTimeOfDay)!, tasks: i == data.count - 1 ? [] : Array(data[(i + 1)...])))
                }
            } else {
                entries.append(.init(date: currentDate, tasks: []))
            }
            
            let timeline = Timeline(entries: entries, policy: .after(today.next.date(at: .init(hour: 0, minute: 0))!))
            completion(timeline)
        }
    }
    
    @MainActor
    private func loadData() async -> [TaskData] {
        let context = WidgetModelContainer.shared.mainContext
        let dayTasks = DayTasks.getOrCreate(for: .today, template: .shared(in: context), in: context)
        return dayTasks.tasks.sorted { $0.startTime < $1.startTime }
    }
    
    private func getCurrentIndex(data: [TaskData], now: Int) -> Int? {
        for i in data.indices {
            if data[i].endTime > now {
                return i
            }
        }
        return nil
    }

//    func relevances() async -> WidgetRelevances<Void> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct NextEventsEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskData]
}

struct TaskIconView: View {
    let task: TaskData
    
    var body: some View {
        switch task.icon {
        case .system(let name):
            Image(systemName: name)
                .bold()
                .foregroundStyle(task.theme.fgColor)
        case .file(let path):
            EmptyView()
        }
    }
}

struct TaskDataImageView: View {
    let image: ImageType
    let theme: Theme

    var body: some View {
        switch image {
        case .system(let name):
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: .largeControl, height: .largeControl)
                .foregroundStyle(theme.fgColor)
        case .file(let path):
            EmptyView()
        }
    }
}

struct TagView: View {
    let tag: String
    let theme: Theme
    
    var body: some View {
        Text(tag)
            .foregroundStyle(theme.fgColor)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(theme.bgColorNoOpacity)
            }
            .padding(.horizontal, 2)
            .lineLimit(1)
    }
}

struct NextEventsEntryView : View {
    @Environment(\.widgetFamily) private var widgetFamily
    var entry: NextEventsProvider.Entry

    var body: some View {
        if entry.tasks.isEmpty {
            Image(systemName: "checkmark.circle")
                .resizable()
                .bold()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tertiary)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.footnote)
                        .bold()
                    if widgetFamily != .systemSmall {
                        Text("NextEventsWidget")
                            .font(.footnote)
                            .bold()
                    } else {
                        Text("NextEventsWidget.short")
                            .font(.footnote)
                            .bold()
                    }
                    Spacer()
                    Text("\(entry.tasks.count)")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .lineLimit(1)
                
                Divider()
                    .padding(.top, 3)
                    .padding(.bottom, 8)
                
                if widgetFamily != .systemSmall && widgetFamily != .systemMedium {
                    let task = entry.tasks[0]
                    
                    HStack {
                        Rectangle()
                            .fill(task.theme.fgColor)
                            .frame(width: 8)
                        VStack(spacing: 0) {
                            HStack {
                                TaskDataImageView(image: task.icon, theme: task.theme)
                                VStack(alignment: .leading) {
                                    Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description) (\(task.durationWithoutPreparation.minutesDescription))")
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(task.title)
                                        .font(.title3)
                                        .bold()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            if !task.tags.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                                FlowLayout {
                                    ForEach(Array(task.tags.enumerated()), id: \.offset) { _, tag in
                                        TagView(tag: tag, theme: task.theme)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, .horizontalTextPadding)
                        .padding(.vertical, .verticalTextPadding + 4)
                    }
                    .background(task.theme.bgColor)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                FillUntilFullLayout(spacing: 1.5) {
                    ForEach(Array(entry.tasks.enumerated()), id: \.offset) { i, task in
                        HStack(spacing: 0) {
                            switch widgetFamily {
                            case .systemSmall:
                                indicator(task: task)
                                icon(task: task)
                                Spacer(minLength: 0)
                                time(task: task)
                            case .systemMedium:
                                indicator(task: task)
                                icon(task: task)
                                title(task: task)
                                Spacer(minLength: 0)
                                time(task: task)
                            default:
                                if i != 0 {
                                    indicator(task: task)
                                    icon(task: task)
                                    title(task: task)
                                    Spacer(minLength: 0)
                                    time(task: task)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 6)
                        .background(task.theme.bgColor)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
    }
    
    private func indicator(task: TaskData) -> some View {
        Rectangle()
            .fill(task.theme.fgColor)
            .frame(width: 8)
            .padding(.trailing, 6)
    }
    
    private func icon(task: TaskData) -> some View {
        TaskIconView(task: task)
            .padding(.trailing, 3)
    }
    
    private func title(task: TaskData) -> some View {
        Text(task.title)
            .bold()
            .lineLimit(1)
    }
    
    private func time(task: TaskData) -> some View {
        Text(task.startTimeOfDay.description)
            .foregroundStyle(task.theme.fgColor)
            .bold()
            .fontDesign(.monospaced)
            .lineLimit(1)
    }
}

struct NextEventsWidget: Widget {
    let kind: String = "NextEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextEventsProvider()) { entry in
            NextEventsEntryView(entry: entry)
                .containerBackground(.accentText, for: .widget)
        }
        .configurationDisplayName("NextEventsWidget")
        .description("NextEventsWidget.description")
    }
}

#Preview(as: .systemLarge) {
    NextEventsWidget()
} timeline: {
    NextEventsEntry(date: .now, tasks: SampleData.weekdayTemplate())
    NextEventsEntry(date: .now, tasks: Array(SampleData.weekdayTemplate()[1...]))
    NextEventsEntry(date: .now, tasks: [])
}
