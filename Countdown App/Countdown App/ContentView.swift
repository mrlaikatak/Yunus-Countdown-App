//
//  ContentView.swift
//  Countdown App
//
//  Created by Yunus ACAR on 16.06.2025.
//

import SwiftUI
import Combine
import UIKit
import UserNotifications

struct CountdownEvent: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var date: Date
}

struct ContentView: View {
    @State private var events: [CountdownEvent] = []
    @State private var selectedEventIndex: Int = 0
    @State private var now: Date = Date()
    @State private var showingSheet = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.36, green: 0.51, blue: 0.99),
                    Color(red: 0.93, green: 0.71, blue: 1.00),
                    Color(red: 0.46, green: 0.91, blue: 0.85)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // Selected event title and countdown or welcome screen
                if events.isEmpty {
                    VStack(spacing: 24) {
                        Text("Welcome!")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Color.white, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Text("Please add an event.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingSheet = true
                        } label: {
                            Text("Add Event")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 18)
                                .padding(.horizontal, 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.purple, Color.blue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.purple.opacity(0.8), radius: 10, x: 0, y: 5)
                                )
                        }
                    }
                    .padding(.top, 44)
                } else {
                    Text(events[selectedEventIndex].name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.white, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 6)
                        .padding(.top, 44)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                    CountdownGlassView(targetDate: events[selectedEventIndex].date, now: now)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                Spacer(minLength: 0)

                // Event list and add button, only shown if events exist
                if !events.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Events")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showingSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.blue.opacity(0.9), radius: 5, x: 0, y: 4)
                            }
                            .padding(.trailing, 4)
                        }.padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(events.enumerated()), id: \.1.id) { idx, event in
                                    HStack(spacing: 8) {
                                        EventRow(event: event, isSelected: idx == selectedEventIndex)
                                            .onTapGesture {
                                                selectedEventIndex = idx
                                            }
                                            .animation(.easeInOut, value: selectedEventIndex)
                                        
                                        Button {
                                            removeNotification(for: events[idx])
                                            withAnimation {
                                                events.remove(at: idx)
                                                if events.isEmpty {
                                                    selectedEventIndex = 0
                                                } else if selectedEventIndex >= idx {
                                                    selectedEventIndex = max(0, selectedEventIndex - 1)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(Color.red)
                                                .padding(8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(Color.red.opacity(0.15))
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .shadow(color: Color.red.opacity(0.35), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                        }
                    }
                    .background(Color.white.opacity(0.07).blur(radius: 0.6))
                    .cornerRadius(26)
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(timer) { _ in
            now = Date()
        }
        .sheet(isPresented: $showingSheet, onDismiss: {
            if let lastEvent = events.last {
                scheduleNotification(for: lastEvent)
            }
        }) {
            AddEventSheet(events: $events, selectedEventIndex: $selectedEventIndex)
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                // Permission request result can be handled here
            }
        }
    }
    
    private func scheduleNotification(for event: CountdownEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder"
        content.body = "\(event.name) event has started!"
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func removeNotification(for event: CountdownEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
    }
}

// MARK: - Countdown Glassmorphism View

private struct CountdownGlassView: View {
    let targetDate: Date
    let now: Date
    
    private var timeLeft: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = max(targetDate.timeIntervalSince(now), 0)
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        return (days, hours, minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 18) {
            TimeUnitView(value: timeLeft.days, label: "DAYS")
            TimeUnitView(value: timeLeft.hours, label: "HRS")
            TimeUnitView(value: timeLeft.minutes, label: "MIN")
            TimeUnitView(value: timeLeft.seconds, label: "SEC")
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            BlurView(style: .systemThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.28), Color.purple.opacity(0.10)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
    }
}

private struct TimeUnitView: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "%02d", value))
                .font(.custom("SF Pro Rounded", size: 48, relativeTo: .largeTitle).weight(.heavy))
                .foregroundStyle(Color.primary)
                .shadow(color: Color.primary.opacity(0.08), radius: 4, x: 0, y: 1)
            Text(label)
                .font(.custom("SF Pro Rounded", size: 14, relativeTo: .caption).weight(.medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .shadow(color: Color.white.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - BlurView

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

private struct EventRow: View {
    let event: CountdownEvent
    let isSelected: Bool
    var body: some View {
        VStack(spacing: 6) {
            Text(event.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.primary))
                .lineLimit(1)
            Text(event.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            isSelected ?
            AnyShapeStyle(LinearGradient(
                colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )) :
            AnyShapeStyle(Color.white.opacity(0.15))
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? AnyShapeStyle(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.clear), lineWidth: 2.5)
        )
        .shadow(color: isSelected ? Color.purple.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        .frame(minWidth: 110)
    }
}

private struct AddEventSheet: View {
    @Binding var events: [CountdownEvent]
    @Binding var selectedEventIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date = Date().addingTimeInterval(3600)
    var body: some View {
        VStack(spacing: 32) {
            Text("Add New Event")
                .font(.title2.bold())
                .padding(.top, 20)
            TextField("Event Name", text: $name)
                .padding(18)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .font(.body)
                .padding(.horizontal, 20)
            DatePicker("Event Date", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
                .font(.body)
            Button("Add Event") {
                guard !name.isEmpty else { return }
                let newEvent = CountdownEvent(name: name, date: date)
                events.append(newEvent)
                selectedEventIndex = events.count - 1
                dismiss()
            }
            .font(.headline)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.purple.opacity(0.7), radius: 8, x: 0, y: 4)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground).opacity(0.96),
                    Color(.secondarySystemBackground).opacity(0.87)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

