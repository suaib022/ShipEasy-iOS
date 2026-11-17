import Foundation
import FirebaseAuth
import Combine

// MARK: - Auth ViewModel
/// Manages user authentication state, sign-in, sign-up, and session persistence using Firebase Auth.
/// Conforms to ObservableObject so any SwiftUI view observing this class will refresh on state changes.
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published Properties
    // @Published tells SwiftUI to automatically notify and re-render any view reading these values when they change.

    /// Tracks whether a seller is currently logged in.
    @Published var isLoggedIn: Bool = false

    /// Stores any error message string returned by Firebase Auth to show in an alert.
    @Published var errorMessage: String?

    /// Flag indicating whether an authentication network request is currently active.
    @Published var isLoading: Bool = false

    /// Email address of the currently authenticated seller.
    @Published var currentEmail: String?

    /// Handle for Firebase's authentication state change listener.
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Initializer
    /// Sets up a listener with Firebase Auth upon app launch to detect if a seller is already signed in.
    init() {
        // Automatically check if a session already exists
        if let existingUser = Auth.auth().currentUser {
            self.isLoggedIn = true
            self.currentEmail = existingUser.email
        }

        // Listen continuously for auth state transitions (login, logout, session expiration)
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.isLoggedIn = true
                    self?.currentEmail = user.email
                } else {
                    self?.isLoggedIn = false
                    self?.currentEmail = nil
                }
            }
        }
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign Up
    /// Registers a new seller account with an email and password.
    func signUp(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            self.currentEmail = result.user.email
            self.isLoggedIn = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Log In
    /// Signs in an existing seller with credentials.
    func logIn(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            self.currentEmail = result.user.email
            self.isLoggedIn = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Log Out
    /// Ends the current seller session in Firebase.
    func logOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.currentEmail = nil
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Input Validation
    /// Verifies that user email and password meet basic requirements before calling Firebase.
    private func validate(email: String, password: String) -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEmail.isEmpty || !cleanEmail.contains("@") {
            self.errorMessage = "Please enter a valid email address."
            return false
        }
        if password.count < 6 {
            self.errorMessage = "Password must be at least 6 characters long."
            return false
        }
        return true
    }
}
