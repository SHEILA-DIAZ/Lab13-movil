import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UserViewModel()
    @State private var editingUser: User? = nil
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            List(viewModel.filteredUsers) { user in
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name).font(.headline)
                    Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteUser(user) }
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                    Button {
                        openForm(for: user)
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .disabled(viewModel.isBusy)
            .overlay {
                if viewModel.isBusy && !showingForm {
                    ProgressView("Procesando…")
                } else if viewModel.filteredUsers.isEmpty && viewModel.errorMessage == nil {
                    if viewModel.searchText.isEmpty {
                        ContentUnavailableView("Sin usuarios", systemImage: "person.2")
                    } else {
                        ContentUnavailableView.search(text: viewModel.searchText)
                    }
                }
            }
            .navigationTitle("Usuarios")
            .searchable(text: $viewModel.searchText, prompt: "Buscar por nombre")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openForm(for: nil)
                    } label: {
                        Label("Agregar usuario", systemImage: "plus")
                    }
                    .disabled(viewModel.isBusy || !viewModel.hasLoaded)
                }
            }
            .task { await viewModel.fetchUsers() }
            .sheet(isPresented: $showingForm) {
                UserFormView(user: editingUser, viewModel: viewModel) { input, completion in
                    Task {
                        let saved = await viewModel.saveUser(editingUser, input: input)
                        completion(saved)
                    }
                }
            }
            .alert("No se pudo completar la acción", isPresented: showError, actions: {
                if !viewModel.hasLoaded {
                    Button("Reintentar") { Task { await viewModel.fetchUsers() } }
                }
                Button("Cerrar", role: .cancel) {}
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }

    private var showError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !showingForm },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func openForm(for user: User?) {
        viewModel.errorMessage = nil
        editingUser = user
        showingForm = true
    }
}
