/* =============================================================================
 * lottie-mini.js — a minimal, dependency-free Lottie (bodymovin) renderer.
 * design-system/motion/vendor/lottie-mini.js
 *
 * HONEST SCOPE: this is NOT full lottie-web. It renders the SUBSET of the
 * bodymovin schema used by the accents shipped in ../lottie/*.json:
 *   - shape layers (ty:4) with layer transforms (ks: o, r, p, a, s)
 *   - shape items: group (gr), ellipse (el), rect (rc), path (sh),
 *                  fill (fl), stroke (st), and shape-group transform (tr, static)
 *   - keyframe interpolation is LINEAR (bezier easing in i/o is ignored)
 * That is enough for compact branded accents while keeping this file ~5KB and
 * lazy-loadable. It renders to inline SVG (transform/opacity only) and exposes
 * play()/pause(). Under prefers-reduced-motion the caller passes autoplay:false,
 * so we paint frame 0 and never start a rAF loop.
 * ========================================================================== */
(function () {
  'use strict';
  var SVGNS = 'http://www.w3.org/2000/svg';

  function el(name, attrs) {
    var n = document.createElementNS(SVGNS, name);
    if (attrs) for (var k in attrs) n.setAttribute(k, attrs[k]);
    return n;
  }
  function rgba(c, o) {
    // c: [r,g,b] or [r,g,b,a] each 0..1
    var r = Math.round((c[0] || 0) * 255);
    var g = Math.round((c[1] || 0) * 255);
    var b = Math.round((c[2] || 0) * 255);
    var a = (c.length > 3 ? c[3] : 1) * (o == null ? 1 : o);
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }

  // Read an animatable property at frame f. Returns array or scalar.
  function valueAt(prop, f) {
    if (!prop) return null;
    if (prop.a !== 1) return prop.k;                 // static
    var kfs = prop.k;
    if (!kfs.length) return null;
    if (f <= kfs[0].t) return kfs[0].s;
    var last = kfs[kfs.length - 1];
    if (f >= last.t) return last.s !== undefined ? last.s : (last.e || null);
    for (var i = 0; i < kfs.length - 1; i++) {
      var a = kfs[i], b = kfs[i + 1];
      if (f >= a.t && f < b.t) {
        var t = (f - a.t) / (b.t - a.t);
        var s0 = a.s, s1 = (b.s !== undefined ? b.s : a.e);
        if (s0 == null || s1 == null) return s0 || s1;
        var out = [];
        for (var j = 0; j < s0.length; j++) out.push(s0[j] + (s1[j] - s0[j]) * t);
        return out;
      }
    }
    return kfs[0].s;
  }
  function scalar(v, d) {
    if (v == null) return d;
    return Array.isArray(v) ? v[0] : v;
  }

  // Build an SVG path "d" from a bodymovin path (v/i/o/c).
  function pathD(sh) {
    var v = sh.v, ino = sh.i, outo = sh.o, closed = sh.c;
    if (!v || !v.length) return '';
    var d = 'M' + v[0][0] + ',' + v[0][1];
    var n = v.length;
    var segs = closed ? n : n - 1;
    for (var i = 0; i < segs; i++) {
      var cur = v[i], nxt = v[(i + 1) % n];
      var o1 = outo[i], i2 = ino[(i + 1) % n];
      var c1x = cur[0] + o1[0], c1y = cur[1] + o1[1];
      var c2x = nxt[0] + i2[0], c2y = nxt[1] + i2[1];
      d += 'C' + c1x + ',' + c1y + ' ' + c2x + ',' + c2y + ' ' + nxt[0] + ',' + nxt[1];
    }
    if (closed) d += 'Z';
    return d;
  }

  // Create static SVG nodes for a list of shape items; return {nodes, fills}.
  function buildShapes(items) {
    var g = el('g');
    var fill = null, stroke = null, strokeW = 0, tr = null;
    var geo = [];

    (items || []).forEach(function (it) {
      switch (it.ty) {
        case 'gr': {
          var sub = buildShapes(it.it);
          g.appendChild(sub.node);
          break;
        }
        case 'fl': fill = it; break;
        case 'st': stroke = it; break;
        case 'tr': tr = it; break;
        case 'el': {
          var s = valueAt(it.s, 0), p = valueAt(it.p, 0) || [0, 0];
          geo.push(el('ellipse', {
            cx: p[0], cy: p[1], rx: (s[0] || 0) / 2, ry: (s[1] || 0) / 2
          }));
          break;
        }
        case 'rc': {
          var rs = valueAt(it.s, 0), rp = valueAt(it.p, 0) || [0, 0];
          var rr = scalar(valueAt(it.r, 0), 0);
          geo.push(el('rect', {
            x: rp[0] - (rs[0] || 0) / 2, y: rp[1] - (rs[1] || 0) / 2,
            width: rs[0] || 0, height: rs[1] || 0, rx: rr, ry: rr
          }));
          break;
        }
        case 'sh': {
          var shp = valueAt(it.ks, 0);
          geo.push(el('path', { d: pathD(shp) }));
          break;
        }
      }
    });

    geo.forEach(function (node) {
      if (fill) {
        node.setAttribute('fill', rgba(fillColor(fill), scalar(valueAt(fill.o, 0), 100) / 100));
      } else {
        node.setAttribute('fill', 'none');
      }
      if (stroke) {
        node.setAttribute('stroke', rgba(fillColor(stroke), scalar(valueAt(stroke.o, 0), 100) / 100));
        node.setAttribute('stroke-width', scalar(valueAt(stroke.w, 0), 1));
        node.setAttribute('stroke-linecap', 'round');
        node.setAttribute('stroke-linejoin', 'round');
      }
      g.appendChild(node);
    });

    // Static group transform.
    if (tr) {
      var tp = valueAt(tr.p, 0) || [0, 0], ta = valueAt(tr.a, 0) || [0, 0];
      var ts = valueAt(tr.s, 0) || [100, 100], trr = scalar(valueAt(tr.r, 0), 0);
      g.setAttribute('transform',
        'translate(' + tp[0] + ',' + tp[1] + ') rotate(' + trr + ') ' +
        'scale(' + (ts[0] / 100) + ',' + (ts[1] / 100) + ') translate(' + (-ta[0]) + ',' + (-ta[1]) + ')');
      var to = scalar(valueAt(tr.o, 0), 100);
      if (to !== 100) g.setAttribute('opacity', to / 100);
    }
    return { node: g };
  }
  function fillColor(item) {
    var c = valueAt(item.c, 0);
    return c || [0, 0, 0, 1];
  }

  function render(host, data, opts) {
    opts = opts || {};
    var w = data.w || 100, h = data.h || 100, fr = data.fr || 30;
    var ip = data.ip || 0, op = data.op || (fr * 2);

    var svg = el('svg', { viewBox: '0 0 ' + w + ' ' + h, xmlns: SVGNS });
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');

    var layers = [];
    (data.layers || []).forEach(function (ly) {
      if (ly.ty !== 4) return; // only shape layers
      var built = buildShapes(ly.shapes);
      var layerG = el('g');
      layerG.appendChild(built.node);
      svg.appendChild(layerG);
      layers.push({ g: layerG, ks: ly.ks });
    });

    host.textContent = '';
    host.appendChild(svg);

    function apply(f) {
      layers.forEach(function (L) {
        var ks = L.ks || {};
        var o = scalar(valueAt(ks.o, f), 100);
        var r = scalar(valueAt(ks.r, f), 0);
        var p = valueAt(ks.p, f) || [w / 2, h / 2];
        var a = valueAt(ks.a, f) || [0, 0];
        var s = valueAt(ks.s, f) || [100, 100];
        L.g.setAttribute('transform',
          'translate(' + p[0] + ',' + p[1] + ') rotate(' + r + ') ' +
          'scale(' + (s[0] / 100) + ',' + (s[1] / 100) + ') ' +
          'translate(' + (-a[0]) + ',' + (-a[1]) + ')');
        L.g.setAttribute('opacity', o / 100);
      });
    }

    var raf = null, start = null, playing = false;
    var frameSpan = Math.max(1, op - ip);

    function tick(now) {
      if (!playing) return;
      if (start == null) start = now;
      var elapsed = (now - start) / 1000;             // seconds
      var frame = ip + (elapsed * fr) % frameSpan;
      if (!opts.loop && elapsed * fr >= frameSpan) {
        apply(op - 0.001);
        playing = false;
        return;
      }
      apply(frame);
      raf = requestAnimationFrame(tick);
    }

    var api = {
      play: function () {
        if (playing) return;
        playing = true;
        start = null;
        raf = requestAnimationFrame(tick);
      },
      pause: function () {
        playing = false;
        if (raf) { cancelAnimationFrame(raf); raf = null; }
      },
      destroy: function () {
        this.pause();
        if (svg.parentNode) svg.parentNode.removeChild(svg);
      }
    };

    apply(ip); // paint first frame (static under reduced motion)
    if (opts.autoplay) api.play();
    return api;
  }

  window.ODLottieMini = { render: render };
})();
