import SwiftUI

// MARK: - Dashboard Home View
/// Displays the seller's summary statistics, metrics, and high-level parcel statuses.
struct HomeView: View {

    // MARK: - Property Wrappers
    /// @ObservedObject:
    /// In SwiftUI, @ObservedObject is used when a view receives an already-created ObservableObject
    /// from an ancestor view. Unlike @StateObject (which creates and owns the object lifecycle),
    /// @ObservedObject simply listens for changes and redraws when notified without recreating it.
    @ObservedObject var shipmentVM: ShipmentViewModel

    /// Grid layout configuration: 2 columns with adaptive sizing.
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Dashboard Top Welcome
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Business Overview")
                            .font(.system(size: 24, weight: .bold))
                        Text("Real-time courier and cash collection summary")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 6 Stat Cards in a 2x3 Grid
                    LazyVGrid(columns: columns, spacing: 14) {

                        // 1. Today's Parcels
                        statCard(
                            title: "Today's Orders",
                            value: "\(shipmentVM.todayCount)",
                            unit: "parcels",
                            iconName: "calendar.badge.clock",
                            color: .blue
                        )

                        // 2. Pending Parcels
                        statCard(
                            title: "Pending / In-Transit",
                            value: "\(shipmentVM.pendingCount)",
                            unit: "active",
                            iconName: "truck.box.fill",
                            color: .orange
                        )

                        // 3. COD to Collect
                        statCard(
                            title: "COD to Collect",
                            value: "৳\(Int(shipmentVM.codToCollect))",
                            unit: "pending collection",
                            iconName: "hourglass.bottomhalf.filled",
                            color: .purple
                        )

                        // 4. COD Received
                        statCard(
                            title: "COD Received",
                            value: "৳\(Int(shipmentVM.codReceived))",
                            unit: "from delivered",
                            iconName: "banknote.fill",
                            color: .green
                        )

                        // 5. Total Net Profit
                        statCard(
                            title: "Total Profit",
                            value: "৳\(Int(shipmentVM.totalProfit))",
                            unit: "net earnings",
                            iconName: "chart.line.uptrend.xyaxis",
                            color: shipmentVM.totalProfit >= 0 ? .teal : .red
                        )

                        // 6. Return Rate Percentage
                        statCard(
                            title: "Return Rate",
                            value: String(format: "%.1f%%", shipmentVM.returnRate),
                            unit: "of all parcels",
                            iconName: "arrow.uturn.backward.circle.fill",
                            color: shipmentVM.returnRate > 15 ? .red : .gray
                        )
                    }
                    .padding(.horizontal)

                    // Recent Deliveries Quick Glance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Courier Performance")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(shipmentVM.couriers) { courier in
                                let count = shipmentVM.shipments.filter { $0.courier == courier.name }.count
                                HStack {
                                    Image(systemName: "box.truck")
                                        .foregroundColor(.blue)
                                    Text(courier.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(count) parcels")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("ShipEasy Dashboard")
            .refreshable {
                shipmentVM.startListening()
            }
        }
    }

    // MARK: - Reusable Stat Card View Builder
    /// Constructs a clean metric card with an SF Symbol icon and colored styling.
    private func statCard(title: String, value: String, unit: String, iconName: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(1)

                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}
