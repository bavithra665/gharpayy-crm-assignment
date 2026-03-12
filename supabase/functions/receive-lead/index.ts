import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Extract IP for rate limiting from headers
  const clientIp = req.headers.get("x-forwarded-for") || req.headers.get("x-real-ip") || "unknown";

  try {
    console.info(JSON.stringify({ event: "receive_lead_started", ip: clientIp, method: req.method }));
    const body = await req.json();
    const { name, phone, email, source, budget, preferred_location, notes } = body;

    // Validate required fields
    if (!name || typeof name !== "string" || name.trim().length === 0) {
      return new Response(JSON.stringify({ error: "Name is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!phone || typeof phone !== "string" || phone.trim().length < 5) {
      return new Response(JSON.stringify({ error: "Valid phone number is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate field lengths
    if (name.length > 200 || (email && email.length > 255) || (phone && phone.length > 30)) {
      console.warn(JSON.stringify({ event: "validation_failed", reason: "Field too long", ip: clientIp }));
      return new Response(JSON.stringify({ error: "Field too long" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const validSources = ["whatsapp", "website", "instagram", "facebook", "phone", "landing_page"];
    const leadSource = validSources.includes(source) ? source : "website";

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // RATE LIMITING CHECK (e.g. Max 10 requests per 60 minutes per IP)
    const { data: isAllowed, error: rateLimitError } = await supabase.rpc("check_rate_limit", {
      p_ip_address: clientIp,
      p_endpoint: "receive-lead",
      p_limit: 10,
      p_window_minutes: 60
    });

    if (rateLimitError) {
      console.error(JSON.stringify({ event: "rate_limit_error", error: rateLimitError.message }));
    } else if (isAllowed === false) {
      console.warn(JSON.stringify({ event: "rate_limit_exceeded", ip: clientIp }));
      return new Response(JSON.stringify({ error: "Too many requests. Please try again later." }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check for duplicate by phone
    const { data: existing } = await supabase
      .from("leads")
      .select("id, name, status")
      .eq("phone", phone.trim())
      .limit(1);

    if (existing && existing.length > 0) {
      return new Response(
        JSON.stringify({
          error: "duplicate",
          message: `Lead already exists: ${existing[0].name} (${existing[0].status})`,
          existing_lead_id: existing[0].id,
        }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Atomic round-robin: call the PL/pgSQL function
    const { data: agentId, error: agentError } = await supabase.rpc('get_next_available_agent');
    
    let assignedAgentId: string | null = null;
    let assignedAgentName: string | null = null;

    if (agentId && !agentError) {
      assignedAgentId = agentId;
      const { data: agentData } = await supabase
        .from("agents")
        .select("name")
        .eq("id", assignedAgentId)
        .single();
      
      if (agentData) assignedAgentName = agentData.name;
    }

    // Insert lead
    const { data: lead, error: insertError } = await supabase
      .from("leads")
      .insert({
        name: name.trim().slice(0, 200),
        phone: phone.trim().slice(0, 30),
        email: email?.trim().slice(0, 255) || null,
        source: leadSource,
        budget: budget?.trim().slice(0, 100) || null,
        preferred_location: preferred_location?.trim().slice(0, 200) || null,
        notes: notes?.trim().slice(0, 2000) || null,
        assigned_agent_id: assignedAgentId,
        status: "new",
      })
      .select("id, name")
      .single();

    if (insertError) throw insertError;

    // Create notification for assigned agent (if agent has a user_id)
    if (assignedAgentId) {
      const { data: agent } = await supabase
        .from("agents")
        .select("user_id")
        .eq("id", assignedAgentId)
        .single();

      if (agent?.user_id) {
        await supabase.from("notifications").insert({
          user_id: agent.user_id,
          type: "new_lead",
          title: "New Lead Assigned",
          body: `${lead.name} (${phone}) has been assigned to you`,
          link: "/leads",
        });
      }
    }

    console.info(JSON.stringify({ 
      event: "lead_processed_successfully", 
      lead_id: lead.id, 
      assigned_agent_id: assignedAgentId,
      source: leadSource 
    }));

    return new Response(
      JSON.stringify({
        success: true,
        id: lead.id,
        name: lead.name,
        assigned_agent: assignedAgentName,
      }),
      {
        status: 201,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error(JSON.stringify({ event: "function_error", error: err.message, stack: err.stack }));
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
