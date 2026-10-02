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

func minutesSinceStartOfDay(_ date: Date = Date(), calendar: Calendar = .current) -> Int {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let hour = components.hour ?? 0
    let minute = components.minute ?? 0
    return hour * 60 + minute
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

struct TimelineTaskRow: View {
    let task: TaskData
    let dayState: DayState
    let minutesSinceStart: Int
    var showEndTime: Bool = true
    var nowTime: TimeOfDay? = nil
    
    @CodableStorage("settings") private var settings = Settings()
    private var minutesPerPt: CGFloat {
        settings.minutesPerPt
    }
    
    init(task: TaskData, dayState: DayState, showEndTime: Bool = true, nowTime: TimeOfDay? = nil) {
        self.task = task
        self.dayState = dayState
        self.minutesSinceStart = minutesSinceStartOfDay()
        self.showEndTime = showEndTime
        self.nowTime = nowTime
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

    var body: some View {
        Button {
            isEditing.toggle()
        } label: {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if prepMinutes > 0 && !preparationIsDone {
                        TimelineTimeLabels(
                            topTime: prepStartTime,
                            bottomTime: task.startTimeOfDay,
                            height: prepActual,
                            showTop: true,
                            showBottom: false,
                            nowTime: nowTime
                        )
                    }
                    TimelineTimeLabels(
                        topTime: task.startTimeOfDay,
                        bottomTime: task.endTimeOfDay,
                        height: bodyActual,
                        showTop: true,
                        showBottom: showEndTime,
                        nowTime: nowTime
                    )
                }
                .frame(width: 60)
                
                if let now = nowMinutes {
                    if now <= task.startTime - task.preparationTime {
                        Rectangle()
                            .fill(task.theme.bgColorNoOpacity)
                            .frame(width: 8, height: totalActual)
                    } else if now >= task.endTime {
                        Rectangle()
                            .fill(task.theme.fgColor)
                            .frame(width: 8, height: totalActual)
                    } else {
                        let pastFraction = CGFloat(now - task.startTime + task.preparationTime) / CGFloat(task.preparationTime + bodyMinutes)
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(task.theme.fgColor)
                                .frame(height: totalActual * pastFraction)
                            
                            Rectangle()
                                .fill(task.theme.bgColorNoOpacity)
                                .frame(height: totalActual * (1 - pastFraction))
                        }
                        .frame(width: 8)
                    }
                } else {
                    Rectangle()
                        .fill(dayState == .before ? task.theme.fgColor : task.theme.bgColorNoOpacity)
                        .frame(width: 8, height: totalActual)
                }
                
                VStack(spacing: 0) {
                    if prepMinutes > 0 && !preparationIsDone {
                        PreparationContentView(task: task)
                            .frame(maxWidth: .infinity, minHeight: prepMinHeight)
                            .background(task.theme.bgColorNoOpacity)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { prepHeight = $0 }
                    }
                    
                    TaskBodyContent(task: task, lastingMinutes: bodyMinutes, taskIsDone: taskIsDone)
                        .frame(maxWidth: .infinity, minHeight: bodyMinHeight)
                        .background(task.theme.bgColor)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
                }
            }
        }
        .buttonStyle(.plain)
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

    var body: some View {
        HStack(spacing: 0) {
            TimelineTimeLabels(
                topTime: gapStart,
                bottomTime: gapEnd,
                height: gapHeight,
                showTop: false,
                showBottom: false,
                nowTime: nowMinutes.map {
                    TimeOfDay(hour: $0 / 60, minute: $0 % 60)
                }
            )

            gapBar

            Spacer()
        }
        .frame(height: gapHeight)
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

struct TimelineTimeLabels: View {
    @CodableStorage("settings") private var settings = Settings()
    private var minutesPerPt: CGFloat {
        settings.minutesPerPt
    }

    let topTime: TimeOfDay
    let bottomTime: TimeOfDay
    let height: CGFloat
    var showTop: Bool = true
    var showBottom: Bool = true
    var nowTime: TimeOfDay? = nil

    private let minLabelPixelGap: CGFloat = 22

    private func pixelDistance(from a: TimeOfDay, to b: TimeOfDay) -> CGFloat {
        CGFloat(abs(a.minutesSinceMidnight - b.minutesSinceMidnight)) / minutesPerPt
    }

    private var interiorHours: [TimeOfDay] {
        let hours = interiorWholeHours(from: topTime, to: bottomTime, minGapMinutes: 15)
        guard let nowTime else { return hours }
        return hours.filter { pixelDistance(from: $0, to: nowTime) >= minLabelPixelGap }
    }
    
    private var topConflictsWithNow: Bool {
        guard let now = nowTime, showTop else { return false }
        return pixelDistance(from: now, to: topTime) < minLabelPixelGap
    }

    private var bottomConflictsWithNow: Bool {
        guard let now = nowTime, showBottom else { return false }
        return pixelDistance(from: now, to: bottomTime) < minLabelPixelGap
    }

    private var nowInsideRange: Bool {
        guard let now = nowTime else { return false }
        return now.minutesSinceMidnight >= topTime.minutesSinceMidnight
            && now.minutesSinceMidnight < bottomTime.minutesSinceMidnight
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 0) {
                if showTop && !topConflictsWithNow { timeText(topTime).offset(y: -.bodyFontSize / 2) }
                Spacer(minLength: 0)
                if showBottom && !bottomConflictsWithNow { timeText(bottomTime).offset(y: .bodyFontSize / 2) }
            }

            ForEach(interiorHours, id: \.minutesSinceMidnight) { hour in
                let total = bottomTime.minutesSinceMidnight - topTime.minutesSinceMidnight
                let offset = hour.minutesSinceMidnight - topTime.minutesSinceMidnight
                let fraction = CGFloat(offset) / CGFloat(max(total, 1))
                timeText(hour)
                    .foregroundStyle(.tertiary)
                    .offset(y: fraction * height - 10)
            }

            if let nowTime, nowInsideRange {
                let total = bottomTime.minutesSinceMidnight - topTime.minutesSinceMidnight
                let offset = nowTime.minutesSinceMidnight - topTime.minutesSinceMidnight
                let fraction = CGFloat(offset) / CGFloat(max(total, 1))
                Text(nowTime.description)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .offset(y: fraction * height - 10)
            }
        }
        .frame(width: 60, height: height)
    }

    private func timeText(_ time: TimeOfDay) -> some View {
        Text(time.description)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
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
                    if taskIsDone {
                        Text("\(task.title) \(Image(systemName: "checkmark.circle.fill"))")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(task.theme.fgColor)
                    } else {
                        Text(task.title)
                            .font(.title3)
                            .bold()
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
                        .frame(height: 6)
                }
                if task.content != "" {
                    Text(task.content)
                }
            }
        }
        .padding(.horizontal, .horizontalTextPadding)
        .padding(.vertical, .verticalTextPadding)
    }
}

struct PreparationContentView: View {
    let task: TaskData

    var body: some View {
        HStack {
            Text("\(Image(systemName: "clock.badge.exclamationmark")) \(Text("PreparationContentView.advance1")) \(task.preparationTime.minutesDescription) \(Text("PreparationContentView.advance2"))")
        }
        .padding(.horizontal, .horizontalTextPadding)
        .padding(.vertical, .verticalTextPadding)
    }
}

#Preview {
    TimelineTaskRow(task: .init(title: "Morning Jogging", content: "xxx", theme: .green, startTime: 60 * 6 + 30, endTime: 60 * 8, preparationTime: 10), dayState: .today)
        .padding()
}
