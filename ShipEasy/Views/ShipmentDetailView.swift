import SwiftUI

// MARK: - Reusable Status Picker (Uses @Binding)
/// A reusable status selector menu that takes a two-way @Binding to the status.
/// Demonstrates the @Binding property wrapper for passing read-write state down to a reusable child component.
/// Shows ALL 5 statuses at all times in the menu, disabling invalid transitions based on business rules.
struct StatusPickerView: View {
    /// @Binding: Creates a two-way binding connection to the parent's status state.
    /// When the user selects a new valid status, this binding updates the parent view's state immediately.
    @Binding var currentStatus: ShipmentStatus

    /// Callback closure invoked whenever a status change is selected.
    var onStatusChanged: (ShipmentStatus) -> Void

    var body: some View {
        Menu {
            ForEach(ShipmentStatus.allCases, id: \.self) { status in
                Button {
                    if status != currentStatus && currentStatus.canTransition(to: status) {
                        currentStatus = status
                        onStatusChanged(status)
                    }
                } label: {
                    HStack {
                        Text(status.label)
                        if status == currentStatus {
                            Image(systemName: "checkmark")
                        } else {
                            Image(systemName: status.symbolName)
                        }
                    }
                }
                .disabled(!currentStatus.canTransition(to: status) || status == currentStatus)
            }
        } label: {
            HStack(spacing: 5) {
                Text(currentStatus.label)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemFill))
            .foregroundColor(currentStatus.statusColor)
            .cornerRadius(8)
        }
    }
}

// MARK: - Shipment Detail View
/// Displays the complete overview, financial breakdown, courier info, and tracking timeline for a shipment.
struct ShipmentDetailView: View {

    /// Current shipment being inspected.
    var shipment: Shipment

    /// @ObservedObject connects to the ShipmentViewModel to execute status changes and deletions.
    @ObservedObject var shipmentVM: ShipmentViewModel

    /// @State holds local status to bind to our reusable StatusPicker child view.
    @State private var localStatus: ShipmentStatus

    /// @State controls presentation of the Edit sheet.
    @State private var isShowingEditSheet: Bool = false

    /// @State controls display of the delete confirmation alert.
    @State private var isShowingDeleteAlert: Bool = false

    /// @Environment allows returning to the list view after deleting.
    @Environment(\.dismiss) private var dismiss

    init(shipment: Shipment, shipmentVM: ShipmentViewModel) {
        self.shipment = shipment
        self.shipmentVM = shipmentVM
        _localStatus = State(initialValue: shipment.status)
    }

    /// Finds the latest state of this shipment from the ViewModel (reactive to Firestore changes).
    private var currentShipment: Shipment {
        return shipmentVM.shipments.first(where: { $0.id == shipment.id }) ?? shipment
    }

    var body: some View {
        List {

            // 1. Live Status & Quick Action Section
            Section("Current Status") {
                HStack {
                    Label(currentShipment.status.label, systemImage: currentShipment.status.symbolName)
                        .font(.headline)
                        .foregroundColor(currentShipment.status.statusColor)

                    Spacer()

                    // Reusable Child View using @Binding
                    StatusPickerView(currentStatus: $localStatus) { newStatus in
                        Task {
                            await shipmentVM.changeStatus(shipment: currentShipment, to: newStatus)
                        }
                    }
                }
            }

            // 2. Customer Information
            Section("Customer Information") {
                detailRow(title: "Customer Name", value: currentShipment.customerName, icon: "person.fill")
                detailRow(title: "Phone", value: currentShipment.phone, icon: "phone.fill")
                detailRow(title: "Delivery Address", value: currentShipment.address, icon: "house.fill")
                detailRow(title: "District", value: currentShipment.district, icon: "mappin.and.ellipse")
                detailRow(title: "Zone", value: currentShipment.zone, icon: "map.fill")
            }

            // 3. Parcel & Financial Summary
            Section("Parcel & Financial Breakdown") {
                detailRow(title: "Product", value: currentShipment.productName, icon: "bag.fill")
                detailRow(title: "Package Weight", value: String(format: "%.1f kg", currentShipment.weightKg), icon: "scalemass.fill")
                detailRow(title: "Wholesale Cost", value: "৳\(String(format: "%.0f", currentShipment.productCost))", icon: "cart.fill")
                detailRow(title: "Courier Charge", value: "৳\(String(format: "%.0f", currentShipment.deliveryCharge))", icon: "box.truck.fill")
                if currentShipment.advancePaid > 0 {
                    detailRow(title: "Advance Paid", value: "৳\(String(format: "%.0f", currentShipment.advancePaid))", icon: "creditcard.fill")
                }
                detailRow(title: "COD to Collect", value: "৳\(String(format: "%.0f", currentShipment.codAmount))", icon: "banknote.fill")

                HStack {
                    Label("Net Profit (if delivered)", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text("৳\(String(format: "%.2f", currentShipment.profit))")
                        .fontWeight(.bold)
                        .foregroundColor(currentShipment.profit >= 0 ? .green : .red)
                }
            }

            // 4. Courier Details
            Section("Courier Information") {
                detailRow(title: "Courier Company", value: currentShipment.courier, icon: "shippingbox.fill")
                detailRow(title: "Booked On", value: formattedDate(currentShipment.createdAt), icon: "calendar")
            }

            // 5. Tracking Timeline
            Section("Shipment Tracking Timeline") {
                if currentShipment.timeline.isEmpty {
                    Text("No timeline events recorded.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(currentShipment.timeline, id: \.self) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(event.status.statusColor)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.status.label)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(formattedDate(event.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // 6. Delete Action
            Section {
                Button(role: .destructive) {
                    isShowingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Shipment", systemImage: "trash.fill")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(currentShipment.productName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
        }
        // Edit Sheet
        .sheet(isPresented: $isShowingEditSheet) {
            AddShipmentView(shipmentVM: shipmentVM, existingShipment: currentShipment)
        }
        // Confirmation Alert
        .alert("Confirm Deletion", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await shipmentVM.deleteShipment(currentShipment)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this shipment? This action cannot be undone.")
        }
        .onChange(of: currentShipment.status) { _, newStatus in
            localStatus = newStatus
        }
    }

    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
