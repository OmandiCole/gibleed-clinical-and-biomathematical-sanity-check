# GiBleed, read as a patient population

**Recovering an undocumented Synthea disease module from its output — using only SQL and clinical reasoning.**

Andrew O. Cole, MD, MSc · PhD candidate, Biomathematics · 2017 · acole9@uw.edu . acole@strathmore.edu · [ORCID](https://orcid.org/0000-0003-4159-3853)

> The mathematics tells you what shape a disease should leave in data. The medicine tells you whether the shape is aligned or not.

---

## At a glance

| | |
|---|---|
| **Dataset** | Eunomia **GiBleed** — 2,694 patients, OMOP CDM v5.3.1. The default sandbox where most people first meet OMOP/OHDSI. |
| **Method** | 7 SQL queries · ~90 seconds · no machine learning, no source access, no documentation read. |
| **Finding** | Recovered an **undocumented, 8-condition "GI-bleed module"** from output alone — then confirmed the reconstruction against Synthea's own metadata. It held. |
| **The point** | Every artifact below is well-formed, in-range, type-correct, and passes the Kahn conformance/completeness/plausibility framework and the OHDSI Data Quality Dashboard. They are **invisible to structure-only tooling** and visible only to a combined clinical + biomathematical reading. |

---

## TL;DR

GiBleed is flawless by every automated check. It is also, read as a clinician *and* a modeller, unmistakably synthetic in ways no range check can see:

- **Eight conditions occur exactly once per person and never again.** Seven are the textbook differential diagnosis of GI bleeding — three upper GI, three lower GI, plus the outcome. The eighth is osteoarthritis, at **100% prevalence**.
- **All eight sit in a ~15-year midlife window and stop by age 47** — in a database that records other conditions out to age 109. Viral sinusitis, recorded from age 0 to 109, is the positive control: the recorder works across the whole lifespan, so the silence after 47 is a *true absence*, not censoring.
- **Nobody dies** — yet 98 people are over 100 and the population reaches 110.
- **There is no confounding by indication**.

Two independent rulers — records-per-person and the age envelope — were measured separately and select the **same eight conditions**, with nothing in between. Two unrelated measurements drawing the identical line likely describe a code path. From that alone I reconstructed the generator's design intent, then read the metadata to check: Synthea, OMOP CDM v5.3.1, ETL-Synthea, 2019.

**None of this is a bug.** GiBleed was built to teach one method — NSAID → GI-bleed — and every artifact here is scaffolding holding that lesson up. For its intended purpose it is excellent and it helped me understand the OMOP-CDM ecosystem: small, fast, portable, conformant, clean. The claim is narrower and, I think, useful: *fitness for purpose is a question no conformance check asks, and the OMOP CDM has no field for it.*

> A flight simulator is perfect for practising landings and not great for studying what turbulence does to a body. Neither statement criticises the simulator. The only problem is that nobody wrote "not for turbulence research" on the box. This work shows the utility of a multidomain sanity check that includes the turbulence angle (Biomathematics and Medicine) for full comformity.

---

## The module, in one table

Eight conditions, each occurring **exactly once per person**. Read as a clinician, seven of them name themselves.

| Tract | Condition | People | Prevalence | Age window | Role |
|---|---|---:|---:|---|---|
| Upper GI | Peptic ulcer | 802 | 29.8% | 24–34 | Cause |
| Upper GI | Esophagitis | 409 | 15.2% | 31–44 | Cause |
| Upper GI | Angiodysplasia of stomach | 388 | 14.4% | 30–44 | Cause |
| Lower GI | Diverticular disease | 405 | 15.0% | 32–47 | Cause |
| Lower GI | Polyp of colon | 380 | 14.1% | 31–46 | Cause |
| Lower GI | Ulcerative colitis | 413 | 15.3% | 31–45 | Cause |
| **Outcome** | **Gastrointestinal hemorrhage** | 479 | 17.8% | 32–47 | Outcome |
| **Indication** | **Osteoarthritis** | 2,694 | **100%** | 31–47 | Indication |

Angiodysplasia is a disease of the elderly (typically >60, in the context of aortic stenosis); here it appears in 388 people aged 30–44 and never again. Colon polyps are finished by 46 in the dataset, in a world where screening now begins at 45 precisely because that is when they start appearing. The clinical impossibility isn't any one age — it's the combination of 100% prevalence, hard truncation at 47, and the absence of recurrence in a population that lives to 110.

---

## Why this matters beyond GiBleed

OHDSI's method is **federated**: an analytic package is written once and executed at many sites against local CDM instances. Patient-level data never moves; only aggregate results return. That architecture has a specific blind spot.

If a site's ETL introduces a *topology* artifact — collapsing recurrent encounters into a single record, gating an age range, dropping a mortality feed — the site's data may still pass conformance, the results still come back well-formed, and genuine cross-site heterogeneity gets attributed to **population differences** when it may really be **ETL differences**. That is a confounder introduced by infrastructure, invisible to every tool currently pointed at the problem and including this type of multidisciplinary sanity checks at the source concept may eliminate or reduce this potential confounder.

**The implication: data quality has to be established at the source, not rescued during analysis.** A sanity check that reads structure *and* pathophysiology *and* topology, run at each node, catches these before they enter the federation. Run afterwards, all you can do is discover that sites disagree and guess why.

That check requires three disciplines in one room:

| Domain | The question it asks | GiBleed |
|---|---|---|
| Computer science | Is the value well-formed? | ✅ Passes |
| Medicine | Is this what the disease naturally does? | ❌ (this audit) |
| Biomathematics | Is this a topological shape a disease can leave? | ❌ (this audit) |

A CS-trained data-quality engineer passes this dataset — *correctly*, by every standard in the toolkit. A clinician without modelling sees the ages are wrong but not that the *shape* is wrong. A modeller without medicine sees `recs_per_person = 1.00` and has no prior that says it should be 6. The findings live only in the overlap.

---

## The single most consequential finding

355 of 479 GI-bleed patients are on celecoxib, and the drug precedes the bleed **355 times out of 355** — no reversals, no same-day ties. In the real world, celecoxib is channelled to exactly the patients already at elevated GI risk; that channelling is the definition of **confounding by indication**, and it is the entire reason NSAID → GI-bleed is a hard causal question rather than a division problem.

GiBleed does not contains it. Every confounding-control method — propensity scores, IPTW, new-user designs, negative controls, self-controlled designs — runs cleanly, converges, and returns plausible numbers. They have to since each exists to subtract a bias, and here each subtracts zero and returns the number it was handed.

---

## Reproduce it in ~90 seconds

```r
install.packages(c("Eunomia", "DBI", "RSQLite"))
library(Eunomia); library(DBI)
con <- dbConnect(RSQLite::SQLite(), getEunomiaConnectionDetails()$server())

# The query that found the module:
dbGetQuery(con, "
  SELECT c.concept_name,
         COUNT(*)                                          AS n_records,
         COUNT(DISTINCT co.person_id)                      AS n_people,
         ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT co.person_id), 2) AS recs_per_person
  FROM condition_occurrence co
  JOIN concept c ON co.condition_concept_id = c.concept_id
  JOIN person  p ON co.person_id = p.person_id
  GROUP BY c.concept_name
  HAVING COUNT(DISTINCT co.person_id) >= 300
  ORDER BY recs_per_person DESC;
")
```

All seven queries: [`sql/audit-queries.sql`](sql/audit-queries.sql) · Full notebook: [`notebooks/gibleed-audit.ipynb`](notebooks/gibleed-audit.ipynb)

**Portability note.** Eunomia's SQLite stores dates as Unix epoch integers rather than the CDM-specified `DATE` type — a small conformance deviation, found by checking a column before trusting arithmetic on it. Use `strftime('%Y', col, 'unixepoch')` on SQLite, `EXTRACT(YEAR FROM col)` on PostgreSQL, `YEAR(col)` on SQL Server.

---

## Repository structure

```
.
├── README.md                          ← you are here
├── DATA.md                            ← how to obtain GiBleed (data not vendored)
├── setup.R                            ← environment bootstrap (renv.lock is authoritative)
├── LICENSE                            ← MIT
├── CITATION.cff
├── paper/
│   └── gibleed-audit-paper.pdf        ← the full write-up
├── appendix/
│   └── gibleed-audit-extended-notes.pdf   ← first-principles / ELI5 deep dives (secondary)
├── sql/
│   └── audit-queries.sql              ← the queries, runnable and verified
├── notebooks/
│   └── gibleed-audit.ipynb            ← reproducible analysis (run top-to-bottom in ~90s)
├── scripts/
│   └── make-figures.R                 ← results/*.csv → figures/*.png
├── results/                           ← verified query output (aggregate, not patients)
│   ├── the-eight.csv
│   ├── recs-per-person.csv
│   ├── celecoxib-2x2.csv
│   ├── reality-gap.csv
│   └── summary-stats.csv
└── figures/                           ← rendered from results/
    ├── 01-topology.png
    ├── 02-age-envelope.png
    ├── 03-module-boundary.png
    └── 04-reality-gap.png
```

---

## Scope and limitations

This describes **this dataset**, not Synthea in general — prior work covers Synthea at scale. GI conditions in the 30s and 40s are individually plausible; the improbability is their combination with 100% prevalence, truncation at 47, and zero recurrence. Osteoarthritis was read via `condition_concept_id = 192671` without descendant expansion. I have **not** read Synthea's source to confirm the eight conditions correspond to one discrete generator component — that is the falsifiable part, and corrections are welcome via issues.

---

## Citation

If this is useful, please cite via [`CITATION.cff`](CITATION.cff), or:

> Cole, Andrew O. *GiBleed, read as a patient population: recovering a synthetic-data generator's disease module from its output.* Self-directed, [year]. https://github.com/[user]/gibleed-clinical-audit

---

## About

I am a physician datascientist with mathematical modeling experience in disease dynamics along the path from data acquisition and extraction, prepation (e.g. EDA and processing for QC), analysis, reporting and visualization, to revelation of inherent insights. I thrive in a multidisciplinary setting where downstream inference and action on findings is dependent on clean data that is representative of the population from which it emanated. I am looking for a team role needing data sanity checks (after extration from the source but before tranformation and analysis) from the intersection of three domains. Potential fits include: real-world evidence, pharmacoepidemiology, observational health data science, or data quality in a federated network such as the OMOP-CDM ETL pipeline.

**Contact:** acole9@uw.edu · [ORCID](https://orcid.org/0000-0003-4159-3853)

## License

Released under the [MIT License](LICENSE). Findings and errors are my own; corrections welcome via issues.



```R

```
