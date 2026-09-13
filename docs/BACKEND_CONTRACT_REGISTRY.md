# BACKEND CONTRACT REGISTRY: Concigo Admin v2

This registry maps every single backend table, RPC, Edge Function, and Supabase service method used by the client. 
**RULE: All backend contracts are immutable and strictly protected.**

---

## 1. Supabase Database Tables & Client Usage

| Table Name | Primary Methods / Queries | Domain Service |
| :--- | :--- | :--- |
| `stays` | `fetchUpcomingStays`, `fetchActiveStays`, `createStay`, `activateStay`, `completeCheckout`, `updateStayDates` | `StayService` |
| `rooms` | `fetchRooms`, `updateRoomStatus`, `updateRoomBookingStatus`, `fetchAvailableRooms` | `RoomService` |
| `users` | `getOrCreateUser`, `fetchUserProfile`, `updateUserDetails`, `verifyUserPhone` | `GuestService` / `AuthService` |
| `kyc_documents` | `fetchKYCDocuments`, `verifyKYCDocument`, `rejectKYCDocument`, `uploadKYCDocument` | `GuestService` |
| `billing_details` | `fetchBillingDetails`, `createBillingEntry`, `updateBillingStatus`, `recordPayment` | `BillingService` |
| `offers` | `fetchActiveOffers`, `createOffer`, `assignOfferToStay`, `deleteOffer` | `OfferService` |
| `room_upgrades` | `fetchRoomUpgrades`, `requestRoomUpgrade`, `approveRoomUpgrade`, `processUpgradePayment` | `RoomService` / `OfferService` |
| `bellboy_requests` | `fetchLuggageRequests`, `updateLuggageStatus`, `assignLuggageRequest` | `BellboyService` |
| `service_requests` | `fetchServiceRequests`, `assignServiceRequest`, `updateServiceStatus` | `ServiceRepository` |
| `spa_appointments` | `fetchSpaAppointments`, `createSpaAppointment`, `updateSpaAppointmentStatus` | `SpaRepository` |
| `laundry_orders` | `fetchLaundryOrders`, `createLaundryOrder`, `updateLaundryOrderStatus` | `LaundryRepository` |

---

## 2. Supabase Storage Buckets

| Bucket Name | Purpose | Operations |
| :--- | :--- | :--- |
| `kyc-documents` | Guest physical identity verification proofs (Passport, Aadhaar, Driving License) | Read / Signed URLs / Direct Upload |
| `invoices` | Generated PDF bills & payment receipt attachments | Read / Download |
| `hotel-assets` | Room photos, offer banners, hotel branding assets | Read / Cached |

---

## 3. Remote Procedure Calls (RPCs) & Edge Functions

| Function / RPC | Expected Parameters | Return Type | Business Purpose |
| :--- | :--- | :--- | :--- |
| `get_or_create_user_by_phone` | `phone_number: text`, `full_name: text`, `email: text?` | `json / user_record` | Atomic guest profile resolver during Walk-In |
| `activate_stay_atomic` | `stay_id: uuid`, `room_number: text`, `checkin_code: text` | `boolean` | Atomic check-in state transition and room occupancy lock |
| `process_departure_atomic` | `stay_id: uuid`, `room_id: uuid` | `boolean` | Settles folio, marks stay completed, transitions room to cleaning |
| `send_stay_notification` | `user_id: uuid`, `title: text`, `body: text` | `json` | Edge function triggering push / SMS notification |

---

## 4. Domain Service Decomposition Plan

The monolithic `SupabaseService` (3,072 lines) is mapped to clean, single-responsibility repositories without altering any query logic or SQL structures:

```
SupabaseService (Monolith)
 ├── Auth & Profiles        --> data/services/auth_service.dart
 ├── Stays & Reservations   --> data/services/stay_service.dart
 ├── Rooms & Inventory      --> data/services/room_service.dart
 ├── KYC & Guests           --> data/services/guest_service.dart
 ├── Billing & Invoices     --> data/services/billing_service.dart
 ├── Upsells & Offers       --> data/services/offer_service.dart
 ├── Bellboy & Luggage      --> data/services/bellboy_service.dart
 └── Analytics & Metrics    --> data/services/analytics_service.dart
```
