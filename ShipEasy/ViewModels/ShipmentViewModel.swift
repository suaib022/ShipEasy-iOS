import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Shipment ViewModel
/// Manages shipment data, connects with Cloud Firestore, calculates metrics, and computes delivery charges.
@MainActor
final class ShipmentViewModel: ObservableObject {

    // MARK: - Published Properties
    // @Published triggers UI updates whenever any of these arrays or values change.

    /// List of all shipments for the current seller, synchronized in real-time from Cloud Firestore.
    @Published var shipments: [Shipment] = []

    /// Available courier services loaded once from couriers.json.
    @Published var couriers: [CourierRate] = []

    /// Available districts in Bangladesh loaded once from districts.json.
    @Published var districts: [District] = []

    /// Indicates whether a network request or sync is in progress.
    @Published var isLoading: Bool = false

    /// Error message string to display in UI alerts.
    @Published var errorMessage: String?

    /// Active Firestore snapshot listener registration.
    private var listenerRegistration: ListenerRegistration?

    /// Reference to the shipment service singleton.
    private let shipmentService = ShipmentService.shared

    // MARK: - Initializer
    /// Initializes the ViewModel by reading bundled JSON files and binding the live Firestore listener.
    init() {
        loadStaticJSONData()
        startListening()
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Load JSON Resources
    /// Loads static courier rates and district lists from the application's bundle files.
    func loadStaticJSONData() {
        // Load courier pricing options from couriers.json
        self.couriers = JSONLoader.load("couriers.json")

        // Load Bangladesh districts from districts.json
        self.districts = JSONLoader.load("districts.json")
    }

    // MARK: - Real-time Firestore Sync
    /// Connects a live listener to fetch all shipments belonging to the logged-in user.
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.shipments = []
            return
        }

        isLoading = true
        listenerRegistration?.remove()

        listenerRegistration = shipmentService.listenToShipments(
            userId: userId,
            onUpdate: { [weak self] freshShipments in
                Task { @MainActor in
                    self?.shipments = freshShipments
                    self?.isLoading = false
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        )
    }

    // MARK: - Delivery Charge Calculation
    /// Computes shipping fee according to courier rate rules:
    /// Base zone fee (Inside Dhaka or Outside Dhaka) + (Extra per kg above 1 kg) * (weight - 1).
    func calculateDeliveryCharge(courierName: String, zone: String, weightKg: Double) -> Double {
        // Find matching courier from loaded JSON list (fallback to default if not found)
        let courier = couriers.first(where: { $0.name == courierName }) ?? couriers.first

        guard let rate = courier else {
            return zone == "Inside Dhaka" ? 60.0 : 120.0
        }

        let baseRate = (zone == "Inside Dhaka") ? rate.insideDhaka : rate.outsideDhaka
        let weight = max(1.0, weightKg)

        // Extra weight fee applies only for weight exceeding the first 1 kg
        let extraWeight = max(0.0, weight - 1.0)
        let extraCharge = extraWeight * rate.perExtraKg

        return baseRate + extraCharge
    }

    // MARK: - CRUD Actions

    /// Adds a newly created shipment to Cloud Firestore.
    func addShipment(_ shipment: Shipment) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await shipmentService.addShipment(shipment, for: userId)
        } catch {
            self.errorMessage = "Failed to add shipment: \(error.localizedDescription)"
        }
    }

    /// Updates existing shipment details in Cloud Firestore.
    func updateShipment(_ shipment: Shipment) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await shipmentService.updateShipment(shipment, for: userId)
        } catch {
            self.errorMessage = "Failed to update shipment: \(error.localizedDescription)"
        }
    }

    /// Deletes a shipment from Cloud Firestore.
    func deleteShipment(_ shipment: Shipment) async {
        guard let userId = Auth.auth().currentUser?.uid, let id = shipment.id else { return }
        do {
            try await shipmentService.deleteShipment(id: id, for: userId)
        } catch {
            self.errorMessage = "Failed to delete shipment: \(error.localizedDescription)"
        }
    }

    /// Changes shipment status and appends a StatusEvent with the current timestamp to the timeline.
    /// Enforces courier lifecycle rules to prevent invalid transitions (e.g., reverting to pending or editing returned).
    func changeStatus(shipment: Shipment, to newStatus: ShipmentStatus) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Ignore redundant triggers
        guard shipment.status != newStatus else { return }

        // Enforce business state machine transition rules
        guard shipment.status.canTransition(to: newStatus) else {
            self.errorMessage = "Invalid status update: Cannot transition from \(shipment.status.label) to \(newStatus.label)."
            return
        }

        // 1. Optimistic immediate update to local memory for instant UI response
        if let index = self.shipments.firstIndex(where: { $0.id == shipment.id }) {
            self.shipments[index].status = newStatus
            self.shipments[index].timeline.append(StatusEvent(status: newStatus, date: Date()))
        }

        // 2. Synchronize update to Cloud Firestore in the background
        do {
            try await shipmentService.updateStatus(shipment: shipment, newStatus: newStatus, for: userId)
        } catch {
            self.errorMessage = "Failed to change status: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Dashboard Statistics
    // These computed properties automatically re-evaluate when shipments array updates.

    /// Count of shipments created today.
    var todayCount: Int {
        let calendar = Calendar.current
        return shipments.filter { calendar.isDateInToday($0.createdAt) }.count
    }

    /// Count of shipments not yet delivered or returned (i.e. pending, picked up, in transit).
    var pendingCount: Int {
        return shipments.filter { $0.status != .delivered && $0.status != .returned }.count
    }

    /// Total cash on delivery amount currently in transit / pending collection.
    var codToCollect: Double {
        return shipments
            .filter { $0.status != .delivered && $0.status != .returned }
            .reduce(0.0) { $0 + $1.codAmount }
    }

    /// Total cash on delivery collected from all successfully delivered parcels.
    var codReceived: Double {
        return shipments
            .filter { $0.status == .delivered }
            .reduce(0.0) { $0 + $1.codAmount }
    }

    /// Net profit realized exclusively from delivered parcels.
    var totalProfit: Double {
        return shipments
            .filter { $0.status == .delivered }
            .reduce(0.0) { $0 + $1.profit }
    }

    /// Percentage of total parcels that were returned back to the seller.
    var returnRate: Double {
        guard !shipments.isEmpty else { return 0.0 }
        let returnedCount = shipments.filter { $0.status == .returned }.count
        return (Double(returnedCount) / Double(shipments.count)) * 100.0
    }
}
