# C&J Pickleball — Flutter User-Side Context Document

Complete handoff context for rebuilding the **client-facing** portions of the C&J Pickleball Next.js web app as a Flutter mobile application. Covers Supabase, PayMongo, and all business logic the Flutter app must replicate.

---

## 1. Environment Keys (Flutter `.env` / `--dart-define`)

| Key | Scope | Value / Source |
|-----|-------|----------------|
| `SUPABASE_URL` | Public | `https://wfvxznvpjjgnjhvukqcp.supabase.co` |
| `SUPABASE_ANON_KEY` | Public | Anon JWT (see `.env`) |
| `PAYMONGO_PUBLIC_KEY` | Public | `pk_live_wiBgchUw7ahRvt6jRg9WBkEB` |
| `PAYMONGO_SECRET_KEY` | **Server only** | Checkout session creation — call via existing Next.js API at `https://c-j-pickleball.vercel.app/api/checkout/paymongo` |
| `PAYMONGO_WEBHOOK_SECRET` | **Server only** | Webhook HMAC verification — handled by existing Next.js webhook |
| `RESEND_API_KEY` | **Server only** | Email dispatch — handled by existing Next.js webhook |
| `APP_URL` | Public | `https://c-j-pickleball.vercel.app` |

> **CAUTION**: `PAYMONGO_SECRET_KEY` and `SUPABASE_SERVICE_ROLE_KEY` must NEVER ship in the Flutter binary. The Flutter app calls the existing Next.js API endpoints for any operation requiring these keys.

---

## 2. Supabase Database Schema (3NF)

### 2.1 Enums

```
user_role       = owner | admin | cashier | client
court_type      = indoor | outdoor
court_status    = active | maintenance | inactive
booking_status  = pending_payment | paid | checked_in | walk_in | cancelled | cancelled_refund_pending | expired
payment_method  = paymongo | cash | counter_qr | other
refund_status   = none | pending | approved | rejected | completed | voided_no_refund
wallet_type     = gcash | maya | bank_transfer | counter_cash
```

### 2.2 Tables

#### `profiles` (extends `auth.users`)
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | References `auth.users(id)` ON DELETE CASCADE |
| `role` | user_role | Default `'client'` |
| `full_name` | text | Nullable |
| `email` | text | |
| `phone` | text | Nullable |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

#### `courts`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `name` | text UNIQUE | e.g. "Court 1 — Indoor (Pro Cushion)" |
| `type` | court_type | Default `'indoor'` |
| `status` | court_status | Default `'active'` |
| `hourly_rate` | numeric(10,2) | Default `300.00`, CHECK >= 0 |
| `is_active` | boolean | **GENERATED** from `status = 'active'` |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

#### `bookings`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `court_id` | uuid FK | References `courts(id)` |
| `user_id` | uuid FK | References `profiles(id)`, nullable |
| `guest_name` | text | Populated from profile on checkout |
| `guest_email` | text | |
| `guest_phone` | text | |
| `start_time` | timestamptz | |
| `end_time` | timestamptz | CHECK `end_time > start_time` |
| `duration_hours` | integer | CHECK >= 1 |
| `total_price` | numeric(10,2) | CHECK >= 0 |
| `currency` | text | Default `'PHP'` |
| `status` | booking_status | Default `'pending_payment'` |
| `payment_method` | payment_method | Default `'paymongo'` |
| `paymongo_checkout_session_id` | text | Nullable |
| `expires_at` | timestamptz | 5-minute checkout hold |
| `notes` | text | Rental add-ons logged here |
| `created_at` / `updated_at` | timestamptz | |

**GiST Exclusion Constraint** prevents double-booking at database level:
```sql
EXCLUDE USING gist (court_id WITH =, tstzrange(start_time, end_time) WITH &&)
WHERE (status IN ('paid','checked_in','walk_in','pending_payment'))
```

#### `booking_refunds`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `booking_id` | uuid FK UNIQUE | 1:1 with bookings |
| `amount` | numeric(10,2) | |
| `wallet_type` | wallet_type | gcash / maya / bank_transfer / counter_cash |
| `account_name` | text | |
| `account_number` | text | |
| `reason` | text | |
| `status` | refund_status | Default `'pending'` |
| `reference` | text | GCash ref number etc. |
| `processed_by` | uuid FK | Staff who processed |
| `processed_at` | timestamptz | |
| `admin_notes` | text | |

#### `pos_products`
| Column | Type |
|--------|------|
| `id` | uuid PK |
| `name` | text UNIQUE |
| `category` | text |
| `price` | numeric(10,2) |
| `stock_level` | integer |
| `is_active` | boolean |

#### `pos_transactions` / `pos_transaction_items`
POS is **staff-only** (cashier/admin). Flutter client app does NOT need these.

---

## 3. Row-Level Security (RLS) Policies — Client-Relevant

| Table | Operation | Policy for `client` role |
|-------|-----------|--------------------------|
| `profiles` | SELECT | Own row only (`auth.uid() = id`) |
| `profiles` | UPDATE | Own row only |
| `courts` | SELECT | **Public** (no auth required) |
| `bookings` | SELECT | Public (for availability calendar) + own bookings |
| `bookings` | INSERT | Open (auth required for checkout validation) |
| `bookings` | UPDATE | Own bookings only |
| `booking_refunds` | SELECT | Own booking's refund only |
| `booking_refunds` | INSERT | Own booking's refund only |
| `pos_products` | SELECT | **Public** |

Helper function used by RLS:
```sql
is_staff(check_uid) → boolean  -- true when role IN ('owner','admin','cashier')
```

---

## 4. Authentication Flow

### 4.1 Sign Up
```dart
final res = await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'full_name': fullName, 'role': 'client'},
  emailRedirectTo: 'https://c-j-pickleball.vercel.app/auth/callback?next=/dashboard',
);
// If res.user != null && res.session == null → email verification sent
```

### 4.2 Login
```dart
final res = await supabase.auth.signInWithPassword(email: email, password: password);
// Fetch profile role for routing
final profile = await supabase.from('profiles').select('role').eq('id', res.user!.id).single();
```

### 4.3 Role-Based Routing
| Role | Destination |
|------|-------------|
| `owner` / `admin` | Admin dashboard (not in Flutter client scope) |
| `cashier` | Cashier schedule (not in Flutter client scope) |
| `client` | Player dashboard |

### 4.4 Forgot Password
Server-side temp password generation + SMTP email. Flutter calls:
```
POST https://c-j-pickleball.vercel.app/api/auth/reset-password
```
Or replicate via Supabase Edge Function (requires admin API).

### 4.5 Password Update (Dashboard Settings)
```dart
await supabase.auth.updateUser(UserAttributes(password: newPassword));
```

---

## 5. Court Availability

### 5.1 Direct Supabase Query (recommended for Flutter)
```dart
// Fetch active courts
final courts = await supabase
  .from('courts')
  .select('*')
  .order('name');
// Filter: c.status != 'inactive' (is_active is generated)

// Fetch bookings for a date range (for slot calculation)
final bookings = await supabase
  .from('bookings')
  .select('id, start_time, end_time, status, expires_at')
  .eq('court_id', courtId)
  .inFilter('status', ['paid', 'checked_in', 'walk_in', 'pending_payment'])
  .gte('end_time', dayStart.toIso8601String())
  .lte('start_time', dayEnd.toIso8601String());
```

### 5.2 Business Rules
- **Operating hours**: 6:00 AM – 10:00 PM Philippine Time (UTC+8)
- **16 hourly slots** per day per court (hours 6–21, last start at `22 - duration`)
- `pending_payment` bookings with expired `expires_at` should be treated as available
- Duration range: 1–12 hours, contiguous block check
- Month heatmap status:
  - `available` — plenty open
  - `almost_full` — ≤5 slots remaining or ≥65% booked
  - `fully_booked` — 0 slots
  - `past` — date before today

### 5.3 Slot Generation Logic (client-side)
```dart
for (int hour = 6; hour <= 22 - durationHours; hour++) {
  bool available = true;
  for (int sub = hour; sub < hour + durationHours; sub++) {
    if (occupiedHours.contains(sub)) {
      available = false;
      break;
    }
  }
  // Also mark past hours on today as unavailable
  slots.add(AvailabilitySlot(hour24: hour, available: available));
}
```

---

## 6. Booking & Checkout Flow (PayMongo)

### 6.1 Sequence

```
Flutter App → POST /api/checkout/paymongo (Next.js backend)
  Backend:
    1. Validate inputs (courtId, date, hour, duration, name, email)
    2. Check overlap against bookings table
    3. Authenticate user (Supabase session cookie/token)
    4. Calculate total price
    5. Insert booking (status=pending_payment, expires_at=now+5min)
    6. Create PayMongo Checkout Session (server-side, secret key)
    7. Update booking with paymongo_checkout_session_id
    8. Return {checkoutUrl, bookingId, expiresAt}
  Flutter:
    9. Open checkoutUrl in WebView or external browser
    10. PayMongo redirects to success_url on payment
    11. PayMongo sends webhook to /api/webhooks/paymongo
  Backend webhook:
    12. Verify signature
    13. Update booking status = 'paid'
    14. Send confirmation email with QR code
```

### 6.2 Checkout Request (Flutter → Next.js API)
```dart
final response = await http.post(
  Uri.parse('https://c-j-pickleball.vercel.app/api/checkout/paymongo'),
  headers: {
    'Content-Type': 'application/json',
    'Cookie': supabaseSessionCookie, // or Authorization header
  },
  body: jsonEncode({
    'courtId': selectedCourt.id,
    'date': '2026-09-10',         // YYYY-MM-DD
    'hour24': 7,                   // start hour
    'durationHours': 2,
    'guestName': 'Juan Dela Cruz',
    'guestEmail': 'juan@email.com',
    'guestPhone': '+639171234567',
    'paddleRental': true,
    'ballThrowerRental': false,
  }),
);
final data = jsonDecode(response.body);
// data['checkoutUrl'] → open in WebView
// data['bookingId'] → track locally
// data['expiresAt'] → 5-minute countdown
```

### 6.3 Price Calculation
```
courtSubtotal  = hourly_rate × durationHours     (default ₱300/hr)
paddleFee      = paddleRental ? ₱150 : 0         (flat, Pro Carbon Paddle Bundle: 2× paddles + 3× balls)
ballThrowerFee = ballThrowerRental ? ₱150 × durationHours : 0
grandTotal     = courtSubtotal + paddleFee + ballThrowerFee
```

### 6.4 PayMongo Payment Methods
`gcash`, `paymaya`, `card`, `grab_pay`, `dob` (direct online banking), `qrph`

### 6.5 Post-Payment
After PayMongo redirects to success URL, Flutter should:
1. Poll or listen for booking status change to `'paid'`
2. Show confirmation screen with booking details
3. Display QR code for check-in (generate client-side from bookingId)

---

## 7. Booking Cancellation & Refund

### 7.1 Cancel Booking
**Strict 24-hour rule**: Client can only cancel if `start_time - now >= 24 hours`.

```dart
// Check eligibility
final startTime = DateTime.parse(booking.startTime);
final hoursUntil = startTime.difference(DateTime.now()).inHours;
if (hoursUntil < 24) {
  // Show error: "Cancellations only permitted 24+ hours in advance"
  return;
}

// Execute cancellation
await supabase
  .from('bookings')
  .update({
    'status': booking.paymentMethod == 'cash' ? 'cancelled' : 'cancelled_refund_pending',
    'updated_at': DateTime.now().toIso8601String(),
  })
  .eq('id', booking.id)
  .eq('user_id', currentUserId); // RLS enforced
```

### 7.2 Request Refund (with e-wallet details)
```dart
await supabase.from('booking_refunds').insert({
  'booking_id': bookingId,
  'amount': booking.totalPrice,
  'wallet_type': 'gcash',              // gcash | maya | bank_transfer | counter_cash
  'account_name': 'Juan Dela Cruz',
  'account_number': '09171234567',
  'reason': 'Schedule conflict',
  'status': 'pending',
});

await supabase
  .from('bookings')
  .update({'status': 'cancelled_refund_pending'})
  .eq('id', bookingId);
```

### 7.3 Refund Status (read-only for client)
| Status | Meaning |
|--------|---------|
| `pending` | Awaiting admin review |
| `approved` | Admin approved, processing |
| `completed` | Refund sent (reference number available) |
| `rejected` | Admin rejected, booking restored to `paid` |
| `voided_no_refund` | Admin voided schedule without refund |

---

## 8. User Dashboard (Player Features)

### 8.1 Data Queries
```dart
// My bookings with court and refund details
final bookings = await supabase
  .from('bookings')
  .select('*, courts(name, type, hourly_rate), booking_refunds(*)')
  .eq('user_id', userId)
  .order('start_time', ascending: false);

// My profile
final profile = await supabase
  .from('profiles')
  .select('*')
  .eq('id', userId)
  .single();
```

### 8.2 Dashboard Sections
| Section | Filter |
|---------|--------|
| **Upcoming** | `status IN ('paid','checked_in')` AND `start_time > now` |
| **Past** | `end_time < now` |
| **Cancelled/Refund** | `status IN ('cancelled','cancelled_refund_pending','expired')` |
| **Profile Settings** | `full_name`, `phone`, password update |

### 8.3 Client Actions Summary
| Action | Conditions |
|--------|------------|
| Cancel booking | `start_time - now >= 24h`, status = `paid` |
| Request refund | Same as cancel, provide e-wallet details |
| Update password | Authenticated, min 6 chars |
| Update profile | Own profile only (name, phone) |

---

## 9. Screens Map (Flutter)

| Screen | Auth Required | Corresponds to Web Route |
|--------|---------------|--------------------------|
| Landing / Marketing | No | `/` |
| Book Court | No (browse) / Yes (checkout) | `/book` |
| Pricing | No | `/pricing` |
| Login | No | `/login` |
| Sign Up | No | `/signup` |
| Forgot Password | No | `/forgot-password` |
| Booking Success | Yes | `/booking/success/[id]` |
| Player Dashboard | Yes | `/dashboard` |
| Profile Settings | Yes | `/dashboard` (tab) |

---

## 10. Route Protection (Flutter equivalent)

```dart
// GoRouter redirect guard
redirect: (context, state) {
  final session = supabase.auth.currentSession;
  final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

  if (protectedRoutes.contains(state.matchedLocation) && session == null) {
    return '/login?next=${state.matchedLocation}';
  }
  if (isAuthRoute && session != null) {
    return '/dashboard';
  }
  return null;
}
```

---

## 11. Confirmation Email & QR Code

After payment webhook confirms, the Next.js backend sends a Resend email containing:
- Booking reference: `#${bookingId.slice(0,8).toUpperCase()}`
- Court name, date, time range, duration, total paid, payment method
- QR code payload: `{ bookingId, system: "C&J Court", timestamp }`
- 24-hour cancellation policy reminder

Flutter can generate the same QR client-side for the dashboard:
```dart
// Using qr_flutter package
QrImageView(data: jsonEncode({
  'bookingId': booking.id,
  'system': 'C&J Court',
  'timestamp': DateTime.now().toIso8601String(),
}))
```

---

## 12. Recommended Flutter Architecture

```
lib/
├── models/
│   ├── profile.dart
│   ├── court.dart
│   ├── booking.dart
│   ├── booking_refund.dart
│   └── availability_slot.dart
├── services/
│   ├── supabase_service.dart      # Auth + DB init
│   ├── booking_service.dart       # Availability, create, cancel, refund
│   └── payment_service.dart       # POST to Next.js checkout API, WebView launch
├── providers/                     # Riverpod or Bloc
│   ├── auth_provider.dart
│   ├── booking_provider.dart
│   └── court_provider.dart
├── screens/
│   ├── landing/
│   ├── auth/                      # login, signup, forgot_password
│   ├── booking/                   # court picker, calendar, slots, checkout WebView
│   ├── dashboard/                 # my bookings, cancel/refund, profile
│   └── success/                   # post-payment confirmation + QR
├── widgets/                       # Reusable components
│   ├── court_card.dart
│   ├── slot_grid.dart
│   ├── booking_card.dart
│   └── qr_ticket.dart
└── router.dart                    # GoRouter with auth guards
```

### Key Packages
| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Auth + DB + Realtime |
| `go_router` | Declarative routing with guards |
| `flutter_riverpod` or `flutter_bloc` | State management |
| `webview_flutter` | PayMongo checkout WebView |
| `qr_flutter` | QR code generation for check-in |
| `intl` | Date/time formatting (Philippine locale) |
| `url_launcher` | Fallback external browser for payments |

### Deep Linking (PayMongo redirect)
Configure custom URL scheme `cjcourt://` so PayMongo success/cancel redirects return to the Flutter app:
- Success: `cjcourt://booking/success/{bookingId}?session_id={id}`
- Cancel: `cjcourt://book?cancelled=true&booking_id={id}`

Update the checkout API call to pass Flutter-specific `originUrl` so the backend generates mobile-compatible redirect URLs.
