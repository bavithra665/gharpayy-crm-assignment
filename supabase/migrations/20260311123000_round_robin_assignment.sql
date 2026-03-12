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
