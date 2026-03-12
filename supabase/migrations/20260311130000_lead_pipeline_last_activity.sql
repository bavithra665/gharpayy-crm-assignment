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
