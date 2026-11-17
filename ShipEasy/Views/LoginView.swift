import SwiftUI

// MARK: - Login View
/// Screen allowing online sellers to log in to their ShipEasy account.
struct LoginView: View {

    // MARK: - Property Wrappers
    /// @EnvironmentObject retrieves the shared AuthViewModel injected higher in the view hierarchy.
    @EnvironmentObject var authVM: AuthViewModel

    /// @State holds local private text field state that belongs solely to this view.
    @State private var emailText: String = ""
    @State private var passwordText: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // App Logo & Branding Header
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .padding(.top, 40)

                        Text("ShipEasy")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Courier & COD Manager for Online Sellers")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    // Credentials Form
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            TextField("Seller Email", text: $emailText)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled(true)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(10)

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            SecureField("Password (min 6 chars)", text: $passwordText)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // Login Button
                    Button {
                        Task {
                            await authVM.logIn(email: emailText, password: passwordText)
                            if authVM.errorMessage != nil {
                                showAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authVM.isLoading)
                    .padding(.horizontal)

                    // Navigation to Sign Up Screen
                    HStack(spacing: 6) {
                        Text("New seller?")
                            .foregroundColor(.secondary)

                        NavigationLink {
                            SignUpView()
                        } label: {
                            Text("Create an Account")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 8)
                }
                .padding(.bottom, 30)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Seller Login")
            .navigationBarTitleDisplayMode(.inline)
            // Error Alert Dialog
            .alert("Login Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    authVM.errorMessage = nil
                }
            } message: {
                Text(authVM.errorMessage ?? "An error occurred.")
            }
        }
    }
}
