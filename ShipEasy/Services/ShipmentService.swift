import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Shipment Firestore Service
/// Handles real-time database operations (Create, Read, Update, Delete) on Cloud Firestore.
/// All records are stored isolated per seller in the path: users/{uid}/shipments
final class ShipmentService {
    /// Shared singleton instance for convenient access across ViewModels.
    static let shared = ShipmentService()

    /// Reference to the Firestore database client.
    private let db = Firestore.firestore()

    private init() {}

    /// Helper to return the user's private shipments subcollection reference.
    private func shipmentsCollection(for userId: String) -> CollectionReference {
        return db.collection("users").document(userId).collection("shipments")
    }

    // MARK: - Real-time Listener (Read)

    /// Starts a real-time Firestore snapshot listener that automatically notifies whenever shipments change.
    /// - Parameters:
    ///   - userId: The current seller's unique user ID from Firebase Auth.
    ///   - onUpdate: Callback invoked with the fresh array of shipments whenever the collection changes.
    ///   - onError: Callback invoked if a network or security rule error occurs.
    /// - Returns: A ListenerRegistration handle that can be used to detach the listener when leaving the screen.
    func listenToShipments(
        userId: String,
        onUpdate: @escaping ([Shipment]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        return shipmentsCollection(for: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onError(error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    onUpdate([])
                    return
                }

                // Decode each document snapshot into our Shipment struct
                let shipments = documents.compactMap { doc -> Shipment? in
                    return Shipment(documentId: doc.documentID, dict: doc.data())
                }

                onUpdate(shipments)
            }
    }

    // MARK: - Add Shipment (Create)

    /// Adds a new shipment document to the seller's private subcollection.
    func addShipment(_ shipment: Shipment, for userId: String) async throws {
        _ = try await shipmentsCollection(for: userId).addDocument(data: shipment.toDictionary())
    }

    // MARK: - Update Shipment (Update)

    /// Updates an existing shipment document in Firestore with new information.
    func updateShipment(_ shipment: Shipment, for userId: String) async throws {
        guard let id = shipment.id else {
            print("⚠️ Cannot update shipment without document ID.")
            return
        }
        try await shipmentsCollection(for: userId).document(id).setData(shipment.toDictionary(), merge: true)
    }

    // MARK: - Update Status with Timeline

    /// Updates the status of a shipment and appends a new status event to its timeline.
    func updateStatus(shipment: Shipment, newStatus: ShipmentStatus, for userId: String) async throws {
        guard let id = shipment.id else { return }

        var updatedTimeline = shipment.timeline
        updatedTimeline.append(StatusEvent(status: newStatus, date: Date()))

        let timelineData = updatedTimeline.map { item -> [String: Any] in
            return [
                "status": item.status.rawValue,
                "date": item.date.timeIntervalSince1970
            ]
        }

        try await shipmentsCollection(for: userId).document(id).updateData([
            "status": newStatus.rawValue,
            "timeline": timelineData
        ])
    }

    // MARK: - Delete Shipment (Delete)

    /// Permanently removes a shipment document from Cloud Firestore.
    func deleteShipment(id: String, for userId: String) async throws {
        try await shipmentsCollection(for: userId).document(id).delete()
    }
}
