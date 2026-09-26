# TODO: When you first start running,
# small movements make ugly looking circles.
# We should not render big circles until after
# some minimum velocity has been reached.

do ()->
  # We use a rand table, rather than Math.random(), so that we can have deterministic randomness.
  # This is not a performance optimization — Math.random() is already VERY fast.
  # It just gives us repeatability from one frame to the next.

  # The table needs to be larger than the number of times we use it in one place, or else we'll get duplication.
  # At this size, it takes about ~1ms to populate the table on my machine
  randTableSize = 4096

  seed = 2 ** 31 - 1
  seed = seed * Math.random() |0 # Comment-out this line for repeatable debugging
  seed = 771 if seed % randTableSize is 1 # If the seed mod randTableSize is 1, we get awful results

  randTable = [0...randTableSize]
  j = 0
  for i in [0...randTableSize]
    j = (j + seed + randTable[i]) % randTableSize
    [randTable[i], randTable[j]] = [randTable[j], randTable[i]]

  # Check the DOM to see which mode we'll be running in
  isInfinite = document.getElementById "starfailed-full"
  bw = document.querySelector "[js-stars-bw]"
  bio = document.querySelector "[js-stars-bio]"

  # For these, the first element is the base value and the second is the random offset from it
  styles =
    normal:
      stars:      h: [15, 40],   s: 35,       l: [50, 80]
      blueBlobs:  h: [205, 25],  s: [40, 10], l: [45, 10]
      redBlobs:   h: [350, 40],  s: [40, 10], l: [65, 10]
      blackBlobs: h: 11,         s: 41,       l: [3, 2]
    bio:
      stars:      h: [330, 10],  s: 100,      l: [90, 10]
      blueBlobs:  h: [345, 10],  s: [30, 10], l: [50, 15]
      redBlobs:   h: [325, 20],  s: [50, 20], l: [40, 40]
      blackBlobs: h: 320,        s: 100,      l: [8, 0]
    bw:
      stars:      h: [0, 0],     s: 0,        l: [0, 0]
      blueBlobs:  h: [0, 0],     s: [0, 0],   l: [0, 0]
      redBlobs:   h: [0, 0],     s: [0, 0],   l: [25, 40]
      blackBlobs: h: 0,          s: 0,        l: [3, 2]

  style = switch
    when bw then styles.bw
    when bio then styles.bio
    else styles.normal

  for canvas in document.querySelectorAll "canvas.js-stars"
    if window.getComputedStyle(canvas).display isnt "none"
      do (canvas)->
        context = canvas.getContext "2d"
        dpi = Math.max 1, Math.round window.devicePixelRatio
        width = 0
        height = 0
        density = 0
        odensity = 0
        sdensity = 0
        bdensity = 0
        dScale = 0
        dScaleHalfDpi = 0
        accel = 0
        vel = 40
        maxVel = defaultMaxVel = if isInfinite then 4 else .3 # Multiplied by root of the screen height
        scaledVel = 0
        pos = 0
        absPos = 0
        renderRequested = false
        first = true
        lastTouchY = 0
        keyboardUp = false
        keyboardDown = false
        keyboardAccel = 0.5
        scrollPos = dpi * (document.body.scrollTop + document.body.parentNode.scrollTop - canvas.offsetTop)
        alpha = 1
        lastTime = 0

        # This is for the css
        canvas.setAttribute "bw", "" if bw
        canvas.setAttribute "bio", "" if bio

        resize = ()->
          width = canvas.width = canvas.parentNode.offsetWidth * dpi
          height = canvas.height = canvas.parentNode.offsetHeight * dpi
          odensity = scale height/dpi, 0, 1000, 0.3, 1 # Scale the opacity of objects based on the canvas height
          sdensity = scale Math.sqrt(width * height)/dpi, 100, 1000, .2, 1 # Scale the number of stars based on the canvas size
          bdensity = scale Math.sqrt(width * height)/dpi, 100, 1000, .6, 1 # Scale the number of blobs based on the canvas size
          density = scale Math.sqrt(width * height)/dpi, 0, 1500, 0, 1 # Scale the radius of objects based on the canvas size
          dScale = scale Math.sqrt(width * height)/dpi, 500, 3000, 1, 2 # Scale the size of objects based on the canvas size
          dScaleHalfDpi = dScale * dpi/2
          maxVel = defaultMaxVel * Math.sqrt window.innerHeight # Scale the velocity based on the height of the screen
          first = true
          vel = 40 if Math.abs(vel) < 40

        doRender = ()->
          renderRequested = false
          renderStars if first then firstDrawCall else normalDrawCall

        requestRender = ()->
          unless renderRequested
            renderRequested = true
            requestAnimationFrame doRender

        requestScrollRender = (e)->
          p = dpi * (document.body.scrollTop + document.body.parentNode.scrollTop - canvas.offsetTop)
          delta = p - scrollPos
          scrollPos = p
          vel += delta / if isInfinite then 24 else if bio then 20 else 5
          requestRender()

        requestWheelRender = (e)->
          vel -= e.deltaY / if isInfinite then 64 else 8
          requestRender()

        requestMoveRender = (e)->
          e.preventDefault() if isInfinite
          y = e.touches.item(0).screenY
          vel -= (y - lastTouchY) / if isInfinite then 24 else 5
          lastTouchY = y
          requestRender()

        touchStart = (e)->
          e.preventDefault() if isInfinite
          lastTouchY = e.touches.item(0).screenY

        keyDown = (e)->
          keyboardUp = true if e.keyCode == 38
          keyboardDown = true if e.keyCode == 40
          requestRender() if keyboardDown or keyboardUp

        keyUp = (e)->
          keyboardUp = false if e.keyCode == 38
          keyboardDown = false if e.keyCode == 40
          # requestRender() if keyboardDown or keyboardUp

        requestResize = ()->
          if width isnt canvas.parentNode.offsetWidth * dpi
            requestAnimationFrame ()->
              first = true
              resize()
              renderStars firstDrawCall

        requestResize()

        window.addEventListener "resize", requestResize
        if isInfinite
          window.addEventListener "wheel", requestWheelRender
        else
          window.addEventListener "scroll", requestScrollRender, passive: true
        window.addEventListener "touchstart", touchStart, passive: !isInfinite
        window.addEventListener "touchmove", requestMoveRender, passive: !isInfinite
        window.addEventListener "keydown", keyDown
        window.addEventListener "keyup", keyUp

        contentVisible = true
        canvas.addEventListener "contentvisibilityautostatechange", (e)->
          if contentVisible = !e.skipped
            first = true
            requestRender()

        firstDrawCall = (x, y, r, s)->
          context.beginPath()
          context.fillStyle = s
          context.arc x, y, r, 0, TAU
          context.fill()

        normalDrawCall = (x, y, r, s, velScale)->
          context.beginPath()
          context.strokeStyle = s
          context.lineWidth = r*2
          context.moveTo x, y - (scaledVel * velScale)
          context.lineTo x, y
          context.stroke()

        renderStars = (drawCall)->
          return unless contentVisible
          return unless scrollPos < Math.max(height, 1000) and !document.hidden
          return if not isInfinite and reduceMotion and not first

          time = performance.now()
          dt = Math.min 1/60, (time - lastTime)/1000
          lastTime = time
          timeScale = 30 * dt # the below is all still written assuming 60 fps, but i've slowed it down for aesthetics

          if keyboardDown and not keyboardUp
            accel = +keyboardAccel
          else if keyboardUp and not keyboardDown
            accel = -keyboardAccel
          else
            accel /= 1 + .05 * timeScale

          vel += accel * timeScale
          absVel = Math.abs vel
          if absVel > .5
            vel /= 1 + (if isInfinite then .02 else .05) * timeScale
          else
            vel /= 1 + (absVel/5) * timeScale

          vel = clip vel, -maxVel, maxVel unless bio

          scaledVel = vel * dpi * dScale
          pos -= scaledVel * timeScale
          oldAbsPos = absPos
          absPos -= Math.abs scaledVel * timeScale

          absVel = Math.abs vel

          if absVel > 0.03
            requestRender()

          if first
            maxPixelStars = 800
            maxStars = 120
            maxSmallGlowingStars = 240
            maxBlueBlobs = 0
            maxRedBlobs = 0
            maxBlackBlobs = 0
          else if bio
            maxPixelStars = 771
            maxStars = 49
            maxSmallGlowingStars = 49
            maxBlueBlobs = 7
            maxRedBlobs = 49
            maxBlackBlobs = 7
          else if isInfinite
            maxPixelStars = 300
            maxStars = 60
            maxSmallGlowingStars = 120
            maxBlueBlobs = 120
            maxRedBlobs = 100
            maxBlackBlobs = 7
          else
            maxPixelStars = 200
            maxStars = 40
            maxSmallGlowingStars = 50
            maxBlueBlobs = 120
            maxRedBlobs = 100
            maxBlackBlobs = 0

          nPixelStars        = sdensity * maxPixelStars |0
          nStars             = sdensity * maxStars |0
          nSmallGlowingStars = sdensity * maxSmallGlowingStars |0
          nBlueBlobs         = bdensity * maxBlueBlobs |0
          nRedBlobs          = bdensity * maxRedBlobs |0
          nBlackBlobs        = maxBlackBlobs

          if not first
            alpha = Math.pow(absVel/40, .5) * Math.cos clip absVel/7, 0, Math.PI

          context.lineCap = "butt"

          if document.spooky
            i = 0
            context.fillStyle = "#000"
            context.fillRect 0, 0, width, height
            scaledVel = -1
            while i < nPixelStars
              increase = i/maxPixelStars
              x = randTable[(i + 5432) % randTableSize]
              y = randTable[x]
              o = randTable[y]
              r = randTable[o]
              x = x * width / randTableSize
              y = mod y * height / randTableSize - pos * increase, height
              o = o / randTableSize * 1 + 0.01
              r = r / randTableSize * 1 + .5
              normalDrawCall x, y, 3 * r * dScaleHalfDpi, "hsl(0 0% 100% / #{o})", 10 + 10 * absVel * increase
              i++

            first = false
            return null

          # Pixel Stars
          i = 0
          while i < nPixelStars
            increase = i/maxPixelStars
            x = randTable[(i + 5432) % randTableSize]
            y = randTable[x]
            o = randTable[y]
            r = randTable[o]
            x = x * width / randTableSize
            y = mod y * height / randTableSize - pos * increase, height
            o = o / randTableSize * .5 + 0.01
            r = r / randTableSize * 1 + .5
            o = o*alpha*odensity
            if o > 0
              firstDrawCall x, y, r * dScaleHalfDpi, "hsl(#{300} #{0}% #{100}% / #{o})", increase
            i++


          # Stars
          i = 0
          while i < nStars
            decrease = 1 - i/maxStars
            x = randTable[i % randTableSize]
            y = randTable[x]
            r = randTable[y]
            sx = randTable[r]
            sy = randTable[sx]
            l = randTable[sy]
            c = randTable[l]
            o = randTable[c]
            x = x * width / randTableSize
            r = r / randTableSize * 4 + .2
            y = mod(r + y * height / randTableSize - pos * decrease, height+r*2)-r
            l = l / randTableSize * 20 + 80
            o = o / randTableSize * decrease + 0.05
            c = c / randTableSize * 120 + 200
            drawCall x, y, r * dScaleHalfDpi, "hsl(#{c} #{30*bw}% #{l}% / #{o*alpha*odensity})", decrease
            i++


          if not first
            alpha = clip Math.pow(absVel/5, 3), 0, 2


          # Small Round Stars with circular glow rings
          i = 0
          while i < nSmallGlowingStars
            decrease = 1 - i/maxSmallGlowingStars
            r = randTable[(i + 345) % randTableSize]
            l = randTable[r]
            o = randTable[l]
            c = randTable[o]
            x = randTable[c]
            y = randTable[x]
            x = x * width / randTableSize
            r = r / randTableSize * 2 + 1
            y = mod(r + y * height / randTableSize - pos * decrease, height+r*2)-r
            l = l / randTableSize * style.stars.l[1] + style.stars.l[0]
            o = o / randTableSize * decrease * .8 + 0.05
            c = c / randTableSize * style.stars.h[1] + style.stars.h[0] % 360
            s = style.stars.s

            # far ring
            drawCall x, y, r * r * r * dScaleHalfDpi, "hsl(#{c} #{.7*s}% #{l}% / #{o/25*alpha})", decrease

            # close ring
            drawCall x, y, r * r * dScaleHalfDpi, "hsl(#{c} #{.5*s}% #{l}% / #{o/6*alpha})", decrease

            # round star body
            drawCall x, y, r * dScaleHalfDpi, "hsl(#{c} #{.2*s}% #{l}% / #{o*alpha})", decrease

            # point of light
            drawCall x, y, 1 * dScaleHalfDpi, "hsl(#{c} #{s}% #{90}% / #{o * 1.5*alpha})", decrease

            i++



          # For blobs
          context.lineCap = "round"
          alpha = clip Math.pow(absVel/24, 1.4), 0, 0.5


          # Blue Blobs
          i = 0
          while i < nBlueBlobs
            increase = i/maxBlueBlobs
            x = randTable[(i + 123) % randTableSize]
            y = randTable[x]
            r = randTable[y]
            l = randTable[r]
            s = randTable[l]
            h = randTable[s]
            o = randTable[h]
            x = x / randTableSize * width
            _r = r / randTableSize
            velScale = 1 - .8 * _r
            r = _r * 120 * density + 20
            y = mod(r + y / randTableSize * height - absPos * velScale, height + r*2)-r
            s = s / randTableSize * style.blueBlobs.s[1] + style.blueBlobs.s[0]
            l = l / randTableSize * style.blueBlobs.l[1] + style.blueBlobs.l[0]
            h = h / randTableSize * style.blueBlobs.h[1] + style.blueBlobs.h[0]
            o = o / randTableSize * 0.1 + 0.05
            drawCall x, y, r * 1 * dScaleHalfDpi, "hsl(#{h} #{s}% #{l}% / #{o*alpha})", velScale
            drawCall x, y, r * 2 * dScaleHalfDpi, "hsl(#{h} #{s}% #{l}% / #{o/2*alpha})", velScale
            i++


          # Red Blobs
          i = 0
          while i < nRedBlobs
            increase = i/maxRedBlobs
            o = randTable[(12345 + i) % randTableSize]
            x = randTable[o]
            y = randTable[x]
            r = randTable[y]
            l = randTable[r]
            h = randTable[l]
            s = randTable[h]
            x = x / randTableSize * width
            _r = r / randTableSize
            velScale = 1 - .8 * _r
            r = _r * 120 * density + 20
            y = mod(r + y / randTableSize * height - absPos * velScale, height + r*2)-r
            l = l / randTableSize * style.redBlobs.l[1] + style.redBlobs.l[0]
            o = o / randTableSize * 0.1 + 0.05
            h = h / randTableSize * style.redBlobs.h[1] + style.redBlobs.h[0]
            s = s / randTableSize * style.redBlobs.s[1] + style.redBlobs.s[0]
            drawCall x, y, r * 1 * dScaleHalfDpi, "hsl(#{h} #{s}% #{l}% / #{o*alpha})", velScale
            drawCall x, y, r * 2 * dScaleHalfDpi, "hsl(#{h} #{s}% #{l}% / #{o/2*alpha})", velScale
            i++


          # Black Blobs
          alpha = 0.002 + 0.05 * Math.sqrt absVel


          deltaPos = absPos - oldAbsPos
          steps = 4
          for q in [0...steps]
            blobPos = oldAbsPos + q * (deltaPos / steps)

            i = 0
            while i < nBlackBlobs
                increase = i/maxBlackBlobs
                decrease = 1 - increase

                x = randTable[(i + 771) % randTableSize]
                y = randTable[x]
                l = randTable[y]
                f = randTable[l]
                p = randTable[f]

                x /= randTableSize
                y /= randTableSize
                l /= randTableSize
                f /= randTableSize
                p /= randTableSize

                # lightness
                l *= style.blackBlobs.l[1] + style.blackBlobs.l[0] * increase + 2
                color = "hsl(#{style.blackBlobs.h} #{style.blackBlobs.s}% #{l}% / #{alpha})"

                # radius
                r = 100 * increase * increase * density + 40

                # stuff like velocity is proportional to radius (bigger = slower)
                rScale = (600 / r / r) + (10 / r)

                # go past the edge before looping
                y = mod(r + y * height + blobPos * rScale, height+r*2) - r

                # wiggle, and don't touch the edges
                wiggle = (100 + width/20) * rScale * Math.cos(-blobPos * rScale / 2000 * f + p)
                minX = width * .1
                rangeX = width * .8
                x = wiggle + minX + rangeX * x

                drawCall x, y, r * dScaleHalfDpi, color, velScale
                i++

          first = false
          null
