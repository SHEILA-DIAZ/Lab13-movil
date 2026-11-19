import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let email: String
}

struct UserInput: Encodable {
    let name: String
    let email: String
}
