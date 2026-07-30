#!/usr/bin/env Rscript
# ============================================================================
# make-figures.R  —  regenerate every figure from results/*.csv
#
# The figures are a deterministic function of the query output, not the live
# database: this script reads the committed CSVs and writes figures/*.png, so
# anyone can reproduce the plots without loading GiBleed.
#
# Pipeline:  sql/audit-queries.sql  ->  results/*.csv  ->  (this)  ->  figures/*.png
# Run from the repository root:   Rscript scripts/make-figures.R
# ============================================================================

suppressPackageStartupMessages(library(ggplot2))

dir.create("figures", showWarnings = FALSE)

MOD <- "#c0392b"   # the module
OTH <- "#9aa3ab"   # other conditions
REF <- "#4a6fa5"   # real-world reference

base_theme <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 13),
        legend.position = "bottom", legend.title = element_blank())

save_fig <- function(p, file, w = 8.4, h = 8.6)
  ggsave(file.path("figures", file), p, width = w, height = h, dpi = 200, bg = "white")

# ---- load the single source of truth --------------------------------------
rp <- read.csv("results/recs-per-person.csv", check.names = FALSE, stringsAsFactors = FALSE)
rp$is_module <- as.logical(rp$is_module)
mod_lab <- c("FALSE" = "other conditions", "TRUE" = "the module")
mod_col <- c("FALSE" = OTH, "TRUE" = MOD)

# ---- FIG 1 · topology (records per person) --------------------------------
d1 <- rp
d1$concept_name <- factor(d1$concept_name, levels = d1$concept_name[order(d1$recs_per_person)])
p1 <- ggplot(d1, aes(recs_per_person, concept_name, color = is_module)) +
  geom_segment(aes(x = 1, xend = recs_per_person, yend = concept_name),
               linewidth = 0.9, alpha = 0.55) +
  geom_point(aes(size = is_module)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey60") +
  scale_color_manual(values = mod_col, labels = mod_lab) +
  scale_size_manual(values = c("FALSE" = 1.8, "TRUE" = 2.7), guide = "none") +
  labs(title = "Disease topology: eight conditions welded to the 1.00 floor",
       x = "records per person  (state-graph signature)", y = NULL,
       caption = "Viral sinusitis at 6.43 is the positive control: the apparatus can represent recurrence.") +
  base_theme
# callout placed in open whitespace to the right of the pinned points, arrow to the cluster
p1 <- p1 +
  annotate("segment", x = 2.25, xend = 1.06, y = 4.6, yend = 3.0,
           color = MOD, linewidth = 0.5, arrow = arrow(length = unit(0.14, "cm"))) +
  annotate("text", x = 2.35, y = 4.6, hjust = 0, color = MOD, fontface = "bold", size = 3,
           label = "the eight:\nexactly 1.00,\nnever re-entered")
save_fig(p1, "01-topology.png")

# ---- FIG 2 · age envelope --------------------------------------------------
d2 <- rp[order(rp$max_age, rp$min_age), ]
d2$concept_name <- factor(d2$concept_name, levels = d2$concept_name)
p2 <- ggplot(d2, aes(y = concept_name, color = is_module)) +
  geom_segment(aes(x = min_age, xend = max_age, yend = concept_name),
               linewidth = 1.5, lineend = "round") +
  geom_vline(xintercept = 47, linetype = "dashed", color = MOD) +
  annotate("text", x = 49, y = 1.5, label = "truncates at 47",
           color = MOD, hjust = 0, size = 3) +
  scale_color_manual(values = mod_col, labels = mod_lab) +
  labs(title = "Age envelope: the module lives in a ~15-year band and stops at 47",
       x = "age at diagnosis (min \u2192 max)  \u2014  hazard-window signature", y = NULL,
       caption = "Viral sinusitis spans 0\u2013109: the recorder works across the whole lifespan, so silence after 47 is a true absence.") +
  base_theme
save_fig(p2, "02-age-envelope.png")

# ---- FIG 3 · module boundary (two rulers) ----------------------------------
mods <- rp[rp$is_module, ]
box  <- data.frame(xmin = min(mods$recs_per_person) - 0.04, xmax = max(mods$recs_per_person) + 0.08,
                   ymin = min(mods$age_span) - 2,          ymax = max(mods$age_span) + 4)
ecoli <- rp[grepl("^Escherichia", rp$concept_name), ]
p3 <- ggplot(rp, aes(recs_per_person, age_span, color = is_module)) +
  geom_rect(data = box, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
            fill = NA, color = MOD, linetype = "dashed") +
  geom_point(aes(size = is_module)) +
  scale_color_manual(values = mod_col, labels = mod_lab) +
  scale_size_manual(values = c("FALSE" = 2.4, "TRUE" = 3.4), guide = "none") +
  labs(title = "Two independent rulers select the same eight \u2014 a code path, not a disease",
       x = "records per person  (recurrence ruler)",
       y = "age span = max \u2212 min age  (hazard-window ruler)") +
  base_theme
if (nrow(ecoli))
  p3 <- p3 + annotate("text", x = ecoli$recs_per_person + 0.5, y = ecoli$age_span + 8,
                      label = "E. coli UTI \u2014 only intermediate case", size = 3, hjust = 0)
save_fig(p3, "03-module-boundary.png", w = 8.6, h = 6.6)

# ---- FIG 4 · reality gap ---------------------------------------------------
gap  <- read.csv("results/reality-gap.csv", stringsAsFactors = FALSE)
long <- rbind(
  data.frame(metric = gap$metric, source = "GiBleed",             pct = gap$gibleed_pct),
  data.frame(metric = gap$metric, source = "real-world reference", pct = gap$realworld_pct))
long$metric <- factor(long$metric, levels = gap$metric)
p4 <- ggplot(long, aes(metric, pct, fill = source)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.72) +
  geom_text(aes(label = paste0(pct, "%")), position = position_dodge(width = 0.8),
            vjust = -0.4, size = 3) +
  scale_y_log10(limits = c(0.02, 200)) +
  scale_fill_manual(values = c("GiBleed" = MOD, "real-world reference" = REF)) +
  labs(title = "The reality gap: GiBleed vs. order-of-magnitude clinical reference values",
       x = NULL, y = "prevalence / coverage (%, log scale)",
       caption = "Deaths omitted: zero has no logarithm.") +
  base_theme
save_fig(p4, "04-reality-gap.png", w = 9, h = 5.6)

cat("figures written:", paste(list.files("figures", pattern = "\\.png$"), collapse = ", "), "\n")
