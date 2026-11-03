.pragma library

// The motion of ROFIoma's popups, kept in plain functions so the overlay and
// OmaCraft's preview move alike. An entrance is a clock running 0 to 1; each
// card works out where it is from the clock and its place in the popup. A
// hover is the card's own t, 0 at rest and 1 lit, which overshoots on the way.

var kPlain = { opacity: 1, scale: 1, x: 0, y: 0, rotation: 0, flip: 0 }

function clamp(v) { return v < 0 ? 0 : v > 1 ? 1 : v }
function outCubic(p) { var q = 1 - p; return 1 - q * q * q }
function outBack(p) { var q = p - 1; return 1 + 2.70158 * q * q * q + 1.70158 * q * q }
function outBounce(p) {
  if (p < 1 / 2.75) return 7.5625 * p * p
  if (p < 2 / 2.75) { p -= 1.5 / 2.75; return 7.5625 * p * p + 0.75 }
  if (p < 2.5 / 2.75) { p -= 2.25 / 2.75; return 7.5625 * p * p + 0.9375 }
  p -= 2.625 / 2.75
  return 7.5625 * p * p + 0.984375
}

// Entrances that deal the cards out one after another.
function staggered(style) { return style === "cascade" || style === "slide" || style === "flip" }

// How far along card i of n is, with the clock shared out among them.
function progress(style, clock, i, n) {
  if (!staggered(style) || n < 2) return clamp(clock)
  var step = Math.min(0.12, 0.6 / (n - 1))
  return clamp((clock - i * step) / (1 - (n - 1) * step))
}

// The whole entrance takes longer the more cards it deals out.
function duration(style, speed, n) {
  if (style === "none") return 0
  var base = (staggered(style) ? 520 : 380) + (style === "drop" ? 260 : 0)
  return Math.round(base * Math.max(0.25, speed || 1))
}

// Card i of n at this point of the entrance. reach is how far it travels in
// pixels, columns how the cards are laid out (the burst comes from their middle).
function enter(style, clock, i, n, reach, columns) {
  if (!style || style === "none" || clock >= 1) return kPlain
  var p = progress(style, clock, i, n)
  var e = outCubic(p)
  switch (style) {
  case "fade": return { opacity: p, scale: 1, x: 0, y: 0, rotation: 0, flip: 0 }
  case "rise": return { opacity: p, scale: 1, x: 0, y: (1 - e) * reach, rotation: 0, flip: 0 }
  case "drop": return { opacity: clamp(p * 3), scale: 1, x: 0, y: -(1 - outBounce(p)) * reach * 2.2, rotation: 0, flip: 0 }
  case "zoom": return { opacity: clamp(p * 2), scale: 0.55 + 0.45 * outBack(p), x: 0, y: 0, rotation: 0, flip: 0 }
  case "cascade": return { opacity: clamp(p * 2), scale: 0.86 + 0.14 * outBack(p), x: 0, y: (1 - outBack(p)) * reach, rotation: 0, flip: 0 }
  case "slide": return { opacity: clamp(p * 2), scale: 1, x: -(1 - outBack(p)) * reach * 1.6, y: 0, rotation: 0, flip: 0 }
  case "flip": return { opacity: clamp(p * 2.5), scale: 1, x: 0, y: 0, rotation: 0, flip: (1 - e) * -92 }
  case "spin": return { opacity: clamp(p * 2), scale: 0.4 + 0.6 * e, x: 0, y: 0, rotation: (1 - e) * -120, flip: 0 }
  case "burst": {
    var cols = Math.max(1, columns || n), rows = Math.ceil(n / cols)
    var cx = (i % cols) - (cols - 1) / 2, cy = Math.floor(i / cols) - (rows - 1) / 2
    return { opacity: clamp(p * 2), scale: 0.5 + 0.5 * outBack(p), x: -cx * reach * (1 - outBack(p)), y: -cy * reach * (1 - outBack(p)),
             rotation: 0, flip: 0 }
  }
  }
  return kPlain
}

// A lit card: t its own 0 to 1, beat a slow 0 to 1 and back for the styles
// that keep moving. swell is how much of HyDE's swell into the margins it
// gets, glow the halo behind it, outline whether it stays hollow and ringed.
function hover(style, t, beat) {
  switch (style) {
  case "none": return { scale: 1, y: 0, rotation: 0, glow: 0, swell: 0, outline: false }
  case "lift": return { scale: 1 + 0.03 * t, y: -12 * t, rotation: 0, glow: 0.45 * t, swell: 0, outline: false }
  case "glow": return { scale: 1, y: 0, rotation: 0, glow: t, swell: 0.3, outline: false }
  case "pulse": return { scale: 1 + (0.03 + 0.05 * beat) * t, y: 0, rotation: 0, glow: 0.35 * t * beat, swell: 0, outline: false }
  case "tilt": return { scale: 1 + 0.06 * t, y: 0, rotation: -3.5 * t, glow: 0.3 * t, swell: 0, outline: false }
  case "ring": return { scale: 1 + 0.02 * t, y: 0, rotation: 0, glow: 0.55 * t, swell: 0, outline: true }
  }
  return { scale: 1, y: 0, rotation: 0, glow: 0, swell: 1, outline: false }
}
