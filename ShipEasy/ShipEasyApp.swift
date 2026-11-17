import SwiftUI
import FirebaseCore

// MARK: - ShipEasy App Entry Point
/// Main application entry point for the ShipEasy courier & cash-on-delivery manager.
/// Configures Firebase services and creates the root environment state.
@main
struct ShipEasyApp: App {

    // MARK: - Property Wrappers
    /// @StateObject:
    /// Creates and owns the single global instance of AuthViewModel for the entire application life cycle.
    /// Because it is marked @StateObject here at the root level, SwiftUI ensures it is never destroyed
    /// or recreated during re-renders.
    @StateObject private var authVM = AuthViewModel()

    // MARK: - App Initializer
    init() {
        // Initialize Firebase services (Auth and Firestore) when the app launches
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Root view container
            ContentView()
                // .environmentObject:
                // Injects authVM into the SwiftUI environment so any child view can access it
                // using @EnvironmentObject without having to pass it through every initializer.
                .environmentObject(authVM)
        }
    }
}
