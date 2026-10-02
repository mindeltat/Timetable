//
//  TemplateView.swift
//  Timetable
//
//  Created by Zack on 2026/9/30.
//

import SwiftUI
import SwiftData

struct TemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TimelineViewModel()
    @State private var isAddingTask: Bool = false

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            ScrollView {
                if viewModel.dayTasks != nil {
                    TimelineStackView(
                        tasks: viewModel.sortedTasks,
                        currentDay: viewModel.currentDay,
                        dayState: viewModel.dayState,
                        nowFreshId: 0
                    )
                    .padding()
                }
            }
            .sheet(isPresented: $isAddingTask) {
                let i: Int? = viewModel.firstAvailableIndexAfter(viewModel.dayTasks?.tasks.last?.endTime ?? 359)
                if let i {
                    TaskEditingView(
                        task: .init(startTime: i * 5, endTime: i * 5 + 1),
                        existed: false
                    )
                }
            }
            .safeAreaBar(edge: .top) {
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(1...7, id: \.self) { i in
                        let day = Day(year: 100000, month: 1, day: i)
                        let accent = i == viewModel.currentDay.day
                        
                        Button {
                            viewModel.setCurrentDay(to: day, context: modelContext)
                        } label: {
                            Text(String(localized: .init(Weekday(rawValue: i)!.shortName)).uppercased())
                                .foregroundStyle(accent ? .accentText : .secondary)
                                .fontWeight(accent ? .bold : .regular)
                                .padding(.horizontal, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(accent ? .accentColor : .clear)
                                }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .padding(.bottom)
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
            .navigationTitle("AppTab.template")
            .safeSetNavigationTitleDisplayModeToInline()
            .toolbar {
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
            viewModel.currentDay = .init(year: 100000, month: 1, day: 1)
            viewModel.loadDayTasks(context: modelContext)
        }
        .environment(viewModel)
        .environment(\.isTemplate, true)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
