-- Allow anonymous users to insert leads (for lead capture forms)
CREATE POLICY "Allow anonymous lead insertion" ON public.leads
FOR INSERT TO anon
WITH CHECK (true);

-- Allow anonymous users to see leads (only for testing/demo purposes)
-- NOTE: In a real production app, you would remove this and only allow signed-in agents to see leads.
CREATE POLICY "Allow anonymous lead selection" ON public.leads
FOR SELECT TO anon
USING (true);

-- Allow anonymous updates (needed for some frontend demo states)
CREATE POLICY "Allow anonymous lead updates" ON public.leads
FOR UPDATE TO anon
USING (true)
WITH CHECK (true);
