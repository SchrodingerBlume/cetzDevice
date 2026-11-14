#let r-check-page(page) = {
  assert(type(page) == int and page >= 1 and page <= r-layers.len(),
    message: "Figure page out of range")
}

#let r-figure(page: 1) = context {
  r-check-page(page)
  r-page-content(page, r-build-scene(page))
}

#let r-figures = range(r-layers.len()).map(i => () => r-figure(page: i + 1))

// Transform clipped layers as a whole; raw elements follow CeTZ rules.
#let r-elements(page: 1, background: true, clip: false) = {
  r-check-page(page)
  let clipping = clip
  import cetz.draw: *
  let (w, h) = r-size
  let backdrop = {
    hide(rect((0, 0), (w, h), stroke: none), bounds: true)
    if background { rect((0, 0), (w, h), stroke: none, fill: r-backgrounds.at(page - 1)) }
  }
  if not clipping {
    backdrop
    r-coordinate-elements(page)
    for layer in r-layers.at(page - 1) { (layer.draw)() }
  } else {
    (ctx => {
      let scene = r-build-scene(page)
      let result = cetz.process.many(ctx, backdrop, compute-bounds: false)
      let drawables = result.drawables
      ctx = result.ctx
      for layer in scene.layers {
        drawables += r-place-content(ctx, ctx.transform, r-layer-content(layer))
      }
      ctx = cetz.process.many(ctx, r-import-nodes(scene.nodes, ctx.transform)).ctx
      (ctx: ctx, drawables: drawables)
    },)
  }
}

#let r-draw(page: 1, origin: (0, 0), angle: 0deg, name: none) = {
  r-check-page(page)
  cetz.draw.get-ctx(ctx => {
    let (_, origin) = cetz.coordinate.resolve(ctx, origin)
    let u = 1pt / ctx.length
    let local = cetz.matrix.mul-mat(
      cetz.matrix.transform-translate(..origin), cetz.matrix.mul-mat(
        cetz.matrix.transform-rotate-z(angle), cetz.matrix.transform-scale(u)))
    let matrix = cetz.matrix.mul-mat(ctx.transform, local)
    let scene = r-build-scene(page)
    let nodes = scene.nodes
    if "origin" not in nodes {
      nodes += cetz.process.many(cetz.make-ctx(length: 1pt),
        cetz.draw.anchor("origin", (0, 0))).ctx.nodes
    }
    let drawables = r-place-content(ctx, matrix, r-page-content(page, scene))
    cetz.draw.group(name: name, {
      (inner => (ctx: inner, drawables: drawables),)
      r-import-nodes(nodes, matrix)
    })
  })
}
