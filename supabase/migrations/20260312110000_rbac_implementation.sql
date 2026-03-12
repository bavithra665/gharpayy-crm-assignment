-- Role-Based Access Control (RBAC) Setup

-- 1. Create app_role enum
DO $$ BEGIN
    CREATE TYPE public.app_role AS ENUM ('admin', 'manager', 'agent', 'owner');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Create user_roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'agent',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);

-- Enable RLS on user_roles
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 3. Implement has_role() SQL function
-- This function checks if the current user has a specific role efficiently.
CREATE OR REPLACE FUNCTION public.has_role(target_role public.app_role)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
    AND role = target_role
  );
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- Also a helper for "at least" or "is in"
CREATE OR REPLACE FUNCTION public.is_admin_or_manager()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager')
  );
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- 4. Initial Roles Seeding (Policies for user_roles)
CREATE POLICY "Admins can manage roles" ON public.user_roles
  FOR ALL TO authenticated USING (public.has_role('admin'));

CREATE POLICY "Users can view their own roles" ON public.user_roles
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 5. Update Properties to support Ownership
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);

-- 6. Update RLS Policies for RBAC

-- LEADS
-- Admins/Managers: Full Access
-- Agents: Can see leads assigned to them or unassigned leads
-- Owners: No access (typically)
-- Anon: Insert Only (Lead capture)

DROP POLICY IF EXISTS "Auth users read leads" ON public.leads;
DROP POLICY IF EXISTS "Auth users manage leads" ON public.leads;
DROP POLICY IF EXISTS "Auth users update leads" ON public.leads;
DROP POLICY IF EXISTS "Auth users delete leads" ON public.leads;

CREATE POLICY "Admins/Managers full lead access" ON public.leads
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

CREATE POLICY "Agents see assigned leads" ON public.leads
  FOR SELECT TO authenticated USING (
    public.has_role('agent') AND (assigned_agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid()) OR assigned_agent_id IS NULL)
  );

CREATE POLICY "Agents update assigned leads" ON public.leads
  FOR UPDATE TO authenticated USING (
    public.has_role('agent') AND (assigned_agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid()))
  );

-- PROPERTIES (Inventory)
-- Admins/Managers: Full Access (Edit inventory)
-- Agents: Read Only
-- Owners: Read Only (their own properties)
-- Anon: Read Only

DROP POLICY IF EXISTS "Auth users read properties" ON public.properties;
DROP POLICY IF EXISTS "Auth users manage properties" ON public.properties;
DROP POLICY IF EXISTS "Auth users update properties" ON public.properties;
DROP POLICY IF EXISTS "Auth users delete properties" ON public.properties;

CREATE POLICY "Admins/Managers manage inventory" ON public.properties
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

CREATE POLICY "Agents/Owners/Anon read properties" ON public.properties
  FOR SELECT USING (true);

-- ROOMS & BEDS (Inventory)
-- Restrict editing to Managers/Admins

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.beds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Managers manage rooms" ON public.rooms;
CREATE POLICY "Managers manage rooms" ON public.rooms
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

CREATE POLICY "Public read rooms" ON public.rooms FOR SELECT USING (true);

DROP POLICY IF EXISTS "Managers manage beds" ON public.beds;
CREATE POLICY "Managers manage beds" ON public.beds
  FOR ALL TO authenticated USING (public.is_admin_or_manager());

CREATE POLICY "Public read beds" ON public.beds FOR SELECT USING (true);

-- 6. Update RLS Policies for RBAC
-- (Policies remain the same as before)
-- ... [Existing policies] ...

-- 7. AUTO-ASSIGN ADMIN ROLE
-- This ensures the first user (usually you) becomes the Admin automatically.
DO $$ 
DECLARE 
  first_user_id UUID;
BEGIN
  -- Get the first user from the project
  SELECT id INTO first_user_id FROM auth.users LIMIT 1;
  
  -- Assign them the admin role if they don't have one
  IF first_user_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (first_user_id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
END $$;
