# ROLE CAPABILITY MATRIX: Concigo Admin v2

This matrix defines the security and functional boundaries for all 8 authenticated roles across the platform.

---

| Feature Area / Capability | SuperAdmin | Reception Desk | Service Manager | Service Employee | Spa Manager | Spa Employee | Laundry Manager | Laundry Employee |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Hotel Financial Analytics & KPIs** |  Full |  Front-Desk Only |  Dept Only | ❌ None |  Dept Only | ❌ None |  Dept Only | ❌ None |
| **Staff & User Management** |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Room Inventory & Configuration** |  Full |  Status Only | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Live Room Matrix & Status Toggle**|  View |  Full |  Clean/Maint |  Clean/Maint | ❌ None | ❌ None | ❌ None | ❌ None |
| **Instant Walk-In & Guest Creation**|  Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Pre-Check-in & KYC Document Review**| Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Stay Activation & Check-in Codes** | Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Room Upgrades & Payment Allotment**| Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **In-Stay Offers & Package Deals** |  Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Billing, Folios & Departure Release**| Full |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Bellboy Luggage Dispatch Queue** |  View |  Full | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Service Request Dispatch & Assign**|  View |  Create |  Full |  Execute | ❌ None | ❌ None | ❌ None | ❌ None |
| **Spa Booking & Therapist Scheduling**| View |  View | ❌ None | ❌ None |  Full |  Execute | ❌ None | ❌ None |
| **Laundry Orders & Stage Tracking** |  View |  View | ❌ None | ❌ None | ❌ None | ❌ None |  Full |  Execute |

---

## Access & Route Guarding Strategy

1. **Authentication Guard**: Validates active Supabase session upon launch.
2. **Role Resolver**: Reads user metadata & role table (`role: superadmin | desk_manager | service_manager | service_employee | spa_manager | spa_employee | laundry_manager | laundry_employee`).
3. **Shell Router**: Dispatches directly to the designated Role Dashboard Shell.
4. **Safety Net**: If an unauthorized role attempts deep link traversal to another role route, it falls back gracefully to their authorized primary dashboard.
