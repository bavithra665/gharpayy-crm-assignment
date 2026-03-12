-- Safe type handling: drop and recreate if needed
DO $$ BEGIN
  DROP TYPE IF EXISTS public.lead_source CASCADE;
  DROP TYPE IF EXISTS public.pipeline_stage CASCADE;
  DROP TYPE IF EXISTS public.lead_status CASCADE;
  DROP TYPE IF EXISTS public.booking_status CASCADE;
  DROP TYPE IF EXISTS public.visit_outcome CASCADE;
  DROP TYPE IF EXISTS public.bed_status CASCADE;
  DROP TYPE IF EXISTS public.room_type CASCADE;
  DROP TYPE IF EXISTS public.payment_status CASCADE;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
-- Create enum types
CREATE TYPE public.lead_source AS ENUM ('whatsapp', 'website', 'instagram', 'facebook', 'phone', 'landing_page');
CREATE TYPE public.pipeline_stage AS ENUM ('new', 'contacted', 'requirement_collected', 'property_suggested', 'visit_scheduled', 'visit_completed', 'booked', 'lost');
CREATE TYPE public.visit_outcome AS ENUM ('booked', 'considering', 'not_interested');

-- Create agents table
CREATE TABLE public.agents (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create properties table
CREATE TABLE public.properties (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  city TEXT,
  area TEXT,
  price_range TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create leads table
CREATE TABLE public.leads (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  source lead_source NOT NULL DEFAULT 'website',
  status pipeline_stage NOT NULL DEFAULT 'new',
  assigned_agent_id UUID REFERENCES public.agents(id) ON DELETE SET NULL,
  budget TEXT,
  preferred_location TEXT,
  notes TEXT,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  first_response_time_min INTEGER,
  next_follow_up TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  last_activity_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create visits table
CREATE TABLE public.visits (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  assigned_staff_id UUID REFERENCES public.agents(id) ON DELETE SET NULL,
  scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
  confirmed BOOLEAN NOT NULL DEFAULT false,
  outcome visit_outcome,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create conversations table
CREATE TABLE public.conversations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE SET NULL,
  message TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  channel TEXT NOT NULL DEFAULT 'whatsapp',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create follow_up_reminders table
CREATE TABLE public.follow_up_reminders (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES public.agents(id) ON DELETE SET NULL,
  reminder_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follow_up_reminders ENABLE ROW LEVEL SECURITY;

-- RLS: authenticated users can read/write all CRM data
CREATE POLICY "Auth users read agents" ON public.agents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage agents" ON public.agents FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update agents" ON public.agents FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete agents" ON public.agents FOR DELETE TO authenticated USING (true);

CREATE POLICY "Auth users read properties" ON public.properties FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage properties" ON public.properties FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update properties" ON public.properties FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete properties" ON public.properties FOR DELETE TO authenticated USING (true);

CREATE POLICY "Auth users read leads" ON public.leads FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage leads" ON public.leads FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update leads" ON public.leads FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete leads" ON public.leads FOR DELETE TO authenticated USING (true);

CREATE POLICY "Auth users read visits" ON public.visits FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage visits" ON public.visits FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update visits" ON public.visits FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete visits" ON public.visits FOR DELETE TO authenticated USING (true);

CREATE POLICY "Auth users read conversations" ON public.conversations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage conversations" ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Auth users read reminders" ON public.follow_up_reminders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users manage reminders" ON public.follow_up_reminders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update reminders" ON public.follow_up_reminders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Indexes
CREATE INDEX idx_leads_status ON public.leads(status);
CREATE INDEX idx_leads_agent ON public.leads(assigned_agent_id);
CREATE INDEX idx_leads_source ON public.leads(source);
CREATE INDEX idx_leads_created ON public.leads(created_at DESC);
CREATE INDEX idx_visits_lead ON public.visits(lead_id);
CREATE INDEX idx_visits_scheduled ON public.visits(scheduled_at);
CREATE INDEX idx_conversations_lead ON public.conversations(lead_id);
CREATE INDEX idx_reminders_lead ON public.follow_up_reminders(lead_id);
CREATE INDEX idx_reminders_date ON public.follow_up_reminders(reminder_date);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Triggers
CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON public.agents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_leads_updated_at BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_visits_updated_at BEFORE UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
-- Allow anon read access for development (no auth yet)
CREATE POLICY "Anon read agents" ON public.agents FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read properties" ON public.properties FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read leads" ON public.leads FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read visits" ON public.visits FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read conversations" ON public.conversations FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read reminders" ON public.follow_up_reminders FOR SELECT TO anon USING (true);

ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS lead_score integer DEFAULT 0;
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name', NEW.email));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.calculate_lead_score(p_lead_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score integer := 0;
  v_lead leads%ROWTYPE;
  v_visit_count integer;
  v_conv_count integer;
BEGIN
  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  CASE v_lead.status
    WHEN 'new' THEN v_score := 10;
    WHEN 'contacted' THEN v_score := 20;
    WHEN 'requirement_collected' THEN v_score := 35;
    WHEN 'property_suggested' THEN v_score := 50;
    WHEN 'visit_scheduled' THEN v_score := 65;
    WHEN 'visit_completed' THEN v_score := 80;
    WHEN 'booked' THEN v_score := 100;
    WHEN 'lost' THEN v_score := 5;
    ELSE v_score := 10;
  END CASE;

  IF v_lead.first_response_time_min IS NOT NULL AND v_lead.first_response_time_min <= 5 THEN
    v_score := v_score + 10;
  END IF;

  IF v_lead.budget IS NOT NULL AND v_lead.budget != '' THEN
    v_score := v_score + 5;
  END IF;

  IF v_lead.email IS NOT NULL AND v_lead.email != '' THEN
    v_score := v_score + 5;
  END IF;

  SELECT COUNT(*) INTO v_visit_count FROM visits WHERE lead_id = p_lead_id;
  v_score := v_score + LEAST(v_visit_count * 5, 15);

  SELECT COUNT(*) INTO v_conv_count FROM conversations WHERE lead_id = p_lead_id;
  v_score := v_score + LEAST(v_conv_count * 2, 10);

  IF v_lead.last_activity_at < now() - interval '7 days' THEN
    v_score := GREATEST(v_score - 15, 0);
  END IF;

  v_score := LEAST(v_score, 100);
  UPDATE leads SET lead_score = v_score WHERE id = p_lead_id;
  RETURN v_score;
END;
$$;

CREATE OR REPLACE FUNCTION public.recalculate_all_lead_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead_id uuid;
BEGIN
  FOR v_lead_id IN SELECT id FROM leads LOOP
    PERFORM calculate_lead_score(v_lead_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_score_lead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM calculate_lead_score(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS lead_auto_score ON public.leads;
CREATE TRIGGER lead_auto_score
  AFTER INSERT OR UPDATE OF status, first_response_time_min, budget, email, last_activity_at ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.auto_score_lead();

ALTER PUBLICATION supabase_realtime ADD TABLE public.follow_up_reminders;
-- Create notifications table
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL DEFAULT 'info',
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  link text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications" ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Users update own notifications" ON public.notifications
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "System insert notifications" ON public.notifications
  FOR INSERT TO authenticated WITH CHECK (true);

-- Create activity_log table
CREATE TABLE public.activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE NOT NULL,
  agent_id uuid REFERENCES public.agents(id) ON DELETE SET NULL,
  action text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Auth users read activity_log" ON public.activity_log
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users insert activity_log" ON public.activity_log
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Anon read activity_log" ON public.activity_log
  FOR SELECT TO anon USING (true);

-- Create message_templates table
CREATE TABLE public.message_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  body text NOT NULL,
  channel text NOT NULL DEFAULT 'whatsapp',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.message_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Auth users read templates" ON public.message_templates
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth users insert templates" ON public.message_templates
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth users update templates" ON public.message_templates
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete templates" ON public.message_templates
  FOR DELETE TO authenticated USING (true);

-- Trigger function: log lead status change
CREATE OR REPLACE FUNCTION public.log_lead_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.activity_log (lead_id, agent_id, action, metadata)
    VALUES (NEW.id, NEW.assigned_agent_id, 'status_change', jsonb_build_object('from', OLD.status, 'to', NEW.status));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lead_status_change
  AFTER UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.log_lead_status_change();

-- Trigger function: log lead agent reassignment
CREATE OR REPLACE FUNCTION public.log_lead_agent_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.assigned_agent_id IS DISTINCT FROM NEW.assigned_agent_id THEN
    INSERT INTO public.activity_log (lead_id, agent_id, action, metadata)
    VALUES (NEW.id, NEW.assigned_agent_id, 'agent_reassigned', jsonb_build_object('from_agent', OLD.assigned_agent_id, 'to_agent', NEW.assigned_agent_id));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lead_agent_change
  AFTER UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.log_lead_agent_change();

-- Trigger function: log visit changes
CREATE OR REPLACE FUNCTION public.log_visit_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.activity_log (lead_id, agent_id, action, metadata)
    VALUES (NEW.lead_id, NEW.assigned_staff_id, 'visit_scheduled', jsonb_build_object('visit_id', NEW.id, 'property_id', NEW.property_id, 'scheduled_at', NEW.scheduled_at));
  ELSIF TG_OP = 'UPDATE' AND OLD.outcome IS DISTINCT FROM NEW.outcome AND NEW.outcome IS NOT NULL THEN
    INSERT INTO public.activity_log (lead_id, agent_id, action, metadata)
    VALUES (NEW.lead_id, NEW.assigned_staff_id, 'visit_outcome', jsonb_build_object('visit_id', NEW.id, 'outcome', NEW.outcome));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_visit_change
  AFTER INSERT OR UPDATE ON public.visits
  FOR EACH ROW
  EXECUTE FUNCTION public.log_visit_change();

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_log;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;

-- 1. Room status enum
CREATE TYPE public.room_status AS ENUM ('occupied', 'vacating', 'vacant', 'blocked');

-- 2. Owners table
CREATE TABLE public.owners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  company_name text,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.owners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read owners" ON public.owners FOR SELECT USING (true);
CREATE POLICY "Auth users manage owners" ON public.owners FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth users update owners" ON public.owners FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete owners" ON public.owners FOR DELETE USING (true);

CREATE TRIGGER update_owners_updated_at BEFORE UPDATE ON public.owners
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 3. Add owner_id to properties
ALTER TABLE public.properties ADD COLUMN owner_id uuid REFERENCES public.owners(id) ON DELETE SET NULL;

-- 4. Rooms table (the atomic unit: Room Ã— Status)
CREATE TABLE public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  floor text,
  bed_count integer NOT NULL DEFAULT 1,
  status public.room_status NOT NULL DEFAULT 'vacant',
  vacating_date date,
  actual_rent numeric,
  expected_rent numeric,
  min_acceptable_rent numeric,
  amenities text[],
  room_type text,
  last_confirmed_at timestamptz DEFAULT now(),
  auto_locked boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read rooms" ON public.rooms FOR SELECT USING (true);
CREATE POLICY "Auth users manage rooms" ON public.rooms FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth users update rooms" ON public.rooms FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete rooms" ON public.rooms FOR DELETE USING (true);

CREATE TRIGGER update_rooms_updated_at BEFORE UPDATE ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Room status log (daily confirmation ritual)
CREATE TABLE public.room_status_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  status public.room_status NOT NULL,
  confirmed_by uuid REFERENCES public.owners(id),
  rent_updated boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.room_status_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read room_status_log" ON public.room_status_log FOR SELECT USING (true);
CREATE POLICY "Auth users manage room_status_log" ON public.room_status_log FOR INSERT WITH CHECK (true);

-- 6. Soft locks (visit-room binding)
CREATE TYPE public.lock_type AS ENUM ('visit_scheduled', 'pre_booking', 'virtual_tour');

CREATE TABLE public.soft_locks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  lead_id uuid REFERENCES public.leads(id) ON DELETE SET NULL,
  lock_type public.lock_type NOT NULL,
  locked_by uuid REFERENCES public.agents(id),
  locked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.soft_locks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read soft_locks" ON public.soft_locks FOR SELECT USING (true);
CREATE POLICY "Auth users manage soft_locks" ON public.soft_locks FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth users update soft_locks" ON public.soft_locks FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete soft_locks" ON public.soft_locks FOR DELETE USING (true);

-- 7. Auto-lock function: rooms not confirmed in 24h get auto_locked = true
CREATE OR REPLACE FUNCTION public.auto_lock_stale_rooms()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE rooms
  SET auto_locked = true
  WHERE last_confirmed_at < now() - interval '24 hours'
    AND auto_locked = false
    AND status != 'occupied';
END;
$$;

-- 8. Trigger: when room status is confirmed, update last_confirmed_at and unlock
CREATE OR REPLACE FUNCTION public.on_room_status_confirm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE rooms
  SET last_confirmed_at = now(),
      auto_locked = false,
      status = NEW.status
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER room_status_confirm_trigger
  AFTER INSERT ON public.room_status_log
  FOR EACH ROW EXECUTE FUNCTION on_room_status_confirm();

-- 9. Effort tracking view: leads/visits/tours per property (as a function for flexibility)
CREATE OR REPLACE FUNCTION public.get_property_effort(p_property_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_leads', (SELECT COUNT(*) FROM leads WHERE property_id = p_property_id),
    'total_visits', (SELECT COUNT(*) FROM visits WHERE property_id = p_property_id),
    'completed_visits', (SELECT COUNT(*) FROM visits WHERE property_id = p_property_id AND outcome IS NOT NULL),
    'booked', (SELECT COUNT(*) FROM visits WHERE property_id = p_property_id AND outcome = 'booked'),
    'considering', (SELECT COUNT(*) FROM visits WHERE property_id = p_property_id AND outcome = 'considering'),
    'not_interested', (SELECT COUNT(*) FROM visits WHERE property_id = p_property_id AND outcome = 'not_interested')
  ) INTO result;
  RETURN result;
END;
$$;

-- 10. Enable realtime for rooms
ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.soft_locks;

-- 1. Bed status enum
CREATE TYPE public.bed_status AS ENUM ('vacant', 'occupied', 'vacating_soon', 'blocked', 'reserved', 'booked');

-- 2. Enhance properties table
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS property_manager text,
  ADD COLUMN IF NOT EXISTS total_rooms integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_beds integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS amenities text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS gender_allowed text DEFAULT 'any',
  ADD COLUMN IF NOT EXISTS google_maps_link text,
  ADD COLUMN IF NOT EXISTS photos text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS virtual_tour_link text;

-- 3. Enhance rooms table
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS room_code text,
  ADD COLUMN IF NOT EXISTS bathroom_type text,
  ADD COLUMN IF NOT EXISTS furnishing text,
  ADD COLUMN IF NOT EXISTS rent_per_bed numeric;

-- 4. Beds table
CREATE TABLE public.beds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  bed_number text NOT NULL,
  status public.bed_status NOT NULL DEFAULT 'vacant',
  current_tenant_name text,
  current_rent numeric,
  move_in_date date,
  move_out_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.beds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read beds" ON public.beds FOR SELECT USING (true);
CREATE POLICY "Auth users manage beds" ON public.beds FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth users update beds" ON public.beds FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete beds" ON public.beds FOR DELETE USING (true);

CREATE TRIGGER update_beds_updated_at BEFORE UPDATE ON public.beds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Add bed_id to visits
ALTER TABLE public.visits
  ADD COLUMN IF NOT EXISTS room_id uuid REFERENCES public.rooms(id),
  ADD COLUMN IF NOT EXISTS bed_id uuid REFERENCES public.beds(id);

-- 6. Add bed_id to soft_locks
ALTER TABLE public.soft_locks
  ADD COLUMN IF NOT EXISTS bed_id uuid REFERENCES public.beds(id);

-- 7. Enable realtime for beds
ALTER PUBLICATION supabase_realtime ADD TABLE public.beds;

-- 8. Bed status log for tracking changes
CREATE TABLE public.bed_status_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bed_id uuid NOT NULL REFERENCES public.beds(id) ON DELETE CASCADE,
  old_status public.bed_status,
  new_status public.bed_status NOT NULL,
  changed_by text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bed_status_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon read bed_status_log" ON public.bed_status_log FOR SELECT USING (true);
CREATE POLICY "Auth users manage bed_status_log" ON public.bed_status_log FOR INSERT WITH CHECK (true);

-- 9. Trigger: log bed status changes
CREATE OR REPLACE FUNCTION public.log_bed_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO bed_status_log (bed_id, old_status, new_status)
    VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER bed_status_change_trigger
  AFTER UPDATE ON public.beds
  FOR EACH ROW EXECUTE FUNCTION log_bed_status_change();

-- 10. Function: auto-generate beds when room is created
CREATE OR REPLACE FUNCTION public.auto_create_beds()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  i integer;
BEGIN
  FOR i IN 1..NEW.bed_count LOOP
    INSERT INTO beds (room_id, bed_number) VALUES (NEW.id, 'B' || i);
  END LOOP;
  RETURN NEW;
END;
$$;

CREATE TRIGGER auto_create_beds_trigger
  AFTER INSERT ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION auto_create_beds();

-- Booking status enum
CREATE TYPE public.booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'checked_in', 'checked_out');

-- Payment status enum
CREATE TYPE public.payment_status AS ENUM ('unpaid', 'partial', 'paid');

-- Bookings table
CREATE TABLE public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  property_id uuid REFERENCES public.properties(id),
  room_id uuid REFERENCES public.rooms(id),
  bed_id uuid REFERENCES public.beds(id),
  visit_id uuid REFERENCES public.visits(id),
  booking_status public.booking_status NOT NULL DEFAULT 'pending',
  monthly_rent numeric,
  security_deposit numeric,
  move_in_date date,
  move_out_date date,
  payment_status public.payment_status NOT NULL DEFAULT 'unpaid',
  notes text,
  booked_by uuid REFERENCES public.agents(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Updated_at trigger
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anon read bookings" ON public.bookings FOR SELECT USING (true);
CREATE POLICY "Auth users insert bookings" ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth users update bookings" ON public.bookings FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth users delete bookings" ON public.bookings FOR DELETE USING (true);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;

-- Trigger: visit outcome 'booked' â†’ auto-create booking + soft lock
CREATE OR REPLACE FUNCTION public.on_visit_booked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.outcome IS DISTINCT FROM NEW.outcome AND NEW.outcome = 'booked' THEN
    -- Create pending booking
    INSERT INTO public.bookings (lead_id, property_id, room_id, bed_id, visit_id, booking_status, booked_by)
    VALUES (NEW.lead_id, NEW.property_id, NEW.room_id, NEW.bed_id, NEW.id, 'pending', NEW.assigned_staff_id);

    -- Create pre_booking soft lock (24h) if bed is specified
    IF NEW.bed_id IS NOT NULL THEN
      INSERT INTO public.soft_locks (room_id, bed_id, lead_id, lock_type, locked_by, expires_at, notes)
      VALUES (NEW.room_id, NEW.bed_id, NEW.lead_id, 'pre_booking', NEW.assigned_staff_id, now() + interval '24 hours', 'Auto-locked from visit booking');
    END IF;

    -- Update lead status to booked
    UPDATE public.leads SET status = 'booked' WHERE id = NEW.lead_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_visit_booked AFTER UPDATE ON public.visits
  FOR EACH ROW EXECUTE FUNCTION public.on_visit_booked();

-- Trigger: booking confirmed â†’ bed status 'booked'
CREATE OR REPLACE FUNCTION public.on_booking_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF OLD.booking_status IS DISTINCT FROM NEW.booking_status AND NEW.booking_status = 'confirmed' THEN
    IF NEW.bed_id IS NOT NULL THEN
      UPDATE public.beds SET status = 'booked' WHERE id = NEW.bed_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_confirmed AFTER UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.on_booking_confirmed();

-- Trigger: booking cancelled â†’ release locks + revert bed
CREATE OR REPLACE FUNCTION public.on_booking_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF OLD.booking_status IS DISTINCT FROM NEW.booking_status AND NEW.booking_status = 'cancelled' THEN
    -- Release soft locks for this lead+room
    UPDATE public.soft_locks SET is_active = false
    WHERE lead_id = NEW.lead_id AND room_id = NEW.room_id AND is_active = true;

    -- Revert bed to vacant if it was booked
    IF NEW.bed_id IS NOT NULL THEN
      UPDATE public.beds SET status = 'vacant' WHERE id = NEW.bed_id AND status = 'booked';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_cancelled AFTER UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.on_booking_cancelled();

-- Also attach the missing triggers from earlier
CREATE TRIGGER trg_auto_score_lead AFTER INSERT OR UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.auto_score_lead();

CREATE TRIGGER trg_log_lead_status AFTER UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.log_lead_status_change();

CREATE TRIGGER trg_log_lead_agent AFTER UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.log_lead_agent_change();

CREATE TRIGGER trg_log_visit AFTER INSERT OR UPDATE ON public.visits
  FOR EACH ROW EXECUTE FUNCTION public.log_visit_change();

CREATE TRIGGER trg_auto_create_beds AFTER INSERT ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_beds();

CREATE TRIGGER trg_log_bed_status AFTER UPDATE ON public.beds
  FOR EACH ROW EXECUTE FUNCTION public.log_bed_status_change();

CREATE TRIGGER trg_room_status_confirm AFTER INSERT ON public.room_status_log
  FOR EACH ROW EXECUTE FUNCTION public.on_room_status_confirm();

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- PERFORMANCE INDEXES
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_agent ON public.leads(assigned_agent_id);
CREATE INDEX IF NOT EXISTS idx_leads_preferred_location ON public.leads(preferred_location);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_score ON public.leads(lead_score DESC);
CREATE INDEX IF NOT EXISTS idx_rooms_property ON public.rooms(property_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);
CREATE INDEX IF NOT EXISTS idx_beds_room ON public.beds(room_id);
CREATE INDEX IF NOT EXISTS idx_beds_status ON public.beds(status);
CREATE INDEX IF NOT EXISTS idx_visits_lead ON public.visits(lead_id);
CREATE INDEX IF NOT EXISTS idx_visits_property ON public.visits(property_id);
CREATE INDEX IF NOT EXISTS idx_visits_scheduled ON public.visits(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_conversations_lead ON public.conversations(lead_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created ON public.conversations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_lead ON public.activity_log(lead_id);
CREATE INDEX IF NOT EXISTS idx_soft_locks_active ON public.soft_locks(is_active, expires_at);
CREATE INDEX IF NOT EXISTS idx_bookings_lead ON public.bookings(lead_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(booking_status);
CREATE INDEX IF NOT EXISTS idx_follow_ups_date ON public.follow_up_reminders(reminder_date) WHERE is_completed = false;

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- ZONES TABLE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE TABLE public.zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  city text NOT NULL DEFAULT 'Bangalore',
  areas text[] NOT NULL DEFAULT '{}',
  manager_id uuid REFERENCES public.agents(id),
  color text DEFAULT '#6366f1',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read zones" ON public.zones FOR SELECT USING (true);
CREATE POLICY "Auth manage zones" ON public.zones FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth update zones" ON public.zones FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth delete zones" ON public.zones FOR DELETE USING (true);

-- Add zone_id to properties and agents
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS zone_id uuid REFERENCES public.zones(id);
ALTER TABLE public.agents ADD COLUMN IF NOT EXISTS zone_id uuid REFERENCES public.zones(id);
ALTER TABLE public.agents ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'agent';

CREATE INDEX IF NOT EXISTS idx_properties_zone ON public.properties(zone_id);
CREATE INDEX IF NOT EXISTS idx_agents_zone ON public.agents(zone_id);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- TEAM QUEUES
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE TABLE public.team_queues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id uuid NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
  team_name text NOT NULL,
  owner_agent_id uuid REFERENCES public.agents(id),
  member_ids uuid[] NOT NULL DEFAULT '{}',
  dispatch_rule text NOT NULL DEFAULT 'round_robin',
  last_assigned_idx integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.team_queues ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read team_queues" ON public.team_queues FOR SELECT USING (true);
CREATE POLICY "Auth manage team_queues" ON public.team_queues FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth update team_queues" ON public.team_queues FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Auth delete team_queues" ON public.team_queues FOR DELETE USING (true);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- HANDOFFS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE TABLE public.handoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  from_agent_id uuid REFERENCES public.agents(id),
  to_agent_id uuid REFERENCES public.agents(id),
  zone_id uuid REFERENCES public.zones(id),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.handoffs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read handoffs" ON public.handoffs FOR SELECT USING (true);
CREATE POLICY "Auth insert handoffs" ON public.handoffs FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_handoffs_lead ON public.handoffs(lead_id);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- ESCALATIONS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE TABLE public.escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL DEFAULT 'general',
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  zone_id uuid REFERENCES public.zones(id),
  raised_by uuid REFERENCES public.agents(id),
  assigned_to uuid REFERENCES public.agents(id),
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'medium',
  description text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.escalations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read escalations" ON public.escalations FOR SELECT USING (true);
CREATE POLICY "Auth manage escalations" ON public.escalations FOR INSERT WITH CHECK (true);
CREATE POLICY "Auth update escalations" ON public.escalations FOR UPDATE USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_escalations_status ON public.escalations(status) WHERE status = 'open';

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- CONVERSATION CONTEXT (chat channels)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS context_type text DEFAULT 'lead';
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS context_id uuid;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_conversations_context ON public.conversations(context_type, context_id);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- ZONE ROUTING FUNCTION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE OR REPLACE FUNCTION public.route_lead_to_zone(p_location text)
RETURNS TABLE(zone_id uuid, zone_name text, queue_id uuid, assigned_agent_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_zone zones%ROWTYPE;
  v_queue team_queues%ROWTYPE;
  v_agent_id uuid;
  v_next_idx integer;
BEGIN
  -- Find matching zone by area overlap
  SELECT z.* INTO v_zone
  FROM zones z
  WHERE z.is_active = true
    AND EXISTS (
      SELECT 1 FROM unnest(z.areas) a
      WHERE lower(p_location) LIKE '%' || lower(a) || '%'
    )
  LIMIT 1;

  IF v_zone.id IS NULL THEN
    -- No zone match, return nulls
    RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::uuid, NULL::uuid;
    RETURN;
  END IF;

  -- Find active queue for zone
  SELECT tq.* INTO v_queue
  FROM team_queues tq
  WHERE tq.zone_id = v_zone.id AND tq.is_active = true
  LIMIT 1;

  IF v_queue.id IS NOT NULL AND array_length(v_queue.member_ids, 1) > 0 THEN
    -- Round-robin assignment
    v_next_idx := (v_queue.last_assigned_idx % array_length(v_queue.member_ids, 1)) + 1;
    v_agent_id := v_queue.member_ids[v_next_idx];
    UPDATE team_queues SET last_assigned_idx = v_next_idx WHERE id = v_queue.id;
  ELSE
    v_agent_id := v_zone.manager_id;
  END IF;

  RETURN QUERY SELECT v_zone.id, v_zone.name, v_queue.id, v_agent_id;
END;
$$;

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- DB-LEVEL MATCHING FUNCTION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE OR REPLACE FUNCTION public.match_beds_for_lead(
  p_location text,
  p_budget numeric,
  p_room_type text DEFAULT NULL
)
RETURNS TABLE(
  bed_id uuid,
  bed_number text,
  room_id uuid,
  room_number text,
  room_type text,
  rent_per_bed numeric,
  property_id uuid,
  property_name text,
  property_area text,
  match_score integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    b.id AS bed_id,
    b.bed_number,
    r.id AS room_id,
    r.room_number,
    r.room_type,
    r.rent_per_bed,
    p.id AS property_id,
    p.name AS property_name,
    p.area AS property_area,
    (
      -- Location match (40 pts)
      CASE WHEN lower(p.area) = lower(p_location) THEN 40
           WHEN lower(p.area) LIKE '%' || lower(p_location) || '%' THEN 25
           WHEN lower(p.city) = lower(p_location) THEN 10
           ELSE 0 END
      +
      -- Budget match (35 pts)
      CASE WHEN r.rent_per_bed IS NOT NULL AND p_budget > 0 THEN
        CASE WHEN r.rent_per_bed <= p_budget THEN 35
             WHEN r.rent_per_bed <= p_budget * 1.15 THEN 20
             WHEN r.rent_per_bed <= p_budget * 1.3 THEN 10
             ELSE 0 END
      ELSE 15 END
      +
      -- Room type match (15 pts)
      CASE WHEN p_room_type IS NOT NULL AND r.room_type = p_room_type THEN 15
           WHEN p_room_type IS NULL THEN 8
           ELSE 0 END
      +
      -- Availability bonus (10 pts)
      CASE WHEN b.status = 'vacant' THEN 10
           WHEN b.status = 'vacating_soon' THEN 5
           ELSE 0 END
    )::integer AS match_score
  FROM beds b
  JOIN rooms r ON r.id = b.room_id
  JOIN properties p ON p.id = r.property_id
  WHERE b.status IN ('vacant', 'vacating_soon')
    AND r.auto_locked = false
    AND p.is_active = true
  ORDER BY match_score DESC
  LIMIT 10;
END;
$$;

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- OVERDUE FOLLOW-UP NOTIFICATION FUNCTION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
CREATE OR REPLACE FUNCTION public.create_overdue_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT f.id, f.lead_id, f.agent_id, l.name as lead_name
    FROM follow_up_reminders f
    JOIN leads l ON l.id = f.lead_id
    WHERE f.is_completed = false
      AND f.reminder_date < now()
      AND f.agent_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.link = '/leads'
          AND n.title LIKE '%' || l.name || '%overdue%'
          AND n.created_at > now() - interval '4 hours'
      )
  LOOP
    INSERT INTO notifications (user_id, title, body, type, link)
    SELECT r.agent_id, 'Follow-up overdue: ' || r.lead_name,
           'A follow-up for ' || r.lead_name || ' is past due. Please take action.',
           'warning', '/leads'
    WHERE EXISTS (SELECT 1 FROM agents WHERE id = r.agent_id AND user_id IS NOT NULL);
  END LOOP;
END;
$$;

-- Enable realtime on new tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.zones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.escalations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.handoffs;

-- Add reservation_hold to lock_type enum
ALTER TYPE public.lock_type ADD VALUE IF NOT EXISTS 'reservation_hold';

-- Create landmarks table for smart discovery
CREATE TABLE public.landmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL DEFAULT 'tech_park', -- tech_park, university, metro_station, mall
  city text NOT NULL DEFAULT 'Bangalore',
  area text,
  latitude numeric,
  longitude numeric,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.landmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read landmarks" ON public.landmarks FOR SELECT USING (true);
CREATE POLICY "Auth manage landmarks" ON public.landmarks FOR INSERT TO authenticated WITH CHECK (true);

-- Add lat/lng to properties for map discovery
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS latitude numeric;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS longitude numeric;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 4.5;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS total_reviews integer DEFAULT 0;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false;

-- Create public reservations table (customer-facing bookings)
CREATE TABLE public.reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_email text,
  property_id uuid REFERENCES public.properties(id) NOT NULL,
  room_id uuid REFERENCES public.rooms(id),
  bed_id uuid REFERENCES public.beds(id),
  move_in_date date NOT NULL,
  room_type text,
  monthly_rent numeric,
  reservation_fee numeric DEFAULT 1000,
  reservation_status text NOT NULL DEFAULT 'pending', -- pending, paid, confirmed, cancelled, expired
  payment_reference text,
  lead_id uuid REFERENCES public.leads(id),
  soft_lock_id uuid REFERENCES public.soft_locks(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone read reservations" ON public.reservations FOR SELECT USING (true);
CREATE POLICY "Anyone insert reservations" ON public.reservations FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone update reservations" ON public.reservations FOR UPDATE USING (true) WITH CHECK (true);

-- Indexes for public platform performance
CREATE INDEX IF NOT EXISTS idx_properties_city ON public.properties(city);
CREATE INDEX IF NOT EXISTS idx_properties_area ON public.properties(area);
CREATE INDEX IF NOT EXISTS idx_properties_active ON public.properties(is_active);
CREATE INDEX IF NOT EXISTS idx_properties_zone ON public.properties(zone_id);
CREATE INDEX IF NOT EXISTS idx_beds_status ON public.beds(status);
CREATE INDEX IF NOT EXISTS idx_rooms_property ON public.rooms(property_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON public.reservations(reservation_status);
CREATE INDEX IF NOT EXISTS idx_reservations_property ON public.reservations(property_id);
CREATE INDEX IF NOT EXISTS idx_landmarks_city ON public.landmarks(city);
CREATE INDEX IF NOT EXISTS idx_landmarks_type ON public.landmarks(type);

-- Enable realtime for reservations
ALTER PUBLICATION supabase_realtime ADD TABLE public.reservations;

-- Function to create reservation with soft lock
CREATE OR REPLACE FUNCTION public.create_reservation_lock(
  p_property_id uuid,
  p_bed_id uuid,
  p_room_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text DEFAULT NULL,
  p_move_in_date date DEFAULT NULL,
  p_room_type text DEFAULT NULL,
  p_monthly_rent numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lock_id uuid;
  v_reservation_id uuid;
  v_expires_at timestamptz;
BEGIN
  v_expires_at := now() + interval '10 minutes';

  -- Check bed is available
  IF NOT EXISTS (SELECT 1 FROM beds WHERE id = p_bed_id AND status = 'vacant') THEN
    RETURN jsonb_build_object('error', 'Bed is no longer available');
  END IF;

  -- Check no active lock exists
  IF EXISTS (SELECT 1 FROM soft_locks WHERE bed_id = p_bed_id AND is_active = true AND expires_at > now()) THEN
    RETURN jsonb_build_object('error', 'Bed is temporarily reserved by another user');
  END IF;

  -- Create soft lock
  INSERT INTO soft_locks (room_id, bed_id, lock_type, expires_at, notes)
  VALUES (p_room_id, p_bed_id, 'reservation_hold', v_expires_at, 'Customer reservation hold')
  RETURNING id INTO v_lock_id;

  -- Update bed status to reserved
  UPDATE beds SET status = 'reserved' WHERE id = p_bed_id;

  -- Create reservation
  INSERT INTO reservations (customer_name, customer_phone, customer_email, property_id, room_id, bed_id, move_in_date, room_type, monthly_rent, soft_lock_id, expires_at)
  VALUES (p_customer_name, p_customer_phone, p_customer_email, p_property_id, p_room_id, p_bed_id, COALESCE(p_move_in_date, CURRENT_DATE + 7), p_room_type, p_monthly_rent, v_lock_id, v_expires_at)
  RETURNING id INTO v_reservation_id;

  RETURN jsonb_build_object('reservation_id', v_reservation_id, 'lock_id', v_lock_id, 'expires_at', v_expires_at);
END;
$$;

-- Function to confirm reservation after payment
CREATE OR REPLACE FUNCTION public.confirm_reservation(
  p_reservation_id uuid,
  p_payment_reference text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res reservations%ROWTYPE;
  v_lead_id uuid;
BEGIN
  SELECT * INTO v_res FROM reservations WHERE id = p_reservation_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Reservation not found'); END IF;
  IF v_res.reservation_status != 'pending' THEN RETURN jsonb_build_object('error', 'Reservation already processed'); END IF;

  -- Update reservation
  UPDATE reservations SET reservation_status = 'paid', payment_reference = p_payment_reference, updated_at = now() WHERE id = p_reservation_id;

  -- Create CRM lead
  INSERT INTO leads (name, phone, email, source, status, property_id, preferred_location, notes)
  VALUES (v_res.customer_name, v_res.customer_phone, v_res.customer_email, 'website', 'booked', v_res.property_id,
    (SELECT area FROM properties WHERE id = v_res.property_id),
    'Online reservation #' || p_reservation_id::text || ' | Payment: ' || p_payment_reference)
  RETURNING id INTO v_lead_id;

  -- Update reservation with lead
  UPDATE reservations SET lead_id = v_lead_id WHERE id = p_reservation_id;

  -- Create booking
  INSERT INTO bookings (lead_id, property_id, room_id, bed_id, booking_status, monthly_rent, move_in_date, payment_status, notes)
  VALUES (v_lead_id, v_res.property_id, v_res.room_id, v_res.bed_id, 'confirmed', v_res.monthly_rent, v_res.move_in_date, 'partial', 'Online reservation fee paid');

  -- Update bed to booked
  IF v_res.bed_id IS NOT NULL THEN
    UPDATE beds SET status = 'booked' WHERE id = v_res.bed_id;
  END IF;

  -- Deactivate soft lock
  IF v_res.soft_lock_id IS NOT NULL THEN
    UPDATE soft_locks SET is_active = false WHERE id = v_res.soft_lock_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'lead_id', v_lead_id, 'reservation_id', p_reservation_id);
END;
$$;

-- Performance indexes for marketplace search
CREATE INDEX IF NOT EXISTS idx_properties_city_area_active ON public.properties (city, area, is_active);
CREATE INDEX IF NOT EXISTS idx_properties_active_rating ON public.properties (is_active, rating DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_rooms_property_status ON public.rooms (property_id, status);
CREATE INDEX IF NOT EXISTS idx_beds_room_status ON public.beds (room_id, status);
CREATE INDEX IF NOT EXISTS idx_beds_status ON public.beds (status);
CREATE INDEX IF NOT EXISTS idx_landmarks_city ON public.landmarks (city);
CREATE INDEX IF NOT EXISTS idx_properties_coords ON public.properties (latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reservations_status ON public.reservations (reservation_status);
CREATE INDEX IF NOT EXISTS idx_soft_locks_active ON public.soft_locks (is_active, expires_at) WHERE is_active = true;
-- Add unique constraint to phone numbers in the leads table
ALTER TABLE public.leads ADD CONSTRAINT leads_phone_key UNIQUE (phone);

-- Add index for fast duplicate checks during high volume
CREATE INDEX IF NOT EXISTS idx_leads_phone ON public.leads(phone);
-- Add last_assigned_at to agents for round-robin tracking
ALTER TABLE public.agents ADD COLUMN IF NOT EXISTS last_assigned_at TIMESTAMPTZ DEFAULT to_timestamp(0);

-- Create a secure function to pick the next agent and update their timestamp atomically
CREATE OR REPLACE FUNCTION public.get_next_available_agent()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    next_agent_id UUID;
BEGIN
    -- Find the active agent who was assigned a lead longest ago
    SELECT id INTO next_agent_id
    FROM public.agents
    WHERE is_active = true
    ORDER BY last_assigned_at ASC, id ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED; -- Prevent concurrent assignment of the same agent if possible

    IF next_agent_id IS NOT NULL THEN
        -- Update their timestamp so they go to the back of the queue
        UPDATE public.agents
        SET last_assigned_at = now()
        WHERE id = next_agent_id;
    END IF;

    RETURN next_agent_id;
END;
$$;
-- Automatically update the lead's last_activity_at timestamp whenever a new activity is logged
CREATE OR REPLACE FUNCTION public.update_lead_last_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update the parent lead's last_activity_at timestamp
  -- This creates a cascading chain: Kanban Drop -> Status Change -> Activity Log -> Update last_activity_at -> Auto-Recalculate Lead Score
  UPDATE public.leads
  SET last_activity_at = NEW.created_at
  WHERE id = NEW.lead_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_last_activity ON public.activity_log;
CREATE TRIGGER trg_update_last_activity
  AFTER INSERT ON public.activity_log
  FOR EACH ROW
  EXECUTE FUNCTION public.update_lead_last_activity();
-- Add room_id and bed_id to visits table to support the auto-booking trigger
ALTER TABLE public.visits 
ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS bed_id UUID REFERENCES public.beds(id) ON DELETE SET NULL;
CREATE OR REPLACE FUNCTION public.generate_inactivity_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count integer := 0;
BEGIN
    -- CTE to find leads that are inactive for 24+ hours and active in pipeline
    WITH inactive_leads AS (
        SELECT l.id AS lead_id, l.name AS lead_name, a.user_id AS agent_user_id, a.id AS agent_id
        FROM public.leads l
        JOIN public.agents a ON a.id = l.assigned_agent_id
        WHERE l.last_activity_at < now() - interval '24 hours'
          AND l.status NOT IN ('booked', 'lost')
          AND a.user_id IS NOT NULL
          -- Ensure we haven't already notified the agent about this lead in the last 24h to prevent spam
          AND NOT EXISTS (
              SELECT 1 FROM public.notifications n
              WHERE n.user_id = a.user_id 
                AND n.type = 'inactivity_reminder'
                AND n.link = '/pipeline?lead=' || l.id
                AND n.created_at > now() - interval '24 hours'
          )
    ),
    inserted_notifications AS (
        -- Insert a system notification for the agent
        INSERT INTO public.notifications (user_id, type, title, body, link)
        SELECT 
            agent_user_id, 
            'inactivity_reminder', 
            'Lead Needs Attention: ' || lead_name, 
            'No activity logged for over 24 hours. Please follow up.', 
            '/pipeline?lead=' || lead_id
        FROM inactive_leads
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_count FROM inserted_notifications;
    
    -- Also auto-generate a pending Follow-Up Reminder in the CRM module if they don't already have one
    INSERT INTO public.follow_up_reminders (lead_id, agent_id, reminder_date, note)
    SELECT 
        l.lead_id, 
        l.agent_id, 
        now(), 
        'Automated reminder: No activity for 24 hours'
    FROM inactive_leads l
    WHERE NOT EXISTS (
        SELECT 1 FROM public.follow_up_reminders f
        WHERE f.lead_id = l.lead_id AND f.is_completed = false
    );

    RETURN v_count;
END;
$$;
-- Function to retrieve highly aggregated dashboard metrics instantly
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_leads int;
  v_new_today int;
  v_avg_resp numeric;
  v_sla_comp int := 0;
  v_sla_breach int := 0;
  v_conv_rate numeric := 0;
  v_bookings int;
  v_visits_sched int;
  v_visits_comp int;
  v_pipeline json;
  v_sources json;
BEGIN
  -- Basic Lead Counts
  SELECT count(*) INTO v_total_leads FROM public.leads;
  SELECT count(*) INTO v_new_today FROM public.leads WHERE created_at >= date_trunc('day', now());
  
  -- Response SLA Metrics
  WITH resp AS (SELECT first_response_time_min FROM public.leads WHERE first_response_time_min IS NOT NULL)
  SELECT 
    COALESCE(round(avg(first_response_time_min), 1), 0),
    count(*) FILTER (WHERE first_response_time_min <= 5),
    count(*) FILTER (WHERE first_response_time_min > 5)
  INTO v_avg_resp, v_sla_comp, v_sla_breach 
  FROM resp;
  
  IF (v_sla_comp + v_sla_breach) > 0 THEN
    v_sla_comp := round((v_sla_comp::numeric / (v_sla_comp + v_sla_breach)) * 100);
  END IF;

  -- Visit Metrics
  SELECT count(*) FILTER (WHERE scheduled_at >= date_trunc('day', now()) AND outcome IS NULL),
         count(*) FILTER (WHERE outcome IS NOT NULL)
  INTO v_visits_sched, v_visits_comp
  FROM public.visits;

  -- Booking Conversions
  SELECT count(*) INTO v_bookings FROM public.leads WHERE status = 'booked';
  IF v_total_leads > 0 THEN
    v_conv_rate := round((v_bookings::numeric / v_total_leads) * 100, 1);
  END IF;

  -- Pipeline Distribution (for the Bar Chart)
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_pipeline
  FROM (SELECT status, count(*) FROM public.leads GROUP BY status) t;
  
  -- Sources Distribution (for the Pie Chart)
  SELECT COALESCE(json_agg(row_to_json(s)), '[]'::json) INTO v_sources
  FROM (SELECT source, count(*) FROM public.leads GROUP BY source) s;

  RETURN json_build_object(
    'totalLeads', v_total_leads,
    'newToday', v_new_today,
    'avgResponseTime', v_avg_resp,
    'slaCompliance', v_sla_comp,
    'slaBreaches', v_sla_breach,
    'conversionRate', v_conv_rate,
    'visitsScheduled', v_visits_sched,
    'visitsCompleted', v_visits_comp,
    'bookingsClosed', v_bookings,
    'pipeline', v_pipeline,
    'sources', v_sources
  );
END;
$$;

-- Function to retrieve aggregated agent performance
CREATE OR REPLACE FUNCTION public.get_agent_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_res json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_res FROM (
    SELECT 
      a.id, 
      a.name,
      count(l.id)::int as "totalLeads",
      (count(l.id) FILTER (WHERE l.status NOT IN ('booked', 'lost')))::int as "activeLeads",
      (count(l.id) FILTER (WHERE l.status = 'booked'))::int as "conversions",
      COALESCE(round(avg(l.first_response_time_min), 1), 0)::numeric as "avgResponseTime"
    FROM public.agents a
    LEFT JOIN public.leads l ON l.assigned_agent_id = a.id
    WHERE a.is_active = true
    GROUP BY a.id, a.name
    ORDER BY "conversions" DESC, "activeLeads" DESC
  ) t;
  
  RETURN v_res;
END;
$$;

