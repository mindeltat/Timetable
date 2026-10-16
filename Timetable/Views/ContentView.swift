//
//  ContentView.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    enum AppTab: String {
        case timeline
        case template
        case settings
        case unscheduled
    }
    
    @CodableStorage("settings") private var settings = Settings()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentTab: AppTab = .timeline

    var body: some View {
        TabView(selection: $currentTab) {
            Tab("AppTab.unscheduled", systemImage: "checklist", value: .unscheduled) {
                UnscheduledTasksView()
                    .fontDesign(settings.fontDeisgn.font)
            }
            
            Tab("AppTab.timeline", systemImage: "calendar.day.timeline.left", value: .timeline) {
                TimelineView()
                    .fontDesign(settings.fontDeisgn.font)
            }
            
            Tab("AppTab.template", systemImage: "pencil.and.list.clipboard", value: .template) {
                TemplateView()
                    .fontDesign(settings.fontDeisgn.font)
            }
            
            if #available(anyAppleOS 27.0, *) {
                Tab("AppTab.settings", systemImage: "gear", value: .settings, role: .prominent) {
                    SettingsView()
                }
            } else {
                Tab("AppTab.settings", systemImage: "gear", value: .settings) {
                    SettingsView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .preferredColorScheme(settings.appearance.colorScheme)
        .task {
            DayTasks.scheduleNextThreeDaysNotification(template: .shared(in: modelContext), in: modelContext)
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                DayTasks.scheduleNextThreeDaysNotification(template: .shared(in: modelContext), in: modelContext)
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
