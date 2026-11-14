# Run from the repository root after R CMD INSTALL .
library(cetzDevice)
dir.create("output", showWarnings = FALSE)

cetz("output/base.typ", width = 6, height = 4, standalone = TRUE)
plot(mtcars$wt, mtcars$mpg, pch = 21, bg = "#2673b8", col = "#173d61",
     xlab = "Weight (1000 lbs)", ylab = "Miles per gallon",
     main = "R graphics rendered by CeTZ")
abline(lm(mpg ~ wt, data = mtcars), col = "#d45d36", lwd = 2, lty = 2)
legend("topright", c("Cars", "Linear fit"), pch = c(21, NA),
       pt.bg = "#2673b8", col = c("#173d61", "#d45d36"),
       lty = c(NA, 2), bty = "n")
dev.off()

if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) +
    geom_point(size = 2.5) +
    geom_smooth(aes(group = 1), colour = "#536779", method = "lm",
                se = TRUE, linewidth = 0.6) +
    facet_wrap(vars(am), labeller = label_both) +
    labs(title = "ggplot2 → CeTZ", x = "Weight (1000 lbs)",
         y = "Miles per gallon", colour = "Cylinders") +
    theme_minimal(base_family = "Arial")
  cetz_save("output/ggplot.typ", p, width = 7, height = 4, standalone = TRUE)
}
