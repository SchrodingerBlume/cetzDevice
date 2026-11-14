// Keep gradient geometry in R device coordinates.
#let r-svg-number(value) = str(value).replace("\u{2212}", "-")

#let r-gradient-fill(index, bounds, shape) = (ctx => {
  let (x0, y0, x1, y1) = bounds
  let m = ctx.transform
  assert(type(m) == array and m.at(3) == (0, 0, 0, 1),
    message: "R gradient fills require an affine CeTZ transform")
  let corners = ((x0, y0), (x1, y0), (x1, y1), (x0, y1)).map(
    p => cetz.util.apply-transform(m, (..p, 0)))
  let left = calc.min(..corners.map(p => p.at(0)))
  let right = calc.max(..corners.map(p => p.at(0)))
  let bottom = calc.min(..corners.map(p => p.at(1)))
  let top = calc.max(..corners.map(p => p.at(1)))
  let (w, h) = (right - left, top - bottom)
  if w <= 0 or h <= 0 { return (ctx: ctx, drawables: ()) }
  let matrix = (m.at(0).at(0), -m.at(1).at(0), -m.at(0).at(1),
    m.at(1).at(1), m.at(0).at(3), -m.at(1).at(3)).map(r-svg-number).join(" ")
  let view = (left, -top, w, h).map(r-svg-number).join(" ")
  let source = ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + str(w) +
    "\" height=\"" + str(h) + "\" viewBox=\"" + view +
    "\"><defs>" + r-patterns.at(index) + "</defs><g transform=\"matrix(" + matrix +
    ")\">" + shape + "</g></svg>")
  let body = box(image(bytes(source), format: "svg", fit: "stretch",
    width: w * ctx.length, height: h * ctx.length))
  let border = cetz.drawable.line-strip(
    ((left, bottom, 0), (right, bottom, 0), (right, top, 0), (left, top, 0)), close: true)
  (ctx: ctx, drawables: (cetz.drawable.content(
    ((left + right) / 2, (bottom + top) / 2, 0), w, h, border.segments, body),))
},)
