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

    func fetchUsers() {
        guard !hasLoaded, !isBusy else { return }
        send(URLRequest(url: endpoint), decode: { data in
            try JSONDecoder().decode([User].self, from: data)
        }) { users in
            self.users = users
            self.hasLoaded = true
        }
    }

    private func send<Value: Sendable>(
        _ request: URLRequest,
        decode: @escaping @Sendable (Data) throws -> Value,
        completion: @escaping (Value) -> Void,
        onFailure: @escaping () -> Void = {}
    ) {
        isBusy = true
        errorMessage = nil
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result = Result<Value, Error> {
                if let error { throw error }
                try APIError.validate(response)
                guard let data else { throw APIError.invalidResponse }
                return try decode(data)
            }
            DispatchQueue.main.async {
                self.isBusy = false
                switch result {
                case .success(let value):
                    completion(value)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    onFailure()
                }
            }
        }.resume()
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
