import Foundation

// MARK: - API Error

enum APIError: Error {
    case notRegistered
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
}

// MARK: - Response DTOs

struct UserDTO: Decodable {
    let name: String
    let vibe: String
    let role: String?
    let totalStars: Int
    let dailyStars: Int
    let shield: ShieldDTO
    let tasks: [TaskDTO]
    let tomorrowExtras: [TaskDTO]
}

struct ShieldDTO: Decodable {
    let fragments: Int
    let isActive: Bool
}

struct TaskDTO: Decodable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let isSnoozed: Bool
    let isDismissedToday: Bool
    let isSkippedTomorrow: Bool
    let isTomorrowOnly: Bool
}

struct UpdateTaskResponse: Decodable {
    let task: TaskDTO
    let user: UserStarsDTO
}

struct UserStarsDTO: Decodable {
    let totalStars: Int
    let dailyStars: Int
}

struct RegisterResponse: Decodable {
    let userId: UUID
    let token: String
    let user: UserDTO
}

struct GoogleAuthResponse: Decodable {
    let userId: UUID?
    let token: String?
    let isNewUser: Bool
    let user: UserDTO?
    let googleId: String?
    let email: String?
}

struct AppleAuthResponse: Decodable {
    let userId: UUID?
    let token: String?
    let isNewUser: Bool
    let user: UserDTO?
    let appleId: String?
    let email: String?
    let fullName: String?
}

struct FamilyMemberDTO: Decodable {
    let userId: UUID
    let name: String
    let role: String
    let totalStars: Int
    let dailyStars: Int
}

struct FamilyResponse: Decodable {
    let familyId: UUID
    let name: String
    let members: [FamilyMemberDTO]
}

struct InviteResponse: Decodable {
    let inviteCode: String
    let email: String
}

struct ChildProgressDTO: Decodable {
    let userId: UUID
    let name: String
    let totalStars: Int
    let dailyStars: Int
    let dailyCompletionPercentage: Double
    let shield: ShieldDTO
    let tasks: [TaskDTO]
}

struct NewDayResponse: Decodable {
    let wasNewDay: Bool
    let snapshot: SnapshotDTO?
    let shield: ShieldDTO
    let tasks: [TaskDTO]
}

struct SnapshotDTO: Decodable {
    let date: String
    let completionPercentage: Double
    let starsLit: Int
}

// MARK: - VibeType service mapping

extension VibeType {
    /// Lowercase string expected by the service ("bestie" | "boss")
    var serviceValue: String {
        switch self {
        case .bestie: return "bestie"
        case .boss:   return "boss"
        }
    }

    /// Initialise from the lowercase string returned by the service
    init?(serviceString: String) {
        switch serviceString.lowercased() {
        case "bestie": self = .bestie
        case "boss":   self = .boss
        default:       return nil
        }
    }
}

// MARK: - HabitTask mapping from DTO

extension HabitTask {
    init(from dto: TaskDTO) {
        self.id               = dto.id
        self.title            = dto.title
        self.isCompleted      = dto.isCompleted
        self.isSnoozed        = dto.isSnoozed
        self.isDismissedToday = dto.isDismissedToday
        self.isSkippedTomorrow = dto.isSkippedTomorrow
        self.lastUpdated      = Date()
    }
}

// MARK: - Shield mapping from DTO

extension Shield {
    init(from dto: ShieldDTO) {
        self.fragments = dto.fragments
        self.isActive  = dto.isActive
    }
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    /// Base URL resolved from the active build configuration via Info.plist.
    /// Dev xcconfig → http://localhost:5000
    /// PROD xcconfig → https://nimbos.runasp.net
    var baseURL: String {
        let info   = Bundle.main.infoDictionary
        let scheme = info?["APIBaseScheme"] as? String ?? "https"
        let host   = info?["APIBaseHost"]   as? String ?? "nimbos.runasp.net"
        return "\(scheme)://\(host)"
    }

    private enum StorageKeys {
        static let token    = "nimbus_token"
        static let deviceId = "nimbus_deviceId"
    }

    var token: String? {
        UserDefaults.standard.string(forKey: StorageKeys.token)
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: StorageKeys.token)
    }

    var isRegistered: Bool { token != nil }

    /// A stable per-install identifier that does not require UIKit.
    static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: StorageKeys.deviceId) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: StorageKeys.deviceId)
        return id
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // ASP.NET Core serialises to camelCase by default; Swift property names
        // match so no key strategy is needed beyond the default.
        return d
    }()

    // MARK: - Request helpers

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.httpError(status) }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performVoid(_ req: URLRequest) async throws {
        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.httpError(status) }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    // MARK: - Users

    func register(deviceId: String, name: String, vibe: String, pin: String?, tasks: [String],
                  role: String? = nil, googleId: String? = nil, appleId: String? = nil, email: String? = nil) async throws -> RegisterResponse {
        struct Body: Encodable {
            let deviceId: String; let name: String; let vibe: String
            let pin: String?; let tasks: [String]; let role: String?
            let googleId: String?; let appleId: String?; let email: String?
        }
        let body = try encode(Body(deviceId: deviceId, name: name, vibe: vibe, pin: pin,
                                   tasks: tasks, role: role, googleId: googleId, appleId: appleId, email: email))
        // Registration does not require auth — build request manually
        guard let url = URL(string: baseURL + "/users") else {
            throw APIError.networkError(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await perform(req)
    }

    func appleAuth(userIdentifier: String, email: String?, fullName: String?) async throws -> AppleAuthResponse {
        struct Body: Encodable { let userIdentifier: String; let deviceId: String; let email: String?; let fullName: String? }
        let body = try encode(Body(userIdentifier: userIdentifier, deviceId: APIClient.deviceId, email: email, fullName: fullName))
        guard let url = URL(string: baseURL + "/auth/apple") else {
            throw APIError.networkError(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await perform(req)
    }

    func googleAuth(idToken: String) async throws -> GoogleAuthResponse {
        struct Body: Encodable { let idToken: String; let deviceId: String }
        let body = try encode(Body(idToken: idToken, deviceId: APIClient.deviceId))
        guard let url = URL(string: baseURL + "/auth/google") else {
            throw APIError.networkError(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await perform(req)
    }

    func getMe() async throws -> UserDTO {
        let req = try makeRequest("/users/me")
        return try await perform(req)
    }

    func updateMe(name: String? = nil, vibe: String? = nil, pin: String? = nil) async throws {
        struct Body: Encodable { let name: String?; let vibe: String?; let pin: String? }
        let body = try encode(Body(name: name, vibe: vibe, pin: pin))
        let req = try makeRequest("/users/me", method: "PATCH", body: body)
        try await performVoid(req)
    }

    func updateApnsToken(_ token: String) async throws {
        struct Body: Encodable { let apnsToken: String }
        let body = try encode(Body(apnsToken: token))
        let req  = try makeRequest("/users/me", method: "PATCH", body: body)
        try await performVoid(req)
    }

    // MARK: - Tasks

    func createTask(title: String) async throws -> TaskDTO {
        struct Body: Encodable { let title: String }
        let body = try encode(Body(title: title))
        let req = try makeRequest("/tasks", method: "POST", body: body)
        return try await perform(req)
    }

    func updateTask(id: UUID,
                    isCompleted: Bool? = nil,
                    isSnoozed: Bool? = nil,
                    isDismissedToday: Bool? = nil,
                    isSkippedTomorrow: Bool? = nil,
                    title: String? = nil) async throws -> UpdateTaskResponse {
        struct Body: Encodable {
            let isCompleted: Bool?; let isSnoozed: Bool?
            let isDismissedToday: Bool?; let isSkippedTomorrow: Bool?
            let title: String?
        }
        let body = try encode(Body(isCompleted: isCompleted, isSnoozed: isSnoozed,
                                   isDismissedToday: isDismissedToday,
                                   isSkippedTomorrow: isSkippedTomorrow, title: title))
        let req = try makeRequest("/tasks/\(id.uuidString.lowercased())", method: "PATCH", body: body)
        return try await perform(req)
    }

    func deleteTask(id: UUID) async throws {
        let req = try makeRequest("/tasks/\(id.uuidString.lowercased())", method: "DELETE")
        try await performVoid(req)
    }

    func createTomorrowExtra(title: String) async throws -> TaskDTO {
        struct Body: Encodable { let title: String }
        let body = try encode(Body(title: title))
        let req = try makeRequest("/tasks/tomorrow-extras", method: "POST", body: body)
        return try await perform(req)
    }

    func deleteTomorrowExtra(id: UUID) async throws {
        let req = try makeRequest("/tasks/tomorrow-extras/\(id.uuidString.lowercased())", method: "DELETE")
        try await performVoid(req)
    }

    // MARK: - Daily

    func newDay(lastOpenedDate: String, currentDate: String) async throws -> NewDayResponse {
        struct Body: Encodable { let lastOpenedDate: String; let currentDate: String }
        let body = try encode(Body(lastOpenedDate: lastOpenedDate, currentDate: currentDate))
        let req = try makeRequest("/daily/new-day", method: "POST", body: body)
        return try await perform(req)
    }

    func getSnapshots(month: String) async throws -> [SnapshotDTO] {
        let encoded = month.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? month
        let req = try makeRequest("/daily/snapshots?month=\(encoded)")
        return try await perform(req)
    }

    // MARK: - Family

    func createFamily(name: String) async throws -> FamilyResponse {
        struct Body: Encodable { let familyName: String }
        let body = try encode(Body(familyName: name))
        let req = try makeRequest("/family", method: "POST", body: body)
        return try await perform(req)
    }

    func deleteFamilyInvite(inviteCode: String) async throws {
        let req = try makeRequest("/family/invites/\(inviteCode)", method: "DELETE")
        try await performVoid(req)
    }

    func getPendingInvites() async throws -> [InviteResponse] {
        let req = try makeRequest("/family/invites")
        return try await perform(req)
    }

    func createFamilyInvite(email: String) async throws -> InviteResponse {
        struct Body: Encodable { let email: String }
        let body = try encode(Body(email: email))
        let req = try makeRequest("/family/invites", method: "POST", body: body)
        return try await perform(req)
    }

    func joinFamily(inviteCode: String, email: String) async throws -> FamilyResponse {
        struct Body: Encodable { let inviteCode: String; let email: String }
        let body = try encode(Body(inviteCode: inviteCode, email: email))
        let req = try makeRequest("/family/join", method: "POST", body: body)
        return try await perform(req)
    }

    func getFamily() async throws -> FamilyResponse {
        let req = try makeRequest("/family")
        return try await perform(req)
    }

    func getChildren() async throws -> [ChildProgressDTO] {
        let req = try makeRequest("/family/children")
        return try await perform(req)
    }

    func getChild(_ childId: UUID) async throws -> ChildProgressDTO {
        let req = try makeRequest("/family/children/\(childId.uuidString.lowercased())")
        return try await perform(req)
    }

    func addTaskToChild(_ childId: UUID, title: String) async throws -> TaskDTO {
        struct Body: Encodable { let title: String }
        let body = try encode(Body(title: title))
        let req = try makeRequest("/family/children/\(childId.uuidString.lowercased())/tasks", method: "POST", body: body)
        return try await perform(req)
    }

    func removeTaskFromChild(_ childId: UUID, taskId: UUID) async throws {
        let req = try makeRequest("/family/children/\(childId.uuidString.lowercased())/tasks/\(taskId.uuidString.lowercased())", method: "DELETE")
        try await performVoid(req)
    }

    func renameTaskForChild(_ childId: UUID, taskId: UUID, title: String) async throws -> TaskDTO {
        struct Body: Encodable { let title: String? }
        let body = try encode(Body(title: title))
        let req = try makeRequest("/family/children/\(childId.uuidString.lowercased())/tasks/\(taskId.uuidString.lowercased())", method: "PATCH", body: body)
        return try await perform(req)
    }
}
