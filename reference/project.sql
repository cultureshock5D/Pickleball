-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  role USER-DEFINED NOT NULL DEFAULT 'customer'::user_role,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.courts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text DEFAULT 'active'::text,
  CONSTRAINT courts_pkey PRIMARY KEY (id)
);
CREATE TABLE public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  court_id uuid NOT NULL,
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  status text DEFAULT 'pending'::text,
  total_amount numeric NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.profiles(id),
  CONSTRAINT bookings_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id)
);
CREATE TABLE public.pos_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  price numeric NOT NULL,
  category text NOT NULL,
  stock_level integer DEFAULT 100,
  CONSTRAINT pos_products_pkey PRIMARY KEY (id)
);
CREATE TABLE public.pos_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cashier_id uuid,
  total_amount numeric NOT NULL,
  payment_method text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  status text DEFAULT 'completed'::text,
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