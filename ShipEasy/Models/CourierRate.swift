import Foundation

// MARK: - Courier Rate Model
/// Represents pricing and delivery charge rules for a specific courier company.
struct CourierRate: Identifiable, Codable, Hashable {
    /// Use the courier name as the unique identifier.
    var id: String { name }

    /// Brand name of the courier service (e.g., "Pathao", "Steadfast").
    let name: String

    /// Base rate in BDT for standard deliveries inside Dhaka city.
    let insideDhaka: Double

    /// Base rate in BDT for deliveries outside Dhaka to other districts.
    let outsideDhaka: Double

    /// Additional fee in BDT charged per kilogram for parcel weights exceeding 1 kg.
    let perExtraKg: Double

    /// Optional descriptive note or disclaimer.
    let note: String?
}

// MARK: - District Model
/// Represents a geographical district and its administrative division in Bangladesh.
struct District: Identifiable, Codable, Hashable {
    /// Use district name as the unique identifier.
    var id: String { name }

    /// Name of the district (e.g., "Dhaka", "Chattogram").
    let name: String

    /// Administrative division containing this district (e.g., "Dhaka", "Chittagong").
    let division: String
}
