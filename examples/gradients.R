library(cetzDevice)
library(grid)
dir.create("output", showWarnings = FALSE)

cetz("output/gradients.typ", width = 6, height = 4, standalone = TRUE)
grid.newpage()
grid.rect(x = 0.26, y = 0.65, width = 0.4, height = 0.4,
          gp = gpar(col = "#173d61", lwd = 1.5,
                    fill = linearGradient(c("#2673b8", "#e6b450", "#d45d36"))))
grid.circle(x = 0.75, y = 0.65, r = 0.2,
            gp = gpar(col = "#173d61", lwd = 1.5,
                      fill = radialGradient(c("white", "#2673b8", "#173d61"),
                                            cx1 = 0.3, cy1 = 0.7, r1 = 0.05)))
grid.rect(x = 0.5, y = 0.22, width = 0.87, height = 0.13,
          gp = gpar(col = NA,
                    fill = linearGradient(c("#2673b8", "#e6b450"),
                                          x1 = 0.1, x2 = 0.35,
                                          y1 = 0.5, y2 = 0.5, extend = "reflect")))
grid.text("Linear", x = 0.26, y = 0.38)
grid.text("Radial", x = 0.75, y = 0.38)
grid.text("Reflected device-space gradient", y = 0.08)
dev.off()
