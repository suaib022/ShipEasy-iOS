import SwiftUI

// MARK: - Shipment List View
/// Screen allowing the seller to search, filter, view, and manage all shipments.
struct ShipmentListView: View {

    // MARK: - Property Wrappers
    /// @ObservedObject connects to the shared ShipmentViewModel passed from MainTabView.
    @ObservedObject var shipmentVM: ShipmentViewModel

    /// @State holds local user search query for the .searchable modifier.
    @State private var searchText: String = ""

    /// @State holds the currently selected status filter (nil means 'All').
    @State private var selectedStatusFilter: ShipmentStatus? = nil

    /// @State holds the currently selected courier filter ("All" means all couriers).
    @State private var selectedCourierFilter: String = "All"

    /// @State controls whether the AddShipmentView sheet is presented.
    @State private var isPresentingAddSheet: Bool = false

    // MARK: - Filtered Shipments Computed Property
    /// Returns the filtered list of shipments based on search text, status, and courier.
    private var filteredShipments: [Shipment] {
        shipmentVM.shipments.filter { shipment in
            // Search query matches customer name or phone
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = shipment.customerName.lowercased().contains(query) ||
                                shipment.phone.lowercased().contains(query) ||
                                shipment.productName.lowercased().contains(query)
            }

            // Status filter match
            let matchesStatus: Bool
            if let statusFilter = selectedStatusFilter {
                matchesStatus = (shipment.status == statusFilter)
            } else {
                matchesStatus = true
            }

            // Courier filter match
            let matchesCourier: Bool
            if selectedCourierFilter == "All" {
                matchesCourier = true
            } else {
                matchesCourier = (shipment.courier == selectedCourierFilter)
            }

            return matchesSearch && matchesStatus && matchesCourier
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Filter Controls Header
                VStack(spacing: 8) {
                    // Status Filter Segment
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(title: "All", isSelected: selectedStatusFilter == nil) {
                                selectedStatusFilter = nil
                            }

                            ForEach(ShipmentStatus.allCases, id: \.self) { status in
                                filterChip(title: status.label, isSelected: selectedStatusFilter == status) {
                                    selectedStatusFilter = status
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Courier Filter Dropdown
                    HStack {
                        Text("Filter Courier:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Courier", selection: $selectedCourierFilter) {
                            Text("All Couriers").tag("All")
                            ForEach(shipmentVM.couriers) { courier in
                                Text(courier.name).tag(courier.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)

                        Spacer()

                        Text("\(filteredShipments.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
                .padding(.top, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))

                Divider()

                // Shipments List
                if filteredShipments.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredShipments) { shipment in
                            // NavigationLink sends the selected shipment into ShipmentDetailView
                            NavigationLink(destination: ShipmentDetailView(shipment: shipment, shipmentVM: shipmentVM)) {
                                shipmentRow(for: shipment)
                            }
                        }
                        // Swipe to delete handler
                        .onDelete(perform: deleteShipments)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Shipments")
            .navigationBarTitleDisplayMode(.inline)
            // Searchable modifier for customer name and phone lookup
            .searchable(text: $searchText, prompt: "Search by customer or phone")
            // Toolbar '+' button opens AddShipmentView
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
            // Add Shipment Modal Sheet
            .sheet(isPresented: $isPresentingAddSheet) {
                AddShipmentView(shipmentVM: shipmentVM)
            }
        }
    }

    // MARK: - Row Subview
    private func shipmentRow(for shipment: Shipment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(shipment.customerName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: shipment.status.symbolName)
                        .font(.system(size: 10))
                    Text(shipment.status.label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(shipment.status.statusColor.opacity(0.15))
                .foregroundColor(shipment.status.statusColor)
                .clipShape(Capsule())
            }

            HStack {
                Text(shipment.productName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("COD: ৳\(Int(shipment.codAmount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 10) {
                Label(shipment.courier, systemImage: "box.truck")
                Label(shipment.district, systemImage: "mappin.and.ellipse")
                Spacer()
                Text(shipment.zone)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Filter Chip Component
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No Shipments Found")
                .font(.headline)
            Text("Try adjusting your filters, or tap '+' to create a new delivery order.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Delete Action
    private func deleteShipments(at offsets: IndexSet) {
        for index in offsets {
            let target = filteredShipments[index]
            Task {
                await shipmentVM.deleteShipment(target)
            }
        }
    }
}
