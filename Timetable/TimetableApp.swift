//
//  TimetableApp.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import SwiftUI
import SwiftData

@main
struct TimetableApp: App {
    @AppStorage("hasRequestedNotification") private var hasRequestedNotification = false
    
    var sharedModelContainer: ModelContainer = {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !hasRequestedNotification {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                            hasRequestedNotification = true
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
