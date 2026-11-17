import SwiftUI

// MARK: - Add / Edit Shipment View
/// Form allowing a seller to create a new courier shipment or edit an existing one.
struct AddShipmentView: View {

    // MARK: - Dependencies & Environment
    /// @ObservedObject connects to the ViewModel for courier rates and CRUD methods.
    @ObservedObject var shipmentVM: ShipmentViewModel

    /// Optional existing shipment passed in when editing an existing parcel.
    var existingShipment: Shipment? = nil

    /// @Environment dismisses the sheet modal after saving or canceling.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local Form State
    // @State properties store transient form values while the user is typing.

    @State private var customerName: String = ""
    /// Pre-filled with Bangladesh country code (+880 ); cannot be erased and formats to +880 1x xxxx xxxx.
    @State private var phone: String = "+880 "
    @State private var address: String = ""

    /// Administrative division selector for convenient filtering across all 64 districts.
    @State private var selectedDivision: String = "Dhaka"
    @State private var district: String = "Dhaka"
    @State private var zone: String = "Inside Dhaka"

    @State private var productName: String = ""
    @State private var productCostText: String = ""
    @State private var codAmountText: String = ""
    /// Amount already paid by customer in advance via bKash / Nagad / Card.
    @State private var advancePaidText: String = ""
    /// Free-form custom decimal weight (e.g. 1.2 kg or 2.6 kg).
    @State private var weightText: String = "1.0"

    @State private var selectedCourier: String = "Pathao"
    @State private var createdAt: Date = Date()
    @State private var selectedStatus: ShipmentStatus = .pending

    @State private var showValidationError: Bool = false

    /// Indicates whether we are in Edit mode vs Create mode.
    private var isEditMode: Bool {
        existingShipment != nil
    }

    // MARK: - Dynamic Division & District Lists

    /// List of unique divisions sorted alphabetically.
    private var availableDivisions: [String] {
        let uniqueDivisions = Set(shipmentVM.districts.map { $0.division })
        let sorted = uniqueDivisions.sorted()
        return sorted.isEmpty ? ["Dhaka"] : sorted
    }

    /// List of districts filtered by the currently chosen division.
    private var filteredDistricts: [District] {
        let matching = shipmentVM.districts.filter { $0.division == selectedDivision }
        return matching.isEmpty ? shipmentVM.districts : matching
    }

    /// Parsed positive numeric weight in kilograms.
    private var effectiveWeight: Double {
        let parsed = Double(weightText.trimmingCharacters(in: .whitespaces)) ?? 1.0
        return max(0.1, parsed)
    }

    // MARK: - Live Computed Values

    /// Live delivery charge calculated instantly from courier rates and parcel weight.
    private var liveDeliveryCharge: Double {
        return shipmentVM.calculateDeliveryCharge(
            courierName: selectedCourier,
            zone: zone,
            weightKg: effectiveWeight
        )
    }

    /// Live estimated profit: (COD Amount + Advance Paid) - Product Cost - Delivery Charge.
    private var liveProfit: Double {
        let cod = Double(codAmountText) ?? 0.0
        let advance = Double(advancePaidText) ?? 0.0
        let cost = Double(productCostText) ?? 0.0
        return (cod + advance) - cost - liveDeliveryCharge
    }

    var body: some View {
        NavigationStack {
            Form {

                // 1. Customer Section
                Section("Customer Details") {
                    TextField("Full Name", text: $customerName)

                    HStack {
                        Text("Phone:")
                        TextField("+880 1X XXXX XXXX", text: $phone)
                            .keyboardType(.phonePad)
                            .onChange(of: phone) { _, newPhone in
                                let formatted = formatBDPhoneNumber(newPhone)
                                if phone != formatted {
                                    phone = formatted
                                }
                            }
                    }

                    TextField("Delivery Address", text: $address)
                }

                // 2. Location Section (Select Division first, then District)
                Section("Delivery Location") {
                    Picker("Division", selection: $selectedDivision) {
                        ForEach(availableDivisions, id: \.self) { div in
                            Text(div).tag(div)
                        }
                    }
                    .onChange(of: selectedDivision) { _, newDivision in
                        // When division changes, auto-select its first available district
                        let matching = shipmentVM.districts.filter { $0.division == newDivision }
                        if let firstInDivision = matching.first {
                            district = firstInDivision.name
                            updateZone(for: firstInDivision.name)
                        }
                    }

                    Picker("District", selection: $district) {
                        ForEach(filteredDistricts) { dist in
                            Text(dist.name).tag(dist.name)
                        }
                    }
                    .onChange(of: district) { _, newDistrict in
                        updateZone(for: newDistrict)
                    }

                    Picker("Zone", selection: $zone) {
                        Text("Inside Dhaka").tag("Inside Dhaka")
                        Text("Outside Dhaka").tag("Outside Dhaka")
                    }
                    .pickerStyle(.segmented)
                }

                // 3. Parcel & Cost Section
                Section("Parcel & Cost") {
                    TextField("Product Name / Items", text: $productName)

                    HStack {
                        Text("Product Cost (Wholesale):")
                        Spacer()
                        TextField("0", text: $productCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Advance Paid / Prepaid:")
                        Spacer()
                        TextField("0", text: $advancePaidText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Cash on Delivery (COD):")
                        Spacer()
                        TextField("0", text: $codAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    // Package Weight: Clean native UI (No dark/black border box)
                    HStack {
                        Text("Package Weight:")
                        Spacer()

                        TextField("1.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 50, maxWidth: 80)

                        Text("kg")
                            .foregroundColor(.secondary)

                        Stepper("", value: Binding(
                            get: { effectiveWeight },
                            set: { newValue in weightText = String(format: "%.1f", max(0.1, newValue)) }
                        ), in: 0.1...50.0, step: 0.1)
                        .labelsHidden()
                    }
                }

                // 4. Courier Selection
                Section("Courier Partner") {
                    Picker("Courier", selection: $selectedCourier) {
                        ForEach(shipmentVM.couriers) { courier in
                            Text(courier.name).tag(courier.name)
                        }
                    }

                    DatePicker("Order Created On", selection: $createdAt, displayedComponents: [.date, .hourAndMinute])
                }

                // 5. Live Calculation Preview Section
                Section("Financial Summary (Live Preview)") {
                    HStack {
                        Text("Estimated Delivery Charge:")
                        Spacer()
                        Text("৳\(String(format: "%.2f", liveDeliveryCharge))")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Estimated Net Profit:")
                        Spacer()
                        Text("৳\(String(format: "%.2f", liveProfit))")
                            .fontWeight(.bold)
                            .foregroundColor(liveProfit >= 0 ? .green : .red)
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Shipment" : "New Shipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save Changes" : "Create Order") {
                        saveShipment()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Missing / Invalid Fields", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please fill in Customer Name, complete Phone Number (+880 1x xxxx xxxx), and Product Name.")
            }
            .onAppear {
                prefillExistingIfPresent()
            }
        }
    }

    // MARK: - Auto-Adjust Zone
    /// Automatically assigns "Inside Dhaka" or "Outside Dhaka" based on the district.
    private func updateZone(for districtName: String) {
        if districtName.caseInsensitiveCompare("Dhaka") == .orderedSame {
            zone = "Inside Dhaka"
        } else {
            zone = "Outside Dhaka"
        }
    }

    // MARK: - Phone Number Formatter
    /// Formats input to enforce: +880 1x xxxx xxxx
    /// 1. Locks the '+880 ' prefix so it cannot be deleted.
    /// 2. Limits digits to at most 10 subscriber digits (equivalent to an 11-digit local 01xxxxxxxxx number).
    /// 3. Applies the spacing style: +880 1x xxxx xxxx
    private func formatBDPhoneNumber(_ input: String) -> String {
        var raw = input

        // If user attempted to delete into "+880 " (or cleared the field), keep "+880 " locked
        if !raw.hasPrefix("+880 ") {
            if raw == "+880" || raw.hasPrefix("+88") || raw.hasPrefix("+8") || raw == "+" || raw.isEmpty {
                return "+880 "
            }
            if raw.hasPrefix("+880") {
                raw.removeFirst(4)
            } else if raw.hasPrefix("880") {
                raw.removeFirst(3)
            }
        } else {
            raw.removeFirst(5)
        }

        // Filter for numeric characters only
        var digits = raw.filter { $0.isNumber }

        // If user entered local leading 0 (e.g. 017...), strip the 0
        if digits.hasPrefix("0") {
            digits.removeFirst()
        }

        // Max 10 subscriber digits (1x xxxx xxxx)
        if digits.count > 10 {
            digits = String(digits.prefix(10))
        }

        var formatted = "+880 "
        let count = digits.count

        if count == 0 {
            return formatted
        } else if count <= 2 {
            // e.g. +880 1 or +880 17
            formatted.append(digits)
        } else if count <= 6 {
            // e.g. +880 17 1234
            let p1 = digits.prefix(2)
            let p2 = digits.dropFirst(2)
            formatted.append("\(p1) \(p2)")
        } else {
            // e.g. +880 17 1234 5678
            let p1 = digits.prefix(2)
            let midStart = digits.index(digits.startIndex, offsetBy: 2)
            let midEnd = digits.index(digits.startIndex, offsetBy: 6)
            let p2 = digits[midStart..<midEnd]
            let p3 = digits.suffix(from: midEnd)
            formatted.append("\(p1) \(p2) \(p3)")
        }

        return formatted
    }

    // MARK: - Save Action
    private func saveShipment() {
        let cleanName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check that phone has subscriber digits
        let subscriberDigits = cleanPhone.filter { $0.isNumber }.dropFirst(3) // removes 880
        if cleanName.isEmpty || subscriberDigits.count < 10 || cleanProduct.isEmpty {
            showValidationError = true
            return
        }

        let cost = Double(productCostText) ?? 0.0
        let cod = Double(codAmountText) ?? 0.0
        let advance = Double(advancePaidText) ?? 0.0
        let finalWeight = effectiveWeight

        if var existing = existingShipment {
            // Update mode
            existing.customerName = cleanName
            existing.phone = cleanPhone
            existing.address = address
            existing.district = district
            existing.zone = zone
            existing.productName = cleanProduct
            existing.productCost = cost
            existing.weightKg = finalWeight
            existing.codAmount = cod
            existing.advancePaid = advance
            existing.courier = selectedCourier
            existing.deliveryCharge = liveDeliveryCharge

            Task {
                await shipmentVM.updateShipment(existing)
                dismiss()
            }
        } else {
            // Create mode
            let newShipment = Shipment(
                customerName: cleanName,
                phone: cleanPhone,
                address: address,
                district: district,
                productName: cleanProduct,
                productCost: cost,
                weightKg: finalWeight,
                codAmount: cod,
                advancePaid: advance,
                courier: selectedCourier,
                zone: zone,
                deliveryCharge: liveDeliveryCharge,
                status: .pending,
                createdAt: createdAt
            )

            Task {
                await shipmentVM.addShipment(newShipment)
                dismiss()
            }
        }
    }

    // MARK: - Pre-fill Data in Edit Mode
    private func prefillExistingIfPresent() {
        if let existing = existingShipment {
            customerName = existing.customerName
            phone = formatBDPhoneNumber(existing.phone)
            address = existing.address
            district = existing.district
            zone = existing.zone
            productName = existing.productName
            productCostText = existing.productCost > 0 ? String(format: "%.0f", existing.productCost) : ""
            codAmountText = existing.codAmount > 0 ? String(format: "%.0f", existing.codAmount) : ""
            advancePaidText = existing.advancePaid > 0 ? String(format: "%.0f", existing.advancePaid) : ""
            weightText = String(format: "%.1f", existing.weightKg)
            selectedCourier = existing.courier
            createdAt = existing.createdAt
            selectedStatus = existing.status

            // Sync the division dropdown with the district
            if let matchedDistrict = shipmentVM.districts.first(where: { $0.name == existing.district }) {
                selectedDivision = matchedDistrict.division
            }
        } else {
            phone = "+880 "
            if let firstCourier = shipmentVM.couriers.first {
                selectedCourier = firstCourier.name
            }
        }
    }
}
