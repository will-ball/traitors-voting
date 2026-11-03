# make_header.R
# Creates header.png for the report: a stylised, stepped running-score chart.
#
# Run this from the folder that contains traitors_scorecard_report.qmd.
# It runs the report's own code to get the data (this scrapes Wikipedia, so it
# takes a few seconds), then saves header.png into the same folder.

library(tidyverse)
library(knitr)

report_file   <- "index.qmd"
header_series <- "UK 1"   # which series to draw

# Stop with a clear message if R isn't running in the report's folder
if (!file.exists(report_file)) {
  stop("Can't find ", report_file, " in ", getwd(),
       ". Set the working directory to the report's folder first.")
}

# Windows can delete R's temporary folder from under a long-running session,
# which breaks anything that writes temporary files. This recreates it if needed.
invisible(tempdir(check = TRUE))

# ---- Get the data by running the report's code ----------------------------------
# purl() pulls the R code out of the .qmd into a script in this folder (not the
# temporary folder), which is then run and deleted. pdf(NULL) quietly swallows the
# report's own plots so they don't go to the plot window or create stray files.
report_code <- "header_report_code.R"
purl(report_file, output = report_code, quiet = TRUE)
pdf(NULL)
source(report_code)
invisible(dev.off())
invisible(file.remove(report_code))

# ---- Draw the header -----------------------------------------------------------------
header_data <- running_scores %>%
  filter(series == header_series) %>%
  arrange(player, round_table_number)

# Each score holds from its round table until the next. Repeat each player's last
# score one round table later, so their final level is drawn as a flat step too.
header_data <- header_data %>%
  bind_rows(header_data %>%
              slice_max(round_table_number, n = 1, by = player) %>%
              mutate(round_table_number = round_table_number + 1)) %>%
  arrange(player, round_table_number)

# The red part of each Traitor's line: only the round tables where they were a
# Traitor, so a recruit's line turns red from the point they switched sides
traitor_runs <- header_data %>% filter(traitor)

header <- ggplot(header_data, aes(round_table_number, score, group = player)) +
  # geom_step() holds each score level until the next round table, then jumps
  # ("hv" = horizontal first, then vertical)
  geom_step(direction = "hv", colour = "grey70", linewidth = 0.4, alpha = 0.35) +
  # Traitors: a wide, transparent "glow" underneath a sharp red line
  geom_step(data = traitor_runs, direction = "hv", colour = "#E0352B",
            linewidth = 3, alpha = 0.18) +
  geom_step(data = traitor_runs, direction = "hv", colour = "#E0352B",
            linewidth = 1) +
  # A dot where each Traitor's run ends
  geom_point(data = traitor_runs %>% slice_max(round_table_number, n = 1, by = player),
             colour = "#E0352B", size = 2) +
  scale_x_continuous(expand = expansion(mult = c(0.01, 0.03))) +
  theme_void() +
  # The report shows this as a wide, short banner with the title on the left, so
  # the lines are kept to the right-hand side (a wide left margin)
  theme(plot.background = element_rect(fill = "#0E0E10", colour = NA),
        plot.margin = margin(0.15, 0.3, 0.15, 7.6, unit = "in"))

# ---- Save it next to the report ------------------------------------------------------
# Wide and short, to match the banner's shape so none of it gets cropped
ggsave("header.png", header, width = 12, height = 1.8, dpi = 200, bg = "#0E0E10")
message("Saved header.png")
