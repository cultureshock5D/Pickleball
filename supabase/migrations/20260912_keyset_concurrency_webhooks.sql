-- Migration: 20260912_keyset_concurrency_webhooks.sql
-- Description: Enable btree_gist, create venues table with RLS & Realtime publication,
--              add GiST exclusion constraint on bookings (code 23P01),
--              composite indexes for keyset pagination, and atomic create_booking_hold RPC.

-- ============================================================================
-- 1. Enable btree_gist Extension
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================================
-- 2. Venues Table & Realtime Publication
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.venues (
  id text PRIMARY KEY,
  name text NOT NULL,
  city text NOT NULL,
  address text NOT NULL,
  rating numeric(3, 2) DEFAULT 4.90,
  review_count integer DEFAULT 0,
  amenities text[] DEFAULT '{}'::text[],
  court_count integer DEFAULT 1,
  price_starting_at numeric(10, 2) DEFAULT 120.00,
  tag text DEFAULT 'POPULAR',
  court_type text DEFAULT 'Championship Indoor',
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'venues' AND policyname = 'Public venues read access'
  ) THEN
    CREATE POLICY "Public venues read access" ON public.venues FOR SELECT USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'venues'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.venues;
  END IF;
END $$;

-- Seed initial venues if missing
INSERT INTO public.venues (
  id, name, city, address, rating, review_count, amenities, court_count, price_starting_at, tag, court_type, created_at, updated_at
)
VALUES 
  (
    'venue-bgc-prime', 
    'C&J Court — BGC Prime Club', 
    'Taguig, Metro Manila', 
    '9th Ave & 28th St, Bonifacio Global City', 
    4.95, 
    342, 
    ARRAY['Pro Cushion Surface', 'LED Tournament Lighting', 'Player Lounge & Cafe', 'Locker & Shower Facilities', 'Equipment Pro Shop'], 
    4, 
    280.00, 
    'PREMIUM', 
    'Indoor & Outdoor',
    timezone('utc'::text, now()) - interval '30 days',
    timezone('utc'::text, now()) - interval '30 days'
  ),
  (
    'venue-alabang-center', 
    'C&J Court — Alabang Sports Hub', 
    'Muntinlupa, Metro Manila', 
    'Commerce Ave, Filinvest City, Alabang', 
    4.88, 
    184, 
    ARRAY['Tour Spec Acrylic', 'Covered Outdoor Courts', 'Refreshment Bar', 'Free Parking'], 
    6, 
    250.00, 
    'POPULAR', 
    'Championship Covered',
    timezone('utc'::text, now()) - interval '25 days',
    timezone('utc'::text, now()) - interval '25 days'
  )
ON CONFLICT (id) DO NOTHING;

-- Optional venue reference on courts
ALTER TABLE public.courts ADD COLUMN IF NOT EXISTS venue_id text REFERENCES public.venues(id) ON DELETE SET NULL;

-- ============================================================================
-- 3. GiST Exclusion Constraint on Bookings (Error Code 23P01)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'exclude_overlapping_court_bookings'
  ) THEN
    ALTER TABLE public.bookings
    ADD CONSTRAINT exclude_overlapping_court_bookings
    EXCLUDE USING gist (
      court_id WITH =,
      tstzrange(start_time, end_time, '[)') WITH &&
    )
    WHERE (status NOT IN ('cancelled', 'cancelled_refund_pending', 'expired'));
  END IF;
END $$;

-- ============================================================================
-- 4. Keyset Pagination Composite Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_venues_created_at_id 
  ON public.venues (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_courts_created_at_id 
  ON public.courts (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_created_at_id 
  ON public.bookings (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_user_created_at_id 
  ON public.bookings (user_id, created_at DESC, id DESC);

-- ============================================================================
-- 5. Atomic RPC Hold Flow: create_booking_hold
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_booking_hold(
  p_court_id uuid,
  p_user_id uuid,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_total_amount numeric,
  p_guest_name text DEFAULT '',
  p_guest_email text DEFAULT '',
  p_guest_phone text DEFAULT '',
  p_notes text DEFAULT NULL,
  p_hold_duration_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_expires_at timestamptz;
BEGIN
  -- Input assertions
  IF p_court_id IS NULL THEN
    RAISE EXCEPTION 'Court ID is required' USING ERRCODE = '22004';
  END IF;
  IF p_start_time IS NULL OR p_end_time IS NULL THEN
    RAISE EXCEPTION 'Start time and end time are required' USING ERRCODE = '22004';
  END IF;
  IF p_start_time >= p_end_time THEN
    RAISE EXCEPTION 'Start time must be before end time' USING ERRCODE = '22023';
  END IF;
  IF p_total_amount < 0 THEN
    RAISE EXCEPTION 'Total amount must be non-negative' USING ERRCODE = '22023';
  END IF;

  -- 1. Lazy cleanup of expired holds on this court to free up slot
  UPDATE public.bookings
  SET status = 'expired',
      updated_at = timezone('utc'::text, now())
  WHERE court_id = p_court_id
    AND status IN ('pending', 'pending_payment')
    AND expires_at IS NOT NULL
    AND expires_at < timezone('utc'::text, now());

  -- 2. Compute hold expiration
  v_expires_at := timezone('utc'::text, now()) + (p_hold_duration_minutes || ' minutes')::interval;

  -- 3. Insert new hold record. 
  -- The GiST constraint will reject overlapping active reservations with 23P01!
  INSERT INTO public.bookings (
    court_id,
    user_id,
    customer_id,
    start_time,
    end_time,
    total_amount,
    total_price,
    duration_hours,
    status,
    payment_method,
    expires_at,
    guest_name,
    guest_email,
    guest_phone,
    notes,
    created_at,
    updated_at
  ) VALUES (
    p_court_id,
    p_user_id,
    p_user_id,
    p_start_time,
    p_end_time,
    p_total_amount,
    p_total_amount,
    GREATEST(1, ROUND(EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600)::integer),
    'pending_payment',
    'paymongo',
    v_expires_at,
    COALESCE(p_guest_name, ''),
    COALESCE(p_guest_email, ''),
    COALESCE(p_guest_phone, ''),
    p_notes,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  RETURNING * INTO v_booking;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'court_id', v_booking.court_id,
    'start_time', v_booking.start_time,
    'end_time', v_booking.end_time,
    'status', v_booking.status,
    'expires_at', v_booking.expires_at,
    'total_price', v_booking.total_price
  );

EXCEPTION
  WHEN exclusion_violation THEN -- 23P01
    RAISE EXCEPTION 'Slot is no longer available: Another player has reserved this time.'
      USING ERRCODE = '23P01',
            DETAIL = 'GiST exclusion constraint violation on court slot interval.';
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_booking_hold TO authenticated, anon, service_role;
