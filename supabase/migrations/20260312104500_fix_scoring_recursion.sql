-- Fix Lead Scoring to prevent infinite recursion
-- We change calculate_lead_score to return ONLY the score, without performing an UPDATE itself.
-- Then we use a BEFORE trigger to set the value.

CREATE OR REPLACE FUNCTION public.calculate_lead_score_value(p_lead_id uuid, p_lead leads)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score integer := 0;
  v_visit_count integer;
  v_conv_count integer;
BEGIN
  -- We use the p_lead record passed in directly to avoid re-querying and recursion issues
  CASE p_lead.status
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

  IF p_lead.first_response_time_min IS NOT NULL AND p_lead.first_response_time_min <= 5 THEN
    v_score := v_score + 10;
  END IF;

  IF p_lead.budget IS NOT NULL AND p_lead.budget != '' THEN
    v_score := v_score + 5;
  END IF;

  IF p_lead.email IS NOT NULL AND p_lead.email != '' THEN
    v_score := v_score + 5;
  END IF;

  SELECT COUNT(*) INTO v_visit_count FROM visits WHERE lead_id = p_lead_id;
  v_score := v_score + LEAST(v_visit_count * 5, 15);

  SELECT COUNT(*) INTO v_conv_count FROM conversations WHERE lead_id = p_lead_id;
  v_score := v_score + LEAST(v_conv_count * 2, 10);

  IF p_lead.last_activity_at < now() - interval '7 days' THEN
    v_score := GREATEST(v_score - 15, 0);
  END IF;

  RETURN LEAST(v_score, 100);
END;
$$;

-- New trigger function for BEFORE UPDATE/INSERT
CREATE OR REPLACE FUNCTION public.trg_fn_auto_score_lead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Simply set the lead_score on the NEW record
  NEW.lead_score := public.calculate_lead_score_value(NEW.id, NEW);
  RETURN NEW;
END;
$$;

-- Replace the old trigger with a BEFORE trigger
DROP TRIGGER IF EXISTS lead_auto_score ON public.leads;
CREATE TRIGGER lead_auto_score
  BEFORE INSERT OR UPDATE OF status, first_response_time_min, budget, email, last_activity_at ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.trg_fn_auto_score_lead();

-- Update existing calculate_lead_score to use the new logic (for manual calls)
CREATE OR REPLACE FUNCTION public.calculate_lead_score(p_lead_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score integer;
  v_lead leads%ROWTYPE;
BEGIN
  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id;
  IF NOT FOUND THEN RETURN 0; END IF;
  
  v_score := public.calculate_lead_score_value(p_lead_id, v_lead);
  
  -- Manual update if called outside a trigger
  UPDATE leads SET lead_score = v_score WHERE id = p_lead_id;
  RETURN v_score;
END;
$$;
