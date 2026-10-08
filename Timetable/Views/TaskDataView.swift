//
//  TaskDataView.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI

func interiorWholeHours(
    from start: TimeOfDay,
    to end: TimeOfDay,
    minGapMinutes: Int = 15
) -> [TimeOfDay] {
    let s = start.minutesSinceMidnight
    let e = end.minutesSinceMidnight
    guard e > s else { return [] }
    var result: [TimeOfDay] = []
    var hour = s / 60 + 1
    while hour * 60 < e {
        let candidate = TimeOfDay(hour: hour % 24, minute: 0)
        let distTop = candidate.minutesSinceMidnight - s
        let distBottom = e - candidate.minutesSinceMidnight
        if distTop >= minGapMinutes && distBottom >= minGapMinutes {
            result.append(candidate)
        }
        hour += 1
    }
    return result
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

struct TimelineTimeLabels: View {
    struct Entry {
        let time: TimeOfDay
        let y: CGFloat
        let priority: Int
        let style: Style
    }
    
    struct FilteredEntry {
        let entry: Entry
        var show: Bool = false
    }

    enum Style {
        case now
        case taskStart
        case prepTime
        case taskEnd
        case hour
    }

    let entries: [Entry]
    var minGap: CGFloat = .bodyFontSize * 1.5

    private var filtered: [FilteredEntry] {
        var result = entries.map { FilteredEntry(entry: $0) }
        guard !result.isEmpty else { return result }

        let sortedIndices = entries.indices.sorted {
            let lhs = entries[$0]
            let rhs = entries[$1]

            if lhs.y != rhs.y {
                return lhs.y < rhs.y
            }
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return $0 < $1
        }

        var visibleIndices: [Int] = []

        for index in sortedIndices {
            let current = entries[index]

            guard let lastVisibleIndex = visibleIndices.last else {
                visibleIndices.append(index)
                continue
            }

            let lastVisible = entries[lastVisibleIndex]
            let distance = current.y - lastVisible.y

            if distance >= minGap {
                visibleIndices.append(index)
            } else if current.priority <= lastVisible.priority {
                visibleIndices[visibleIndices.count - 1] = index
            } else {
                continue
            }
        }

        for index in visibleIndices {
            result[index].show = true
        }

        return result
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear

            ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                if item.show {
                    Text(item.entry.time.description)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(shapeStyle(for: item.entry.style))
                        .offset(y: item.entry.y - .bodyFontSize / 2)
                        .frame(width: 60)
                }
            }
        }
        .frame(width: 60, alignment: .topTrailing)
    }

    private func shapeStyle(for style: Style) -> AnyShapeStyle {
        switch style {
        case .now:
            return AnyShapeStyle(.primary)
        case .taskStart, .taskEnd, .prepTime:
            return AnyShapeStyle(.secondary)
        case .hour:
            return AnyShapeStyle(.tertiary)
        }
    }
}

struct TimelineRowLayout {
    let order: Int
    let height: CGFloat
    let labels: [TimelineTimeLabels.Entry]
}

struct TimelineRowLayoutKey: PreferenceKey {
    static let defaultValue: [TimelineRowLayout] = []
    static func reduce(value: inout [TimelineRowLayout], nextValue: () -> [TimelineRowLayout]) {
        value.append(contentsOf: nextValue())
    }
}

struct TimelineTaskRow: View {
    let task: TaskData
    let dayState: DayState
    let minutesSinceStart: Int
    var showEndTime: Bool = true
    var nowTime: TimeOfDay? = nil
    let layoutOrder: Int

    @CodableStorage("settings") private var settings = Settings()
    private var minutesPerPt: CGFloat {
        settings.minutesPerPt
    }

    init(task: TaskData, dayState: DayState, showEndTime: Bool = true, nowTime: TimeOfDay? = nil, layoutOrder: Int) {
        self.task = task
        self.dayState = dayState
        self.minutesSinceStart = minutesSinceStartOfDay()
        self.showEndTime = showEndTime
        self.nowTime = nowTime
        self.layoutOrder = layoutOrder
    }

    @State private var prepHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0

    @State private var isEditing: Bool = false

    private var prepMinutes: Int { task.preparationTime }
    private var bodyMinutes: Int { task.endTime - task.startTime }
    private var prepMinHeight: CGFloat { max(0, CGFloat(prepMinutes) / minutesPerPt) }
    private var bodyMinHeight: CGFloat { max(0, CGFloat(bodyMinutes) / minutesPerPt) }

    private var prepActual: CGFloat { max(prepMinHeight, prepHeight) }
    private var bodyActual: CGFloat { max(bodyMinHeight, bodyHeight) }
    private var totalActual: CGFloat { prepActual + bodyActual }

    private var hasPrep: Bool {
        prepMinutes > 0
    }

    private var prepH: CGFloat {
        hasPrep ? prepActual : 0
    }

    private var prepStartTime: TimeOfDay {
        let m = task.startTime - prepMinutes
        let wrapped = ((m % 1440) + 1440) % 1440
        return TimeOfDay(hour: wrapped / 60, minute: wrapped % 60)
    }

    private var preparationIsDone: Bool {
        switch dayState {
        case .before:
            return true
        case .after:
            return false
        case .today:
            return minutesSinceStart >= task.startTime
        }
    }

    private var taskIsDone: Bool {
        switch dayState {
        case .before:
            return true
        case .after:
            return false
        case .today:
            return minutesSinceStart >= task.endTime
        }
    }

    private var nowMinutes: Int? {
        guard dayState == .today else { return nil }
        return minutesSinceStartOfDay()
    }

    private func pixelY(forMinute minute: Int) -> CGFloat? {
        let earliest = hasPrep ? (task.startTime - prepMinutes) : task.startTime
        guard minute >= earliest && minute < task.endTime else { return nil }
        if hasPrep && minute < task.startTime {
            let offset = minute - (task.startTime - prepMinutes)
            return prepH * CGFloat(offset) / CGFloat(max(prepMinutes, 1))
        } else {
            let offset = minute - task.startTime
            return prepH + bodyActual * CGFloat(offset) / CGFloat(max(bodyMinutes, 1))
        }
    }

    private var labelEntries: [TimelineTimeLabels.Entry] {
        var rv: [TimelineTimeLabels.Entry] = []
        let bodyH = bodyActual

        if hasPrep {
            for hour in interiorWholeHours(from: prepStartTime, to: task.startTimeOfDay) {
                let offset = hour.minutesSinceMidnight - (task.startTime - prepMinutes)
                let frac = CGFloat(offset) / CGFloat(max(prepMinutes, 1))
                rv.append(.init(time: hour, y: prepH * frac, priority: 4, style: .hour))
            }
        }
        for hour in interiorWholeHours(from: task.startTimeOfDay, to: task.endTimeOfDay) {
            let offset = hour.minutesSinceMidnight - task.startTime
            let frac = CGFloat(offset) / CGFloat(max(bodyMinutes, 1))
            rv.append(.init(time: hour, y: prepH + bodyH * frac, priority: 4, style: .hour))
        }

        if hasPrep {
            rv.append(.init(time: prepStartTime, y: 0, priority: 2, style: .prepTime))
        }

        rv.append(.init(time: task.startTimeOfDay, y: prepH, priority: 1, style: .taskStart))

        if showEndTime {
            rv.append(.init(time: task.endTimeOfDay, y: prepH + bodyH, priority: 3, style: .taskEnd))
        }

        if let now = nowTime, let nowY = pixelY(forMinute: now.minutesSinceMidnight) {
            rv.append(.init(time: now, y: nowY, priority: 0, style: .now))
        }

        return rv
    }

    var body: some View {
        Button {
            isEditing.toggle()
        } label: {
            HStack(alignment: .top, spacing: 0) {
                Color.clear
                    .frame(width: 60)

                if let now = nowMinutes {
                    if let nowY = pixelY(forMinute: now) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(task.theme.fgColor)
                                .frame(height: nowY)
                            Rectangle()
                                .fill(task.theme.bgColorNoOpacity)
                                .frame(height: max(0, totalActual - nowY))
                        }
                        .frame(width: 8)
                    } else if now < (hasPrep ? task.startTime - prepMinutes : task.startTime) {
                        Rectangle()
                            .fill(task.theme.bgColorNoOpacity)
                            .frame(width: 8, height: totalActual)
                    } else {
                        Rectangle()
                            .fill(task.theme.fgColor)
                            .frame(width: 8, height: totalActual)
                    }
                } else {
                    Rectangle()
                        .fill(dayState == .before ? task.theme.fgColor : task.theme.bgColorNoOpacity)
                        .frame(width: 8, height: totalActual)
                }

                VStack(spacing: 0) {
                    if hasPrep {
                        Group {
                            if preparationIsDone {
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: prepMinHeight)
                                    .background(task.theme.bgColorNoOpacity)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { prepHeight = $0 }
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                PreparationContentView(task: task)
                                    .frame(maxWidth: .infinity, minHeight: prepMinHeight)
                                    .background(task.theme.bgColorNoOpacity)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { prepHeight = $0 }
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    TaskBodyContent(task: task, lastingMinutes: bodyMinutes, taskIsDone: taskIsDone)
                        .frame(maxWidth: .infinity, minHeight: bodyMinHeight)
                        .background(task.theme.bgColor)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .preference(key: TimelineRowLayoutKey.self, value: [
            TimelineRowLayout(order: layoutOrder, height: totalActual, labels: labelEntries)
        ])
        .sheet(isPresented: $isEditing) {
            TaskEditingView(task: task, existed: true)
        }
    }
}

struct TimelineGapRow: View {
    @CodableStorage("settings") private var settings = Settings()
    private var minutesPerPt: CGFloat {
        settings.minutesPerPt
    }

    let currentTask: TaskData
    let nextTask: TaskData
    let dayState: DayState
    let layoutOrder: Int

    private var gapStart: TimeOfDay { currentTask.endTimeOfDay }
    private var gapEnd: TimeOfDay {
        let m = nextTask.startTime - nextTask.preparationTime
        let wrapped = ((m % 1440) + 1440) % 1440
        return TimeOfDay(hour: wrapped / 60, minute: wrapped % 60)
    }

    private var gapMinutes: Int {
        nextTask.startTime - currentTask.endTime - nextTask.preparationTime
    }
    private var gapHeight: CGFloat { max(0, CGFloat(gapMinutes) / minutesPerPt) }

    private var nowMinutes: Int? {
        guard dayState == .today else { return nil }
        return minutesSinceStartOfDay()
    }

    private var labelEntries: [TimelineTimeLabels.Entry] {
        var rv: [TimelineTimeLabels.Entry] = []
        let total = max(gapMinutes, 1)
        let gapStartMin = gapStart.minutesSinceMidnight
        let gapEndMin = gapEnd.minutesSinceMidnight

        for hour in interiorWholeHours(from: gapStart, to: gapEnd) {
            let offset = hour.minutesSinceMidnight - gapStartMin
            let frac = CGFloat(offset) / CGFloat(total)
            rv.append(.init(time: hour, y: gapHeight * frac, priority: 4, style: .hour))
        }

        if let now = nowMinutes {
            if now >= gapStartMin && now < gapEndMin {
                let offset = now - gapStartMin
                let frac = CGFloat(offset) / CGFloat(total)
                let nowTime = TimeOfDay(hour: now / 60, minute: now % 60)
                rv.append(.init(time: nowTime, y: gapHeight * frac, priority: 0, style: .now))
            }
        }

        return rv
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 60)

            gapBar

            Spacer()
        }
        .frame(height: gapHeight)
        .preference(key: TimelineRowLayoutKey.self, value: [
            TimelineRowLayout(order: layoutOrder, height: gapHeight, labels: labelEntries)
        ])
    }

    @ViewBuilder
    private var gapBar: some View {
        let total = max(gapMinutes, 1)

        if let now = nowMinutes {
            if now <= gapStart.minutesSinceMidnight {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [currentTask.theme.bgColorNoOpacity, nextTask.theme.bgColorNoOpacity],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8)
            } else if now >= gapEnd.minutesSinceMidnight {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [currentTask.theme.fgColor, nextTask.theme.fgColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8)
            } else {
                let pastFraction = CGFloat(now - gapStart.minutesSinceMidnight) / CGFloat(total)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [currentTask.theme.fgColor, nextTask.theme.fgColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: gapHeight * pastFraction)

                    Rectangle()
                        .fill(nextTask.theme.bgColorNoOpacity)
                        .frame(height: gapHeight * (1 - pastFraction))
                }
                .frame(width: 8)
            }
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [dayState == .before ? currentTask.theme.fgColor : currentTask.theme.bgColorNoOpacity, dayState == .before ? nextTask.theme.fgColor : nextTask.theme.bgColorNoOpacity],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8)
        }
    }
}

struct TaskBodyContent: View {
    let task: TaskData
    let lastingMinutes: Int
    let taskIsDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TaskDataImageView(image: task.icon, theme: task.theme)
                VStack(alignment: .leading) {
                    Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description) (\(lastingMinutes.minutesDescription))")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if taskIsDone {
                        Text("\(task.title) \(Image(systemName: "checkmark.circle.fill"))")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(task.theme.fgColor)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(task.title)
                            .font(.title3)
                            .bold()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
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
        .padding(.horizontal, .horizontalTextPadding)
        .padding(.vertical, .verticalTextPadding + 4)
        .layoutPriority(1)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PreparationContentView: View {
    let task: TaskData

    var body: some View {
        HStack {
            Text("\(Image(systemName: "clock.badge.exclamationmark")) \(Text("PreparationContentView.advance1")) \(task.preparationTime.minutesDescription) \(Text("PreparationContentView.advance2"))")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, .horizontalTextPadding)
        .padding(.vertical, .verticalTextPadding)
    }
}

#Preview {
    TimelineTaskRow(task: .init(title: "Morning Jogging", content: "xxx\nxxx\nxxx\nxxx", theme: .green, startTime: 60 * 6 + 30, endTime: 60 * 8, preparationTime: 10), dayState: .today, layoutOrder: 0)
}
