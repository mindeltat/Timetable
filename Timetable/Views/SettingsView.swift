//
//  SettingsView.swift
//  Timetable
//
//  Created by Zack on 2026/10/3.
//

import SwiftUI

struct DisplaySettingsView: View {
    @CodableStorage("settings") private var settings = Settings()
    
    var body: some View {
        Form {
            Picker(selection: Binding {
                return settings.appearance
            } set: { newValue in
                settings.appearance = newValue
            }) {
                ForEach(Appearance.allCases, id: \.self) { a in
                    Text(String(localized: .init("DisplaySettingsView.appearance.\(a.rawValue)")))
                }
            } label: {
                Label("DisplaySettingsView.appearance", systemImage: "appwindow.swipe.rectangle")
            }
            Picker(selection: Binding {
                return settings.fontDeisgn
            } set: { newValue in
                settings.fontDeisgn = newValue
            }) {
                ForEach(FontDesign.allCases, id: \.self) { a in
                    Text(String(localized: .init("DisplaySettingsView.font.\(a.rawValue)")))
                }
            } label: {
                Label("DisplaySettingsView.font", systemImage: "character")
            }
            
            Section("SettingsView.displayMode") {
                VStack {
                    Text("\(String(format: "%.1f", settings.minutesPerPt)) \(Text("min/pt").foregroundStyle(.secondary))")
                        .frame(maxWidth: .infinity)
                        .fontDesign(.monospaced)
                    Slider(value: Binding {
                        return settings.minutesPerPt
                    } set: { newValue in
                        settings.minutesPerPt = newValue
                    }, in: 0.2...2, step: 0.2, label: {})
                    HStack {
                        Text("DisplaySettingsView.mode.minimum")
                        Spacer()
                        Text("DisplaySettingsView.mode.maximum")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .formStyle(.grouped)
        .safeSetNavigationTitleDisplayModeToInline()
        .navigationTitle("SettingsView.display")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SettingsView.display")
                    .fontWeight(.semibold)
            }
        }
    }
}

struct DurationPresetEditingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var duration: Int
    
    var body: some View {
        NavigationStack {
            HStack {
                Picker("", selection: Binding<Int> {
                    return duration / 60
                } set: { newValue in
                    if newValue == 24 {
                        duration = 1440
                    } else if newValue == 0 && duration / 60 == 0 {
                        duration = 1
                    } else {
                        duration = newValue * 60 + duration % 60
                    }
                }) {
                    ForEach(0...24, id: \.self) { i in
                        Text("\(i) \(String(localized: .init("hour")))")
                            .tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                Picker("", selection: Binding<Int> {
                    return duration % 60
                } set: { newValue in
                    duration = duration / 60 * 60 + newValue
                }) {
                    if duration == 1440 {
                        Text("0 \(String(localized: .init("minute")))")
                            .tag(0)
                    } else if duration == 0 {
                        ForEach(1...59, id: \.self) { i in
                            Text("\(i) \(String(localized: .init("minute")))")
                                .tag(i)
                        }
                    } else {
                        ForEach(0...59, id: \.self) { i in
                            Text("\(i) \(String(localized: .init("minute")))")
                                .tag(i)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
            }
            .padding(.horizontal)
            .safeSetNavigationTitleDisplayModeToInline()
            .navigationTitle("DurationPresetEditingView.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("DurationPresetEditingView.title")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct PresetsSettingsView: View {
    @CodableStorage("settings") private var settings = Settings()
    @State private var durationEditingIndex: Int? = nil
    
    var body: some View {
        Form {
            Section("PresetsSettingsView.duration") {
                FlowLayout {
                    ForEach(settings.defaultDurations.indices, id: \.self) { i in
                        Button {
                            durationEditingIndex = i
                        } label: {
                            Text("\(settings.defaultDurations[i].minutesDescription) \(Image(systemName: "pencil.line"))")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background {
                                    Capsule().fill(.accentText)
                                }
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, -12)
            }
            .listRowBackground(Color.clear)
            .buttonStyle(.plain)
            
            Section("PresetsSettingsView.notification") {
                Toggle(isOn: Binding {
                    settings.defaultNotification
                } set: { newValue in
                    settings.defaultNotification = newValue
                }) {
                    Label("PresetsSettingsView.notification.notification", systemImage: "bell.fill")
                }
                Toggle(isOn: Binding {
                    settings.defaultNotificationSound != nil
                } set: { newValue in
                    if newValue {
                        settings.defaultNotificationSound = .default
                    } else {
                        settings.defaultNotificationSound = nil
                    }
                }) {
                    Label("PresetsSettingsView.notification.sound", systemImage: "waveform.mid")
                        .foregroundStyle(settings.defaultNotification ? .primary : .secondary)
                }
                .disabled(!settings.defaultNotification)
            }
        }
        .sheet(item: $durationEditingIndex, onDismiss: {
            settings.defaultDurations = settings.defaultDurations.sorted()
        }) { i in
            DurationPresetEditingView(duration: Binding {
                settings.defaultDurations[i]
            } set: { newValue in
                settings.defaultDurations[i] = newValue
            })
            .presentationDetents([.fraction(0.36)])
        }
        .formStyle(.grouped)
        .safeSetNavigationTitleDisplayModeToInline()
        .navigationTitle("SettingsView.presets")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SettingsView.presets")
                    .fontWeight(.semibold)
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                NavigationLink {
                    DisplaySettingsView()
                } label: {
                    Label("SettingsView.display", systemImage: "desktopcomputer")
                }
                NavigationLink {
                    PresetsSettingsView()
                } label: {
                    Label("SettingsView.presets", systemImage: "paintbrush.fill")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("SettingsView.title")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SettingsView.title")
                        .fontWeight(.semibold)
                }
            }
            .safeSetNavigationTitleDisplayModeToInline()
        }
    }
}

#Preview {
    SettingsView()
}
