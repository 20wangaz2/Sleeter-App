import Vapor
import Fluent
import FluentMySQLDriver

// Defining a User model
final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    init() { }
    
    init(id: UUID? = nil, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

// CMigration to set up the users table
struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

@main
struct SleeterServer {
    static func main() async throws {
        let app = try Application(.detect())
        defer { app.shutdown() }
        
        // MySQL Config
        app.databases.use(.mysql(
            hostname: "localhost",
            username: "your_username",
            password: "your_password", 
            database: "sleeter_database"
        ), as: .mysql)
        
        app.migrations.add(CreateUser())
        
        // Migrations run automatically
        try await app.autoMigrate().get()
        
        // Routes
        app.get("hello") { req -> String in
            return "Hello from Sleeter MySQL Server!"
        }

        // GET all users (MySQL query)
        app.get("users") { req async throws -> [User] in
            return try await User.query(on: req.db).all()
        }

        // CREATE user (MySQL insert)
        app.post("users") { req async throws -> User in
            let user = try req.content.decode(User.self)
            try await user.save(on: req.db)
            return user
        }

        // GET user by ID(MySQL query)
        app.get("users", ":id") { req async throws -> User in
            guard let user = try await User.find(req.parameters.get("id"), on: req.db) else {
                throw Abort(.notFound)
            }
            return user
        }
        
        try await app.execute()
    }
}