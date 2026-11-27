-- What a drug's price is for when it is not one piece (e.g. "60 ml bottle"), so cheaper brands
-- are only compared pack for pack

alter table public.drugs add column pack text;

comment on column public.drugs.pack is
    'What unit_price_bdt is for when it is not one piece, e.g. "60 ml bottle"; null = per piece';
