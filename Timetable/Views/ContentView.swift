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
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var currentTab: AppTab = .timeline

    var body: some View {
        TabView(selection: $currentTab) {
            Tab("AppTab.timeline", systemImage: "calendar.day.timeline.left", value: .timeline) {
                TimelineView()
            }
            
            Tab("AppTab.template", systemImage: "pencil.and.list.clipboard", value: .template) {
                TemplateView()
            }
            
            Tab("AppTab.settings", systemImage: "gear", value: .settings) {
                EmptyView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}


#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
