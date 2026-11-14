# Small deterministic scenarios adapted from tikzDevice's graphics tests.
# Source: daqana/tikzDevice tests/testthat/test_graphics.R, blob
# 140ee268c92de41902cf61cd2532dd157b07ab4a (GPL-2-or-later).
# Inputs are intentionally smaller and device-specific labels use an adapter.
acceptance_cases <- function() {
  case <- function(id, source, draw, family = "TeX Gyre Heros", pages = 1L,
                   coloured = TRUE, reference_error = NULL) {
    list(id = id, source = source, draw = draw, family = family,
         pages = pages, coloured = coloured, reference_error = reference_error)
  }
  list(
    case("hello", "hello_TeX", function(ctx) {
      plot(1, axes = FALSE, xlab = "", ylab = "", col = "#2673b8")
      text(1, 1.1, "Hello TeX")
    }),
    case("graph_box", "graph_box", function(ctx) {
      plot(1, type = "n", axes = FALSE, xlab = "", ylab = "")
      box(col = "#2673b8")
    }),
    case("legend", "plot_legend", function(ctx) {
      plot(1, 1, type = "n", xlim = c(0, 10), ylim = c(0, 10), xlab = "x", ylab = "y")
      legend("top", title = "Legend Test", c("Series A", "Series B"),
             col = c("#2673b8", "#d45d36"), lty = 1:2, pch = c(1, 16), inset = 0.05)
      legend(5, 4, title = "Another legend", c("Long label", "Short"),
             col = c("#2673b8", "#d45d36"), pch = c(21, 22), pt.bg = "#70af95")
    }),
    case("symbols", "pch_caracters", function(ctx) {
      plot(0, type = "n", xlim = c(-0.6, 5.6), ylim = c(-0.6, 4.6), axes = FALSE, xlab = "", ylab = "")
      for (i in 0:25) {
        x <- i %% 6; y <- 4 - i %/% 6
        points(x, y, pch = i, col = "#2673b8", bg = "#e6b450", cex = 1.5)
        text(x - 0.25, y, i, cex = 0.7)
      }
    }),
    case("filled_shapes", "draw_filled_circles / filled_rectangle", function(ctx) {
      plot(0, type = "n", xlim = c(0, 6), ylim = c(0, 4), xlab = "", ylab = "")
      for (i in 21:25) points(i - 20, 2, pch = i, col = "#173d61", bg = "#e6b450", cex = 4)
      rect(0.5, 0.5, 2.5, 1, col = "#2673b8", border = "#d45d36")
    }),
    case("line_types", "line_types", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(-0.5, 6.5), axes = FALSE, xlab = "", ylab = "")
      for (i in 0:6) lines(c(0, 1), c(i, i), lty = i, lwd = 2, col = "#2673b8")
    }),
    case("line_weights", "line_weights / line_color_width", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(-0.5, 6.5), axes = FALSE, xlab = "", ylab = "")
      for (i in 0:6) lines(c(0, 1), c(i, i), lwd = i, col = "#d45d36")
    }),
    case("alpha", "transparency", function(ctx) {
      set.seed(4)
      plot(rnorm(35), rnorm(35), pch = 21, bg = grDevices::rainbow(35, alpha = 0.5),
           col = NA, cex = 5, xlab = "x", ylab = "y")
    }),
    case("many_points", "lots_of_elements", function(ctx) {
      set.seed(4)
      plot(rnorm(500), rnorm(500), pch = 21, bg = grDevices::rainbow(50, alpha = 0.5),
           cex = 1.5, xlab = "x", ylab = "y")
    }),
    case("contours", "contour_lines", function(ctx) {
      x <- seq(-2, 2, length.out = 20)
      z <- outer(x, x, function(a, b) sin(a) * cos(b))
      par(mfrow = c(2, 2), mar = c(3, 3, 2, 1))
      contour(x, x, z, col = "#2673b8", method = "edge")
      image(x, x, z, col = grDevices::hcl.colors(12, "YlOrRd"))
      contour(x, x, z, add = TRUE, col = "#173d61")
      contour(x, x, z, ylim = c(0, 2), method = "simple", col = "#d45d36")
      contour(x, x, z, nlevels = 12, lty = 2, col = "#70af95")
    }),
    case("text_alignment", "text_alignment / text_color", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
      abline(v = 0.5, col = "#173d61")
      text(0.5, 0.8, "Left", adj = 0, col = "#d45d36")
      text(0.5, 0.5, "Center", adj = 0.5, col = "#2673b8")
      text(0.5, 0.2, "Right", adj = 1, col = "#70af95")
    }),
    case("font_styles", "character_expansion / xetex_variants", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
      for (i in 1:4) text(0.5, 1 - i/5, "Affine office ffi 123", font = i, cex = 0.7 + i/5,
                           col = c("#2673b8", "#d45d36", "#173d61", "#70af95")[i])
    }),
    case("multiline_rotation", "text_alignment (extended)", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
      text(0.2, 0.7, "First line\nSecond line", adj = 0, col = "#2673b8")
      text(0.65, 0.6, "Rotated 35", srt = 35, col = "#d45d36")
      text(0.5, 0.2, "Vertical", srt = 90, col = "#70af95")
    }),
    case("formula_labels", "string_placement", function(ctx) {
      labels <- c("$\\alpha^2$", "$\\frac{x}{\\sigma}$", "$\\sum_{i=1}^n x_i$",
                  "$\\sqrt{1+x^2}$", "$\\int_0^1 x^2 dx$")
      plot(1:5, c(1, 2, 1, 2, 1), type = "n", xlim = c(0.5, 5.5), ylim = c(0, 3),
           xlab = ctx$math("$\\alpha$"), ylab = ctx$math("$\\beta$"))
      points(1:5, c(1, 2, 1, 2, 1), pch = 16, col = "#2673b8")
      text(1:5, c(1, 2, 1, 2, 1) + 0.35, ctx$math(labels))
    }),
    case("plotmath", "ggplot2_superscripts (extended)", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(0, 1),
           xlab = expression(alpha), ylab = expression(beta))
      points(c(0.2, 0.5, 0.8), rep(0.3, 3), pch = 19, col = "#2673b8")
      text(c(0.2, 0.5, 0.8), rep(0.6, 3),
           expression(alpha^2, frac(1, sigma), sqrt(x)))
    }, family = "Noto Sans", reference_error = "\\char-"),
    case("polypath", "polypath", function(ctx) {
      par(mfrow = c(1, 2))
      for (rule in c("winding", "evenodd")) {
        plot.new(); plot.window(c(0, 1), c(0, 1))
        polypath(c(.1, .1, .9, .9, NA, .2, .2, .8, .8),
                 c(.1, .9, .9, .1, NA, .2, .8, .8, .2), col = "#2673b8", rule = rule)
        title(rule)
      }
    }),
    case("perspective", "persp_3D", function(ctx) {
      x <- seq(-1.8, 1.8, length.out = 12)
      z <- outer(x, x, function(a, b) a * b^2)
      persp(x, x, z, xlab = "x", ylab = "y", zlab = "z",
            col = grDevices::hcl.colors(12, "YlGnBu"), phi = 30, theta = -30, ticktype = "detailed")
    }),
    case("raster", "base_raster", function(ctx) {
      plot(0, type = "n", xlim = c(0, 10), ylim = c(0, 8), xlab = "", ylab = "")
      pixels <- as.raster(matrix(c("#2673b8", "#d45d36", "#70af95", "#e6b450"), 2))
      rasterImage(pixels, 1, 1, 4, 4, interpolate = FALSE)
      rasterImage(pixels, 6, 2, 9, 5, angle = 25, interpolate = FALSE)
    }),
    case("raster_reflection", "raster_reflection", function(ctx) {
      par(mfrow = c(2, 2), mar = c(3, 3, 1, 1))
      for (i in 0:3) image(volcano, useRaster = TRUE,
        xlim = if (i %% 2) c(1, 0) else c(0, 1),
        ylim = if (i %/% 2) c(1, 0) else c(0, 1))
    }),
    case("base_annotation", "base_annotation", function(ctx) {
      plot(1:5, (1:5)^2, pch = 19, col = "#2673b8", xlab = "x", ylab = "y")
      ctx$coord(4, 16, "marked")
      ctx$node(2, 20, "Named node", "label", TRUE)
      lines(c(1, 5), c(2, 8), col = "#70af95")
      ctx$link("label", "marked")
    }),
    case("annotation_noflush", "annotation_noflush", function(ctx) {
      plot.new(); plot.window(c(0, 1), c(0, 1))
      ctx$coord(0, 0, "ll")
      ctx$coord(1, 1, "ur")
      ctx$segment("ll", "ur")
    }),
    case("grid_annotation", "grid_annotation", function(ctx) {
      grid::grid.newpage()
      grid::pushViewport(grid::viewport(width = 0.8, height = 0.75,
                                        xscale = c(0, 10), yscale = c(0, 10), clip = "on"))
      grid::grid.rect(gp = grid::gpar(col = "#173d61"))
      grid::grid.points(2:8, 2:8, default.units = "native", gp = grid::gpar(col = "#2673b8"))
      ctx$grid_node(4, 7, "Grid node", "grid-label", TRUE)
      grid::popViewport()
      ctx$grid_link("grid-label")
    }),
    case("unicode", "utf8_characters", function(ctx) {
      plot(0, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
      text(0.5, 0.75, "caf\u00e9 na\u00efve \u00c5ngstr\u00f6m", col = "#2673b8")
      text(0.5, 0.35, "\u0391\u03b2\u0393 \u03c0 \u03a9", col = "#d45d36")
    }, family = "Noto Sans"),
    case("cjk", "utf8_characters (extended)", function(ctx) {
      plot(1:4, col = "#2673b8", xlab = "\u6a2a\u5750\u6807", ylab = "\u7eb5\u5750\u6807",
           main = "\u4e2d\u6587\u5b57\u4f53\u5e03\u5c40")
      text(2, 3, "\u6df7\u5408 English 123", col = "#d45d36")
    }, family = "Noto Sans CJK SC"),
    case("ggplot_facets", "ggplot2_test", function(ctx) {
      print(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
        ggplot2::geom_point() + ggplot2::facet_wrap(ggplot2::vars(am)) +
        ggplot2::labs(colour = "Cylinders") + ggplot2::theme_minimal(base_family = ctx$family))
    }),
    case("ggplot_superscripts", "ggplot2_superscripts", function(ctx) {
      data <- data.frame(x = 10^(0:5), y = seq(0.1, 0.9, length.out = 6))
      print(ggplot2::ggplot(data, ggplot2::aes(x, y)) + ggplot2::geom_point(colour = "#2673b8") +
        ggplot2::scale_x_log10(labels = function(x) parse(text = paste0("10^", log10(x)))) +
        ggplot2::theme_bw(base_family = ctx$family))
    }),
    case("lattice_raster", "grid_raster", function(ctx) {
      print(lattice::levelplot(volcano, panel = lattice::panel.levelplot.raster,
        col.regions = grDevices::topo.colors, cuts = 15,
        par.settings = list(fontfamily = ctx$family)))
    }),
    case("multiple_pages", "onefile (extended)", function(ctx) {
      plot(pressure, col = "#2673b8")
      barplot(1:5, col = "#d45d36", main = "Second page")
    }, pages = 2L)
  )
}
