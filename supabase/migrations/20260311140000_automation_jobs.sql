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
