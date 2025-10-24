import Vapor
import Fluent
import FluentMySQLDriver

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
            database: "sleeter_database"
        ), as: .mysql)
        
        // Routes
        app.get("hello") { req -> String in
            return "Hello from Sleeter MySQL Server!"
        }
        
        try await app.execute()
    }
}