//
//  TimelineView.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData

enum DayState {
    case before
    case after
    case today
}

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
                    nowTime: nowTime
                )
                .id(task.id)
                .environment(\.currentTaskIndex, index)

                if index < tasks.count - 1 {
                    TimelineGapRow(
                        currentTask: task,
                        nextTask: tasks[index + 1],
                        dayState: dayState
                    )
                    .id("gap-\(task.id)")
                }
            }
        }
        .scrollTargetLayout()
    }
}

@Observable
final class TimelineViewModel {
    static let allIndexes: [Int] = {
        var rv: [Int] = []
        for i in 0..<288 {
            rv.append(i)
        }
        return rv
    }()
    
    static let allHoursAndMinutes: [Int: [Int]] = {
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

        if scheduled.isEmpty {
            return TimelineViewModel.allIndexes
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

    func availableDuration(after time: Int, exclude: Int? = nil) -> Int {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
        for r in scheduled {
            if time < r.lowerBound {
                return r.lowerBound - time
            }
        }
        
        return 1440 - time
    }
    
    func availableDuration(before time: Int, exclude: Int? = nil) -> Int {
        var scheduled: [ClosedRange<Int>]
        if let exclude {
            scheduled = self.scheduled
            scheduled.remove(at: exclude)
        } else {
            scheduled = self.scheduled
        }
        
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
        
        if scheduled.isEmpty {
            return TimelineViewModel.allHoursAndMinutes
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
    
    func availableHoursAndMinutes(after: Int, exclude: Int? = nil) -> [Int: [Int]] {
        let max = availableDuration(after: after, exclude: exclude)
        
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimelineViewModel()
    @State private var isAddingTask: Bool = false
    @State private var nowFreshId: Int = 0
    
    @State var templateToChange: Weekday? = nil
    @State var showClearAlert: Bool = false

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
            .sheet(isPresented: $isAddingTask) {
                let i: Int? = vm.dayState == .today ? viewModel.firstAvailableIndexAfterNow : viewModel.firstAvailableIndexAfter(viewModel.dayTasks?.tasks.last?.endTime ?? 359)
                if let i {
                    TaskEditingView(
                        task: .init(startTime: i * 5, endTime: i * 5 + 1),
                        existed: false
                    )
                }
            }
            .scrollPosition(id: $vm.scrollId, anchor: .center)
            .safeAreaBar(edge: .top) {
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
                .padding(.bottom)
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
            .navigationTitle(viewModel.currentDay.localizedDescription)
            .safeSetNavigationTitleDisplayModeToInline()
            .toolbar {
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
                            viewModel.dayTasks?.applyTemplate(use: newValue, template: UserTemplates.shared(in: modelContext))
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
                            viewModel.dayTasks?.removeTasks(in: modelContext)
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
        .environment(viewModel)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
