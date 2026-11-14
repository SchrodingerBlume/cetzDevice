// Share names and anchors across clipping layers.
#let r-coordinate-elements(page) = {
  let elements = ()
  for (name, position) in r-coordinates.at(page - 1) {
    elements += cetz.draw.anchor(name, position)
  }
  elements
}

#let r-build-scene(page) = {
  let ctx = cetz.make-ctx(length: 1pt)
  ctx = cetz.process.many(ctx, r-coordinate-elements(page)).ctx
  let layers = ()
  for layer in r-layers.at(page - 1) {
    let body = (layer.draw)()
    let result = cetz.process.many(ctx, if body == none { () } else { body }, compute-bounds: false)
    ctx = result.ctx
    layers.push((clip: layer.clip, drawables: result.drawables))
  }
  (layers: layers, nodes: ctx.nodes)
}

#let r-layer-content(layer) = {
  let (w, h) = r-size
  let (x0, x1, y0, y1) = layer.clip
  let dy = h - y1
  block(width: w * 1pt, height: h * 1pt, spacing: 0pt, clip: true, {
    place(top + left, dx: x0 * 1pt, dy: dy * 1pt,
      box(width: (x1 - x0) * 1pt, height: (y1 - y0) * 1pt, clip: true,
        place(top + left, dx: -x0 * 1pt, dy: -dy * 1pt,
          cetz.canvas(length: 1pt, {
            import cetz.draw: *
            hide(rect((0, 0), (w, h), stroke: none), bounds: true)
            floating((inner => (ctx: inner, drawables: layer.drawables),))
          })
        )
      )
    )
  })
}

#let r-page-content(page, scene) = {
  let (w, h) = r-size
  block(width: w * 1pt, height: h * 1pt, spacing: 0pt, clip: true,
    fill: r-backgrounds.at(page - 1), {
    for layer in scene.layers { place(top + left, r-layer-content(layer)) }
  })
}

// Transform the rendered layer; use its final bounds for layout.
#let r-affine-body(body, matrix, length, width, height) = {
  let q = length / 1pt
  let (a, b, c, d) = (matrix.at(0).at(0), matrix.at(0).at(1),
    matrix.at(1).at(0), matrix.at(1).at(1)).map(v => v * q)
  let sx = calc.sqrt(a*a + c*c)
  let sy = (a*d - b*c) / sx
  let shear = -(a*b + c*d) / (sx*sx)
  let rotation = calc.atan2(a, -c)
  if calc.abs(shear) > 1e-12 {
    body = std.skew(ax: calc.atan(shear), reflow: false, origin: center + horizon, body)
  }
  if sx != 1 or sy != 1 {
    body = std.scale(x: sx * 100%, y: sy * 100%, reflow: false,
      origin: center + horizon, body)
  }
  if rotation != 0deg {
    body = std.rotate(rotation, reflow: false, origin: center + horizon, body)
  }
  box(width: width * length, height: height * length,
    place(center + horizon, body))
}

#let r-place-content(ctx, matrix, body) = {
  assert(type(matrix) == array and matrix.at(3) == (0, 0, 0, 1)
    and matrix.at(2).at(0) == 0 and matrix.at(2).at(1) == 0,
    message: "R figure embedding requires a two-dimensional affine transform")
  assert(ctx.length > 0pt, message: "R figure embedding requires a positive canvas length")
  let (a, b, c, d) = (matrix.at(0).at(0), matrix.at(0).at(1),
    matrix.at(1).at(0), matrix.at(1).at(1))
  if calc.abs(a*d - b*c) < 1e-14 { return () }
  let (w, h) = r-size
  let corners = ((0, 0, 0), (w, 0, 0), (w, h, 0), (0, h, 0)).map(
    p => cetz.util.apply-transform(matrix, p))
  let xs = corners.map(p => p.at(0))
  let ys = corners.map(p => p.at(1))
  let width = calc.max(..xs) - calc.min(..xs)
  let height = calc.max(..ys) - calc.min(..ys)
  let position = cetz.util.apply-transform(matrix, (w/2, h/2, 0))
  let border = cetz.drawable.line-strip(corners, close: true)
  (cetz.drawable.content(position, width, height, border.segments,
    r-affine-body(box(body), matrix, ctx.length, width, height)),)
}

#let r-import-nodes(nodes, matrix) = (ctx => {
  for (name, original) in nodes {
    let node = original
    let anchors = original.anchors
    node.anchors = anchor => {
      if anchor == () { return anchors(()) }
      cetz.util.apply-transform(matrix, anchors(anchor))
    }
    node.drawables = cetz.drawable.apply-transform(matrix, original.at("drawables", default: ()))
    ctx.nodes.insert(name, node)
    if ctx.groups.len() > 0 { ctx.groups.last().push(name) }
  }
  (ctx: ctx)
},)
