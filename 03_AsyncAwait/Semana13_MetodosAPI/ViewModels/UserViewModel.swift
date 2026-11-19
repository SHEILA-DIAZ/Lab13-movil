import Combine
import Foundation

@MainActor
final class UserViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published var searchText = ""
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false

    private let endpoint = URL(string: "https://jsonplaceholder.typicode.com/users")!

    var filteredUsers: [User] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return users }
        return users.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // JSONPlaceholder no conserva las altas. Los IDs negativos identifican
    // las filas creadas durante esta sesión.
    private var nextLocalID = -1

    private func writeRequest(method: String, user: User?, input: UserInput? = nil) throws -> URLRequest {
        let url = user.map { endpoint.appendingPathComponent(String($0.id)) } ?? endpoint
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let input {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(input)
        }
        return request
    }

    private func applySavedUser(_ saved: User, replacing original: User?) {
        if let original {
            guard let index = users.firstIndex(where: { $0.id == original.id }) else { return }
            users[index] = User(id: original.id, name: saved.name, email: saved.email)
        } else {
            users.insert(User(id: nextLocalID, name: saved.name, email: saved.email), at: 0)
            nextLocalID -= 1
        }
    }

    func fetchUsers() async {
        guard !hasLoaded, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            try APIError.validate(response)
            users = try JSONDecoder().decode([User].self, from: data)
            hasLoaded = true
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func saveUser(_ user: User?, input: UserInput) async -> Bool {
        guard !isBusy else { return false }
        errorMessage = nil
        if let user, user.id < 0 {
            applySavedUser(User(id: user.id, name: input.name, email: input.email), replacing: user)
            return true
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let request = try writeRequest(method: user == nil ? "POST" : "PUT", user: user, input: input)
            let (data, response) = try await URLSession.shared.data(for: request)
            try APIError.validate(response)
            let saved = try JSONDecoder().decode(User.self, from: data)
            applySavedUser(saved, replacing: user)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteUser(_ user: User) async {
        guard !isBusy else { return }
        errorMessage = nil
        if user.id < 0 {
            users.removeAll { $0.id == user.id }
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let request = try writeRequest(method: "DELETE", user: user)
            let (_, response) = try await URLSession.shared.data(for: request)
            try APIError.validate(response)
            users.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "La API devolvió una respuesta no válida."
        case .httpStatus(let status):
            return "La API devolvió el código HTTP \(status)."
        }
    }

    static func validate(_ response: URLResponse?) throws {
        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.httpStatus(response.statusCode)
        }
    }
}
