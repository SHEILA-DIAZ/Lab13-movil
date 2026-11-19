import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
