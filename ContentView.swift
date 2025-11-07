//
//  ContentView.swift
//  Sleeter-Fitness-App
//
//  Created by Kolby Hart on 10/27/25.
//  Adjusted by Gemini
//

import SwiftUI

struct ContentView: View {
    
    // --- STATE VARIABLES ---
    
    // Sleep State
    @State private var baseSleepGoal: Double = 8.0 // Base goal in hours
    @State private var workoutIntensity: WorkoutIntensity = .none
    
    // Water State
    // We use a String for the TextField, and convert to Double for calculations (can switch to double?)
    // @State private var waterGoalText: String = "3000"

    // Enum to manage workout intensity options
    enum WorkoutIntensity: String, CaseIterable, Identifiable {
        case none = "None"
        case light = "Light"
        case moderate = "Moderate"
        case hard = "Hard"
        
        var id: String { self.rawValue }
    }

    var suggestedSleepGoal: Double {
        // 1. Define the "bonus" sleep time per workout
        let bonus: Double
        switch workoutIntensity { // later can just be a selectable "how was your workout intensity)
        case .none:
            bonus = 0.0
        case .light:
            bonus = 0.25 // 15 minutes
        case .moderate:
            bonus = 0.75 // 45 minutes
        case .hard:
            bonus = 1.25 // 1 hour 15 minutes
        }

        // 2. Check for the 10-hour upper bound.
        // If the user's goal is 10 or more, it should not be kept at 10 as maximum rec.
        if baseSleepGoal >= 10.0 {
            baseSleepGoal = 10.0;
            return baseSleepGoal
        }
        
        // 3. Calculate the adjusted goal
        let adjustedGoal = baseSleepGoal + bonus
        
        // 4. Return the adjusted goal, but cap it at a maximum of 10.0
        // e.g., if base is 9.5 + hard (1.25) = 10.75, this will return 10.0
        return min(adjustedGoal, 10.0)
    }
    /*
    var waterSchedule: (segments: Int, waterPerSegment: Double) {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let endHour = 22 // Last suggested time to drink is 10pm
        
        // Get the water goal from the text field, default to 0 if invalid
        let waterGoalML = Double(waterGoalText) ?? 0.0

        // If it's already 10 PM or later, there are no segments left.
        if currentHour >= endHour {
            return (0, 0)
        }
        
        
        // This counts all 30-min slots from the start of the current hour until 22:30
        let daySegments = ((endHour - currentHour) * 2) + 1
        let waterPerSegment = waterGoalML / Double(daySegments)

        // Calculates that the water goal has been met
        if daySegments <= 0 || waterGoalML == 0.0 {
            return (0, 0)
        }
        
        return (daySegments, waterPerSegment)
    }
    */

    func formatHours(_ totalHours: Double) -> String {
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    // --- BODY (The UI) ---
    
    var body: some View {
        NavigationView {
            Form {
                // --- SLEEP SECTION ---
                Section(header: Text("Sleep Goal").font(.headline)) {
                    // Stepper for setting the base sleep goal
                    Stepper("Base Goal: \(formatHours(baseSleepGoal))",
                            value: $baseSleepGoal,
                            in: 7...10,   // User can set a goal from 7 to 10 hours
                            step: 0.25)  // Steps in 15-minute (0.25) increments
                    
                    // Picker for workout intensity
                    Picker("Workout Intensity", selection: $workoutIntensity) {
                        ForEach(WorkoutIntensity.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Display the final suggested goal
                    HStack {
                        Text("Suggested Goal:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(formatHours(suggestedSleepGoal))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                /* --- WATER SECTION ---
                Section(header: Text("Water Goal").font(.headline))
                {
                    // Text field for total water goal
                    HStack {
                        TextField("Total Daily Goal", text: $waterGoalText)
                            .keyboardType(.numberPad)
                        Text("ml")
                    }
                    
                    // Display the calculated water schedule
                    VStack(alignment: .leading, spacing: 8) {
                        let schedule = waterSchedule
                        
                        // Check if there are any segments left today
                        if schedule.segments > 0 && schedule.waterPerSegment > 0 {
                            Text("Drink \(String(format: "%.0f", schedule.waterPerSegment)) ml every 30 minutes")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("You have \(schedule.segments) 30-minute periods left until 10:30 PM to hit your goal.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if Double(waterGoalText) == nil {
                            Text("Please enter a valid number for your water goal.")
                                .foregroundColor(.red)
                        } else {
                            // This shows if it's past 10 PM
                            Text("It's past 10:00 PM. Time to rest!")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }
                 */
                    .padding(.vertical, 5)
                    
                }
            }
            .navigationTitle("Sleeter Fitness")
            // Dismiss keyboard when tapping outside the form
            .onTapGesture {
                hideKeyboard()
            }
        }
    }


// Helper extension to hide the keyboard
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// --- PREVIEW ---
#Preview {
    ContentView()
}
