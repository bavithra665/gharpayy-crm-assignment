-- 1. Create a table for API Rate Limiting
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ip_address TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index the rate limit table for high-performance reading and writing
CREATE INDEX IF NOT EXISTS idx_api_rate_limits_window ON public.api_rate_limits(ip_address, endpoint, window_start);

-- RPC for incrementing and checking rate limits inside Edge Functions
CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_ip_address TEXT, 
    p_endpoint TEXT, 
    p_limit INTEGER, 
    p_window_minutes INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_window_start TIMESTAMPTZ := now() - MAKE_INTERVAL(mins => p_window_minutes);
    v_current_count INTEGER;
BEGIN
    -- Delete old records outside the window for cleanup
    DELETE FROM public.api_rate_limits
    WHERE window_start < v_window_start 
      AND ip_address = p_ip_address 
      AND endpoint = p_endpoint;

    -- Check current requests in window
    SELECT COALESCE(SUM(request_count), 0) INTO v_current_count
    FROM public.api_rate_limits
    WHERE ip_address = p_ip_address
      AND endpoint = p_endpoint
      AND window_start >= v_window_start;

    IF v_current_count >= p_limit THEN
        RETURN FALSE; -- Rate limit exceeded
    END IF;

    -- Log the new request (using a new row per request for high concurrency append, or incrementing existing)
    INSERT INTO public.api_rate_limits (ip_address, endpoint)
    VALUES (p_ip_address, p_endpoint);

    RETURN TRUE; -- Within limit
END;
$$;

-- 2. Add Supabase storage for property images
-- First, create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('property_images', 'property_images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
-- Allow anyone to read images
CREATE POLICY "Public Access" ON storage.objects
FOR SELECT USING (bucket_id = 'property_images');

-- Allow only authenticated users to upload images
CREATE POLICY "Auth Users Upload" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'property_images' 
    AND auth.role() = 'authenticated'
);

-- Allow users to update and delete their own uploads
CREATE POLICY "Auth Users Manage Uploads" ON storage.objects
FOR UPDATE TO authenticated USING (bucket_id = 'property_images' AND owner = auth.uid());

CREATE POLICY "Auth Users Delete Uploads" ON storage.objects
FOR DELETE TO authenticated USING (bucket_id = 'property_images' AND owner = auth.uid());

-- 3. Optimize Database Queries with additional Indexes
-- Creating indexes for frequently joined or filtered columns
CREATE INDEX IF NOT EXISTS idx_leads_source_status ON public.leads(source, status);
CREATE INDEX IF NOT EXISTS idx_visits_property ON public.visits(property_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_beds_room ON public.beds(room_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created ON public.conversations(created_at DESC);
