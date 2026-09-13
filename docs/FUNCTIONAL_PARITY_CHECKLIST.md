# FUNCTIONAL PARITY CHECKLIST: Concigo Admin v2

This document guarantees that **100% of the existing functionality** from the original project is accounted for and retained in the new architecture.

---

## 1. Receptionist / Desk Manager Role

| Feature ID | Feature Name | Original Location | v2 Location | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **REC-01** | Live Room Grid / Matrix | `room_management_widget.dart` | `features/reception/live_desk/` | Retained + Upgraded |
| **REC-02** | Room Status Updates (Vacant, Occupied, Cleaning, Maintenance) | `room_management_widget.dart` | `features/reception/live_desk/` | Retained + Upgraded |
| **REC-03** | Guest Search (Phone / Name / Code) | `search_booking_widget.dart` | `features/reception/live_desk/` & `arrivals_checkin/` | Retained + Upgraded |
| **REC-04** | KPI Header Cards (Occupancy, Revenue, Stays, Pending KYC) | `dashboard_screen.dart` | `features/reception/live_desk/` | Retained + Upgraded |
| **REC-05** | Pre-Check-in & KYC Document Verification | `pre_checkin_verification_widget.dart` | `features/reception/arrivals_checkin/` | Retained + Upgraded |
| **REC-06** | Manual Document Upload (Aadhaar/Passport/Driving License) | `pre_checkin_verification_widget.dart` | `features/reception/arrivals_checkin/` | Retained + Upgraded |
| **REC-07** | Document Image Viewer / Inspector | `pre_checkin_verification_widget.dart` | `features/reception/arrivals_checkin/` | Retained + Upgraded |
| **REC-08** | Instant Walk-In (Phone lookup, user create, stay create, instant activate) | `booking_management_widget.dart` | `features/reception/walk_in/` | Retained + Streamlined (30s UX) |
| **REC-09** | Upcoming Stays & Pre-arrival Allocations | `upcoming_stays_widget.dart` | `features/reception/arrivals_checkin/` | Retained + Upgraded |
| **REC-10** | Activate Stay (Generate check-in code, set status active) | `pre_checkin_verification_widget.dart` | `features/reception/arrivals_checkin/` & `walk_in/` | Retained + Upgraded |
| **REC-11** | Room Upgrades & Upgrade Payments | `room_upgrade_widget.dart` | `features/reception/upsells_offers/` | Retained + Upgraded |
| **REC-12** | In-Stay Offers Creation & Allotment | `create_offer_widget.dart` / `active_offers_widget.dart` | `features/reception/upsells_offers/` | Retained + Upgraded |
| **REC-13** | Early Check-In / Late Check-Out Requests | `dashboard_screen.dart` / `stay_details_dialog.dart` | `features/reception/upsells_offers/` | Retained + Upgraded |
| **REC-14** | Active Stays & Guest Folio View | `active_stays_widget.dart` / `stay_details_dialog.dart` | `features/reception/billing_departure/` | Retained + Upgraded |
| **REC-15** | Extend Stay / Change Checkout Date | `stay_details_dialog.dart` | `features/reception/billing_departure/` | Retained + Upgraded |
| **REC-16** | Billing, Surcharges & Payment Settlement | `billing_management_widget.dart` | `features/reception/billing_departure/` | Retained + Upgraded |
| **REC-17** | Invoice Generation & Payment Status | `billing_management_widget.dart` | `features/reception/billing_departure/` | Retained + Upgraded |
| **REC-18** | Departure / Checkout & Instant Room Release | `active_stays_widget.dart` | `features/reception/billing_departure/` | Retained + Upgraded |
| **REC-19** | Bellboy Luggage Queue Management | `bellboy_requests_widget.dart` | `features/reception/live_desk/` | Retained + Upgraded |
| **REC-20** | QR Code Generator for Guests | `qr_code_generator_widget.dart` | `features/reception/live_desk/` | Retained + Upgraded |

---

## 2. SuperAdmin Role

| Feature ID | Feature Name | Original Location | v2 Location | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **ADM-01** | Hotel Financial Overview & Multi-Department Analytics | `admin_dashboard_screen.dart` | `features/super_admin/` | Preserved 100% |
| **ADM-02** | User & Staff Management (Assign Roles, Deactivate Staff) | `admin_dashboard_screen.dart` | `features/super_admin/` | Preserved 100% |
| **ADM-03** | Room Category & Inventory Master Configuration | `admin_dashboard_screen.dart` | `features/super_admin/` | Preserved 100% |
| **ADM-04** | Global Hotel Settings & Policy Rules | `admin_dashboard_screen.dart` | `features/super_admin/` | Preserved 100% |

---

## 3. Service Manager & Service Employee Roles

| Feature ID | Feature Name | Original Location | v2 Location | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **SRV-01** | Service Request Board (Housekeeping, Maintenance, Dining) | `service_manager_dashboard_screen.dart` | `features/service_manager/` | Preserved 100% |
| **SRV-02** | Task Assignment to Specific Employees | `service_manager_dashboard_screen.dart` | `features/service_manager/` | Preserved 100% |
| **SRV-03** | Service Employee Task Execution & Status Transitions | `employee_dashboard_screen.dart` | `features/service_employee/` | Preserved 100% |
| **SRV-04** | Room Cleaning State Synchronization | `employee_dashboard_screen.dart` | `features/service_employee/` | Preserved 100% |

---

## 4. Spa Manager & Spa Employee Roles

| Feature ID | Feature Name | Original Location | v2 Location | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **SPA-01** | Spa Appointment Calendar & Booking Intake | `spa_manager_dashboard_screen.dart` | `features/spa_manager/` | Preserved 100% |
| **SPA-02** | Therapist Scheduling & Room Allocation | `spa_manager_dashboard_screen.dart` | `features/spa_manager/` | Preserved 100% |
| **SPA-03** | Spa Employee Daily Treatments & Completion Tracking | `spa_employee_dashboard_screen.dart` | `features/spa_employee/` | Preserved 100% |

---

## 5. Laundry Manager & Laundry Employee Roles

| Feature ID | Feature Name | Original Location | v2 Location | Parity Status |
| :--- | :--- | :--- | :--- | :--- |
| **LND-01** | Laundry Order Tracking (Washing, Dry Cleaning, Ironing) | `laundry_manager_dashboard_screen.dart` | `features/laundry_manager/` | Preserved 100% |
| **LND-02** | Order Assignment, Urgent Flagging & Delivery Scheduling | `laundry_manager_dashboard_screen.dart` | `features/laundry_manager/` | Preserved 100% |
| **LND-03** | Laundry Employee Stage Transitions (Received -> Done) | `laundry_employee_dashboard_screen.dart` | `features/laundry_employee/` | Preserved 100% |
