-- Migration: 20260911_realtime_and_webhooks.sql
-- Description: Enable Supabase Realtime CDC on bookings/courts, add webhook idempotency audit table,
--              create indexing, and define atomic process_paymongo_webhook PL/pgSQL function.

-- ============================================================================
-- 1. Enable Supabase Realtime CDC Publication
-- ============================================================================
DO $$
BEGIN
  -- Add public.bookings to supabase_realtime publication if not already included
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;

  -- Add public.courts to supabase_realtime publication if not already included
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'courts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.courts;
  END IF;
END $$;

-- Set REPLICA IDENTITY FULL on bookings to guarantee oldRecord is present in CDC updates/deletes
ALTER TABLE public.bookings REPLICA IDENTITY FULL;

-- ============================================================================
-- 2. Webhook Idempotency & Audit Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id text NOT NULL UNIQUE,              -- PayMongo 'evt_...'
  event_type text NOT NULL,                   -- 'checkout_session.payment.paid', 'payment.paid', etc.
  resource_id text NOT NULL,                  -- 'cs_...' or 'pay_...'
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'processed',   -- 'processed', 'ignored', 'failed'
  payload jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for sub-millisecond lookups and idempotency validation
CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_event_id 
  ON public.payment_webhook_events(event_id);

CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_resource_id 
  ON public.payment_webhook_events(resource_id);

CREATE INDEX IF NOT EXISTS idx_bookings_paymongo_session 
  ON public.bookings(paymongo_checkout_session_id);

CREATE INDEX IF NOT EXISTS idx_bookings_status 
  ON public.bookings(status);

-- ============================================================================
-- 3. Row-Level Security for payment_webhook_events
-- ============================================================================
ALTER TABLE public.payment_webhook_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'payment_webhook_events' AND policyname = 'Service role full access to payment_webhook_events'
  ) THEN
    CREATE POLICY "Service role full access to payment_webhook_events"
      ON public.payment_webhook_events
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- ============================================================================
-- 4. Atomic Idempotent Webhook Processing Function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_paymongo_webhook(
  p_event_id text,
  p_event_type text,
  p_resource_id text,
  p_booking_id uuid DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid := p_booking_id;
  v_current_status text;
  v_new_status text;
BEGIN
  -- Idempotency check: Return immediately if event has already been processed
  IF EXISTS (SELECT 1 FROM public.payment_webhook_events WHERE event_id = p_event_id) THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent_replay', true,
      'event_id', p_event_id,
      'message', 'Event already processed'
    );
  END IF;

  -- Resolve booking ID from paymongo_checkout_session_id if not provided
  IF v_booking_id IS NULL THEN
    SELECT id, status INTO v_booking_id, v_current_status
    FROM public.bookings
    WHERE paymongo_checkout_session_id = p_resource_id
    LIMIT 1;

    -- If still null, try extracting booking_id from payload metadata or reference_number
    IF v_booking_id IS NULL AND p_payload IS NOT NULL THEN
      BEGIN
        IF (p_payload->'data'->'attributes'->'data'->'attributes'->'metadata'->>'booking_id') IS NOT NULL THEN
          v_booking_id := (p_payload->'data'->'attributes'->'data'->'attributes'->'metadata'->>'booking_id')::uuid;
        ELSIF (p_payload->'data'->'attributes'->'data'->'attributes'->>'reference_number') IS NOT NULL THEN
          v_booking_id := (p_payload->'data'->'attributes'->'data'->'attributes'->>'reference_number')::uuid;
        END IF;

        IF v_booking_id IS NOT NULL THEN
          SELECT status INTO v_current_status FROM public.bookings WHERE id = v_booking_id;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_booking_id := NULL;
      END;
    END IF;
  ELSE
    SELECT status INTO v_current_status
    FROM public.bookings
    WHERE id = v_booking_id;
  END IF;

  -- Determine state transition
  IF p_event_type IN ('checkout_session.payment.paid', 'payment.paid') THEN
    v_new_status := 'confirmed';
  ELSIF p_event_type = 'payment.failed' THEN
    v_new_status := 'cancelled';
  ELSE
    v_new_status := NULL;
  END IF;

  -- Apply state change only if booking exists and is currently in pending state
  -- Never void or cancel a booking that is already confirmed or paid!
  IF v_booking_id IS NOT NULL AND v_new_status IS NOT NULL THEN
    IF v_current_status IN ('pending', 'pending_payment') THEN
      UPDATE public.bookings
      SET status = v_new_status,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_booking_id;
    END IF;
  END IF;

  -- Record event in idempotency audit log
  INSERT INTO public.payment_webhook_events (
    event_id, event_type, resource_id, booking_id, status, payload
  ) VALUES (
    p_event_id, p_event_type, p_resource_id, v_booking_id, 'processed', p_payload
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent_replay', false,
    'event_id', p_event_id,
    'booking_id', v_booking_id,
    'old_status', v_current_status,
    'new_status', CASE WHEN v_current_status IN ('pending', 'pending_payment') THEN v_new_status ELSE v_current_status END
  );
END;
$$;
