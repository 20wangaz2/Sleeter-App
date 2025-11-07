//
//  ContentView.swift
//  Sleeter
//
//  Created by Andrew Wang on R 7/10/24.
//

import SwiftUI
import EventKit

final class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var isReadAccessGranted: Bool = false
    @Published var events: [EKEvent] = []

    private var canWriteEvents: Bool {
        if #available(iOS 17.0, *) {
            return authStatus == .fullAccess || authStatus == .writeOnly
        } else {
            return authStatus == .authorized
        }
    }

    func updateAuthorization() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            isReadAccessGranted = (authStatus == .fullAccess)
        } else {
            isReadAccessGranted = (authStatus == .authorized)
        }
    }

    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted { self.loadEvents(for: Date()) }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted { self.loadEvents(for: Date()) }
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
        DispatchQueue.main.async { self.events = fetched }
    }

    func ensureAccessAndScheduleWater(forLiters liters: Double, on date: Date, completion: ((Int) -> Void)? = nil) {
        updateAuthorization()
        if canWriteEvents {
            let count = scheduleWaterReminders(liters: liters, on: date)
            loadEvents(for: date)
            completion?(count)
            return
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted {
                        let count = self.scheduleWaterReminders(liters: liters, on: date)
                        self.loadEvents(for: date)
                        completion?(count)
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    self.updateAuthorization()
                    if granted {
                        let count = self.scheduleWaterReminders(liters: liters, on: date)
                        self.loadEvents(for: date)
                        completion?(count)
                    }
                }
            }
        }
    }

    func scheduleWaterReminders(liters: Double, on date: Date, startHour: Int = 9, endHour: Int = 21) -> Int {
        guard canWriteEvents else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Remove any existing Sleeter water events for today to avoid duplicates
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let todaysEvents = eventStore.events(matching: predicate)
        for e in todaysEvents where e.title.hasPrefix("Sleeter: Drink") {
            do { try eventStore.remove(e, span: .thisEvent, commit: false) } catch { /* ignore */ }
        }
        try? eventStore.commit()

        let hoursCount = max(endHour - startHour, 0)
        guard hoursCount > 0 else { return 0 }
        let totalML = max(liters, 0) * 1000.0
        let perSlotML = totalML / Double(hoursCount)
        let roundedPerSlot = (perSlotML / 50.0).rounded() * 50.0 // round to nearest 50ml

        var created = 0
        for i in 0..<hoursCount {
            let hour = startHour + i
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            components.second = 0
            guard let start = calendar.date(from: components) else { continue }
            let end = calendar.date(byAdding: .minute, value: 10, to: start)!

            let event = EKEvent(eventStore: eventStore)
            if let defaultCal = eventStore.defaultCalendarForNewEvents {
                event.calendar = defaultCal
            } else {
                event.calendar = eventStore.calendars(for: .event).first
            }
            event.title = "Sleeter: Drink \(Int(roundedPerSlot)) ml"
            event.startDate = start
            event.endDate = end
            event.notes = "Automated water schedule from Sleeter"
            event.availability = .free

            do {
                try eventStore.save(event, span: .thisEvent, commit: false)
                created += 1
            } catch {
                // continue
            }
        }

        try? eventStore.commit()
        return created
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

final class FormatterCache {
    static let shared = FormatterCache()
    let dayFormatter: DateFormatter
    private init() {
        dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .full
    }
}

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
                    Image(systemName: "calendar")
                    Text("Calender")
                }

            Workout()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Workout")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    @AppStorage("waterGoalLiters") private var waterGoalLiters: Double = 2.0
    @AppStorage("sleepGoalHours") private var sleepGoalHours: Double = 8.0
    @StateObject private var manager = CalendarManager()
    @StateObject private var tracker = CompletedTracker()
    @State private var showScheduleAlert = false
    @State private var scheduleMessage = ""
    @State private var now = Date()
    @State private var consumedML: Double = 0
    @State private var expectedML: Double = 0
    @State private var goalML: Double = 0

    // Recalculate progress using today's scheduled water events and completion state
    private func recalcProgress() {
        let todayEvents = manager.events.filter { $0.title.hasPrefix("Sleeter: Drink") }
        func ml(from title: String) -> Double {
            let digits = title.filter { $0.isNumber }
            return Double(digits) ?? 0
        }
        goalML = todayEvents.map { ml(from: $0.title) }.reduce(0, +)
        consumedML = todayEvents.filter { tracker.isCompleted($0.eventIdentifier) }
            .map { ml(from: $0.title) }
            .reduce(0, +)
        expectedML = todayEvents.filter { $0.startDate <= now }
            .map { ml(from: $0.title) }
            .reduce(0, +)
        if goalML == 0 { goalML = waterGoalLiters * 1000.0 }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Sleeter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Targets")
                        .foregroundColor(.white)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Text("Water goal (L)")
                            .foregroundColor(.white)
                        TextField("Liters", value: $waterGoalLiters, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 12) {
                        Text("Sleep goal (hrs)")
                            .foregroundColor(.white)
                        TextField("Hours", value: $sleepGoalHours, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                    }

                    Button {
                        manager.ensureAccessAndScheduleWater(forLiters: waterGoalLiters, on: Date()) { count in
                            scheduleMessage = "Scheduled \(count) water reminders for today"
                            showScheduleAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Schedule today's water reminders")
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                WaterProgressView(consumedML: consumedML, expectedML: expectedML, goalML: goalML)
                    .frame(height: 180)

                Spacer()
            }
            .padding()
        }
        .alert(scheduleMessage, isPresented: $showScheduleAlert) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            let today = Date()
            manager.loadEvents(for: today)
            tracker.load(for: today)
            recalcProgress()
        }
        .onReceive(manager.$events) { _ in
            recalcProgress()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
            tracker.load(for: date)
            recalcProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            recalcProgress()
        }
    }
}

final class CompletedTracker: ObservableObject {
    @Published private(set) var completed: Set<String> = []
    private var storageKeyForDay: String = ""
    private let defaults = UserDefaults.standard

    func load(for date: Date) {
        storageKeyForDay = "completedEvents:" + FormatterCache.shared.dayFormatter.string(from: date)
        let ids = defaults.stringArray(forKey: storageKeyForDay) ?? []
        completed = Set(ids)
    }

    func isCompleted(_ id: String) -> Bool {
        completed.contains(id)
    }

    func toggle(_ id: String) {
        if completed.contains(id) { completed.remove(id) } else { completed.insert(id) }
        defaults.set(Array(completed), forKey: storageKeyForDay)
        objectWillChange.send()
    }
}
struct Calender: View {
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @StateObject private var manager = CalendarManager()
    @StateObject private var tracker = CompletedTracker()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(FormatterCache.shared.dayFormatter.string(from: selectedDate))
                    .foregroundColor(.white)
                    .font(.headline)

                if manager.isReadAccessGranted {
                    if manager.events.isEmpty {
                        Text("No events for today")
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        List {
                            ForEach(manager.events, id: \.eventIdentifier) { event in
                                let isDone = tracker.isCompleted(event.eventIdentifier)
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.body)
                                            .foregroundColor(isDone ? .gray : .white)
                                        Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                                            .font(.caption)
                                            .foregroundColor(isDone ? .gray.opacity(0.7) : .gray)
                                    }
                                    Spacer()
                                    Button {
                                        tracker.toggle(event.eventIdentifier)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isDone ? .green : .blue)
                                            Text(isDone ? "Completed" : "Mark done")
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(isDone ? .gray : .blue)
                                }
                                .opacity(isDone ? 0.5 : 1.0)
                                .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
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




struct WaterProgressView: View {
    let consumedML: Double
    let expectedML: Double
    let goalML: Double

    private var onTrack: Bool { consumedML >= expectedML }
    private var statusText: String {
        if onTrack {
            return "On track"
        } else {
            let needed = max(expectedML - consumedML, 0)
            return "Catch up: drink \(Int(needed)) ml"
        }
    }
    private var progress: Double { max(min(consumedML / max(goalML, 1), 1), 0) }
    private var expectedProgress: Double { max(min(expectedML / max(goalML, 1), 1), 0) }

    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Gauge(value: progress) {
                    Text("")
                } currentValueLabel: {
                    Text("\(Int(consumedML)) ml")
                        .foregroundColor(.white)
                        .font(.caption)
                } minimumValueLabel: {
                    Text("0")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("\(Int(goalML))")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(onTrack ? .green : .blue)
                .frame(width: 120, height: 120)
                Text(statusText)
                    .foregroundColor(onTrack ? .green : .orange)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Water Progress Today")
                    .font(.headline)
                    .foregroundColor(.white)
                GeometryReader { geo in
                    let width = geo.size.width
                    let expectedW = min(width * expectedProgress, width)
                    let consumedW = min(width * progress, width)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15)).frame(height: 12)
                        Capsule().fill(Color.gray.opacity(0.5)).frame(width: expectedW, height: 12)
                        Capsule().fill(onTrack ? Color.green : Color.blue).frame(width: consumedW, height: 12)
                    }
                }
                .frame(height: 12)
                HStack {
                    Text("Consumed \(Int(consumedML)) ml")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    Spacer()
                    Text("Goal \(Int(goalML)) ml")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
    
