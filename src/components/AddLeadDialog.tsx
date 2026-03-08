import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { Plus, AlertTriangle } from 'lucide-react';
import { useCreateLead, useAgents } from '@/hooks/useCrmData';
import { SOURCE_LABELS } from '@/types/crm';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';

const AddLeadDialog = () => {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    name: '',
    phone: '',
    email: '',
    source: 'whatsapp' as string,
    budget: '',
    preferred_location: '',
    notes: '',
    assigned_agent_id: '' as string,
  });
  const [duplicate, setDuplicate] = useState<{ id: string; name: string; phone: string; status: string } | null>(null);

  const createLead = useCreateLead();
  const { data: agents } = useAgents();

  const checkDuplicate = async (phone: string) => {
    if (!phone || phone.length < 5) { setDuplicate(null); return; }
    const { data } = await supabase.from('leads').select('id, name, phone, status').eq('phone', phone).limit(1);
    if (data && data.length > 0) setDuplicate(data[0]);
    else setDuplicate(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.phone) {
      toast.error('Name and phone are required');
      return;
    }

    try {
      const agentId = form.assigned_agent_id || agents?.[0]?.id || null;

      await createLead.mutateAsync({
        name: form.name,
        phone: form.phone,
        email: form.email || null,
        source: form.source as any,
        budget: form.budget || null,
        preferred_location: form.preferred_location || null,
        notes: form.notes || null,
        assigned_agent_id: agentId,
        status: 'new',
      });

      toast.success('Lead created successfully!');
      setOpen(false);
      setDuplicate(null);
      setForm({ name: '', phone: '', email: '', source: 'whatsapp', budget: '', preferred_location: '', notes: '', assigned_agent_id: '' });
    } catch (err: any) {
      toast.error(err.message || 'Failed to create lead');
    }
  };

  return (
    <Dialog open={open} onOpenChange={(v) => { setOpen(v); if (!v) setDuplicate(null); }}>
      <DialogTrigger asChild>
        <Button size="sm" className="gap-1.5 text-xs">
          <Plus size={13} /> Add Lead
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[480px]">
        <DialogHeader>
          <DialogTitle className="font-display">Add New Lead</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 mt-2">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Name *</Label>
              <Input placeholder="Full name" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Phone *</Label>
              <Input
                placeholder="+91 98765 43210"
                value={form.phone}
                onChange={e => { setForm(f => ({ ...f, phone: e.target.value })); }}
                onBlur={() => checkDuplicate(form.phone)}
              />
            </div>
          </div>

          {/* Duplicate warning */}
          {duplicate && (
            <div className="flex items-start gap-2 p-3 rounded-xl bg-warning/10 border border-warning/20">
              <AlertTriangle size={14} className="text-warning shrink-0 mt-0.5" />
              <div className="text-xs">
                <p className="font-medium text-foreground">Possible duplicate found</p>
                <p className="text-muted-foreground mt-0.5">
                  <strong>{duplicate.name}</strong> ({duplicate.phone}) — Status: {duplicate.status.replace(/_/g, ' ')}
                </p>
                <p className="text-[10px] text-muted-foreground mt-1">You can still create this lead if needed.</p>
              </div>
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Email</Label>
              <Input type="email" placeholder="email@example.com" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Source</Label>
              <Select value={form.source} onValueChange={v => setForm(f => ({ ...f, source: v }))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(SOURCE_LABELS).map(([k, v]) => (
                    <SelectItem key={k} value={k}>{v}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Budget</Label>
              <Input placeholder="₹8,000-12,000" value={form.budget} onChange={e => setForm(f => ({ ...f, budget: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Preferred Location</Label>
              <Input placeholder="Koramangala" value={form.preferred_location} onChange={e => setForm(f => ({ ...f, preferred_location: e.target.value }))} />
            </div>
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs">Assign Agent</Label>
            <Select value={form.assigned_agent_id} onValueChange={v => setForm(f => ({ ...f, assigned_agent_id: v }))}>
              <SelectTrigger><SelectValue placeholder="Auto-assign (round robin)" /></SelectTrigger>
              <SelectContent>
                {agents?.map(a => (
                  <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs">Notes</Label>
            <Textarea placeholder="Any additional notes..." value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} rows={2} />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" size="sm" onClick={() => setOpen(false)}>Cancel</Button>
            <Button type="submit" size="sm" disabled={createLead.isPending}>
              {createLead.isPending ? 'Creating...' : 'Create Lead'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default AddLeadDialog;
