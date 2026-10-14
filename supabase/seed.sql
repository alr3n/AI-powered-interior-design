-- Reference data. Safe to re-run.
insert into public.cost_catalog (region, currency, rates) values (
  'PH', 'PHP',
  '{
    "paint_liter":            {"low": 400,  "medium": 650,   "premium": 950,   "luxury": 1500},
    "tile_m2":                {"low": 450,  "medium": 800,   "premium": 1500,  "luxury": 3500},
    "flooring_m2":            {"low": 600,  "medium": 1200,  "premium": 2500,  "luxury": 5000},
    "lighting_fixture":       {"low": 800,  "medium": 2500,  "premium": 6000,  "luxury": 15000},
    "cabinet_lm":             {"low": 6000, "medium": 12000, "premium": 22000, "luxury": 45000},
    "decor_lump":             {"low": 3000, "medium": 8000,  "premium": 20000, "luxury": 60000},
    "labor_paint_m2":         {"low": 60,   "medium": 90,    "premium": 120,   "luxury": 180},
    "labor_tile_m2":          {"low": 350,  "medium": 450,   "premium": 600,   "luxury": 800},
    "labor_electrical_point": {"low": 800,  "medium": 1200,  "premium": 1800,  "luxury": 2500}
  }'::jsonb
) on conflict (region) do update set currency = excluded.currency, rates = excluded.rates;

insert into public.design_tips (text, category)
select v.text, v.category
from (values
  ('Anchor a seating area with a rug at least 20 cm wider than the sofa.', 'layout'),
  ('Layer three light sources per room: ambient, task, and accent.', 'lighting'),
  ('Keep walkways at least 75 cm clear for comfortable circulation.', 'layout'),
  ('Warm white (2700K) suits bedrooms; neutral (4000K) suits kitchens.', 'lighting')
) as v(text, category)
where not exists (select 1 from public.design_tips);
