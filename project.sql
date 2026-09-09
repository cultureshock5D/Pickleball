-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  role USER-DEFINED NOT NULL DEFAULT 'customer'::user_role,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  phone text,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  email text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.courts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text DEFAULT 'active'::text,
  type text DEFAULT 'indoor'::text,
  hourly_rate numeric DEFAULT 300.00,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT courts_pkey PRIMARY KEY (id)
);
CREATE TABLE public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  court_id uuid NOT NULL,
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  status text DEFAULT 'pending'::text,
  total_amount numeric,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  user_id uuid,
  guest_name text,
  guest_email text,
  guest_phone text,
  duration_hours integer DEFAULT 1,
  total_price numeric DEFAULT 300.00,
  currency text DEFAULT 'PHP'::text,
  payment_method text DEFAULT 'paymongo'::text,
  paymongo_checkout_session_id text,
  expires_at timestamp with time zone,
  notes text,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  refund_wallet_type text,
  refund_account_name text,
  refund_account_number text,
  refund_reason text,
  refund_status text DEFAULT 'none'::text,
  refund_reference text,
  refund_processed_at timestamp with time zone,
  refund_processed_by uuid,
  paddle_count integer NOT NULL DEFAULT 0 CHECK (paddle_count >= 0 AND paddle_count <= 4),
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.profiles(id),
  CONSTRAINT bookings_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id),
  CONSTRAINT bookings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT bookings_refund_processed_by_fkey FOREIGN KEY (refund_processed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.pos_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  price numeric NOT NULL,
  category text NOT NULL,
  stock_level integer DEFAULT 100,
  category_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT pos_products_pkey PRIMARY KEY (id),
  CONSTRAINT pos_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.pos_categories(id)
);
CREATE TABLE public.pos_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cashier_id uuid,
  total_amount numeric NOT NULL,
  payment_method text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  status text DEFAULT 'completed'::text,
  invoice_number text UNIQUE,
  customer_name text,
  customer_tin text,
  discount_type text DEFAULT 'none'::text,
  discount_id_number text,
  gross_amount numeric DEFAULT 0.00,
  discount_amount numeric DEFAULT 0.00,
  vatable_sales numeric DEFAULT 0.00,
  vat_amount numeric DEFAULT 0.00,
  vat_exempt_sales numeric DEFAULT 0.00,
  zero_rated_sales numeric DEFAULT 0.00,
  CONSTRAINT pos_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT pos_transactions_cashier_id_fkey FOREIGN KEY (cashier_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.pos_transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid,
  product_id uuid,
  quantity integer NOT NULL,
  price_at_time numeric NOT NULL,
  CONSTRAINT pos_transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT pos_transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.pos_transactions(id),
  CONSTRAINT pos_transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.pos_products(id)
);
CREATE TABLE public.booking_refunds (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE,
  amount numeric NOT NULL DEFAULT 0.00 CHECK (amount >= 0::numeric),
  wallet_type text NOT NULL DEFAULT 'gcash'::text,
  account_name text,
  account_number text,
  reason text,
  status text NOT NULL DEFAULT 'pending'::text,
  reference text,
  processed_by uuid,
  processed_at timestamp with time zone,
  admin_notes text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_refunds_pkey PRIMARY KEY (id),
  CONSTRAINT booking_refunds_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT booking_refunds_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.pos_categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  description text,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT pos_categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.equipment_rentals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL,
  product_id uuid,
  equipment_type text NOT NULL CHECK (equipment_type = ANY (ARRAY['paddle'::text, 'ball_thrower'::text, 'balls'::text, 'other'::text])),
  equipment_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0 AND quantity <= 4),
  rate_per_unit numeric NOT NULL CHECK (rate_per_unit >= 0::numeric),
  total_price numeric NOT NULL CHECK (total_price >= 0::numeric),
  returned_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT equipment_rentals_pkey PRIMARY KEY (id),
  CONSTRAINT equipment_rentals_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT equipment_rentals_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.pos_products(id)
);
CREATE TABLE public.court_maintenance_schedules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  court_id uuid NOT NULL,
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  title text NOT NULL,
  description text,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT court_maintenance_schedules_pkey PRIMARY KEY (id),
  CONSTRAINT court_maintenance_schedules_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id),
  CONSTRAINT court_maintenance_schedules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.court_pricing_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  court_id uuid,
  name text NOT NULL,
  day_of_week integer CHECK (day_of_week >= 0 AND day_of_week <= 6),
  start_hour integer NOT NULL CHECK (start_hour >= 0 AND start_hour <= 23),
  end_hour integer NOT NULL,
  hourly_rate numeric NOT NULL CHECK (hourly_rate >= 0::numeric),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT court_pricing_rules_pkey PRIMARY KEY (id),
  CONSTRAINT court_pricing_rules_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id)
);
CREATE TABLE public.security_audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  old_data jsonb,
  new_data jsonb,
  ip_address text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT security_audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT security_audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id)
);