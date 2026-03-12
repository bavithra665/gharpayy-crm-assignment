-- Add unique constraint to phone numbers in the leads table
ALTER TABLE public.leads ADD CONSTRAINT leads_phone_key UNIQUE (phone);

-- Add index for fast duplicate checks during high volume
CREATE INDEX IF NOT EXISTS idx_leads_phone ON public.leads(phone);
