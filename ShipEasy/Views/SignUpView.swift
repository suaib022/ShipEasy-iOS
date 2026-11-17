import SwiftUI

// MARK: - Sign Up View
/// Screen allowing new online sellers to register an account in ShipEasy.
struct SignUpView: View {

    // MARK: - Property Wrappers
    /// @EnvironmentObject connects to the shared auth state created in ShipEasyApp.
    @EnvironmentObject var authVM: AuthViewModel

    /// @State holds local private form fields for account creation.
    @State private var emailText: String = ""
    @State private var passwordText: String = ""
    @State private var confirmPasswordText: String = ""
    @State private var showAlert: Bool = false

    /// @Environment dismisses this view from the navigation stack when tapped.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 58))
                        .foregroundColor(.blue)
                        .padding(.top, 30)

                    Text("Register Seller")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Create your seller profile to manage couriers")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // Input Fields
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        TextField("Email Address", text: $emailText)
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

                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        SecureField("Confirm Password", text: $confirmPasswordText)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // Sign Up Button
                Button {
                    Task {
                        if passwordText != confirmPasswordText {
                            authVM.errorMessage = "Passwords do not match."
                            showAlert = true
                            return
                        }

                        await authVM.signUp(email: emailText, password: passwordText)
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
                            Text("Create Account")
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

                // Back to Login Button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Text("Already registered?")
                            .foregroundColor(.secondary)
                        Text("Back to Log In")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .font(.subheadline)
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 30)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        // Alert on Failure
        .alert("Registration Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                authVM.errorMessage = nil
            }
        } message: {
            Text(authVM.errorMessage ?? "An error occurred during registration.")
        }
    }
}
