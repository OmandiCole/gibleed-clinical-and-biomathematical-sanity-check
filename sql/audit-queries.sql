-- ============================================================================
-- GiBleed clinical audit — the queries
-- Andrew O. Cole, MD, MSc, PhD (Biomathematics) · self-directed, 2026
--
-- Dataset : Eunomia GiBleed, OMOP CDM v5.3.1 (2,694 patients)
-- Dialect : SQLite (as shipped by the Eunomia R package)
-- Verified: every result below was confirmed against the GiBleed 5.3 database.
--
-- PORTABILITY NOTE. Eunomia's SQLite stores dates as Unix-epoch INTEGERS, not the
-- CDM-specified DATE type. Age therefore uses:  strftime('%Y', col, 'unixepoch')
--   PostgreSQL : EXTRACT(YEAR FROM col)
--   SQL Server : YEAR(col)
-- ============================================================================


-- Q0 · Orientation --------------------------------------------------------------
-- 2,694 people; 65,332 condition records.
SELECT COUNT(*) AS n_persons FROM person;

SELECT COUNT(*) AS n_conditions, COUNT(DISTINCT person_id) AS n_people
FROM condition_occurrence;

-- Confirm the date encoding before doing arithmetic on it (expect integers).
SELECT condition_start_date FROM condition_occurrence LIMIT 5;


-- Q1 · The one-shot module — the single most important query --------------------
-- Records-per-person is a measurement of a disease's state graph. Life-like
-- conditions recur (viral sinusitis 6.43); eight sit pinned at exactly 1.00.
SELECT c.concept_name,
       COUNT(*)                                                   AS n_records,
       COUNT(DISTINCT co.person_id)                               AS n_people,
       ROUND(COUNT(*)*1.0 / COUNT(DISTINCT co.person_id), 2)      AS recs_per_person,
       MIN(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS min_age,
       MAX(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS max_age
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
JOIN person  p ON co.person_id = p.person_id
GROUP BY c.concept_name
HAVING COUNT(DISTINCT co.person_id) >= 300
ORDER BY recs_per_person DESC;


-- Q2 · Isolate the eight, labeled by clinical role ------------------------------
-- Seven are the differential diagnosis of GI bleeding; the eighth is the indication.
-- Reproduces the audit's centerpiece table directly from the data.
SELECT
  CASE c.concept_name
    WHEN 'Peptic ulcer'                THEN 'Upper GI (cause)'
    WHEN 'Esophagitis'                 THEN 'Upper GI (cause)'
    WHEN 'Angiodysplasia of stomach'   THEN 'Upper GI (cause)'
    WHEN 'Diverticular disease'        THEN 'Lower GI (cause)'
    WHEN 'Polyp of colon'              THEN 'Lower GI (cause)'
    WHEN 'Ulcerative colitis'          THEN 'Lower GI (cause)'
    WHEN 'Gastrointestinal hemorrhage' THEN 'OUTCOME'
    WHEN 'Osteoarthritis'              THEN 'INDICATION'
  END                                                        AS module_role,
  c.concept_name,
  COUNT(DISTINCT co.person_id)                               AS n_people,
  ROUND(COUNT(DISTINCT co.person_id)*100.0 / 2694, 1)        AS prevalence_pct,
  ROUND(COUNT(*)*1.0 / COUNT(DISTINCT co.person_id), 2)      AS recs_per_person,
  MIN(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS min_age,
  MAX(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS max_age
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
JOIN person  p ON co.person_id = p.person_id
GROUP BY c.concept_name
HAVING COUNT(DISTINCT co.person_id) >= 300
   AND ROUND(COUNT(*)*1.0 / COUNT(DISTINCT co.person_id), 2) = 1.00
ORDER BY (c.concept_name = 'Osteoarthritis') DESC,
         (c.concept_name = 'Gastrointestinal hemorrhage') DESC,
         n_people DESC;


-- Q3 · Positive control — the recorder works across the whole lifespan ----------
-- Viral sinusitis spans ages 0-109, so the module's silence after 47 is a true
-- absence, not censoring.
SELECT MIN(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS min_age,
       MAX(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS max_age
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
JOIN person  p ON co.person_id = p.person_id
WHERE c.concept_name = 'Viral sinusitis';


-- Q4 · Osteoarthritis is the eligibility scaffold -------------------------------
-- 2,694 people (100%), one record each, ages 31-47.
SELECT COUNT(*)                                                AS n_records,
       COUNT(DISTINCT co.person_id)                            AS n_people,
       ROUND(COUNT(DISTINCT co.person_id)*100.0 / 2694, 1)     AS prevalence_pct,
       MIN(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS min_age,
       MAX(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth) AS max_age
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
JOIN person  p ON co.person_id = p.person_id
WHERE c.concept_name = 'Osteoarthritis';

-- Forced overlap: 2,025 = ALL otitis-media patients (identity, not comorbidity).
SELECT COUNT(DISTINCT a.person_id) AS people_with_both
FROM condition_occurrence a
JOIN concept ca ON a.condition_concept_id = ca.concept_id
JOIN condition_occurrence b ON a.person_id = b.person_id
JOIN concept cb ON b.condition_concept_id = cb.concept_id
WHERE ca.concept_name = 'Otitis media'
  AND cb.concept_name = 'Osteoarthritis';


-- Q5 · No mortality compartment -------------------------------------------------
-- death table empty; oldest RECORDED age is 110 (n_over_100 uses a 2020 birth-year
-- reference and is an approximate head-count).
SELECT
  (SELECT COUNT(*) FROM death) AS n_deaths,
  (SELECT COUNT(*) FROM person WHERE (2020 - year_of_birth) > 100) AS n_over_100_by_birthyear,
  (SELECT MAX(CAST(strftime('%Y', co.condition_start_date, 'unixepoch') AS INTEGER) - p.year_of_birth)
     FROM condition_occurrence co JOIN person p ON co.person_id = p.person_id) AS max_recorded_age;


-- Q6 · Prescribing does not resemble prescribing --------------------------------
-- celecoxib: 1,844 users = 68% of the population, one exposure record each.
SELECT COUNT(*)                                            AS n_records,
       COUNT(DISTINCT de.person_id)                        AS n_users,
       ROUND(COUNT(DISTINCT de.person_id)*100.0 / 2694, 1) AS pct_of_population
FROM drug_exposure de
JOIN concept c ON de.drug_concept_id = c.concept_id
WHERE c.concept_name = 'celecoxib';


-- Q7 · The outcome, and the drawn arrow -----------------------------------------
-- GI hemorrhage (192671): 479 people, one record each.
SELECT COUNT(*) AS n_records, COUNT(DISTINCT person_id) AS n_people
FROM condition_occurrence
WHERE condition_concept_id = 192671;

-- 355 of the 479 bleeders are on celecoxib; drug precedes bleed 355/355.
-- The >= folds any same-day pair into bleed_first, so 0 = zero reversals AND zero ties.
SELECT SUM(CASE WHEN de.drug_exposure_start_date <  co.condition_start_date THEN 1 ELSE 0 END) AS drug_first,
       SUM(CASE WHEN de.drug_exposure_start_date >= co.condition_start_date THEN 1 ELSE 0 END) AS bleed_first
FROM condition_occurrence co
JOIN drug_exposure de ON co.person_id = de.person_id
JOIN concept c ON de.drug_concept_id = c.concept_id
WHERE co.condition_concept_id = 192671 AND c.concept_name = 'celecoxib';


-- Q8 · The 2x2 (celecoxib x GI-bleed) -------------------------------------------
-- Cells 355 / 1489 / 124 / 726  ->  RR = 1.32, OR = 1.40.
-- Correct arithmetic that measures the generator's settings, not celecoxib.
WITH bleeders AS (SELECT DISTINCT person_id FROM condition_occurrence WHERE condition_concept_id = 192671),
     cele     AS (SELECT DISTINCT de.person_id FROM drug_exposure de
                  JOIN concept c ON de.drug_concept_id = c.concept_id
                  WHERE c.concept_name = 'celecoxib')
SELECT
  SUM(CASE WHEN e.person_id IS NOT NULL AND b.person_id IS NOT NULL THEN 1 ELSE 0 END) AS exposed_bled,
  SUM(CASE WHEN e.person_id IS NOT NULL AND b.person_id IS NULL     THEN 1 ELSE 0 END) AS exposed_no_bleed,
  SUM(CASE WHEN e.person_id IS NULL     AND b.person_id IS NOT NULL THEN 1 ELSE 0 END) AS unexposed_bled,
  SUM(CASE WHEN e.person_id IS NULL     AND b.person_id IS NULL     THEN 1 ELSE 0 END) AS unexposed_no_bleed
FROM person p
LEFT JOIN cele     e ON p.person_id = e.person_id
LEFT JOIN bleeders b ON p.person_id = b.person_id;


-- Q9 · Provenance confirms the reconstruction -----------------------------------
-- Synthea, CDM v5.3.1, released 2019-05-25, vocabulary v5.0 (18-JAN-19).
SELECT cdm_source_abbreviation, cdm_holder, cdm_version, vocabulary_version,
       source_release_date, cdm_etl_reference
FROM cdm_source;
