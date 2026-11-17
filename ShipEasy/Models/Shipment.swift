import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Shipment Status Enum
/// Represents the different stages of a shipment from order to delivery or return.
enum ShipmentStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case pickedUp = "pickedUp"
    case inTransit = "inTransit"
    case delivered = "delivered"
    case returned = "returned"

    /// Plain English title for display in the user interface.
    var label: String {
        switch self {
        case .pending: return "Pending"
        case .pickedUp: return "Picked Up"
        case .inTransit: return "In Transit"
        case .delivered: return "Delivered"
        case .returned: return "Returned"
        }
    }

    /// SF Symbol icon name representing the status (no emojis used).
    var symbolName: String {
        switch self {
        case .pending: return "clock"
        case .pickedUp: return "shippingbox"
        case .inTransit: return "truck.box"
        case .delivered: return "checkmark.seal"
        case .returned: return "arrow.uturn.backward.circle"
        }
    }

    /// Color representing this status in badges and icons.
    var statusColor: Color {
        switch self {
        case .pending: return Color.orange
        case .pickedUp: return Color.blue
        case .inTransit: return Color.purple
        case .delivered: return Color.green
        case .returned: return Color.red
        }
    }

    // MARK: - Status Lifecycle & State Machine Rules
    /// Returns the allowed next statuses based on courier delivery lifecycle rules:
    /// 1. Once updated from pending, an order cannot be reverted to pending from any state.
    /// 2. In Transit cannot go back to Picked Up or Pending.
    /// 3. Delivered cannot go back to Pending, Picked Up, or In Transit (only Returned is allowed if customer returns item).
    /// 4. Returned is a terminal state and cannot transition to any other state.
    var validNextStatuses: [ShipmentStatus] {
        switch self {
        case .pending:
            // An uncollected parcel can be picked up, directly routed, or cancelled/returned
            return [.pickedUp, .inTransit, .returned]
        case .pickedUp:
            // Once picked up, parcel cannot return to pending
            return [.inTransit, .delivered, .returned]
        case .inTransit:
            // In transit parcel cannot go back to pending or pickedUp
            return [.delivered, .returned]
        case .delivered:
            // Delivered cannot revert to pending, pickedUp, or inTransit
            return [.returned]
        case .returned:
            // Terminal state: returned parcels cannot transition anywhere
            return []
        }
    }

    /// Indicates whether this status is a terminal state (no further transitions allowed).
    var isTerminal: Bool {
        return validNextStatuses.isEmpty
    }

    /// Validates whether transitioning to a target status is permitted under business rules.
    func canTransition(to target: ShipmentStatus) -> Bool {
        if self == target { return true }
        return validNextStatuses.contains(target)
    }
}

// MARK: - Status Event Model
/// Records a specific timestamp when a shipment changed status for its tracking timeline.
struct StatusEvent: Codable, Hashable {
    /// The new status reached.
    var status: ShipmentStatus
    /// The date and time when this status was assigned.
    var date: Date
}

// MARK: - Shipment Model
/// Core data model representing a customer order and courier delivery.
struct Shipment: Identifiable, Codable {
    /// Unique identifier from Firestore document ID.
    var id: String?

    /// Customer's full name.
    var customerName: String

    /// Customer's mobile contact number.
    var phone: String

    /// Street or home delivery address.
    var address: String

    /// Destination district in Bangladesh (e.g., Dhaka, Chattogram).
    var district: String

    /// Name or short description of the product sold.
    var productName: String

    /// Wholesale / purchase cost paid by the seller for the product.
    var productCost: Double

    /// Total package weight in kilograms.
    var weightKg: Double

    /// Cash on delivery amount to be collected from the customer upon delivery.
    var codAmount: Double

    /// Amount already paid by customer in advance while placing order (e.g. via bKash / Nagad).
    var advancePaid: Double

    /// Courier partner handling delivery (e.g., Pathao, Steadfast).
    var courier: String

    /// Delivery zone: "Inside Dhaka" or "Outside Dhaka".
    var zone: String

    /// Calculated delivery charge billed by the courier.
    var deliveryCharge: Double

    /// Current shipment progress status.
    var status: ShipmentStatus

    /// When the shipment record was first created.
    var createdAt: Date

    /// Complete history of status updates with timestamps.
    var timeline: [StatusEvent]

    /// Simple profit calculation: (COD Amount + Advance Paid) minus product cost and delivery fee.
    var profit: Double {
        return (codAmount + advancePaid) - productCost - deliveryCharge
    }

    // Default initializer with default values for easy creation
    init(
        id: String? = nil,
        customerName: String,
        phone: String,
        address: String,
        district: String,
        productName: String,
        productCost: Double,
        weightKg: Double,
        codAmount: Double,
        advancePaid: Double = 0.0,
        courier: String,
        zone: String,
        deliveryCharge: Double,
        status: ShipmentStatus = .pending,
        createdAt: Date = Date(),
        timeline: [StatusEvent] = []
    ) {
        self.id = id
        self.customerName = customerName
        self.phone = phone
        self.address = address
        self.district = district
        self.productName = productName
        self.productCost = productCost
        self.weightKg = weightKg
        self.codAmount = codAmount
        self.advancePaid = advancePaid
        self.courier = courier
        self.zone = zone
        self.deliveryCharge = deliveryCharge
        self.status = status
        self.createdAt = createdAt
        // If no timeline was passed, initialize with the current pending event
        self.timeline = timeline.isEmpty ? [StatusEvent(status: status, date: createdAt)] : timeline
    }

    // MARK: - Codable Handling
    enum CodingKeys: String, CodingKey {
        case id, customerName, phone, address, district, productName
        case productCost, weightKg, codAmount, advancePaid, courier
        case zone, deliveryCharge, status, createdAt, timeline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.customerName = try container.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.district = try container.decodeIfPresent(String.self, forKey: .district) ?? "Dhaka"
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName) ?? ""
        self.productCost = try container.decodeIfPresent(Double.self, forKey: .productCost) ?? 0.0
        self.weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 1.0
        self.codAmount = try container.decodeIfPresent(Double.self, forKey: .codAmount) ?? 0.0
        self.advancePaid = try container.decodeIfPresent(Double.self, forKey: .advancePaid) ?? 0.0
        self.courier = try container.decodeIfPresent(String.self, forKey: .courier) ?? "Pathao"
        self.zone = try container.decodeIfPresent(String.self, forKey: .zone) ?? "Inside Dhaka"
        self.deliveryCharge = try container.decodeIfPresent(Double.self, forKey: .deliveryCharge) ?? 60.0
        self.status = try container.decodeIfPresent(ShipmentStatus.self, forKey: .status) ?? .pending
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.timeline = try container.decodeIfPresent([StatusEvent].self, forKey: .timeline) ?? []
    }

    // Initialize from Firestore document dictionary
    init?(documentId: String, dict: [String: Any]) {
        self.id = documentId
        self.customerName = dict["customerName"] as? String ?? ""
        self.phone = dict["phone"] as? String ?? ""
        self.address = dict["address"] as? String ?? ""
        self.district = dict["district"] as? String ?? "Dhaka"
        self.productName = dict["productName"] as? String ?? ""
        self.productCost = dict["productCost"] as? Double ?? 0.0
        self.weightKg = dict["weightKg"] as? Double ?? 1.0
        self.codAmount = dict["codAmount"] as? Double ?? 0.0
        self.advancePaid = dict["advancePaid"] as? Double ?? 0.0
        self.courier = dict["courier"] as? String ?? "Pathao"
        self.zone = dict["zone"] as? String ?? "Inside Dhaka"
        self.deliveryCharge = dict["deliveryCharge"] as? Double ?? 60.0

        if let rawStatus = dict["status"] as? String,
           let parsedStatus = ShipmentStatus(rawValue: rawStatus) {
            self.status = parsedStatus
        } else {
            self.status = .pending
        }

        if let timestamp = dict["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.createdAt = Date()
        }

        if let rawTimeline = dict["timeline"] as? [[String: Any]] {
            self.timeline = rawTimeline.compactMap { item in
                guard let rawSt = item["status"] as? String,
                      let st = ShipmentStatus(rawValue: rawSt),
                      let dateNum = item["date"] as? TimeInterval else {
                    return nil
                }
                return StatusEvent(status: st, date: Date(timeIntervalSince1970: dateNum))
            }
        } else {
            self.timeline = [StatusEvent(status: self.status, date: self.createdAt)]
        }
    }

    // Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        let timelineDicts = timeline.map { item -> [String: Any] in
            return [
                "status": item.status.rawValue,
                "date": item.date.timeIntervalSince1970
            ]
        }

        return [
            "customerName": customerName,
            "phone": phone,
            "address": address,
            "district": district,
            "productName": productName,
            "productCost": productCost,
            "weightKg": weightKg,
            "codAmount": codAmount,
            "advancePaid": advancePaid,
            "courier": courier,
            "zone": zone,
            "deliveryCharge": deliveryCharge,
            "status": status.rawValue,
            "createdAt": createdAt.timeIntervalSince1970,
            "timeline": timelineDicts
        ]
    }
}
