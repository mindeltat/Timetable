//
//  TaskEditingView.swift
//  Timetable
//
//  Created by Zack on 2026/9/30.
//

import SwiftUI
import SwiftData
import Observation

struct TaskEditingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimelineViewModel.self) private var vm
    
    let task: TaskData
    @State var copiedTask: TaskData
    let existed: Bool
    
    init(task: TaskData, existed: Bool = true) {
        self.task = task
        self.copiedTask = TaskData(copying: task)
        self.existed = existed
    }
    
    var body: some View {
        NavigationStack {
            TaskDataEditingView(task: copiedTask) {
                vm.dayTasks!.tasks.removeAll { $0.id == task.id }
                vm.dayTasks!.useTemplate = nil
                modelContext.delete(task)
                dismiss()
            } onSave: {
                task.copy(copiedTask)
                if !existed {
                    modelContext.insert(task)
                    vm.dayTasks!.tasks.append(task)
                }
                vm.dayTasks!.useTemplate = nil
                try? modelContext.save()
                dismiss()
            }
        }
    }
}

struct TaskDataEditingTopBarView: View {
    @Bindable var task: TaskData
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(task.theme.fgColor)
                .frame(width: 8)
            HStack {
                TaskDataImageView(image: task.icon, theme: task.theme)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description) (\((task.endTime - task.startTime).minutesDescription))")
                        .foregroundStyle(.secondary)
                    TextField("", text: $task.title)
                        .font(.title3)
                        .bold()
                    Rectangle()
                        .fill(task.theme.fgColor)
                        .frame(height: 2)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .background {
                Rectangle()
                    .fill(task.theme.bgColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal)
        .padding(.horizontal)
        .padding(.bottom)
        .scrollContentBackground(.hidden)
    }
}

struct TaskDataEditingThemeView: View {
    @CodableStorage("settings") private var settings = Settings()
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskData
    @State var scrollId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(taskIconCategoryKeys, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 0) {
                            Label(String(localized: .init(key)), systemImage: taskIconCategoryRepresentativeSymbols[key]!)
                                .font(.title2)
                                .fontWeight(scrollId == key ? .bold : .regular)
                                .foregroundStyle(scrollId == key ? .primary : .secondary)
                            Divider()
                                .padding(.top, 6)
                                .padding(.bottom, 12)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 48), spacing: 8)], spacing: 8) {
                                ForEach(key == "symbols.recents" ? settings.recentSymbols : taskIconSymbolsByCategory[key]!, id: \.self) { symbol in
                                    let selected = checkSelected(symbol)
                                    Button {
                                        task.icon = .system(name: symbol)
                                        settings.recentSymbols.removeAll { $0 == symbol }
                                        settings.recentSymbols.insert(symbol, at: 0)
                                        if settings.recentSymbols.count > 50 {
                                            settings.recentSymbols.removeLast()
                                        }
                                    } label: {
                                        Image(systemName: symbol)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                            .padding(.all, 12)
                                            .foregroundStyle(selected ? task.theme.bgColorNoOpacity : .primary)
                                            .background {
                                                if selected {
                                                    Circle()
                                                        .fill(task.theme.fgColor)
                                                } else {
                                                    Circle()
                                                        .fill(.quinary)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding()
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollId, anchor: .top)
            .onAppear {
                scrollId = "symbols.recents"
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .safeAreaBar(edge: .top) {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Theme.allCases, id: \.rawValue) { theme in
                            Button {
                                task.theme = theme
                            } label: {
                                Circle()
                                    .fill(theme.fgColor)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if task.theme == theme {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.bgColorNoOpacity)
                                                .bold()
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.all, 10)
                }
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect()
                }
                .padding(.horizontal)
            }
            .safeAreaBar(edge: .bottom) {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(taskIconCategoryKeys, id: \.self) { key in
                            Button {
                                scrollId = key
                            } label: {
                                Image(systemName: taskIconCategoryRepresentativeSymbols[key]!)
                                    .imageScale(.large)
                                    .padding(.horizontal, 12)
                                    .frame(height: 40)
                                    .contentShape(Capsule())
                                    .foregroundStyle(scrollId == key ? task.theme.bgColorNoOpacity : .primary)
                                    .background {
                                        if scrollId == key {
                                            Capsule()
                                                .fill(task.theme.fgColor)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.all, 8)
                }
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect()
                }
                .clipShape(Capsule())
                .padding(.horizontal)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .navigationTitle("TaskDataEditingThemeView.title")
            .safeSetNavigationTitleDisplayModeToInline()
        }
    }
    
    private func checkSelected(_ symbol: String) -> Bool {
        switch task.icon {
        case .system(let name):
            return name == symbol
        case .file(let path):
            return false
        }
    }
}

struct TaskDataEditingTimeView: View {
    @CodableStorage("settings") private var settings = Settings()
    
    @Environment(TimelineViewModel.self) private var vm
    @Environment(\.currentTaskIndex) private var index: Int?
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskData
    
    @State private var customize: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Picker("", selection: Binding<Int> {
                    return task.startTime
                } set: { newValue in
                    let maxD = vm.availableDuration(after: newValue, exclude: index)
                    let maxPT = vm.availableDuration(before: newValue, exclude: index)
                    if maxD < task.durationWithoutPreparation {
                        task.endTime = newValue + maxD
                    } else {
                        task.endTime = newValue + task.durationWithoutPreparation
                    }
                    if maxPT < task.preparationTime {
                        task.preparationTime = maxPT
                    }
                    task.startTime = newValue
                }) {
                    ForEach(vm.availableIndexes(exclude: index), id: \.self) { i in
                        if i * 5 == task.startTime {
                            Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description)")
                                .bold()
                                .tag(i * 5)
                        } else {
                            Text(TimeOfDay(hour: i * 5 / 60, minute: i * 5 % 60).description)
                                .tag(i * 5)
                        }
                        
                        if i * 5 < task.startTime && (i + 1) * 5 > task.startTime {
                            Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description)")
                                .bold()
                                .tag(task.startTime)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                Spacer()
                
                let maxD = vm.availableDuration(after: task.startTime, exclude: index)
                HStack(spacing: 0) {
                    ForEach(0...4, id: \.self) { i in
                        let value = settings.defaultDurations[i]
                        let selected = value == task.durationWithoutPreparation
                        
                        Button {
                            task.endTime = task.startTime + value
                        } label: {
                            Text(value.minutesShortDescription)
                                .foregroundStyle(selected ? task.theme.bgColorNoOpacity : .secondary)
                                .fontWeight(selected ? .bold : .regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical)
                                .background {
                                    if selected {
                                        Capsule()
                                            .fill(task.theme.fgColor)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(value > maxD)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.all, 8)
                .background {
                    Capsule()
                        .fill(.quinary)
                }
                HStack {
                    let maxSelected = task.durationWithoutPreparation == maxD
                    
                    HStack(spacing: 0) {
                        let value = settings.defaultDurations[5]
                        let selected = value == task.durationWithoutPreparation
                        Button {
                            task.endTime = task.startTime + value
                        } label: {
                            Text(value.minutesShortDescription)
                                .foregroundStyle(selected ? task.theme.bgColorNoOpacity : .secondary)
                                .fontWeight(selected ? .bold : .regular)
                                .padding()
                                .background {
                                    if selected {
                                        Capsule()
                                            .fill(task.theme.fgColor)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(value > maxD)
                        
                        Button {
                            task.endTime = task.startTime + maxD
                        } label: {
                            Text("TaskDataEditingTimeView.max")
                                .foregroundStyle(maxSelected ? task.theme.bgColorNoOpacity : .secondary)
                                .fontWeight(maxSelected ? .bold : .regular)
                                .padding()
                                .background {
                                    if maxSelected {
                                        Capsule()
                                            .fill(task.theme.fgColor)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.all, 8)
                    .background {
                        Capsule()
                            .fill(.quinary)
                    }
                    
                    Spacer()
                    
                    let customizeSelected = !maxSelected && !settings.defaultDurations.contains(task.durationWithoutPreparation)
                    
                    Button {
                        customize.toggle()
                    } label: {
                        Text(customizeSelected ? "\(task.durationWithoutPreparation.minutesShortDescription)" : String(localized: .init("TaskDataEditingTimeView.customize")))
                            .bold()
                            .padding()
                            .background {
                                if customizeSelected {
                                    Capsule()
                                        .fill(task.theme.fgColor)
                                }
                            }
                            .foregroundStyle(customizeSelected ? task.theme.bgColorNoOpacity : .primary)
                            .padding(.all, 8)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background {
                        Capsule()
                            .fill(.quinary)
                    }
                }
            }
            .padding()
            .navigationTitle("TaskDataEditingTimeView.title")
            .safeSetNavigationTitleDisplayModeToInline()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $customize) {
                TaskDataEditingTimeCustomizeView(task: task)
                    .presentationDetents([.medium])
            }
        }
    }
}

struct TaskDataEditingTimeCustomizeView: View {
    @Environment(TimelineViewModel.self) private var vm
    @Environment(\.currentTaskIndex) private var index: Int?
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskData
    
    @State var hoursAndMinutes: [Int: [Int]] = [:]
    @State var endHoursAndMinutes: [Int: [Int]] = [:]
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("", selection: Binding<Int> {
                    return task.startTime / 60
                } set: { newValue in
                    if hoursAndMinutes[newValue]!.contains(task.startTime % 60) {
                        task.startTime = newValue * 60 + task.startTime % 60
                    } else {
                        task.startTime = newValue * 60 + hoursAndMinutes[newValue]!.first!
                    }
                    
                    if task.endTime <= task.startTime {
                        task.endTime = task.startTime + 1
                    }
                    
                    let maxD = vm.availableDuration(after: task.startTime)
                    if task.durationWithoutPreparation > maxD {
                        task.endTime = task.startTime + maxD
                    }
                    
                    endHoursAndMinutes = vm.availableHoursAndMinutes(after: task.startTime, exclude: index)
                }) {
                    ForEach(hoursAndMinutes.keys.sorted(), id: \.self) { i in
                        Text(String(format: "%02d", i))
                            .tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                Text(":")
                    .font(.title2)
                    .bold()
                Picker("", selection: Binding<Int> {
                    return task.startTime % 60
                } set: { newValue in
                    task.startTime = task.startTime / 60 * 60 + newValue
                    
                    if task.endTime <= task.startTime {
                        task.endTime = task.startTime + 1
                    }
                    
                    let maxD = vm.availableDuration(after: task.startTime)
                    if task.durationWithoutPreparation > maxD {
                        task.endTime = task.startTime + maxD
                    }
                    
                    endHoursAndMinutes = vm.availableHoursAndMinutes(after: task.startTime, exclude: index)
                }) {
                    if let v = hoursAndMinutes[task.startTime / 60] {
                        ForEach(v, id: \.self) { i in
                            Text(String(format: "%02d", i))
                                .tag(i)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                
                Image(systemName: "arrow.right")
                    .bold()
                    .padding()
                
                Picker("", selection: Binding<Int> {
                    return task.endTime / 60
                } set: { newValue in
                    if endHoursAndMinutes[newValue]?.contains(task.endTime % 60) ?? false {
                        task.endTime = newValue * 60 + task.endTime % 60
                    } else {
                        task.endTime = newValue * 60 + (hoursAndMinutes[newValue]?.first ?? 0)
                    }
                }) {
                    ForEach(endHoursAndMinutes.keys.sorted(), id: \.self) { i in
                        Text(String(format: "%02d", i))
                            .tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                Text(":")
                    .font(.title2)
                    .bold()
                Picker("", selection: Binding<Int> {
                    return task.endTime % 60
                } set: { newValue in
                    task.endTime = task.endTime / 60 * 60 + newValue
                }) {
                    if let v = endHoursAndMinutes[task.endTime / 60] {
                        ForEach(v, id: \.self) { i in
                            Text(String(format: "%02d", i))
                                .tag(i)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
            }
            .padding()
            .navigationTitle("TaskDataEditingTimeCustomizeView.title")
            .safeSetNavigationTitleDisplayModeToInline()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                hoursAndMinutes = vm.availableHoursAndMinutes(exclude: index)
                endHoursAndMinutes = vm.availableHoursAndMinutes(after: task.startTime, exclude: index)
            }
        }
    }
}

struct TaskDataEditingPreparationView: View {
    @Environment(TimelineViewModel.self) private var vm
    @Environment(\.currentTaskIndex) private var index: Int?
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskData
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Picker("", selection: $task.preparationTime) {
                        Text("TaskDataEditingView.noPreparation")
                            .tag(0)
                        
                        let availableTime = vm.availableDuration(before: task.startTime, exclude: index)
                        if availableTime != 0 {
                            ForEach(1...availableTime, id: \.self) { i in
                                Text(i.minutesDescription)
                                    .tag(i)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("TaskDataEditingPreparationView.title")
            .safeSetNavigationTitleDisplayModeToInline()
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
            .fontDesign(.rounded)
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

struct TagEditingView: View {
    @Binding var tag: String
    let theme: Theme
    
    let onDeletion: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $tag)
            Button {
                onDeletion()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .foregroundStyle(theme.fgColor)
        .fontWeight(.semibold)
        .fontDesign(.rounded)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(theme.bgColorNoOpacity)
        }
        .lineLimit(1)
    }
}

struct TaskDataEditingTagsView: View {
    @Bindable var task: TaskData
    
    var body: some View {
        FlowLayout {
            let _ = print(task.tags)
            ForEach(Array($task.tags.enumerated()), id: \.offset) { index, tag in
                TagEditingView(tag: tag, theme: task.theme) {
                    task.tags.remove(at: index)
                }
            }
            
            Button {
                task.tags.append(String(localized: .init("TaskDataEditingTagsView.newTag")))
            } label: {
                HStack(spacing: 4) {
                    Text("TaskDataEditingTagsView.new")
                    Image(systemName: "plus")
                }
                .bold()
                .foregroundStyle(task.theme.bgColorNoOpacity)
                .contentShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(task.theme.fgColor)
            }
            .lineLimit(1)
        }
    }
}

struct TaskDataEditingView: View {
    @Environment(\.dismiss) private var dismiss
    
    enum SecondaryMenu: String, Identifiable {
        case theme
        case time
        case preparation
        
        var id: String { rawValue }
    }
    
    @Bindable var task: TaskData
    let onDelete: () -> Void
    let onSave: () -> Void
    
    @State private var secondaryMenu: SecondaryMenu? = nil
    
    var body: some View {
        Form {
            Section {
                Button {
                    secondaryMenu = .time
                } label: {
                    HStack {
                        Image(systemName: "clock.fill")
                            .imageScale(.large)
                            .foregroundStyle(task.theme.fgColor)
                        Text("\(task.startTimeOfDay.description)-\(task.endTimeOfDay.description)")
                        Spacer()
                        Text("\((task.endTime - task.startTime).minutesDescription)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    secondaryMenu = .preparation
                } label: {
                    HStack {
                        Image(systemName: "car.rear.fill")
                            .imageScale(.large)
                            .foregroundStyle(task.theme.fgColor)
                        if task.preparationTime == 0 {
                            Text("TaskDataEditingView.noPreparation")
                        } else {
                            Text("\(task.preparationTime.minutesDescription) \(Text("TaskDataEditingView.inAdvance"))")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Section("TaskDataEditingView.tags") {
                TaskDataEditingTagsView(task: task)
            }
            .buttonStyle(.plain)
            
            Section("TaskDataEditingView.details") {
                TextField("TaskDataEditingView.detailsTextField", text: $task.content, axis: .vertical)
                    .lineLimit(nil)
            }
            
            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("\(Image(systemName: "trash.fill")) \(Text("TaskEditingView.delete"))")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .bold()
                }
            }
        }
        .sheet(item: $secondaryMenu) { menu in
            switch menu {
            case .theme:
                TaskDataEditingThemeView(task: task)
                    .presentationDetents([.medium, .large])
            case .time:
                TaskDataEditingTimeView(task: task)
                    .presentationDetents([.medium])
            case .preparation:
                TaskDataEditingPreparationView(task: task)
                    .presentationDetents([.medium])
            }
        }
        .safeAreaBar(edge: .top) {
            TaskDataEditingTopBarView(task: task)
                .background(.bar)
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("", systemImage: "xmark") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("", systemImage: "paintpalette") {
                    secondaryMenu = .theme
                }
            }
        }
        .safeSetNavigationTitleDisplayModeToInline()
        .safeAreaBar(edge: .bottom) {
            Button {
                onSave()
            } label: {
                Text("TaskEditingView.save")
                    .foregroundStyle(task.theme.bgColorNoOpacity)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(task.theme.fgColor)
            .controlSize(.extraLarge)
            .padding()
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }
}

#Preview {
    let container = PreviewContainer.shared
    let vm = TimelineViewModel()
    vm.loadDayTasks(context: container.mainContext)
    let task: TaskData = .init(title: "Morning Jogging", content: "xxx", theme: .green, startTime: 60 * 4 + 30, endTime: 60 * 5, preparationTime: 10, tags: ["Morning", "Outdoor"])
    return TaskEditingView(task: task)
        .environment(vm)
}
