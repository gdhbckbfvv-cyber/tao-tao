import Foundation

/// 用户模型
struct User: Codable, Identifiable {
    let id: UUID
    let email: String?
    var username: String?
    var avatarUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
