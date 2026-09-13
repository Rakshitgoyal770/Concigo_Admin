# ARCHITECTURE MAP: Concigo Admin v2

## 1. High-Level Architectural Evolution

```
========================= AS-IS (Monolithic) =========================
+--------------------------------------------------------------------+
| UI Layer: StatefulWidgets (15 Dashboard Sub-widgets in Reception)  |
| - setState() everywhere for local state & cross-component triggers |
| - Ad-hoc dialogs, scattered forms, duplicated validation logic     |
+--------------------------------------------------------------------+
                                  |
                                  v
+--------------------------------------------------------------------+
| Monolithic Service: `SupabaseService` (3,072 lines, 100+ methods)  |
| - Mixed concerns: Auth, Stays, Rooms, KYC, Billing, Realtime, Push |
+--------------------------------------------------------------------+
                                  |
                                  v
+--------------------------------------------------------------------+
| Backend: Supabase (PostgreSQL, RLS, RPCs, Edge Functions, Storage) |
+--------------------------------------------------------------------+

======================= TO-BE (Modular / Clean) ======================
+--------------------------------------------------------------------+
| Presentation Layer:                                                |
| - Luxury Design System (Soft Slate palette, Plus Jakarta Sans)     |
| - 4 Consolidated Reception Hubs (Live Desk, Arrivals, Upsells,     |
|   Billing/Departure) + Modernized Shell for All 8 Roles            |
| - ConsumerWidgets / Riverpod State Management                      |
+--------------------------------------------------------------------+
                                  |
                                  v
+--------------------------------------------------------------------+
| Application / State Layer (Riverpod Providers):                    |
| - `live_desk_provider.dart`                                        |
| - `arrivals_checkin_provider.dart`                                 |
| - `walk_in_provider.dart`                                          |
| - `upsells_offers_provider.dart`                                   |
| - `billing_departure_provider.dart`                                |
| - `auth_state_provider.dart`                                       |
+--------------------------------------------------------------------+
                                  |
                                  v
+--------------------------------------------------------------------+
| Domain Service Layer (Single-Responsibility Repositories):         |
| - `StayService`       (createStay, activateStay, updateDates)      |
| - `RoomService`       (fetchRooms, updateRoomStatus, upgrades)     |
| - `GuestService`      (getOrCreateUser, uploadKYC, guestSearch)    |
| - `BillingService`    (fetchBilling, createInvoice, recordPayment) |
| - `OfferService`      (fetchOffers, createOffer, upsellApply)      |
| - `BellboyService`    (fetchLuggageRequests, updateStatus)         |
| - `AuthService`       (login, session, roleVerification)           |
| - `AnalyticsService`  (KPI metrics, revenue, occupancy stats)      |
+--------------------------------------------------------------------+
                                  | (Shared Supabase Client)
                                  v
+--------------------------------------------------------------------+
| Supabase Backend (PROTECTED / 100% UNTOUCHED):                     |
| - Tables, RPCs, Edge Functions, RLS, Storage Buckets               |
+--------------------------------------------------------------------+
```

## 2. Directory Layout Comparison

### Previous Layout
```
lib/
├── main.dart
├── routes/
│   └── app_routes.dart
├── services/
│   ├── supabase_service.dart (3072 lines)
│   ├── auth_service.dart
│   └── ...
├── theme/
│   └── ...
├── utils/
└── presentation/
    ├── dashboard_screen/
    │   ├── dashboard_screen.dart
    │   └── widgets/ (15 fragmented widgets)
    ├── admin_dashboard_screen/
    ├── employee_dashboard_screen/
    ├── service_manager_dashboard_screen/
    ├── spa_manager_dashboard_screen/
    ├── spa_employee_dashboard_screen/
    ├── laundry_manager_dashboard_screen/
    ├── laundry_employee_dashboard_screen/
    └── ...
```

### v2 Modern Modular Layout
```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        (Luxury Soft Palette)
│   │   ├── app_typography.dart    (Plus Jakarta Sans & JetBrains Mono)
│   │   └── app_spacing.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── component_styles.dart
│   ├── routing/
│   │   └── app_router.dart
│   └── widgets/
│       ├── luxury_card.dart
│       ├── luxury_badge.dart
│       ├── luxury_button.dart
│       ├── luxury_text_field.dart
│       ├── metric_card.dart
│       └── custom_icon_widget.dart (Preserved SVG mapper)
├── data/
│   ├── models/
│   └── services/
│       ├── supabase_client_provider.dart
│       ├── auth_service.dart
│       ├── stay_service.dart
│       ├── room_service.dart
│       ├── guest_service.dart
│       ├── billing_service.dart
│       ├── offer_service.dart
│       ├── bellboy_service.dart
│       └── analytics_service.dart
├── features/
│   ├── auth/
│   ├── reception/
│   │   ├── shell/
│   │   ├── live_desk/
│   │   ├── arrivals_checkin/
│   │   ├── walk_in/
│   │   ├── upsells_offers/
│   │   └── billing_departure/
│   ├── super_admin/
│   ├── service_manager/
│   ├── service_employee/
│   ├── spa_manager/
│   ├── spa_employee/
│   ├── laundry_manager/
│   └── laundry_employee/
└── legacy/ (Backward-compatibility bridging for unmigrated screens)
```
