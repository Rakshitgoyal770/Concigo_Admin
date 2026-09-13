# RECEPTION NAVIGATION MAP: Concigo Admin v2

This document maps the consolidation of the legacy 15-section Reception dashboard into four streamlined, high-speed operational hubs.

---

## 1. High-Level Consolidation Overview

```
+-----------------------------------------------------------------------------------------------+
|                                    RECEPTION GLOBAL SHELL                                     |
|  [Logo & Hotel Name]   [Quick Global Search (Phone/Room)]   [Active Shift / Receptionist]     |
+-----------------------------------------------------------------------------------------------+
|                                                                                               |
|  [ 🏨 LIVE FRONT DESK ]  [ 🛎️ ARRIVALS & CHECK-IN ]  [ 💎 UPSELLS & OFFERS ]  [ 🧾 BILLING ]  |
|                                                                                               |
+-----------------------------------------------------------------------------------------------+
```

---

## 2. Legacy Section Mapping to 4 Operational Hubs

### Hub 1: 🏨 Live Front Desk
* **Purpose**: Real-time room occupancy overview, daily KPIs, quick status updates, bellboy queue, and instant guest lookup.
* **Consolidated Legacy Components**:
  1. `RoomManagementWidget` (Room status matrix: Vacant, Occupied, Cleaning, Maintenance)
  2. `DashboardScreen KPIs` (Total Rooms, Occupied %, Expected Arrivals, Checkouts)
  3. `BellboyRequestsWidget` (Luggage pickup / delivery queue)
  4. `SearchBookingWidget` (Instant phone / room / booking search)
  5. `QrCodeGeneratorWidget` (Desk QR code for guest digital companion)

---

### Hub 2: 🛎️ Arrivals & Check-In
* **Purpose**: High-speed check-in operations, physical walk-ins, digital pre-check-in approval, KYC verification, and stay activation.
* **Consolidated Legacy Components**:
  1. **Instant Walk-In Engine** (30-second workflow: Phone → Guest → Room → Dates → Tariff → Activate)
  2. `PreCheckinVerificationWidget` (Pending KYC list, document inspector, manual upload, instant approve/reject)
  3. `UpcomingStaysWidget` (Today's scheduled arrivals, advance allocations)
  4. `StayActivationFlow` (Generate code, room key allocation, physical ID check)

---

### Hub 3: 💎 Upsells & Offers
* **Purpose**: Maximizing hotel revenue per room through dynamic upgrades, packages, and stay extensions.
* **Consolidated Legacy Components**:
  1. `RoomUpgradeWidget` (Category upgrades, differential pricing, payment allotment)
  2. `CreateOfferWidget` (New discount packages, dining deals, spa bundles)
  3. `ActiveOffersWidget` (Assigned offers per room, expiration tracking)
  4. **Early Check-In / Late Check-Out Engine** (Hourly surcharges & automatic folio addition)

---

### Hub 4: 🧾 Billing & Departure
* **Purpose**: Complete financial folios, payment collection, invoice generation, checkout completion, and automatic room release.
* **Consolidated Legacy Components**:
  1. `ActiveStaysWidget` (In-house guests list & active stays)
  2. `StayDetailsDialog` (Stay extension, date modifications, guest preferences)
  3. `BillingManagementWidget` (Itemized charges, restaurant/service bills, tax calculation)
  4. **Payment Settlement** (Cash, Card, UPI, Room Charge)
  5. **Checkout & Instant Room Release** (Marks stay completed, sets room to "Needs Cleaning", triggers bellboy)
