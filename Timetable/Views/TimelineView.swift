//
//  TimelineView.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData

struct TimelineStackView: View {
    let tasks: [TaskData]
    let currentDay: Day
    let dayState: DayState
    let nowFreshId: Int

    var body: some View {
        let nowMinutes = minutesSinceStartOfDay()
        let nowTime: TimeOfDay? = dayState == .today
            ? TimeOfDay(hour: nowMinutes / 60, minute: nowMinutes % 60)
            : nil

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    let isLast = index == tasks.count - 1

                    let showEndTime: Bool = {
                        if isLast { return true }
                        let next = tasks[index + 1]
                        let nextTop = next.topTime(dayState: dayState, nowMinutes: nowMinutes)
                        return task.endTimeOfDay.minutes(to: nextTop) >= 10
                    }()

                    TimelineTaskRow(
                        task: task,
                        dayState: dayState,
                        showEndTime: showEndTime,
                        nowTime: nowTime,
                        layoutOrder: index * 2
                    )
                    .id(task.id)
                    .environment(\.currentTaskIndex, index)

                    if index < tasks.count - 1 {
                        TimelineGapRow(
                            currentTask: task,
                            nextTask: tasks[index + 1],
                            dayState: dayState,
                            layoutOrder: index * 2 + 1
                        )
                        .id("gap-\(task.id)")
                    }
                }
            }
            .scrollTargetLayout()
            .frame(maxWidth: .infinity)
        }
        .overlayPreferenceValue(TimelineRowLayoutKey.self, alignment: .topLeading) { layouts in
            TimelineTimeLabels(entries: TimelineStackView.globalEntries(from: layouts))
                .frame(width: 60)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    static func globalEntries(from layouts: [TimelineRowLayout]) -> [TimelineTimeLabels.Entry] {
        let sorted = layouts.sorted { $0.order < $1.order }
        var offset: CGFloat = 0
        var result: [TimelineTimeLabels.Entry] = []
        for layout in sorted {
            for label in layout.labels {
                result.append(.init(
                    time: label.time,
                    y: offset + label.y,
                    priority: label.priority,
                    style: label.style
                ))
            }
            offset += layout.height
        }
        return result
    }
}

struct TaskIconView: View {
    let task: TaskData
    
    var body: some View {
        switch task.icon {
        case .system(let name):
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .bold()
                .foregroundStyle(task.theme.fgColor)
        case .file(let path):
            EmptyView()
                .frame(width: 24, height: 24)
        }
    }
}

struct WeekView: View {
    let week: [Day]
    let height: CGFloat
    let dayTasks: [[TaskData]]
    let modelContext: ModelContext
    
    let earliestTime: Int?
    let latestTime: Int?
    
    init(week: [Day], height: CGFloat, modelContext: ModelContext) {
        self.week = week
        self.height = height
        self.modelContext = modelContext
        var rv: [[TaskData]] = []
        for day in week {
            rv.append(DayTasks.getOrCreate(for: day, template: .shared(in: modelContext), in: modelContext).tasks.sorted { $0.startTime < $1.startTime })
        }
        self.dayTasks = rv
        
        rv = rv.filter { !$0.isEmpty }
        
        self.earliestTime = rv.map { $0.first!.startTimeIncludingPreparation }.min()
        self.latestTime = rv.map { $0.last!.endTime }.max()
    }
    
    var body: some View {
        if let earliestTime, let latestTime {
            let minutesPerPt = CGFloat(latestTime - earliestTime) / height
            HStack(spacing: 0) {
                ForEach(Array(dayTasks.enumerated()), id: \.offset) { _, tasks in
                    VStack(spacing: 0) {
                        if !tasks.isEmpty {
                            Color.clear
                                .frame(height: CGFloat(tasks.first!.startTimeIncludingPreparation - earliestTime) / minutesPerPt)
                            ForEach(Array(tasks.enumerated()), id: \.offset) { i, task in
                                let taskHeight = CGFloat(task.durationWithPreparation) / minutesPerPt
                                Group {
                                    if taskHeight < 28 {
                                        Color.clear
                                    } else {
                                        TaskIconView(task: task)
                                    }
                                }
                                .frame(width: 38, height: taskHeight)
                                .background {
                                    RoundedRectangle(cornerRadius: .largeControl / 4)
                                        .fill(task.theme.bgColorNoOpacity)
                                }
                                if i != tasks.count - 1 {
                                    Rectangle()
                                        .fill(LinearGradient(colors: [task.theme.bgColorNoOpacity, tasks[i + 1].theme.bgColorNoOpacity], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 3, height: CGFloat(tasks[i + 1].startTimeIncludingPreparation - task.endTime) / minutesPerPt)
                                }
                            }
                            Color.clear
                                .frame(height: CGFloat(latestTime - tasks.last!.endTime) / minutesPerPt)
                        }
                    }
                    .frame(width: 40)
                }
            }
        } else {
            Color.clear
        }
    }
}

@Observable
final class TimelineViewModel {
    var currentDay: Day = .today
    var displayedDays: [Day] = Day.today.weeks
    var scrollId: String? = nil

    var dayTasks: DayTasks? {
        didSet {
            rebuild()
            startObservingTasks()
        }
    }

    private(set) var sortedTasks: [TaskData] = []
    private(set) var scheduled: [ClosedRange<Int>] = []

    @ObservationIgnored private var observationGeneration = 0

    var dayState: DayState {
        if currentDay < .today { return .before }
        if currentDay == .today { return .today }
        return .after
    }

    var availableIndexes: [Int] {
        availableIndexes()
    }
    
    func availableIndexes(exclude: Int? = nil) -> [Int] {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }

        return Timetable.availableIndexes(scheduled: scheduled)
    }

    func availableDuration(after time: Int, exclude: Int? = nil) -> Int {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
        return Timetable.availableDuration(scheduled: scheduled, after: time)
    }
    
    func availableDuration(before time: Int, exclude: Int? = nil) -> Int {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
        return Timetable.availableDuration(scheduled: scheduled, before: time)
    }

    var firstAvailableIndexAfterNow: Int? {
        let now = minutesSinceStartOfDay()
        return firstAvailableIndexAfter(now)
    }
    
    func firstAvailableIndexAfter(_ time: Int) -> Int? {
        return availableIndexes.first { $0 > time / 5 } ?? availableIndexes.first
    }
    
    func availableHoursAndMinutes(exclude: Int? = nil) -> [Int: [Int]] {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
        return Timetable.availableHoursAndMinutes(scheduled: scheduled)
    }
    
    func availableHoursAndMinutes(after: Int, exclude: Int? = nil) -> [Int: [Int]] {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
        return Timetable.availableHoursAndMinutes(scheduled: scheduled, after: after)
    }

    func loadDayTasks(context: ModelContext) {
        dayTasks = DayTasks.getOrCreate(
            for: currentDay,
            template: UserTemplates.shared(in: context),
            in: context
        )
    }

    func setCurrentDay(to day: Day, context: ModelContext) {
        currentDay = day
        loadDayTasks(context: context)
        updateScrollId()
    }

    func updateScrollId() {
        if dayState == .today {
            let now = minutesSinceStartOfDay()
            for task in sortedTasks {
                if task.startTime >= now || task.endTime >= now {
                    scrollId = task.id
                    return
                }
            }
            scrollId = sortedTasks.last?.id ?? ""
        } else {
            scrollId = sortedTasks.first?.id
        }
    }

    private func rebuild() {
        sortedTasks = (dayTasks?.tasks ?? []).sorted { $0.startTime < $1.startTime }
        scheduled = sortedTasks.map { ($0.startTime - $0.preparationTime)...$0.endTime }
    }

    private func startObservingTasks() {
        guard let dayTasks else { return }
        observationGeneration += 1
        let generation = observationGeneration

        withObservationTracking {
            _ = dayTasks.tasks
            for task in dayTasks.tasks {
                _ = task.startTime
                _ = task.endTime
                _ = task.preparationTime
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.observationGeneration == generation else { return }
                self.rebuild()
                self.startObservingTasks()
            }
        }
    }
}

struct TimelineView: View {
    @CodableStorage("settings") private var settings = Settings()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimelineViewModel()
    @State private var isAddingTask: Bool = false
    @State private var nowFreshId: Int = 0
    
    @State var templateToChange: Weekday? = nil
    @State var showClearAlert: Bool = false
    @State var expandingWeek: Bool = false
    @State var totalHeight: CGFloat = 0

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            ScrollView {
                if viewModel.dayTasks != nil {
                    TimelineStackView(
                        tasks: viewModel.sortedTasks,
                        currentDay: viewModel.currentDay,
                        dayState: viewModel.dayState,
                        nowFreshId: nowFreshId
                    )
                    .padding()
                }
            }
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(expandingWeek ? .accentText : .clear)
            .sheet(isPresented: $isAddingTask) {
                let i: Int? = vm.dayState == .today ? viewModel.firstAvailableIndexAfterNow : viewModel.firstAvailableIndexAfter(viewModel.sortedTasks.last?.endTime ?? 359)
                if let i {
                    TaskEditingView(
                        task: .init(startTime: i * 5, endTime: i * 5 + 1, notification: settings.defaultNotification, notificationSound: settings.defaultNotificationSound),
                        existed: false
                    )
                    .environment(\.currentViewingDay, vm.currentDay)
                }
            }
            .scrollPosition(id: $vm.scrollId, anchor: .center)
            .safeAreaBar(edge: .top) {
                VStack {
                    HStack(spacing: 0) {
                        Button {
                            viewModel.displayedDays = Day(
                                date: viewModel.displayedDays.first!.date
                                    .addingTimeInterval(-24 * 60 * 60)
                            ).weeks
                        } label: {
                            Image(systemName: "chevron.left")
                                .padding(.horizontal)
                                .imageScale(.large)
                                .bold()
                        }
                        .buttonStyle(.borderless)
                        .tint(.accentColor)
                        
                        Spacer()
                        
                        ForEach(viewModel.displayedDays.indices, id: \.self) { i in
                            let day = viewModel.displayedDays[i]
                            let accent = day == viewModel.currentDay
                            
                            Button {
                                viewModel.setCurrentDay(to: day, context: modelContext)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(String(localized: .init(Weekday(rawValue: i + 1)!.shortName)))
                                        .foregroundStyle(accent ? .primary : .secondary)
                                    Text("\(day.day)")
                                        .foregroundStyle(accent ? Color.accentText : Color.primary)
                                        .font(.system(size: .calendarFontSize, weight: .semibold, design: .rounded))
                                        .background {
                                            Circle()
                                                .fill(accent ? .accentColor : .clear)
                                                .frame(width: .calendarCircleSize, height: .calendarCircleSize)
                                        }
                                        .frame(width: .calendarCircleSize, height: .calendarCircleSize)
                                }
                                .frame(width: 40)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.displayedDays = Day(
                                date: viewModel.displayedDays.last!.date
                                    .addingTimeInterval(24 * 60 * 60)
                            ).weeks
                        } label: {
                            Image(systemName: "chevron.right")
                                .padding(.horizontal)
                                .imageScale(.large)
                                .bold()
                        }
                        .buttonStyle(.borderless)
                        .tint(.accentColor)
                    }
                    if expandingWeek {
                        WeekView(week: vm.displayedDays, height: totalHeight * 0.75, modelContext: modelContext)
                            .frame(height: totalHeight * 0.75)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom)
                .background(expandingWeek ? .accentText : .clear)
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
            .navigationTitle(viewModel.currentDay.localizedDescription)
            .safeSetNavigationTitleDisplayModeToInline()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        withAnimation {
                            expandingWeek.toggle()
                        }
                    } label: {
                        HStack {
                            Text(viewModel.currentDay.localizedDescription)
                            Image(systemName: expandingWeek ? "chevron.up" : "chevron.down")
                                .imageScale(.small)
                        }
                        .fontWeight(.semibold)
                        .contentShape(Rectangle())
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu("", systemImage: "list.clipboard") {
                        Picker("", selection: Binding<Weekday?> {
                            return viewModel.dayTasks?.useTemplate
                        } set: { newValue in
                            if newValue == nil {
                                viewModel.dayTasks?.useTemplate = nil
                            }
                            templateToChange = newValue
                        }) {
                            ForEach(1...8, id: \.self) { i in
                                Text(String(localized: .init("TimelineView.template\(i)")))
                                    .tag(Weekday(rawValue: i))
                            }
                        }
                        .labelsHidden()
                        
                        Divider()
                        
                        Button("TimelineView.clear", systemImage: "trash", role: .destructive) {
                            showClearAlert.toggle()
                        }
                    }
                    .confirmationDialog("TimelineView.confirmTemplate", item: $templateToChange, titleVisibility: .visible) { newValue in
                        Button("confirm", role: .destructive) {
                            viewModel.dayTasks?.removeTasks(in: modelContext)
                            viewModel.dayTasks?.applyTemplate(use: newValue, template: UserTemplates.shared(in: modelContext), in: modelContext)
                            templateToChange = nil
                        }
                        Button("cancel", role: .cancel) {
                            templateToChange = nil
                        }
                    } message: { _ in
                        Text("TimelineView.confirmTemplate.text")
                    }
                    .confirmationDialog("TimelineView.confirmClear", isPresented: $showClearAlert, titleVisibility: .visible) {
                        Button("confirm", role: .destructive) {
                            viewModel.dayTasks?.useTemplate = nil
                            viewModel.dayTasks?.removeTasks(in: modelContext, notification: true)
                        }
                        Button("cancel", role: .cancel) {
                            showClearAlert.toggle()
                        }
                    } message: {
                        Text("TimelineView.confirmClear.text")
                    }
                }
                
                if viewModel.dayState != .today {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.setCurrentDay(to: .today, context: modelContext)
                            viewModel.displayedDays = Day.today.weeks
                        } label: {
                            Image(systemName: "arrowshape.turn.up.backward.badge.clock")
                                .scaleEffect(x: viewModel.dayState == .before ? -1 : 1)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("", systemImage: "plus") {
                        if viewModel.firstAvailableIndexAfterNow != nil {
                            isAddingTask.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            viewModel.loadDayTasks(context: modelContext)
            viewModel.updateScrollId()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.updateScrollId()
                nowFreshId += 1
            }
        }
        .environment(\.currentViewingDay, vm.currentDay)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            totalHeight = newHeight
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
