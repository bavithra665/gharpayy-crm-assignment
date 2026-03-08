import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, MapPin, SlidersHorizontal, Star, Bed, Shield, ChevronDown, X } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { usePublicProperties, useAvailableCities, useAvailableAreas, type PropertyFilters } from '@/hooks/usePublicData';
import { motion, AnimatePresence } from 'framer-motion';

const SHARING_TYPES = ['Private', '2 Sharing', '3 Sharing', '4 Sharing'];
const GENDER_OPTIONS = [
  { value: 'any', label: 'Any Gender' },
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
];

export default function Explore() {
  const navigate = useNavigate();
  const [filters, setFilters] = useState<PropertyFilters>({ city: 'Bangalore' });
  const [searchQuery, setSearchQuery] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [selectedSharing, setSelectedSharing] = useState<string[]>([]);

  const { data: cities } = useAvailableCities();
  const { data: areas } = useAvailableAreas(filters.city);
  const { data: properties, isLoading } = usePublicProperties(filters);

  const getAvailableBeds = (property: any) => {
    if (!property.rooms) return 0;
    return property.rooms.reduce((sum: number, room: any) => {
      if (!room.beds) return sum;
      return sum + room.beds.filter((b: any) => b.status === 'vacant').length;
    }, 0);
  };

  const getRentRange = (property: any) => {
    if (!property.rooms?.length) return property.price_range || '—';
    const rents = property.rooms
      .map((r: any) => r.rent_per_bed || r.expected_rent)
      .filter(Boolean);
    if (!rents.length) return '—';
    const min = Math.min(...rents);
    const max = Math.max(...rents);
    return min === max ? `₹${min.toLocaleString()}` : `₹${min.toLocaleString()} – ₹${max.toLocaleString()}`;
  };

  const getAvailabilityColor = (beds: number) => {
    if (beds === 0) return 'bg-destructive/10 text-destructive';
    if (beds <= 3) return 'bg-warning/10 text-warning';
    return 'bg-success/10 text-success';
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-background/95 backdrop-blur-sm border-b border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <button onClick={() => navigate('/')} className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-accent flex items-center justify-center">
                <span className="text-accent-foreground font-bold text-sm">G</span>
              </div>
              <span className="font-semibold text-lg tracking-tight text-foreground">Gharpayy</span>
            </button>

            <div className="hidden md:flex items-center gap-6 text-sm text-muted-foreground">
              <button className="hover:text-foreground transition-colors font-medium">Explore PGs</button>
              <button onClick={() => navigate('/owner-portal')} className="hover:text-foreground transition-colors">For Owners</button>
              <button className="hover:text-foreground transition-colors">About</button>
            </div>

            <Button variant="outline" size="sm" onClick={() => navigate('/')}>
              CRM Dashboard
            </Button>
          </div>
        </div>
      </header>

      {/* Hero Search */}
      <section className="bg-background border-b border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }}>
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-semibold tracking-tight text-foreground mb-3">
              Find your perfect PG
            </h1>
            <p className="text-muted-foreground text-lg mb-8 max-w-xl">
              300+ verified properties across Bangalore. Transparent pricing, instant booking.
            </p>
          </motion.div>

          {/* Search Bar */}
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
              <Input
                placeholder="Search by area, tech park, or property name..."
                className="pl-10 h-12 text-base"
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value);
                  setFilters(f => ({ ...f, area: e.target.value || undefined }));
                }}
              />
            </div>
            <Select value={filters.city || ''} onValueChange={(v) => setFilters(f => ({ ...f, city: v }))}>
              <SelectTrigger className="w-full sm:w-48 h-12">
                <MapPin size={16} className="mr-1 text-muted-foreground" />
                <SelectValue placeholder="City" />
              </SelectTrigger>
              <SelectContent>
                {(cities || ['Bangalore']).map(c => <SelectItem key={c} value={c}>{c}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button
              variant="outline"
              className="h-12 gap-2"
              onClick={() => setShowFilters(!showFilters)}
            >
              <SlidersHorizontal size={16} />
              Filters
              {showFilters && <X size={14} />}
            </Button>
          </div>

          {/* Filter Panel */}
          <AnimatePresence>
            {showFilters && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="overflow-hidden"
              >
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-6">
                  <Select value={filters.gender || 'any'} onValueChange={(v) => setFilters(f => ({ ...f, gender: v }))}>
                    <SelectTrigger><SelectValue placeholder="Gender" /></SelectTrigger>
                    <SelectContent>
                      {GENDER_OPTIONS.map(g => <SelectItem key={g.value} value={g.value}>{g.label}</SelectItem>)}
                    </SelectContent>
                  </Select>

                  <Select onValueChange={(v) => setFilters(f => ({ ...f, area: v }))}>
                    <SelectTrigger><SelectValue placeholder="Area" /></SelectTrigger>
                    <SelectContent>
                      {(areas || []).map(a => <SelectItem key={a} value={a}>{a}</SelectItem>)}
                    </SelectContent>
                  </Select>

                  <Input
                    type="number"
                    placeholder="Max budget (₹)"
                    className="h-10"
                    onChange={(e) => setFilters(f => ({ ...f, budgetMax: Number(e.target.value) || undefined }))}
                  />

                  <div className="flex gap-1.5 flex-wrap">
                    {SHARING_TYPES.map(type => (
                      <Badge
                        key={type}
                        variant={selectedSharing.includes(type) ? 'default' : 'outline'}
                        className="cursor-pointer text-2xs"
                        onClick={() => setSelectedSharing(prev =>
                          prev.includes(type) ? prev.filter(t => t !== type) : [...prev, type]
                        )}
                      >
                        {type}
                      </Badge>
                    ))}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </section>

      {/* Quick Area Tags */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex gap-2 overflow-x-auto">
        {['Marathahalli', 'Whitefield', 'Koramangala', 'BTM Layout', 'HSR Layout', 'Electronic City', 'Bellandur', 'Indiranagar'].map(area => (
          <Badge
            key={area}
            variant={filters.area === area ? 'default' : 'secondary'}
            className="cursor-pointer whitespace-nowrap shrink-0"
            onClick={() => setFilters(f => ({ ...f, area: f.area === area ? undefined : area }))}
          >
            <MapPin size={12} className="mr-1" /> {area}
          </Badge>
        ))}
      </section>

      {/* Results */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-20">
        <div className="flex items-center justify-between mb-6">
          <p className="text-sm text-muted-foreground">
            {isLoading ? 'Loading...' : `${properties?.length || 0} properties found`}
            {filters.city && ` in ${filters.city}`}
            {filters.area && ` · ${filters.area}`}
          </p>
        </div>

        {/* Property Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {properties?.map((property: any, i: number) => {
            const beds = getAvailableBeds(property);
            const rentRange = getRentRange(property);
            return (
              <motion.div
                key={property.id}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.05 }}
                className="group cursor-pointer"
                onClick={() => navigate(`/property/${property.id}`)}
              >
                <div className="rounded-xl border border-border bg-card overflow-hidden transition-all duration-200 hover:shadow-md hover:border-muted-foreground/20">
                  {/* Image */}
                  <div className="relative aspect-[4/3] bg-muted overflow-hidden">
                    {property.photos?.length > 0 ? (
                      <img src={property.photos[0]} alt={property.name} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <Bed size={40} className="text-muted-foreground/30" />
                      </div>
                    )}
                    {/* Availability badge */}
                    <div className={`absolute top-3 left-3 px-2.5 py-1 rounded-full text-2xs font-medium ${getAvailabilityColor(beds)}`}>
                      {beds === 0 ? 'Full' : `${beds} beds available`}
                    </div>
                    {property.is_verified && (
                      <div className="absolute top-3 right-3 px-2 py-1 rounded-full bg-background/90 backdrop-blur-sm text-2xs font-medium flex items-center gap-1">
                        <Shield size={11} className="text-success" /> Verified
                      </div>
                    )}
                  </div>

                  {/* Info */}
                  <div className="p-4">
                    <div className="flex items-start justify-between gap-2 mb-1">
                      <h3 className="font-semibold text-sm text-foreground line-clamp-1">{property.name}</h3>
                      {property.rating && (
                        <div className="flex items-center gap-0.5 shrink-0">
                          <Star size={12} className="fill-accent text-accent" />
                          <span className="text-2xs font-medium">{property.rating}</span>
                        </div>
                      )}
                    </div>
                    <p className="text-2xs text-muted-foreground mb-3">
                      {[property.area, property.city].filter(Boolean).join(', ')}
                    </p>

                    {/* Amenities preview */}
                    {property.amenities?.length > 0 && (
                      <div className="flex gap-1.5 mb-3 flex-wrap">
                        {property.amenities.slice(0, 4).map((a: string) => (
                          <span key={a} className="text-2xs px-2 py-0.5 rounded-md bg-secondary text-secondary-foreground">{a}</span>
                        ))}
                        {property.amenities.length > 4 && (
                          <span className="text-2xs text-muted-foreground">+{property.amenities.length - 4}</span>
                        )}
                      </div>
                    )}

                    <div className="flex items-baseline justify-between">
                      <span className="text-base font-semibold text-foreground">{rentRange}</span>
                      <span className="text-2xs text-muted-foreground">/month</span>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>

        {properties?.length === 0 && !isLoading && (
          <div className="text-center py-20">
            <Bed size={48} className="mx-auto text-muted-foreground/30 mb-4" />
            <h3 className="text-lg font-medium text-foreground mb-1">No properties found</h3>
            <p className="text-sm text-muted-foreground">Try adjusting your filters or search in a different area.</p>
          </div>
        )}
      </section>
    </div>
  );
}
