library(cetzDevice)
dir.create("output", showWarnings = FALSE)

cetz("output/math.typ", width = 6, height = 4, standalone = TRUE)
plot(1:5, (1:5)^2,
     xlab = cetz_typst("$alpha$"),
     ylab = cetz_latex("$\\frac{x^2}{\\sigma}$"),
     main = "Native Typst and MiTeX labels")
text(2.5, 17, cetz_typst("$integral_0^1 x^2 dif x = 1/3$"))
text(3.5, 8, cetz_latex("$\\sum_{i=1}^{n} x_i$"), srt = 25)
dev.off()
