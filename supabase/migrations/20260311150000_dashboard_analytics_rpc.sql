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
