import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import type { Database } from '@/integrations/supabase/types';

type Lead = Database['public']['Tables']['leads']['Row'];
type Agent = Database['public']['Tables']['agents']['Row'];
type Visit = Database['public']['Tables']['visits']['Row'];
type Property = Database['public']['Tables']['properties']['Row'];

// Type for lead with joined agent and property
export type LeadWithRelations = Lead & {
  agents: Pick<Agent, 'id' | 'name'> | null;
  properties: Pick<Property, 'id' | 'name'> | null;
};

export type VisitWithRelations = Visit & {
  leads: Pick<Lead, 'id' | 'name'> | null;
  properties: Pick<Property, 'id' | 'name'> | null;
  agents: Pick<Agent, 'id' | 'name'> | null;
};

// Leads (all — used by Dashboard, Pipeline, etc.)
export const useLeads = () =>
  useQuery({
    queryKey: ['leads'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads')
        .select('*, agents(id, name), properties(id, name)')
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as LeadWithRelations[];
    },
  });

// Leads (paginated — used by Leads list page)
export const useLeadsPaginated = (page = 0, pageSize = 50) =>
  useQuery({
    queryKey: ['leads-paginated', page, pageSize],
    queryFn: async () => {
      const from = page * pageSize;
      const to = from + pageSize - 1;
      const { data, error, count } = await supabase
        .from('leads')
        .select('*, agents(id, name), properties(id, name)', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(from, to);
      if (error) throw error;
      return { leads: data as LeadWithRelations[], total: count || 0 };
    },
  });

export const useLeadsByStatus = (status: string) =>
  useQuery({
    queryKey: ['leads', 'status', status],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads')
        .select('*, agents(id, name), properties(id, name)')
        .eq('status', status as any)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as LeadWithRelations[];
    },
  });

export const useCreateLead = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (lead: Database['public']['Tables']['leads']['Insert']) => {
      const { data, error } = await supabase.from('leads').insert(lead).select().single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['leads'] }),
  });
};

export const useUpdateLead = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string } & Database['public']['Tables']['leads']['Update']) => {
      const { data, error } = await supabase.from('leads').update(updates).eq('id', id).select().single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['leads'] }),
  });
};

// Agents
export const useAgents = () =>
  useQuery({
    queryKey: ['agents'],
    queryFn: async () => {
      const { data, error } = await supabase.from('agents').select('*').eq('is_active', true).order('name');
      if (error) throw error;
      return data;
    },
  });

// Properties
export const useProperties = () =>
  useQuery({
    queryKey: ['properties'],
    queryFn: async () => {
      const { data, error } = await supabase.from('properties').select('*').eq('is_active', true).order('name');
      if (error) throw error;
      return data;
    },
  });

// Visits
export const useVisits = () =>
  useQuery({
    queryKey: ['visits'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('visits')
        .select('*, leads(id, name), properties(id, name), agents:assigned_staff_id(id, name)')
        .order('scheduled_at', { ascending: true });
      if (error) throw error;
      return data as VisitWithRelations[];
    },
  });

export const useCreateVisit = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (visit: Database['public']['Tables']['visits']['Insert']) => {
      const { data, error } = await supabase.from('visits').insert(visit).select().single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['visits'] }),
  });
};

// Dashboard stats — powered by server-side SQL RPC for efficiency
export const useDashboardStats = () =>
  useQuery({
    queryKey: ['dashboard-stats'],
    staleTime: 60_000, // 60-second cache; realtime subscription invalidates as needed
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_dashboard_stats');
      if (error) throw error;
      const d = data as any;
      return {
        totalLeads: d.totalLeads as number,
        newToday: d.newToday as number,
        avgResponseTime: d.avgResponseTime as number,
        slaCompliance: d.slaCompliance as number,
        slaBreaches: d.slaBreaches as number,
        conversionRate: d.conversionRate as number,
        visitsScheduled: d.visitsScheduled as number,
        visitsCompleted: d.visitsCompleted as number,
        bookingsClosed: d.bookingsClosed as number,
        // Pre-aggregated chart data — no client-side computation needed
        pipelineData: (d.pipeline as Array<{ status: string; count: string }>) || [],
        sourcesData: (d.sources as Array<{ source: string; count: string }>) || [],
      };
    },
  });

// Agent performance stats — single efficient SQL aggregation
export const useAgentStats = () =>
  useQuery({
    queryKey: ['agent-stats'],
    staleTime: 60_000,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_agent_stats');
      if (error) throw error;
      return (data as any[]) as Array<{
        id: string;
        name: string;
        totalLeads: number;
        activeLeads: number;
        conversions: number;
        avgResponseTime: number;
      }>;
    },
  });
