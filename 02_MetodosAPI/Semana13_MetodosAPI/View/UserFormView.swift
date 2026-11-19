import SwiftUI

struct UserFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UserViewModel
    let user: User?
    let onSubmit: (UserInput, @escaping (Bool) -> Void) -> Void

    @State private var name: String
    @State private var email: String

    init(user: User?, viewModel: UserViewModel,
         onSubmit: @escaping (UserInput, @escaping (Bool) -> Void) -> Void) {
        self.user = user
        self.viewModel = viewModel
        self.onSubmit = onSubmit
        _name = State(initialValue: user?.name ?? "")
        _email = State(initialValue: user?.email ?? "")
    }

    private var input: UserInput {
        UserInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del usuario") {
                    TextField("Nombre", text: $name)
                    TextField("Correo electrónico", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .disabled(viewModel.isBusy)

                if viewModel.isBusy {
                    ProgressView("Guardando…")
                }
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle(user == nil ? "Nuevo usuario" : "Editar usuario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(viewModel.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSubmit(input) { saved in
                            if saved { dismiss() }
                        }
                    }
                    .disabled(viewModel.isBusy || input.name.isEmpty || !input.email.contains("@"))
                }
            }
            .interactiveDismissDisabled(viewModel.isBusy)
        }
    }
}
