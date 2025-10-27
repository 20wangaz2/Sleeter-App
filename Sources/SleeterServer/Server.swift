import Vapor
import Fluent
import FluentMySQLDriver

// Models for Hydration & Sleep Health App
final class UserProfile: Model, Content {
    static let schema = "user_profiles"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "age")
    var age: Int
    
    @Field(key: "weight")
    var weight: Double

    @Field(key: "height")
    var height: Double

    @Field(key: "gender")
    var gender: String
    
    @Field(key: "daily_activity_level")
    var dailyActivityLevel: String
    
    init() { }
    
    init(id: UUID? = nil, age: Int, weight: Double, height: Double, gender: String, dailyActivityLevel: String) {
        self.id = id
        self.age = age
        self.weight = weight
        self.height = height
        self.gender = gender
        self.dailyActivityLevel = dailyActivityLevel
    }
}

final class WaterLog: Model, Content {
    static let schema = "water_logs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "amount_ml")
    var amountML: Int
    
    @Field(key: "timestamp")
    var timestamp: Date
    
    init() { }
    
    init(id: UUID? = nil, amountML: Int, timestamp: Date = Date()) {
        self.id = id
        self.amountML = amountML
        self.timestamp = timestamp
    }
}

final class SleepLog: Model, Content {
    static let schema = "sleep_logs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "hours")
    var hours: Double
    
    @Field(key: "quality")
    var quality: Int
    
    @Field(key: "date")
    var date: Date
    
    init() { }
    
    init(id: UUID? = nil, hours: Double, quality: Int, date: Date = Date()) {
        self.id = id
        self.hours = hours
        self.quality = quality
        self.date = date
    }
}

struct HealthRecommendation: Content {
    let dailyWaterGoalML: Int
    let recommendedSleepHours: Double
    let hydrationProgress: Double  // 0.0 to 1.0
    let sleepProgress: Double      // 0.0 to 1.0
    let message: String
}

@main
struct SleeterServer {
    static func main() async throws {
        let app = try Application(.detect())
        defer { app.shutdown() }
        
        // MySQL Configuration
        app.databases.use(.mysql(
            hostname: "localhost",
            username: "your_username",
            password: "your_password", 
            database: "sleeter_health"
        ), as: .mysql)
        
        // Health Recommendations Route
        app.get("health-recommendations") { req async throws -> HealthRecommendation in
            guard let profile = try await UserProfile.query(on: req.db).first() else {
                throw Abort(.badRequest, reason: "Please set up your profile first")
            }
            
            // Get today's water and sleep logs
            let today = Calendar.current.startOfDay(for: Date())
            let waterLogs = try await WaterLog.query(on: req.db)
                .filter(\.$timestamp >= today)
                .all()
            
            let sleepLogs = try await SleepLog.query(on: req.db)
                .filter(\.$date >= today)
                .all()
            
            let (waterGoal, sleepGoal) = calculateHealthGoals(for: profile)
            let waterProgress = calculateWaterProgress(logs: waterLogs, goal: waterGoal)
            let sleepProgress = calculateSleepProgress(logs: sleepLogs, goal: sleepGoal)
            
            return HealthRecommendation(
                dailyWaterGoalML: waterGoal,
                recommendedSleepHours: sleepGoal,
                hydrationProgress: waterProgress,
                sleepProgress: sleepProgress,
                message: "Stay hydrated and rest well!"
            )
        }
        
        // User Profile Routes
        app.post("profile") { req async throws -> UserProfile in
            let profile = try req.content.decode(UserProfile.self)
            try await profile.save(on: req.db)
            return profile
        }
        
        app.get("profile") { req async throws -> UserProfile in
            guard let profile = try await UserProfile.query(on: req.db).first() else {
                throw Abort(.notFound, reason: "No profile found")
            }
            return profile
        }
        
        // Water Log Routes
        app.post("water-log") { req async throws -> WaterLog in
            let log = try req.content.decode(WaterLog.self)
            try await log.save(on: req.db)
            return log
        }
        
        app.get("water-logs") { req async throws -> [WaterLog] in
            return try await WaterLog.query(on: req.db).all()
        }
        
        // Sleep Log Routes
        app.post("sleep-log") { req async throws -> SleepLog in
            let log = try req.content.decode(SleepLog.self)
            try await log.save(on: req.db)
            return log
        }
        
        app.get("sleep-logs") { req async throws -> [SleepLog] in
            return try await SleepLog.query(on: req.db).all()
        }
        
        try await app.execute()
    }
    
    // Health Goal Calculations
    static func calculateHealthGoals(for profile: UserProfile) -> (waterML: Int, sleepHours: Double) {
        // Water calculation: weight (kg) * 30-35 ml
        let baseWater = Int(profile.weight * 33)
        
        // Adjust water based on activity level
        let activityMultiplier: Double
        switch profile.dailyActivityLevel {
        case "sedentary": activityMultiplier = 1.0
        case "light": activityMultiplier = 1.1
        case "moderate": activityMultiplier = 1.2
        case "active": activityMultiplier = 1.3
        default: activityMultiplier = 1.1
        }
        
        let waterGoal = Int(Double(baseWater) * activityMultiplier)
        
        // Sleep recommendation based on age
        let sleepHours: Double
        switch profile.age {
        case 0...17: sleepHours = 8.5
        case 18...64: sleepHours = 7.5
        default: sleepHours = 7.0
        }
        
        return (waterGoal, sleepHours)
    }
    
    static func calculateWaterProgress(logs: [WaterLog], goal: Int) -> Double {
        let totalWater = logs.reduce(0) { $0 + $1.amountML }
        return min(Double(totalWater) / Double(goal), 1.0)
    }
    
    static func calculateSleepProgress(logs: [SleepLog], goal: Double) -> Double {
        let totalSleep = logs.reduce(0.0) { $0 + $1.hours }
        return min(totalSleep / goal, 1.0)
    }
}