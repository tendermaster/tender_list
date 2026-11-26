-- The contract between this app and products.sigmatenders.com (products-web):
-- it reads only these views, with the read-only role products_web_ro, never
-- the tables. Applied by Marketplace::Views.apply! (migrations, and the test
-- setup, since schema.rb doesn't keep views). Safe to run again.
--
-- Changes are additive: add columns at the end. To remove or retype one,
-- deploy products-web without it first. Every change must update
-- db/marketplace/contract.json (test/models/marketplace_contract_test.rb).
-- Slugs are made in Ruby (app/services/marketplace.rb) and stored; views only
-- pass them through.

CREATE SCHEMA IF NOT EXISTS marketplace;

CREATE OR REPLACE VIEW marketplace.categories AS
SELECT p.id,
       p.slug,
       p.name,
       p.summary,
       p.body,
       p.is_numbers,
       p.tender_query,
       p.price_table ->> 'unit' AS price_unit,
       p.price_table ->> 'source' AS price_source,
       p.price_updated_on,
       p.spec_table ->> 'standard' AS spec_standard,
       p.position,
       p.marketplace_changed_at AS changed_at
FROM public.products p
WHERE p.marketplace AND p.published;

CREATE OR REPLACE VIEW marketplace.price_rows AS
SELECT p.id AS category_id,
       e.ordinality::integer AS position,
       r.size_mm,
       r.size_slug,
       r.inch,
       r.grade,
       r.grade_slug,
       r.brand,
       r.min,
       r.max
FROM public.products p
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(p.price_table -> 'rows', '[]'::jsonb))
  WITH ORDINALITY AS e(row_data, ordinality)
CROSS JOIN LATERAL jsonb_to_record(e.row_data)
  AS r(size_mm numeric, size_slug text, inch text, grade text, grade_slug text, brand text, min numeric, max numeric)
WHERE p.marketplace AND p.published;

CREATE OR REPLACE VIEW marketplace.spec_rows AS
SELECT p.id AS category_id,
       e.ordinality::integer AS position,
       r.size_mm,
       r.size_slug,
       r.inch,
       r.grade,
       r.grade_slug,
       r.od_mm,
       r.wall_mm,
       r.kg_per_m
FROM public.products p
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(p.spec_table -> 'rows', '[]'::jsonb))
  WITH ORDINALITY AS e(row_data, ordinality)
CROSS JOIN LATERAL jsonb_to_record(e.row_data)
  AS r(size_mm numeric, size_slug text, inch text, grade text, grade_slug text,
       od_mm numeric, wall_mm numeric, kg_per_m numeric)
WHERE p.marketplace AND p.published;

-- Hidden suppliers never appear; a phone only once the listing is claimed
CREATE OR REPLACE VIEW marketplace.suppliers AS
SELECT s.id,
       s.slug,
       s.name,
       s.address,
       s.pincode,
       s.district,
       s.state,
       s.state_slug,
       s.gstin,
       s.gem_seller_id,
       s.website,
       CASE WHEN s.status = 1 THEN s.phone END AS phone,
       (s.status = 1) AS claimed,
       s.updated_at
FROM public.suppliers s
WHERE s.status <> 2;

-- Operative licences of visible suppliers
CREATE OR REPLACE VIEW marketplace.licences AS
SELECT l.id,
       l.supplier_id,
       l.cml_no,
       l.standard,
       l.is_number,
       l.brands,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.slugs -> 'brands', '[]'::jsonb))) AS brand_slugs,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.slugs -> 'grades', '[]'::jsonb))) AS grade_slugs,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.grades -> 'sizes_mm', '[]'::jsonb))::numeric) AS sizes_mm,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.grades -> 'pn', '[]'::jsonb))::numeric) AS pn,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.grades -> 'sdr', '[]'::jsonb))::numeric) AS sdr,
       ARRAY(SELECT jsonb_array_elements_text(COALESCE(l.grades -> 'classes', '[]'::jsonb))) AS classes,
       l.variety,
       l.granted_on,
       l.valid_until,
       l.data_changed_at AS changed_at
FROM public.bis_licences l
JOIN public.suppliers s ON s.id = l.supplier_id AND s.status <> 2
WHERE l.status = 'Operative';

CREATE OR REPLACE VIEW marketplace.pages AS
SELECT mp.path,
       mp.template,
       mp.key,
       mp.product_id AS category_id,
       p.slug AS category_slug,
       mp.supplier_id,
       mp.indexable,
       mp.lastmod
FROM public.marketplace_pages mp
LEFT JOIN public.products p ON p.id = mp.product_id;

-- The read-only role, when it exists (bin/rails marketplace:db_role creates it)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'products_web_ro') THEN
    GRANT USAGE ON SCHEMA marketplace TO products_web_ro;
    GRANT SELECT ON ALL TABLES IN SCHEMA marketplace TO products_web_ro;
  END IF;
END
$$;
