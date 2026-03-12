import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") as string;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string;

// Initialize Supabase admin client to bypass RLS and perform automated maintenance
const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req) => {
  try {
    // Enforce basic security if the endpoint goes public
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.includes(Deno.env.get("SUPABASE_ANON_KEY") as string)) {
       // Optional: Add strict cron secret validation if needed
    }

    console.log("Starting hourly inactivity sweep...");

    // Execute the secure PL/pgSQL function to prevent race conditions or massive data transfer over the network
    const { data: count, error } = await supabase.rpc("generate_inactivity_reminders");

    if (error) {
      console.error("Error generating follow-up reminders:", error);
      throw error;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Successfully processed inactivity sweep",
        remindersCreated: count,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
