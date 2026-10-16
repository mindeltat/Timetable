//
//  UnscheduledTasksView.swift
//  Timetable
//
//  Created by Zack on 2026/10/13.
//

import SwiftUI
import SwiftData

func generateSectionSegments() -> [Date] {
    return [.distantPast, .now, Day.today.next(byAdding: 1), Day.today.next(byAdding: 2), Day.today.next(byAdding: 8), Day.today.next(byAdding: 31), Day.today.next(byAdding: 181), .distantFuture]
}
let segmentsName: [String] = ["UnscheduledTasksView.overdue", "UnscheduledTasksView.today", "UnscheduledTasksView.tomorrow", "UnscheduledTasksView.nextWeek", "UnscheduledTasksView.nextMonth", "UnscheduledTasksView.next6Month", "UnscheduledTasksView.distantFuture"]

struct DeadlineSection: Identifiable {
    let id: Int
    let title: String
    let range: Range<Date>
    var tasks: [TaskData]
}

func groupTasksByDeadline(
    _ tasks: [TaskData],
    segments: [Date],
    segmentsName: [String]
) -> [DeadlineSection] {
    guard segments.count >= 2 else { return [] }

    var sections: [DeadlineSection] = (0..<(segments.count - 1)).map { i in
        DeadlineSection(
            id: i,
            title: segmentsName.indices.contains(i) ? segmentsName[i] : "",
            range: segments[i]..<segments[i + 1],
            tasks: []
        )
    }

    let lastIndex = sections.count - 1

    for task in tasks {
        let index: Int

        if let d = task.displayedDeadline {
            if let i = (0..<lastIndex).first(where: {
                d >= segments[$0] && d < segments[$0 + 1]
            }) {
                index = i
            } else {
                index = lastIndex
            }
        } else {
            index = lastIndex
        }

        sections[index].tasks.append(task)
    }

    return sections
}

struct UnscheduledTaskDataView: View {
    @State var isEditing: Bool = false
    let task: TaskData
    
    var body: some View {
        Button {
            isEditing.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TaskDataImageView(image: task.icon, theme: task.theme)
                    VStack(alignment: .leading) {
                        if let deadline = task.deadline {
                            Text("\(task.durationWithoutPreparation.minutesDescription), \(Text(task.deadlineDescription).foregroundStyle(deadline > .now || task.isDone ? .secondary : Color.red))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(task.durationWithoutPreparation.minutesDescription)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Text(Image(systemName: task.priority.icon)).foregroundStyle(task.theme.fgColor)) \(task.title)")
                            .font(.title3)
                            .bold()
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            task.isDone.toggle()
                        }
                        task.scheduleNotification()
                    } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "checkmark.circle")
                            .imageScale(.large)
                            .bold()
                            .foregroundStyle(task.theme.fgColor)
                    }
                }
                if task.content != "" || !task.tags.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    if !task.tags.isEmpty {
                        FlowLayout {
                            ForEach(Array(task.tags.enumerated()), id: \.offset) { _, tag in
                                TagView(tag: tag, theme: task.theme)
                            }
                        }
                    }
                    if !task.tags.isEmpty && task.content != "" {
                        Color.clear
                            .frame(height: 4)
                    }
                    if task.content != "" {
                        Text(task.content)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, .horizontalTextPadding + 4)
            .padding(.vertical, .verticalTextPadding + 4)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: .largeControl / 2)
                    .fill(task.theme.bgColor)
            }
            .contentShape(RoundedRectangle(cornerRadius: .largeControl / 2))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isEditing) {
            TaskEditingView(task: task, existed: true)
        }
    }
}

struct SecondaryChevronDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                        .foregroundStyle(.secondary)
                        .font(.headline)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    Spacer()
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

extension DisclosureGroupStyle where Self == SecondaryChevronDisclosureGroupStyle {
    static var secondary: some DisclosureGroupStyle {
        SecondaryChevronDisclosureGroupStyle()
    }
}

struct ExpandableGroup<Content: View>: View {
    @State private var isExpanded: Bool
    private let title: LocalizedStringKey
    private let content: Content

    init(
        _ titleKey: LocalizedStringKey,
        defaultExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = titleKey
        self._isExpanded = State(initialValue: defaultExpanded)
        self.content = content()
    }

    init(
        _ title: String,
        defaultExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = LocalizedStringKey(title)
        self._isExpanded = State(initialValue: defaultExpanded)
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(title, isExpanded: $isExpanded) {
            content
        }
        .disclosureGroupStyle(.secondary)
    }
}

struct UnscheduledTasksView: View {
    @CodableStorage("settings") private var settings = Settings()
    @Environment(\.scenePhase) private var scenePhase
    @State var sectionSegments: [Date] = []
    private static let taskSortDescriptors: [SortDescriptor<TaskData>] = [
        SortDescriptor(\TaskData.priorityNum, order: .forward),
        SortDescriptor(\TaskData.deadline, order: .forward)
    ]
    
    private static let finishedTaskSortDescriptors: [SortDescriptor<TaskData>] = [
        SortDescriptor(\TaskData.deadline, order: .forward),
        SortDescriptor(\TaskData.priorityNum, order: .forward)
    ]

    @Query(
        filter: #Predicate<TaskData> { $0.day == nil && !$0.isDone },
        sort: Self.taskSortDescriptors
    )
    private var tasks: [TaskData]
    
    @Query(
        filter: #Predicate<TaskData> { $0.day == nil && $0.isDone },
        sort: Self.finishedTaskSortDescriptors
    )
    private var finishedTasks: [TaskData]
    
    @State private var sections: [DeadlineSection] = []
    @State private var isAddingTask: Bool = false
    
    private var groupingKey: [String] {
        tasks.map { task in
            let deadlineValue = task.deadline?.timeIntervalSince1970 ?? .leastNormalMagnitude
            return "\(task.persistentModelID.hashValue)-\(task.priorityNum)-\(deadlineValue)-\(task.isDone)"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(sections) { section in
                        if !section.tasks.isEmpty {
                            ExpandableGroup(LocalizedStringKey(section.title)) {
                                LazyVStack(spacing: 16) {
                                    ForEach(section.tasks) { task in
                                        UnscheduledTaskDataView(task: task)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !finishedTasks.isEmpty {
                        ExpandableGroup("UnscheduledTaskView.finished") {
                            LazyVStack(spacing: 16) {
                                ForEach(finishedTasks) { task in
                                    UnscheduledTaskDataView(task: task)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .sheet(isPresented: $isAddingTask) {
                TaskEditingView(
                    task: .init(startTime: 0, endTime: 1, notification: settings.defaultNotification, notificationSound: settings.defaultNotificationSound),
                    existed: false
                )
            }
            .navigationTitle("UnscheduledTasksView.title")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("UnscheduledTasksView.title")
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("", systemImage: "plus") {
                        isAddingTask.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .safeSetNavigationTitleDisplayModeToInline()
        }
        .onAppear {
            rebuild()
        }
        .onChange(of: scenePhase) { _, newPhase in
            rebuild()
        }
        .onChange(of: groupingKey) {
            rebuild()
        }
    }
    
    private func rebuild() {
        let segments = generateSectionSegments()
        sections = groupTasksByDeadline(tasks, segments: segments, segmentsName: segmentsName)
    }
}

#Preview {
    UnscheduledTasksView()
        .modelContainer(PreviewContainer.shared)
}
