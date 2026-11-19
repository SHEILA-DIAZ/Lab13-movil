import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.filteredUsers) { user in
                Text(user.name)
            }
            .overlay {
                if viewModel.isBusy {
                    ProgressView("Cargando usuarios…")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Error de conexión", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { viewModel.fetchUsers() }
                    }
                } else if viewModel.filteredUsers.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .navigationTitle("Usuarios")
            .searchable(text: $viewModel.searchText, prompt: "Buscar por nombre")
            .onAppear { viewModel.fetchUsers() }
        }
    }
}
