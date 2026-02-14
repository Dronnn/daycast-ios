import SwiftUI

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    var body: some View {
        ZStack {
            // Animated gradient mesh background
            GradientMeshBackground()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 80)

                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient.dcAccent
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .dcBlue.opacity(0.4), radius: 20, y: 8)

                        Text("DayCast")
                            .font(.dcHeading(34, weight: .heavy))
                    }

                    // Form
                    VStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .username)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .dcInputFocus(focusedField == .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .dcInputFocus(focusedField == .password)
                            .submitLabel(.go)
                            .onSubmit { submit(action: "login") }
                    }

                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            submit(action: "login")
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Log in")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(LinearGradient.dcAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.dcScale)
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
                        .buttonStyle(.dcScale)
                        .disabled(isLoading || !isFormValid)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focusedField = nil }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var isFormValid: Bool {
        username.count >= 3 && password.count >= 6
    }

    private func submit(action: String) {
        focusedField = nil
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
