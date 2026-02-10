import SwiftUI

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(
                            colors: [.dcBlue, .dcPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("DayCast")
                    .font(.title.bold())
            }

            // Error
            if let error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Form
            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Buttons
            VStack(spacing: 10) {
                Button {
                    submit(action: "login")
                } label: {
                    Text("Log in")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.dcBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading || !isFormValid)

                Button {
                    submit(action: "register")
                } label: {
                    Text("Register")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading || !isFormValid)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var isFormValid: Bool {
        username.count >= 3 && password.count >= 6
    }

    private func submit(action: String) {
        error = nil
        isLoading = true

        Task {
            do {
                let response = try await APIService.shared.auth(action: action, username: username, password: password)
                APIService.shared.saveToken(response.token)
                APIService.shared.saveUsername(response.username)
                isAuthenticated = true
            } catch APIServiceError.serverError(let msg) {
                error = msg
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
