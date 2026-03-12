-- Add room_id and bed_id to visits table to support the auto-booking trigger
ALTER TABLE public.visits 
ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS bed_id UUID REFERENCES public.beds(id) ON DELETE SET NULL;
