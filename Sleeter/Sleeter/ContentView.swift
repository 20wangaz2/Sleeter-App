//
//  ContentView.swift
//  Sleeter
//
//  Created by Andrew Wang on R 7/10/24.
//

import SwiftUI
import EventKit

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().unselectedItemTintColor = UIColor.lightGray
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            Calender()
                .tabItem {
                    Image(systemName: "figure.walk")
                    Text("Calender")
                }

            Workout()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Workout")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Sleeter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Welcome to your workout hub")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct Calender: View {
    @State private var selectedDate = Date()
    @StateObject private var manager = CalendarManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(.white)
                    .padding(.horizontal)

                if manager.isReadAccessGranted {
                    if manager.events.isEmpty {
                        Text("No events for selected date")
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        List {
                            ForEach(manager.events, id: \.eventIdentifier) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .foregroundColor(.white)
                                    Text(event.timeRangeString)
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption)
                                }
                                .listRowBackground(Color.black)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.black)
                    }
                } else if manager.authStatus == .notDetermined {
                    Button("Allow Calendar Access") {
                        manager.requestAccess()
                    }
                    .foregroundColor(.white)
                    .padding(.top, 8)
                } else {
                    Text("Calendar access denied or write-only. Enable full access in Settings.")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                }
            }
            .padding(.bottom)
        }
        .onAppear {
            manager.updateAuthorization()
            manager.loadEvents(for: selectedDate)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            manager.loadEvents(for: newValue)
        }
    }
}

struct Workout: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Workout")
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ContentView()
}

final class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var isReadAccessGranted: Bool = false
    @Published var events: [EKEvent] = []

    func updateAuthorization() {
        if #available(iOS 17.0, *) {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            isReadAccessGranted = (authStatus == .fullAccess)
        } else {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            isReadAccessGranted = (authStatus == .authorized)
        }
    }

    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted {
                        self.loadEvents(for: Date())
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted {
                        self.loadEvents(for: Date())
                    }
                }
            }
        }
    }

    func loadEvents(for date: Date) {
        guard isReadAccessGranted else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let fetched = eventStore.events(matching: predicate).sorted { (a, b) -> Bool in
            if a.isAllDay != b.isAllDay {
                return a.isAllDay && !b.isAllDay
            }
            return a.startDate < b.startDate
        }
        DispatchQueue.main.async {
            self.events = fetched
        }
    }
}

extension EKEvent {
    var timeRangeString: String {
        if isAllDay { return "All-day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}
