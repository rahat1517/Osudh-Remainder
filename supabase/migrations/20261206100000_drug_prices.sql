-- Prices in the drug catalogue, for showing cheaper brands of the same medicine

alter table public.drugs
    add column unit_price_bdt numeric(10, 2) check (unit_price_bdt > 0);

comment on column public.drugs.unit_price_bdt is
    'Maximum retail price of one unit (tablet, capsule, sachet; a bottle for liquids), taka; '
    'unverified (development estimate) while verified = false';
