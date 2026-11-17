import SwiftUI

// MARK: - Seller Profile View
/// Displays the seller's active session, email address, system stats, and logout functionality.
struct ProfileView: View {

    // MARK: - Property Wrappers
    /// @EnvironmentObject reads the shared auth view model to retrieve current email and trigger logOut.
    @EnvironmentObject var authVM: AuthViewModel

    /// @ObservedObject connects to shipment stats to show total account summary.
    @ObservedObject var shipmentVM: ShipmentViewModel

    /// @State controls presentation of the logout confirmation alert.
    @State private var showLogoutConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            List {

                // 1. Seller Account Header
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 54, height: 54)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Online Seller")
                                .font(.headline)
                            Text(authVM.currentEmail ?? "seller@shipeasy.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // 2. Business Performance Snapshot
                Section("All-Time Performance Snapshot") {
                    HStack {
                        Label("Total Shipments", systemImage: "shippingbox")
                        Spacer()
                        Text("\(shipmentVM.shipments.count)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Completed Deliveries", systemImage: "checkmark.seal")
                        Spacer()
                        let deliveredCount = shipmentVM.shipments.filter { $0.status == .delivered }.count
                        Text("\(deliveredCount)")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Label("Total Net Profit", systemImage: "banknote")
                        Spacer()
                        Text("৳\(Int(shipmentVM.totalProfit))")
                            .fontWeight(.bold)
                            .foregroundColor(shipmentVM.totalProfit >= 0 ? .teal : .red)
                    }
                }

                // 3. Supported Couriers Information
                Section("Configured Courier Integrations") {
                    ForEach(shipmentVM.couriers) { courier in
                        HStack {
                            Text(courier.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Inside: ৳\(Int(courier.insideDhaka)) | Outside: ৳\(Int(courier.outsideDhaka))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 4. About App
                Section("Application Information") {
                    HStack {
                        Text("App Name")
                        Spacer()
                        Text("ShipEasy")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (iOS 17+)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Backend")
                        Spacer()
                        Text("Firebase Auth & Firestore")
                            .foregroundColor(.secondary)
                    }
                }

                // 5. Sign Out Button
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Log Out of Account", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Seller Profile")
            .navigationBarTitleDisplayMode(.inline)
            // Confirmation alert before signing out
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    authVM.logOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to end your current session?")
            }
        }
    }
}
