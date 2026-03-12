import AppLayout from '@/components/AppLayout';
import KpiCard from '@/components/KpiCard';
import OnboardingCard from '@/components/OnboardingCard';
import { useDashboardStats, useLeads, useAgentStats } from '@/hooks/useCrmData';
import { useAllReminders, useCompleteFollowUp } from '@/hooks/useLeadDetails';
import { useBookingStats } from '@/hooks/useBookings';
import { PIPELINE_STAGES, SOURCE_LABELS } from '@/types/crm';
import { Users, Clock, CalendarCheck, CheckCircle, TrendingUp, AlertTriangle, Timer, Star, IndianRupee } from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend, LineChart, Line, CartesianGrid,
} from 'recharts';
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import { format, isPast } from 'date-fns';
import { toast } from 'sonner';
import { motion } from 'framer-motion';
import { supabase } from '@/integrations/supabase/client';
import { useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';

const PIE_COLORS = [
  'hsl(var(--accent))', 'hsl(var(--info))', 'hsl(var(--destructive))',
  'hsl(262, 55%, 55%)', 'hsl(var(--warning))', 'hsl(var(--success))',
];

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.05 } },
};

const Dashboard = () => {
  const { data: stats, isLoading: statsLoading } = useDashboardStats();
  const { data: leads, isLoading: leadsLoading } = useLeads();
  const { data: agentStats } = useAgentStats();
  const { data: bookingStats } = useBookingStats();
  const { data: reminders } = useAllReminders();
  const completeFollowUp = useCompleteFollowUp();
  const qc = useQueryClient();

  // Realtime subscription for leads
  useEffect(() => {
    const channel = supabase
      .channel('dashboard-leads-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'leads' }, () => {
        qc.invalidateQueries({ queryKey: ['leads'] });
        qc.invalidateQueries({ queryKey: ['dashboard-stats'] });
        qc.invalidateQueries({ queryKey: ['agent-stats'] });
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [qc]);

  // Chart data comes pre-aggregated from the server RPC — no client-side computation
  const pipelineData = (stats?.pipelineData || []).map((d: any) => ({
    name: PIPELINE_STAGES.find(s => s.key === d.status)?.label.split(' ')[0] ?? d.status,
    count: parseInt(d.count, 10),
    fill: PIPELINE_STAGES.find(s => s.key === d.status)?.color
      ? `hsl(var(--accent))` : `hsl(var(--muted-foreground))`,
  }));

  const sourceData = (stats?.sourcesData || []).map((d: any) => ({
    name: SOURCE_LABELS[d.source as keyof typeof SOURCE_LABELS] ?? d.source,
    value: parseInt(d.count, 10),
  }));

  // Agent performance chart data
  const agentChartData = (agentStats || []).slice(0, 8).map(a => ({
    name: a.name.split(' ')[0],
    Active: a.activeLeads,
    Booked: a.conversions,
    'Avg Resp (min)': a.avgResponseTime,
  }));

  // Visits comparison
  const visitsChartData = [
    { name: 'Scheduled', value: stats?.visitsScheduled ?? 0 },
    { name: 'Completed', value: stats?.visitsCompleted ?? 0 },
    { name: 'Converted', value: stats?.bookingsClosed ?? 0 },
  ];

  const newLeads = leads?.filter(l => l.status === 'new') || [];
  const hotLeads = leads?.filter(l => ((l as any).lead_score ?? 0) >= 70).slice(0, 5) || [];
  const overdueReminders = reminders?.filter(r => isPast(new Date(r.reminder_date))) || [];

  const handleComplete = async (id: string) => {
    try {
      await completeFollowUp.mutateAsync(id);
      toast.success('Follow-up marked as done');
    } catch (err: any) { toast.error(err.message); }
  };

  if (statsLoading || leadsLoading) {
    return (
      <AppLayout title="Dashboard" subtitle="Real-time overview of your sales pipeline">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          {[...Array(8)].map((_, i) => <Skeleton key={i} className="h-[130px] rounded-2xl" />)}
        </div>
      </AppLayout>
    );
  }

  return (
    <AppLayout title="Dashboard" subtitle="Real-time overview of your sales pipeline">
      {/* Onboarding */}
      <OnboardingCard />

      {/* Overdue alert */}
      {overdueReminders.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6 p-4 bg-destructive/5 border border-destructive/15 rounded-2xl flex items-center gap-3 flex-wrap"
        >
          <AlertTriangle size={15} className="text-destructive shrink-0" />
          <span className="text-2xs font-medium text-destructive">{overdueReminders.length} overdue follow-up{overdueReminders.length > 1 ? 's' : ''} need attention</span>
        </motion.div>
      )}

      {/* KPIs */}
      <motion.div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6" variants={container} initial="hidden" animate="show">
        <KpiCard title="Total Leads" value={stats?.totalLeads ?? 0} icon={<Users size={17} />} />
        <KpiCard title="Avg Response Time" value={stats?.avgResponseTime ?? 0} suffix="min" icon={<Clock size={17} />} color="hsl(var(--warning))" />
        <KpiCard title="Visits Scheduled" value={stats?.visitsScheduled ?? 0} icon={<CalendarCheck size={17} />} color="hsl(173, 55%, 42%)" />
        <KpiCard title="Bookings Closed" value={stats?.bookingsClosed ?? 0} icon={<CheckCircle size={17} />} color="hsl(var(--success))" />
      </motion.div>
      <motion.div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8" variants={container} initial="hidden" animate="show">
        <KpiCard title="Conversion Rate" value={stats?.conversionRate ?? 0} suffix="%" icon={<TrendingUp size={17} />} color="hsl(262, 55%, 55%)" />
        <KpiCard title="SLA Compliance" value={stats?.slaCompliance ?? 0} suffix="%" icon={<Timer size={17} />} color="hsl(var(--info))" />
        <KpiCard title="New Today" value={stats?.newToday ?? 0} icon={<Users size={17} />} color="hsl(var(--destructive))" />
        <KpiCard title="SLA Breaches" value={stats?.slaBreaches ?? 0} icon={<AlertTriangle size={17} />} color="hsl(0, 55%, 50%)" />
      </motion.div>

      {/* Revenue Forecast */}
      {bookingStats && (bookingStats.revenue > 0 || bookingStats.pendingRevenue > 0) && (
        <motion.div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <KpiCard title="Confirmed Revenue" value={`₹${(bookingStats.revenue / 1000).toFixed(0)}k`} icon={<IndianRupee size={17} />} color="hsl(var(--success))" />
          <KpiCard title="Pipeline Revenue" value={`₹${(bookingStats.pendingRevenue / 1000).toFixed(0)}k`} icon={<TrendingUp size={17} />} color="hsl(var(--warning))" />
          <KpiCard title="Projected Revenue" value={`₹${((bookingStats.revenue + bookingStats.pendingRevenue * 0.6) / 1000).toFixed(0)}k`} icon={<IndianRupee size={17} />} color="hsl(var(--accent))" />
          <KpiCard title="Active Bookings" value={bookingStats.confirmed + bookingStats.checkedIn} icon={<CheckCircle size={17} />} color="hsl(var(--info))" />
        </motion.div>
      )}

      {/* Charts Row 1: Pipeline + Sources */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
        <div className="lg:col-span-2 kpi-card">
          <h3 className="font-display font-semibold text-xs text-foreground mb-5">Pipeline Distribution</h3>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={pipelineData} barSize={28}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
              <XAxis dataKey="name" tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <Tooltip
                contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 8px 24px rgba(0,0,0,0.08)', fontSize: '11px', background: 'hsl(var(--card))' }}
                cursor={{ fill: 'hsl(var(--secondary))' }}
              />
              <Bar dataKey="count" fill="hsl(var(--accent))" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="kpi-card">
          <h3 className="font-display font-semibold text-xs text-foreground mb-4">Lead Sources</h3>
          <ResponsiveContainer width="100%" height={160}>
            <PieChart>
              <Pie data={sourceData} cx="50%" cy="50%" innerRadius={44} outerRadius={68} paddingAngle={3} dataKey="value" strokeWidth={0}>
                {sourceData.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />)}
              </Pie>
              <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 8px 24px rgba(0,0,0,0.08)', fontSize: '11px', background: 'hsl(var(--card))' }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex flex-wrap gap-x-3 gap-y-1.5 mt-2">
            {sourceData.map((s, i) => (
              <div key={s.name} className="flex items-center gap-1.5 text-[10px] text-muted-foreground">
                <div className="w-2 h-2 rounded-full shrink-0" style={{ background: PIE_COLORS[i % PIE_COLORS.length] }} />
                <span>{s.name}</span>
                <span className="font-semibold text-foreground">{s.value}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Charts Row 2: Agent Performance + Visit Funnel */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-8">
        <div className="lg:col-span-2 kpi-card">
          <h3 className="font-display font-semibold text-xs text-foreground mb-5">Agent Performance</h3>
          {agentChartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={agentChartData} barSize={16}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', fontSize: '11px', background: 'hsl(var(--card))' }} cursor={{ fill: 'hsl(var(--secondary))' }} />
                <Legend wrapperStyle={{ fontSize: '10px', paddingTop: '12px' }} />
                <Bar dataKey="Active" fill="hsl(var(--info))" radius={[4, 4, 0, 0]} />
                <Bar dataKey="Booked" fill="hsl(var(--success))" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <p className="text-xs text-muted-foreground text-center py-10">No agent data yet</p>
          )}
        </div>

        <div className="kpi-card">
          <h3 className="font-display font-semibold text-xs text-foreground mb-5">Visit Funnel</h3>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={visitsChartData} layout="vertical" barSize={18}>
              <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="hsl(var(--border))" />
              <XAxis type="number" tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <YAxis type="category" dataKey="name" tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} width={70} />
              <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', fontSize: '11px', background: 'hsl(var(--card))' }} />
              <Bar dataKey="value" radius={[0, 8, 8, 0]}>
                {visitsChartData.map((_, i) => (
                  <Cell key={i} fill={[
                    'hsl(var(--accent))', 'hsl(var(--info))', 'hsl(var(--success))',
                  ][i]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Bottom Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Needs Attention */}
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-xs text-foreground">Needs Attention</h3>
            <span className="text-2xs text-muted-foreground bg-secondary px-2 py-0.5 rounded-full">{newLeads.length}</span>
          </div>
          <div className="space-y-2">
            {newLeads.slice(0, 5).map(lead => (
              <div key={lead.id} className="flex items-center justify-between p-3 rounded-xl bg-secondary/50">
                <div>
                  <p className="text-xs font-medium text-foreground">{lead.name}</p>
                  <p className="text-[10px] text-muted-foreground">{lead.preferred_location} · {lead.budget}</p>
                </div>
                <div className="text-right">
                  <p className="text-[10px] text-muted-foreground">{lead.agents?.name}</p>
                  <p className="text-[10px] text-destructive font-medium">Awaiting</p>
                </div>
              </div>
            ))}
            {newLeads.length === 0 && <p className="text-2xs text-muted-foreground text-center py-6">All leads responded ✓</p>}
          </div>
        </div>

        {/* Hot Leads */}
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-xs text-foreground">Hot Leads</h3>
            <span className="text-2xs text-muted-foreground bg-secondary px-2 py-0.5 rounded-full">Score ≥70</span>
          </div>
          <div className="space-y-2">
            {hotLeads.map(lead => (
              <div key={lead.id} className="flex items-center justify-between p-3 rounded-xl bg-secondary/50">
                <div>
                  <p className="text-xs font-medium text-foreground">{lead.name}</p>
                  <p className="text-[10px] text-muted-foreground">{lead.preferred_location}</p>
                </div>
                <span className="flex items-center gap-1 text-2xs font-bold text-success">
                  <Star size={10} /> {(lead as any).lead_score}
                </span>
              </div>
            ))}
            {hotLeads.length === 0 && <p className="text-2xs text-muted-foreground text-center py-6">No hot leads yet</p>}
          </div>
        </div>

        {/* Follow-ups */}
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-xs text-foreground">Follow-ups</h3>
            <span className="text-2xs text-muted-foreground bg-secondary px-2 py-0.5 rounded-full">{reminders?.length || 0} pending</span>
          </div>
          <div className="space-y-2">
            {(reminders || []).slice(0, 5).map(r => (
              <div key={r.id} className={`flex items-center justify-between p-3 rounded-xl ${isPast(new Date(r.reminder_date)) ? 'bg-destructive/5 border border-destructive/15' : 'bg-secondary/50'}`}>
                <div>
                  <p className="text-xs font-medium text-foreground">{(r as any).leads?.name}</p>
                  <p className="text-[10px] text-muted-foreground">
                    {format(new Date(r.reminder_date), 'MMM d, h:mm a')}
                    {isPast(new Date(r.reminder_date)) && <span className="text-destructive ml-1 font-medium">OVERDUE</span>}
                  </p>
                </div>
                <Button variant="outline" size="sm" className="h-7 text-[10px] rounded-lg" onClick={() => handleComplete(r.id)}>
                  Done
                </Button>
              </div>
            ))}
            {(reminders?.length || 0) === 0 && <p className="text-2xs text-muted-foreground text-center py-6">No pending follow-ups</p>}
          </div>
        </div>
      </div>

      {/* Agent Performance Detail Table */}
      <div className="kpi-card mt-2">
        <h3 className="font-display font-semibold text-xs text-foreground mb-4">Agent Leaderboard</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-border">
                <th className="text-left pb-2.5 text-[10px] font-medium text-muted-foreground">Agent</th>
                <th className="text-right pb-2.5 text-[10px] font-medium text-muted-foreground">Total Leads</th>
                <th className="text-right pb-2.5 text-[10px] font-medium text-muted-foreground">Active</th>
                <th className="text-right pb-2.5 text-[10px] font-medium text-muted-foreground">Booked</th>
                <th className="text-right pb-2.5 text-[10px] font-medium text-muted-foreground">Avg Resp.</th>
                <th className="text-right pb-2.5 text-[10px] font-medium text-muted-foreground">Conv. Rate</th>
              </tr>
            </thead>
            <tbody>
              {(agentStats || []).map((agent, i) => {
                const rate = agent.totalLeads ? Math.round((agent.conversions / agent.totalLeads) * 100) : 0;
                return (
                  <tr key={agent.id} className="border-b border-border last:border-0 hover:bg-secondary/30 transition-colors">
                    <td className="py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-accent/10 flex items-center justify-center shrink-0">
                          <span className="text-[10px] font-bold text-accent">{agent.name.charAt(0)}</span>
                        </div>
                        <span className="font-medium text-foreground">{agent.name}</span>
                        {i === 0 && <span className="text-[9px] font-bold text-warning ml-1">★ TOP</span>}
                      </div>
                    </td>
                    <td className="text-right py-3 text-muted-foreground">{agent.totalLeads}</td>
                    <td className="text-right py-3 text-muted-foreground">{agent.activeLeads}</td>
                    <td className="text-right py-3 text-success font-medium">{agent.conversions}</td>
                    <td className="text-right py-3 text-muted-foreground">{agent.avgResponseTime}m</td>
                    <td className="text-right py-3">
                      <span className={`font-bold ${
                        rate >= 20 ? 'text-success' : rate >= 10 ? 'text-warning' : 'text-destructive'
                      }`}>{rate}%</span>
                    </td>
                  </tr>
                );
              })}
              {(agentStats?.length ?? 0) === 0 && (
                <tr><td colSpan={6} className="text-center py-8 text-muted-foreground text-xs">No agent data yet</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </AppLayout>
  );
};

export default Dashboard;
