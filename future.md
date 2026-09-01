# Future Feature Blueprint: Pickleball Court Booking Mobile Application
*(Flutter + Supabase + PayMongo Architecture)*

This document outlines three high-impact feature ideas designed for the Pickleball Court Booking Mobile Application. Each feature focuses on providing a premium Flutter mobile client experience, supported by theoretical and high-level architectural visualizations for Supabase (backend & real-time database) and PayMongo (payment gateway integration).

---

## Feature 1: Smart QR Code Court Check-In & Check-Out System

### 1. Overview & User Experience (Flutter Focus)
The Smart QR Code Check-In & Check-Out system allows players with active court reservations to seamlessly check in and check out at the venue by displaying an auto-refreshing dynamic QR code on their mobile device.

- **Flutter UI/UX Design**:
  - **Dynamic QR Modal**: A sleek modal sheet accessible directly from active booking cards displaying a high-contrast QR code generated dynamically using booking token payloads.
  - **Real-Time Status Badge**: Live status indicators (`Upcoming`, `Checked In`, `Checked Out`, `Expired`) with subtle animated pulses.
  - **Countdown Timer Widget**: Real-time widget calculating remaining court session time.
  - **Offline Fallback Pass**: Caches active booking pass locally using `SharedPreferences` / encrypted storage so players can display their QR pass even with unstable venue Wi-Fi/cellular connection.

---

### 2. Conceptual Supabase Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

```
+------------------+         +----------------------------+         +------------------------+
|  Flutter Client  |  RLS    |   Supabase Postgres DB     |  Trigger|  Supabase Edge Func    |
|  (Mobile App)    | --------> ("bookings" & "checkins")   | --------> (Session Auto-Close) |
+------------------+         +----------------------------+         +------------------------+
```

- **Database Schema Extensions**:
  - `bookings.check_in_time`: Timestamp when QR is scanned at venue kiosk/gate.
  - `bookings.check_out_time`: Timestamp when check-out occurs.
  - `bookings.status`: ENUM (`confirmed`, `checked_in`, `completed`, `no_show`).
- **Real-Time Subscriptions**: Flutter app listens to `supabase.from('bookings').stream(...)` to automatically switch screen states from "Tap to Check-In" to "Session Active" once venue staff or gate scanner processes the code.

---

### 3. Conceptual PayMongo Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

- **Overtime & Extended Play Micro-Charges**:
  - If a check-out timestamp exceeds the booked duration by more than a 15-minute grace period, a secondary PayMongo Payment Intent link can be automatically dispatched via push notification/SMS to settle overtime court usage fees.

---

## Feature 2: Interactive Visual Slot Grid & Dynamic Time-Based Pricing

### 1. Overview & User Experience (Flutter Focus)
An interactive visual court timeline and dynamic slot picker that enables players to intuitively select single or consecutive court time slots while clearly distinguishing peak (prime evening/weekend) hours from off-peak discounted hours.

- **Flutter UI/UX Design**:
  - **Horizontal Timeline Grid**: Custom horizontal drag-and-scroll time slot bar with color-coded slots (Green = Available Off-Peak, Amber = Available Peak, Grey = Booked).
  - **Multi-Slot Selection**: Tap-to-select multiple contiguous 30-minute or 1-hour slots with dynamic subtotal recalculation in Philippine Pesos (₱).
  - **Dynamic Price Pill**: Visual indicator displaying rate badges (e.g., "₱500/hr (Off-Peak)" vs "₱800/hr (Peak)").
  - **Transient Slot Hold**: 5-minute local holding timer UI to prevent double booking while the user completes booking confirmation.

---

### 2. Conceptual Supabase Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

```
+------------------+  RPC Call   +----------------------------+  Locking  +-----------------------+
|  Flutter Client  | ----------> | Supabase Postgres Function | --------> | Postgres Advisory     |
| (Slot Selector)  |             |  "fn_hold_court_slot()"    |           | Locks / Slot State    |
+------------------+             +----------------------------+           +-----------------------+
```

- **Database Tables & Functions**:
  - `court_pricing_rules`: Stores base hourly rates, peak hour schedules (e.g., 5 PM - 10 PM), and holiday multipliers.
  - `fn_hold_court_slot(p_court_id, p_start_time, p_end_time, p_user_id)`: Postgres stored procedure that handles concurrency control using advisory locks to temporarily reserve a slot for 5 minutes during checkout.

---

### 3. Conceptual PayMongo Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

- **PayMongo Source & Payment Intent Creation**:
  - Generates a PayMongo `PaymentIntent` matching the dynamically computed total amount from selected peak/off-peak slots.
  - Supported payment methods: GCash, GrabPay, Maya, and Credit/Debit Cards via PayMongo Checkout API.

---

## Feature 3: Downloadable Booking & PayMongo Payment Receipt Manager

### 1. Overview & User Experience (Flutter Focus)
A full-featured receipt generator and manager that lets users view, print, share, and download itemized PDF receipts for all paid pickleball court bookings, complete with breakdown of court rates, taxes, venue details, and PayMongo reference numbers.

- **Flutter UI/UX Design**:
  - **Receipt Preview Modal**: Clean luxury-styled modal displaying itemized invoice breakdown (Court Fee, Peak Hour Surcharge, Service Fee, Total Paid in ₱).
  - **Download & Share Actions**: One-tap action buttons to save receipt as PDF or share via native device share sheet (iOS/Android).
  - **Transaction History Filter**: Easy navigation filter inside "My Bookings" to quickly pull up receipts by date or payment method.

---

### 2. Conceptual Supabase Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

```
+--------------------+  PDF Build +--------------------------+  Upload  +-----------------------+
| PayMongo Webhook   | ---------> | Supabase Storage Bucket  | -------> | Public / Signed URL   |
| (payment.paid)     |            | ("booking-receipts/")    |          | Attached to Booking   |
+--------------------+            +--------------------------+          +-----------------------+
```

- **Receipt Storage & Retrieval**:
  - PayMongo webhook handler triggers storage of transaction ID (`pm_pi_...`) on the `bookings` row.
  - Flutter app builds the printable PDF client-side or fetches the generated signed PDF URL from Supabase Storage (`booking-receipts/{user_id}/{booking_id}.pdf`).

---

### 3. Conceptual PayMongo Integration Architecture
*Note: Conceptual visualization for future backend implementation.*

- **PayMongo Webhook Event Processing**:
  - Listens for `payment.paid` and `checkout_session.payment.paid` webhooks.
  - Extracts payment method payload (e.g., GCash reference number, last 4 digits of card), billing details, and fee structure to generate an accurate, official receipt payload.
