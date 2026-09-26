do ()->

  posterize = 4 # how many different color bands (per channel)
  dither = 0.5 # how much noise to add when posterizing
  tableSize = 8192 # small values show repeating patterns that are very sensitive to the image size

  # dommy mommy
  elm = document.querySelector "profile-pic div"
  img = elm.querySelector "img"
  canvas = document.createElement "canvas"
  ctx = canvas.getContext "2d", willReadFrequently: true, colorSpace: 'display-p3'
  canvas.innerText = img.alt
  elm.prepend canvas

  # extra buffers for pixel data to save reads
  source = null
  work = null

  # cut down on line noise
  round = Math.round

  # sundry state
  w = 0
  h = 0
  fade = 0
  fadeTarget = 0
  dirty = false
  document.spooky = false
  lastT = 0
  phase = 0

  # we're gonna precompute some biased noise outside the hot loop
  bitmask = tableSize - 1
  bias = new Float32Array tableSize
  noise = new Float32Array tableSize
  noise[k] = Math.random() - .5 for k in [0...tableSize]


  setup = ()->
    window.addEventListener "scroll", scroll, passive: true
    window.addEventListener "resize", resize
    resize()


  resize = ()->
    aspect = img.naturalHeight / img.naturalWidth
    rect = elm.getBoundingClientRect()
    width = round rect.width
    height = round width * aspect
    dpr = round @clip window.devicePixelRatio, 1, 2
    w = canvas.width = round width * dpr
    h = canvas.height = round height * dpr

    ctx.drawImage img, 0, 0, w, h
    work = ctx.getImageData 0, 0, w, h
    source = Uint8ClampedArray.from work.data

    scroll()
    render()


  scroll = ()->

    # scroll position of the page
    scrollTop = document.body.scrollTop + document.body.parentNode.scrollTop

    # normalize scrollTop to n window heights
    scrollTop /= window.innerHeight

    # save the old value of fadeTarget before we update it
    lastTarget = fadeTarget

    # the fade kicks in after a lil scrolling,
    # and then hits full strength after scrolling just over one full window height.
    fadeTarget = @scale scrollTop, .4, 1.1

    # fadeTarget is clipped to go slightly past 1 so that we fade all the way
    # to white, even when spooky (cuz it sometimes darkens the photo).
    # (we need to clip so that we're not re-rendering when way offscreen)
    fadeTarget = @clip fadeTarget, 0, 1.1

    # Update if scrolling
    render() if fadeTarget isnt lastTarget

    # Update if spooking
    if not document.spooky and scrollTop > 2
      document.spooky = true
      img.src = "https://cdn.ivy.boo/assets/think.webp"
      img.addEventListener "load", (()-> resize()), once: true

  render = ()->
    return if dirty
    dirty = true
    requestAnimationFrame doRender


  doRender = (t)->
    dirty = false

    dt = Math.min(t - lastT, 30) / 1000
    lastT = t

    # Gradually approach fadeTarget
    err = fadeTarget - fade
    absErr = Math.abs err
    fade += err * 5 * dt

    # Queue another render if we've still not at the target
    render() if absErr > .001

    if document.spooky
      # When spooky, the posterization cycles in a way that looks more random
      phase += dt * absErr
      posterize = @scale Math.sin(phase), -2, 2, 1.5, 4

    # fade goes from 0 to 1-ish
    light = 255 * fade ** (if document.spooky then 1 else 5)

    step = 255 / (posterize - 1)
    invStep = 1/step

    mix = (@scale fade, 0.3, .6, 0, 1, true)
    unmix = 1 - mix

    for k in [0...tableSize]
      bias[k] = dither * step - light

    i = 0
    p = 0
    out = work.data

    if not document.spooky
      while i < source.length
        out[i+0] = unmix * source[i+0] + mix * round((source[i+0] + bias[p++ & bitmask]) * invStep) * step
        out[i+1] = unmix * source[i+1] + mix * round((source[i+1] + bias[p++ & bitmask]) * invStep) * step
        out[i+2] = unmix * source[i+2] + mix * round((source[i+2] + bias[p++ & bitmask]) * invStep) * step
        i += 4
    else
      div = 1 / 255 ** 3 # exponent should be 1 less than the number of q's below
      while i < source.length
        q = round((265 - source[i+0] + bias[p++ & bitmask]) * invStep) * step
        out[i+2] = out[i+1] = out[i+0] = q * q * q * q * div # look at 'em q's
        i += 4

    ctx.putImageData work, 0, 0


  if img.complete and img.naturalWidth then setup()
  else img.addEventListener "load", setup, once: true
