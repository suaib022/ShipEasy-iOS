import SwiftUI

// MARK: - Main Tab View
/// Tab container housing the primary application sections when the seller is logged in.
struct MainTabView: View {

    // MARK: - Property Wrappers
    /// @StateObject:
    /// Owns the lifecycle of the ShipmentViewModel instance while the user is authenticated.
    /// It is created once and preserved across SwiftUI re-renders of the tab view.
    @StateObject private var shipmentVM = ShipmentViewModel()

    var body: some View {
        TabView {
            // Tab 1: Dashboard Home
            HomeView(shipmentVM: shipmentVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            // Tab 2: Shipment List & Filters
            ShipmentListView(shipmentVM: shipmentVM)
                .tabItem {
                    Label("Shipments", systemImage: "shippingbox.fill")
                }

            // Tab 3: Seller Profile & Settings
            ProfileView(shipmentVM: shipmentVM)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(.blue)
    }
}

// MARK: - Content View
/// Root routing view that checks authentication state and directs to either LoginView or MainTabView.
struct ContentView: View {

    // MARK: - Property Wrappers
    /// @EnvironmentObject:
    /// Injected from ShipEasyApp, allows ContentView to read the global login state.
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                // If authenticated, display the main 3-tab experience
                MainTabView()
            } else {
                // If not logged in, display the seller login screen
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authVM.isLoggedIn)
    }
}
