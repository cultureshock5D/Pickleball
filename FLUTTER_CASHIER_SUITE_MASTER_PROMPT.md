# Master Prompt: Complete C&J Cashier Terminal Suite in Flutter / Dart

> **Target Platform**: Flutter (Tablet / Desktop / Mobile - Optimized for 10"-12" POS Tablets)  
> **Target Persona**: Cashier, Front Desk Staff, Duty Supervisor  
> **Backend Engine**: Supabase (PostgreSQL, Realtime Channels, Supabase Auth, Row Level Security)  
> **Scope**: The 5 Cashier Operations Modules:  
> 1. **POS Register** (`/cashier`)  
> 2. **Daily Court Schedule & Walk-in Terminal** (`/cashier/schedule`)  
> 3. **Inventory & Volume Dispensing Table** (`/cashier/inventory`)  
> 4. **Daily Expenses & Cash Drawer Margin** (`/cashier/expenses`)  
> 5. **Shift & BIR EOPT Tax Reconciliation Reports** (`/cashier/reports`)  

---

## 1. Security & Role Gate: Cashier POV Only

- Access is strictly restricted to accounts with roles: `'cashier'`, `'admin'`, `'owner'`, and `'coordinator'` (coordinator restricted to Court Schedule only).
- Accounts with `role == 'player'` must be rejected immediately upon authentication. Terminate the session via `supabase.auth.signOut()` and show an explicit access denial dialog.
- Supervisor Master PIN (`system_settings.pos_master_pin`, default `'8888'`) is required for destructive operations:
  - Voiding a cart line item or clearing the active cart.
  - Voiding completed POS sales invoices.
  - Deleting or modifying expense disbursals.
  - Adjusting inventory stock counts outside normal sales.

---

## 2. Supabase Database Schema

### A. Profiles (`public.profiles`)
- `id` (uuid, references `auth.users`)
- `role` (text: `'owner'`, `'admin'`, `'cashier'`, `'coordinator'`, `'player'`)
- `full_name` (text)
- `email` (text)
- `phone` (text)

### B. Cashier Duty Sessions (`public.cashier_duty_sessions`)
- `id` (uuid, primary key)
- `cashier_id` (uuid, references `profiles.id`)
- `started_at` (timestamptz)
- `ended_at` (timestamptz, nullable)
- `status` (text: `'on_duty'` | `'off_duty'`)
- `opening_float` (numeric(10,2), default 0.00)
- `closing_cash` (numeric(10,2), nullable)
- `notes` (text, nullable)

### C. POS Products (`public.pos_products`)
- `id` (uuid, primary key)
- `sku` (text, nullable)
- `name` (text, not null)
- `category` (text, not null: `'Coffee'`, `'Drinks'`, `'Food'`, `'Supplies'`)
- `price` (numeric, not null)
- `cost_price` (numeric, default 0)
- `stock_level` (numeric, default 0) -- Supports fractional units for volume
- `reorder_threshold` (numeric, default 10)
- `base_unit` (text, default `'pcs'`: `'pcs'`, `'mL'`, `'g'`)
- `volume` (numeric, default 0)
- `is_active` (boolean, default true)
- `updated_at` (timestamptz)

### D. POS Transactions (`public.pos_transactions`)
- `id` (uuid, primary key)
- `invoice_number` (text, unique: format `SI-YYYYMMDD-XXXXX`)
- `cashier_id` (uuid, references `profiles.id`)
- `customer_name` (text, nullable)
- `customer_tin` (text, nullable)
- `discount_type` (text: `'none'`, `'senior_citizen'`, `'pwd'`, `'student'`, `'staff'`)
- `discount_id_number` (text, nullable)
- `gross_amount` (numeric(10,2))
- `discount_amount` (numeric(10,2))
- `vatable_sales` (numeric(10,2))
- `vat_amount` (numeric(10,2))
- `vat_exempt_sales` (numeric(10,2))
- `zero_rated_sales` (numeric(10,2), default 0.00)
- `total_amount` (numeric(10,2))
- `payment_method` (text: `'Cash'`, `'GCash / QR Ph'`, `'Credit / Debit Card'`, `'Split'`)
- `status` (text: `'completed'` | `'voided'`)
- `void_reason` (text, nullable)
- `voided_at` (timestamptz, nullable)
- `voided_by` (uuid, references `profiles.id`, nullable)
- `created_at` (timestamptz)

### E. POS Transaction Items (`public.pos_transaction_items`)
- `id` (uuid, primary key)
- `transaction_id` (uuid, references `pos_transactions.id`)
- `product_id` (uuid, references `pos_products.id`)
- `quantity` (integer)
- `price_at_time` (numeric(10,2))
- `dispensed_volume` (numeric, default 0)
- `volume_unit` (text, default `'pcs'`)

### F. Daily Expenses (`public.daily_expenses`)
- `id` (uuid, primary key)
- `expense_date` (date)
- `category` (text: `'supplies'`, `'ice'`, `'maintenance'`, `'utilities'`, `'petty_cash'`, `'staff_food'`, `'other'`)
- `title` (text)
- `amount` (numeric(10,2))
- `payment_method` (text: `'cash'`, `'gcash'`, `'card'`)
- `receipt_reference` (text, nullable)
- `notes` (text, nullable)
- `recorded_by` (uuid, references `profiles.id`)
- `created_at` (timestamptz)

### G. Courts (`public.courts`)
- `id` (uuid, primary key)
- `name` (text)
- `type` (text)
- `hourly_rate` (numeric)
- `is_active` (boolean)

### H. Bookings (`public.bookings`)
- `id` (uuid, primary key)
- `court_id` (uuid, references `courts.id`)
- `user_id` (uuid, references `profiles.id`, nullable)
- `cashier_id` (uuid, references `profiles.id`, nullable)
- `start_time` (timestamptz)
- `end_time` (timestamptz)
- `duration_hours` (numeric)
- `total_price` (numeric(10,2))
- `status` (text: `'paid'`, `'checked_in'`, `'walk_in'`, `'pending_payment'`, `'cancelled'`)
- `payment_method` (text: `'Cash'`, `'GCash / QR Ph'`, `'Credit Card'`)
- `guest_name` (text, nullable)
- `guest_phone` (text, nullable)
- `guest_email` (text, nullable)
- `notes` (text, nullable)
- `expires_at` (timestamptz, nullable)
- `down_payment_amount` (numeric(10,2), default 0.00)
- `created_at` (timestamptz)

### I. System Settings (`public.system_settings`)
- `key` (text, primary key) -> `'pos_master_pin'`
- `value` (text) -> Default `'8888'`

---

## 3. Module Specifications & Business Logic

### Module 1: POS Register (`/cashier`)
1. **Catalog Panel**:
   - Department categories: `All`, `Coffee`, `Drinks`, `Food`, `Supplies`.
   - Real-time search by product name and SKU.
   - Toggleable Grid and Table views.
   - Display stock status: In stock, Low Stock (< reorder threshold), Out of Stock (disable tap).
   - Volume item indicator (shows remaining volume in mL/g).
2. **Order Cart**:
   - Line items with quantity increment, decrement, and remove.
   - Decrementing to 0 or tapping delete triggers Supervisor PIN prompt.
   - "Clear Order" triggers Supervisor PIN prompt.
3. **Statutory Discounts (RA 9994 / RA 10754)**:
   - Senior Citizen & PWD: 20% discount applied to the VAT-exempt base (Gross / 1.12), exempting the 12% VAT.
   - Mandatory validation: Cardholder full name and ID/OSCA number are required before checkout.
   - Student & Staff discounts: Configurable percentage without VAT exemption.
4. **Tender & Payment Flow**:
   - Payment modes: Cash, GCash / QR Ph, Credit/Debit Card, Split Payment.
   - Cash Tender Modal: Fast note denomination buttons (₱100, ₱200, ₱500, ₱1,000), real-time change calculation, prevent completing when tendered < payable.
5. **Invoice Generation & Printing**:
   - Calls RPC `public.generate_pos_invoice_number()` or local fallback `SI-YYYYMMDD-XXXXX`.
   - Thermal Receipt printing (80mm ESC/POS continuous paper format).
6. **Clock-In / Clock-Out**:
   - Modal for entering Opening Float at shift start.
   - Modal for entering Closing Cash count and reconciling difference at shift end.

### Module 2: Daily Court Schedule & Walk-In Desk (`/cashier/schedule`)
1. **Schedule Timeline Grid**:
   - Manila Timezone (UTC+8) date selector: Previous Day, Today, Next Day, Date Picker.
   - Multi-court column matrix mapped against 1-hour slots from 06:00 to 24:00.
   - Booking slot tiles color-coded by status:
     - `paid` (Emerald/Green)
     - `checked_in` (Blue/Indigo with checked badge)
     - `walk_in` (Teal)
     - `pending_payment` (Amber/Warning)
     - `cancelled` (Muted/Strikethrough)
2. **Real-time Live Sync**:
   - Supabase Realtime Channel subscribed to table `bookings` for instant slot updates without manual refresh.
3. **Player Check-In Action**:
   - Instant one-tap button to update status to `checked_in`.
4. **Walk-In Booking Creation**:
   - Modal to book on the spot: Court selection, Start time & Duration, Guest Name & Phone, Total calculation based on court hourly rate, Payment method (Cash or QR Ph), Full payment or Down payment toggle.
   - Reduces court availability immediately in database.
5. **Down Payment Collector**:
   - Collect remaining balance for bookings with partial down payments.

### Module 3: Inventory Table & Volume Dispensing (`/cashier/inventory`)
1. **KPI Header Cards**:
   - Total Active SKUs.
   - Low Stock Count (`stock_level <= reorder_threshold`).
   - Out of Stock Count (`stock_level <= 0`).
   - Total Inventory Valuation (Cost valuation vs Retail valuation).
2. **Filtering & Search**:
   - Search by SKU or product name.
   - Category selector.
   - Stock health filter: All, Healthy, Low Stock, Out of Stock.
3. **Volume-Aware Display**:
   - Standard units: `pcs`.
   - Volume units: `mL` or `g`. Shows container count plus total volume (e.g., `24 bottles (7,200 mL)`).
4. **Stock Adjustment Modal**:
   - Quick increment/decrement or direct quantity edit.
   - Price and Cost Price adjustment.
   - Volume & Base unit configuration.
   - Supervisor PIN required to save adjustments.

### Module 4: Daily Expenses & Margin (`/cashier/expenses`)
1. **Financial KPIs**:
   - Total Combined Revenue (POS Sales + Court Walk-In Sales).
   - Physical Cash in Register (Cash POS + Cash Court - Cash Disbursals).
   - Total Disbursed Expenses.
   - Net Profit Margin (₱ amount and percentage).
2. **Three-Tab Operations View**:
   - **Invoices**: Chronological list of POS sales and court booking invoices.
   - **Disbursals**: Detailed list of expenses paid out of the register.
   - **Cash Ledger**: Unified chronological ledger of incoming cash vs outgoing disbursals.
3. **Log Expense Modal**:
   - Categories: `supplies`, `ice`, `maintenance`, `utilities`, `petty_cash`, `staff_food`, `other`.
   - Title, Amount, Payment Method (`cash` from drawer vs `gcash`/`card`).
   - Receipt reference number and notes.

### Module 5: Shift Reports & BIR EOPT Reconciliation (`/cashier/reports`)
1. **Shift Audit Header**:
   - Date range selector (Day, Week, Custom).
   - Financial breakdown: Net Revenue, Cash Drawer Tender, Digital QR/Card Tender.
2. **Privilege & Tax Summary**:
   - Gross Subtotal, Total Discounts Granted, Net Sales Paid, Completed Invoice Count, Void Count.
   - BIR statutory breakdown: Vatable Sales, 12% VAT, VAT-Exempt Sales.
3. **Invoice Audit Log Table**:
   - Paginated list of all invoices issued during the shift.
   - Details: Invoice number, Time, Cashier, Customer, Discount Type, Gross, Discount, Net, Payment Method, Status.
4. **Master PIN Void Reversal**:
   - Voids transaction, marks `status = 'voided'`, logs reason and supervisor ID, restores product inventory stock.

---

## 4. Technical Architecture for Flutter / Dart

### Recommended Dependencies (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  flutter_riverpod: ^2.6.1
  intl: ^0.20.2
  google_fonts: ^6.2.1
  lucide_icons: ^0.257.0
  printing: ^5.13.3
  pdf: ^3.11.1
  esc_pos_utils_plus: ^2.0.4
  audioplayers: ^6.1.0
  flutter_animate: ^4.5.2
```

### Clean Folder Structure
```text
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   └── utils/
│       ├── bir_tax_calculator.dart
│       ├── currency_formatter.dart
│       ├── manila_date_utils.dart
│       └── thermal_receipt_builder.dart
├── data/
│   ├── models/
│   │   ├── profile_model.dart
│   │   ├── duty_session_model.dart
│   │   ├── pos_product_model.dart
│   │   ├── pos_transaction_model.dart
│   │   ├── daily_expense_model.dart
│   │   ├── court_model.dart
│   │   └── booking_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── pos_repository.dart
│   │   ├── inventory_repository.dart
│   │   ├── expenses_repository.dart
│   │   ├── schedule_repository.dart
│   │   └── reports_repository.dart
│   └── services/
│       ├── supabase_service.dart
│       └── thermal_printer_service.dart
├── state/
│   ├── auth_provider.dart
│   ├── duty_session_provider.dart
│   ├── pos_cart_provider.dart
│   ├── pos_catalog_provider.dart
│   ├── inventory_provider.dart
│   ├── expenses_provider.dart
│   ├── schedule_provider.dart
│   └── reports_provider.dart
└── ui/
    ├── auth/
    │   └── login_screen.dart
    ├── shell/
    │   └── cashier_shell_screen.dart # Navigation Rail / Top Bar
    ├── pos/
    │   ├── pos_screen.dart
    │   └── widgets/
    ├── schedule/
    │   ├── daily_schedule_screen.dart
    │   └── widgets/
    ├── inventory/
    │   ├── inventory_screen.dart
    │   └── widgets/
    ├── expenses/
    │   ├── expenses_screen.dart
    │   └── widgets/
    ├── reports/
    │   ├── shift_reports_screen.dart
    │   └── widgets/
    └── shared/
        ├── master_pin_dialog.dart
        ├── tender_cash_dialog.dart
        └── date_range_picker_dialog.dart
```
