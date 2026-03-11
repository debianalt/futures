# ──────────────────────────────────────────────────────────────────────
# 03_figure.R
# Fig. 1 — Competing sociotechnical futures and their policy
# architectures.
#
# Three-tier symmetric diagram: empirical evidence (top) flows into
# two interpretive frameworks (green-growth vs. climate-emergency),
# generating distinct policy architectures (bottom). A dashed feedback
# loop on the left represents the "expectations trap."
#
# Output:
#   figures/fig01_competing_futures.png  (300 DPI)
#   figures/fig01_competing_futures.pdf  (vector)
#
# Usage: Rscript R/03_figure.R   (from github/ root)
# ──────────────────────────────────────────────────────────────────────

library(ggplot2)
library(grid)

root <- here::here()
fig_dir <- file.path(root, "figures")

# ── Colour palette ───────────────────────────────────────────────────
# Greyscale-safe: teal (lum ~ 0.36) vs coral (lum ~ 0.53)
c_evidence_border <- "#6c757d"
c_evidence_fill   <- "#f0f0f0"
c_green_border    <- "#1a7a6f"
c_green_fill      <- "#e4f2f0"
c_coral_border    <- "#e76f51"
c_coral_fill      <- "#fce8e4"

# ── Box coordinates ──────────────────────────────────────────────────
# Canvas: x 0-10, y 0-7.5

# Tier 1: Evidence (top centre)
ev_w <- 5.6; ev_h <- 1.1
ev_x <- (10 - ev_w) / 2; ev_y <- 6.0

# Tier 2: Interpretive frameworks (middle, two columns)
t2_w <- 4.2; t2_h <- 1.55
t2_y <- 3.7
t2_lx <- 0.4;  t2_rx <- 10 - t2_w - 0.4

# Tier 3: Policy architectures (bottom, two columns)
t3_w <- 4.2; t3_h <- 1.55
t3_y <- 1.4
t3_lx <- 0.4;  t3_rx <- 10 - t3_w - 0.4

# ── Box data frames ──────────────────────────────────────────────────
boxes <- data.frame(
  xmin = c(ev_x,  t2_lx, t2_rx, t3_lx, t3_rx),
  ymin = c(ev_y,  t2_y,  t2_y,  t3_y,  t3_y),
  xmax = c(ev_x + ev_w,   t2_lx + t2_w, t2_rx + t2_w,
           t3_lx + t3_w,  t3_rx + t3_w),
  ymax = c(ev_y + ev_h,   t2_y + t2_h,  t2_y + t2_h,
           t3_y + t3_h,   t3_y + t3_h),
  fill   = c(c_evidence_fill, c_green_fill, c_coral_fill,
             c_green_fill, c_coral_fill),
  border = c(c_evidence_border, c_green_border, c_coral_border,
             c_green_border, c_coral_border),
  stringsAsFactors = FALSE
)

# ── Title labels ──────────────────────────────────────────────────────
titles <- data.frame(
  x = c(ev_x + ev_w / 2,
        t2_lx + t2_w / 2, t2_rx + t2_w / 2,
        t3_lx + t3_w / 2, t3_rx + t3_w / 2),
  y = c(ev_y + ev_h - 0.22,
        t2_y + t2_h - 0.22, t2_y + t2_h - 0.22,
        t3_y + t3_h - 0.22, t3_y + t3_h - 0.22),
  label = c("Empirical evidence (\u00a73\u20134)",
            "Green-growth future (\u00a75.1)",
            "Climate-emergency future (\u00a75.2)",
            "Supply-side policy",
            "Demand-side policy"),
  colour = c(c_evidence_border, c_green_border, c_coral_border,
             c_green_border, c_coral_border),
  stringsAsFactors = FALSE
)

# ── Body text ─────────────────────────────────────────────────────────
bodies <- data.frame(
  x = c(ev_x + ev_w / 2,
        t2_lx + t2_w / 2, t2_rx + t2_w / 2,
        t3_lx + t3_w / 2, t3_rx + t3_w / 2),
  y = c(ev_y + ev_h - 0.60,
        t2_y + t2_h - 0.55, t2_y + t2_h - 0.55,
        t3_y + t3_h - 0.55, t3_y + t3_h - 0.55),
  label = c(
    "Technology indicators track affluence, not efficiency;\napparent dematerialisation = geographic displacement",
    "\"Current technology insufficient --\nmore innovation needed.\"\nPerformative expectation -> institutional\nlock-in -> evidence domesticated",
    "\"The growth imperative is\nthe problem.\"\nCounter-evidence as mandate\nfor structural change",
    "R&D subsidies, carbon markets,\ncircular economy, green tech funding.\nEffect: defers structural change",
    "Material throughput caps, reduced\nworking hours, redistribution of\nconsumption.\nEffect: requires dismantling\ninstitutional architecture"
  ),
  stringsAsFactors = FALSE
)

# ── Arrow data ────────────────────────────────────────────────────────
arrows <- data.frame(
  x    = c(ev_x + 0.8,                  ev_x + ev_w - 0.8,
           t2_lx + t2_w / 2,            t2_rx + t2_w / 2),
  y    = c(ev_y,                         ev_y,
           t2_y,                         t2_y),
  xend = c(t2_lx + t2_w / 2,            t2_rx + t2_w / 2,
           t3_lx + t3_w / 2,            t3_rx + t3_w / 2),
  yend = c(t2_y + t2_h,                 t2_y + t2_h,
           t3_y + t3_h,                 t3_y + t3_h),
  colour = c(c_green_border, c_coral_border,
             c_green_border, c_coral_border),
  curv   = c(0.2, -0.2, 0.0, 0.0),
  stringsAsFactors = FALSE
)

# ── Column labels (subtle) ───────────────────────────────────────────
col_labels <- data.frame(
  x     = c(t2_lx + t2_w / 2, t2_rx + t2_w / 2),
  y     = c(0.85, 0.85),
  label = c("Ecological modernisation", "Degrowth / post-growth"),
  stringsAsFactors = FALSE
)

# ── Build plot ────────────────────────────────────────────────────────
p <- ggplot() +
  coord_cartesian(xlim = c(-0.5, 10.5), ylim = c(0.3, 7.6), expand = FALSE) +

  # Boxes
  geom_rect(
    data = boxes,
    aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
    fill = boxes$fill, colour = boxes$border,
    linewidth = 0.7, linejoin = "round"
  ) +

  # Titles (bold)
  geom_text(
    data = titles,
    aes(x = x, y = y, label = label),
    colour = titles$colour,
    size = 3.4, fontface = "bold", family = "serif"
  ) +

  # Body text
  geom_text(
    data = bodies,
    aes(x = x, y = y, label = label),
    colour = "#333333",
    size = 2.7, family = "serif", lineheight = 1.2, vjust = 1
  ) +

  # Straight / curved arrows (Tier 1 → 2 and Tier 2 → 3)
  geom_curve(
    data = arrows[1, ],
    aes(x = x, y = y, xend = xend, yend = yend),
    colour = arrows$colour[1], curvature = 0.2,
    arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
    linewidth = 0.6
  ) +
  geom_curve(
    data = arrows[2, ],
    aes(x = x, y = y, xend = xend, yend = yend),
    colour = arrows$colour[2], curvature = -0.2,
    arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
    linewidth = 0.6
  ) +
  geom_segment(
    data = arrows[3, ],
    aes(x = x, y = y, xend = xend, yend = yend),
    colour = arrows$colour[3],
    arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
    linewidth = 0.6
  ) +
  geom_segment(
    data = arrows[4, ],
    aes(x = x, y = y, xend = xend, yend = yend),
    colour = arrows$colour[4],
    arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
    linewidth = 0.6
  ) +

  # Feedback loop (dashed): supply-side left → green-growth left
  geom_curve(
    data = data.frame(
      x = t3_lx, y = t3_y + t3_h * 0.5,
      xend = t2_lx, yend = t2_y + t2_h * 0.35
    ),
    aes(x = x, y = y, xend = xend, yend = yend),
    colour = c_green_border, curvature = 0.45,
    linetype = "dashed", linewidth = 0.8,
    arrow = arrow(length = unit(0.15, "cm"), type = "closed")
  ) +

  # Feedback loop label
  annotate(
    "label", x = t3_lx - 0.65, y = (t3_y + t3_h * 0.5 + t2_y + t2_h * 0.35) / 2,
    label = "expectations\ntrap",
    size = 2.5, fontface = "italic", colour = c_green_border,
    fill = "white", label.padding = unit(0.15, "lines"),
    family = "serif"
  ) +

  # Column labels
  geom_text(
    data = col_labels,
    aes(x = x, y = y, label = label),
    colour = "#888888",
    size = 2.8, fontface = "italic", family = "serif"
  ) +

  # Caption
  labs(caption = paste0(
    "Fig. 1. Competing sociotechnical futures and their policy architectures.\n",
    "The same empirical evidence enters two interpretive frameworks, ",
    "generating distinct policy responses.\n",
    "The dashed feedback loop represents the expectations trap (\u00a75.1\u20135.2)."
  )) +

  theme_void(base_family = "serif", base_size = 9) +
  theme(
    plot.caption = element_text(
      size = 7, face = "italic", colour = "#555555",
      hjust = 0.5, lineheight = 1.3, margin = margin(t = 8)
    ),
    plot.margin = margin(10, 10, 10, 10)
  )

# ── Save ──────────────────────────────────────────────────────────────
png_path <- file.path(fig_dir, "fig01_competing_futures.png")
pdf_path <- file.path(fig_dir, "fig01_competing_futures.pdf")

ggsave(png_path, p, width = 10, height = 7.5, dpi = 300, bg = "white")
ggsave(pdf_path, p, width = 10, height = 7.5, bg = "white")

cat(sprintf("  Saved: %s\n", png_path))
cat(sprintf("  Saved: %s\n", pdf_path))
cat("Done.\n")
