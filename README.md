# 📦 ShipEasy — Courier & Cash-on-Delivery (COD) Manager

A clean, production-grade iOS app built with **SwiftUI** (iOS 17+) and **Firebase** (Authentication & Cloud Firestore) for online sellers managing parcels, courier rates, and COD payments across Bangladesh.

---

## 🌟 Highlights & Features

- **Single User Role (The Seller)**:
  - Seller registration and login using Firebase Authentication.
  - Persistent auth session across app launches.
- **Dashboard Overview**:
  - Live metric cards: Today's Orders, Active / In-Transit, COD to Collect, COD Received, Net Profit, Return Rate %.
- **Shipment Management (CRUD)**:
  - Add new delivery orders with customer contact, address, district, weight, cost, and COD amount.
  - Automatic shipping charge calculation using courier pricing rules (Pathao, Steadfast, RedX, Sundarban).
  - Live profit calculation preview: `Profit = COD - Product Cost - Delivery Charge`.
  - Filter by delivery status and courier partner.
  - Instant search by customer name, phone number, or product.
  - Status progression tracking timeline with timestamps.
- **Explainable Architecture**:
  - Pure MVVM with plain-English comments above every type, property wrapper, and method.
  - Demonstrates `@main`, `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, and `@EnvironmentObject`.

---

## 📁 Project Architecture & Files

```
ShipEasy/
├── ShipEasy.xcodeproj/               # Xcode project file
├── README.md                         # Documentation & teacher presentation notes
├── .gitignore                        # Git ignore file protecting credentials & caches
└── ShipEasy/
    ├── ShipEasyApp.swift             # @main App entry point (FirebaseApp.configure, @StateObject authVM)
    ├── ContentView.swift             # Root router switching between Auth and MainTabView
    ├── GoogleService-Info.plist.example # Configuration template
    ├── Models/
    │   ├── Shipment.swift            # Core order model, ShipmentStatus enum, StatusEvent timeline
    │   └── CourierRate.swift         # Courier pricing and Bangladesh district models
    ├── Services/
    │   ├── JSONLoader.swift          # Generic Decodable loader for bundled resources
    │   └── ShipmentService.swift     # Firestore CRUD on collection "users/{uid}/shipments"
    ├── ViewModels/
    │   ├── AuthViewModel.swift       # ObservableObject managing login, sign-up, and session state
    │   └── ShipmentViewModel.swift   # ObservableObject managing shipments, calculations, and metrics
    ├── Views/
    │   ├── LoginView.swift           # Seller login screen with email and password fields
    │   ├── SignUpView.swift          # Seller account registration screen
    │   ├── HomeView.swift            # Dashboard showing the 6 statistical metric cards
    │   ├── ShipmentListView.swift    # Searchable and filterable parcel list with swipe-to-delete
    │   ├── AddShipmentView.swift     # Form for adding/editing shipments with live price calculations
    │   ├── ShipmentDetailView.swift  # Complete shipment inspection with @Binding StatusPicker & timeline
    │   └── ProfileView.swift         # Seller account profile and logout button
    └── Resources/
        ├── couriers.json             # Courier pricing data (inside Dhaka, outside Dhaka, extra kg)
        └── districts.json            # 10 Bangladesh districts with division names
```

---

## 🔒 Cloud Firestore Security Rules

Publish these security rules in your [Firebase Console](https://console.firebase.google.com/) under **Firestore Database ➔ Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/shipments/{shipmentId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 🚀 Setup Steps

1. Open `ShipEasy.xcodeproj` in Xcode 15 or 16 (iOS 17+).
2. In Firebase Console, create an iOS project with Bundle ID: `com.shipeasy.app`.
3. Enable **Email/Password** under **Authentication ➔ Sign-in method**.
4. Create a **Cloud Firestore** database.
5. Download your `GoogleService-Info.plist` and place it in the `ShipEasy/` directory.
6. Select an iOS Simulator (e.g., iPhone 15 or 16) and press **Cmd + R** to run.
