/* =============================================================================
 * OpenDesign — Motion controller
 * design-system/motion/motion.js
 *
 * Dependency-free. Load with `defer` (or type="module"). Everything here is a
 * strict NO-OP when the user prefers reduced motion:
 *   - reveals/staggers are shown instantly in their final state
 *   - accordions toggle instantly (no height animation)
 *   - sticky-active highlighting still works (it is state, not motion)
 *   - view transitions are skipped (plain navigation)
 *   - Lottie accents render a single static frame and never run rAF
 *
 * Public surface (attribute-driven, no build step):
 *   .od-reveal / .od-stagger            -> IntersectionObserver reveal
 *   .od-accordion > .od-accordion__item -> accessible accordion
 *   [data-od-sticky-nav]                -> sticky-nav active-section highlight
 *   a[data-od-vt]                       -> opt-in View Transitions nav
 *   .od-lottie[data-src]                -> lazy, viewport-gated Lottie accent
 * ========================================================================== */
(function () {
  'use strict';

  var mql = window.matchMedia
    ? window.matchMedia('(prefers-reduced-motion: reduce)')
    : { matches: false, addEventListener: function () {} };

  function reduced() { return !!mql.matches; }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  var IO = 'IntersectionObserver' in window ? window.IntersectionObserver : null;

  // Capture this script's own directory NOW (currentScript is null later, in
  // the deferred boot callback). Used to resolve the vendor Lottie player.
  var SCRIPT_DIR = (function () {
    var s = document.currentScript;
    if (s && s.src) return s.src.replace(/[^/]*$/, '');
    return '';
  })();

  /* ----------------------------------------------------------------------- *
   * Scroll reveal + stagger
   * --------------------------------------------------------------------- */
  function initReveal() {
    var revealEls = qsa('.od-reveal, .od-stagger, .od-divider');
    if (!revealEls.length) return;

    // Assign per-child stagger index (CSS reads --od-i).
    qsa('.od-stagger').forEach(function (container) {
      Array.prototype.forEach.call(container.children, function (child, i) {
        child.style.setProperty('--od-i', String(i));
      });
    });

    if (reduced() || !IO) {
      // Instant final state, no observers.
      revealEls.forEach(function (el) { el.classList.add('is-visible'); });
      return;
    }

    var obs = new IO(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          obs.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });

    revealEls.forEach(function (el) { obs.observe(el); });
  }

  /* ----------------------------------------------------------------------- *
   * Accessible accordion (button[aria-expanded] + WAAPI height)
   * --------------------------------------------------------------------- */
  function initAccordions() {
    qsa('.od-accordion').forEach(function (root) {
      qsa('.od-accordion__item', root).forEach(function (item) {
        var trigger = item.querySelector('.od-accordion__trigger');
        var panel = item.querySelector('.od-accordion__panel');
        if (!trigger || !panel) return;

        var expanded = trigger.getAttribute('aria-expanded') === 'true';
        // Establish a known initial state.
        setState(panel, trigger, expanded, false);

        trigger.addEventListener('click', function () {
          var isOpen = trigger.getAttribute('aria-expanded') === 'true';
          setState(panel, trigger, !isOpen, true);
        });
      });
    });

    function setState(panel, trigger, open, animate) {
      trigger.setAttribute('aria-expanded', open ? 'true' : 'false');

      if (!open) {
        // Collapse
        if (!animate || reduced() || typeof panel.animate !== 'function') {
          panel.hidden = true;
          panel.classList.remove('is-open');
          return;
        }
        panel.classList.remove('is-open');
        var startH = panel.scrollHeight;
        var anim = panel.animate(
          [{ height: startH + 'px' }, { height: '0px' }],
          { duration: 250, easing: 'cubic-bezier(0.4,0,0.2,1)' }
        );
        anim.onfinish = function () { panel.hidden = true; };
        return;
      }

      // Expand
      panel.hidden = false;
      if (!animate || reduced() || typeof panel.animate !== 'function') {
        panel.classList.add('is-open');
        return;
      }
      var endH = panel.scrollHeight;
      panel.classList.add('is-open');
      panel.animate(
        [{ height: '0px' }, { height: endH + 'px' }],
        { duration: 250, easing: 'cubic-bezier(0.4,0,0.2,1)' }
      );
    }
  }

  /* ----------------------------------------------------------------------- *
   * Sticky-nav active-section highlight
   *   [data-od-sticky-nav] contains a[href="#id"]; sections are the targets.
   * --------------------------------------------------------------------- */
  function initStickyNav() {
    qsa('[data-od-sticky-nav]').forEach(function (nav) {
      var links = qsa('a[href^="#"]', nav);
      if (!links.length) return;

      var byId = {};
      var sections = [];
      links.forEach(function (link) {
        var id = link.getAttribute('href').slice(1);
        var section = id && document.getElementById(id);
        if (section) { byId[id] = link; sections.push(section); }
      });
      if (!sections.length) return;

      function activate(id) {
        links.forEach(function (l) { l.classList.remove('is-active'); });
        if (byId[id]) byId[id].classList.add('is-active');
      }
      activate(sections[0].id);

      // Toggle the sticky "stuck" hairline when the header leaves the top.
      qsa('.od-sticky').forEach(function (stick) {
        var sentinel = document.createElement('span');
        sentinel.style.cssText = 'position:absolute;top:0;left:0;width:1px;height:1px;';
        stick.parentNode.insertBefore(sentinel, stick);
        if (IO) {
          new IO(function (e) {
            stick.classList.toggle('is-stuck', !e[0].isIntersecting);
          }, { threshold: 0 }).observe(sentinel);
        }
      });

      if (!IO) return; // active highlight is progressive enhancement
      var obs = new IO(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) activate(entry.target.id);
        });
      }, { rootMargin: '-45% 0px -45% 0px', threshold: 0 });
      sections.forEach(function (s) { obs.observe(s); });
    });
  }

  /* ----------------------------------------------------------------------- *
   * Highlight helpers (selection + click pulse)
   * --------------------------------------------------------------------- */
  function initHighlights() {
    // Single-select groups: [data-od-select] wraps .od-highlight items.
    qsa('[data-od-select]').forEach(function (group) {
      group.addEventListener('click', function (ev) {
        var item = ev.target.closest ? ev.target.closest('.od-highlight') : null;
        if (!item || !group.contains(item)) return;
        qsa('.od-highlight', group).forEach(function (el) {
          el.classList.remove('is-selected');
          el.setAttribute('aria-pressed', 'false');
        });
        item.classList.add('is-selected');
        item.setAttribute('aria-pressed', 'true');
        if (!reduced()) {
          item.classList.remove('od-pulse');
          void item.offsetWidth; // reflow to restart animation
          item.classList.add('od-pulse');
        }
      });
    });
  }

  /* ----------------------------------------------------------------------- *
   * Opt-in View Transitions for internal nav, with graceful fallback.
   * --------------------------------------------------------------------- */
  function initViewTransitions() {
    var supported = typeof document.startViewTransition === 'function';
    qsa('a[data-od-vt]').forEach(function (link) {
      link.addEventListener('click', function (ev) {
        var href = link.getAttribute('href') || '';
        // Only same-origin, in-page or same-document targets are enhanced.
        if (ev.defaultPrevented || ev.metaKey || ev.ctrlKey || link.target === '_blank') return;

        var targetId = href.charAt(0) === '#' ? href.slice(1) : null;
        if (!supported || reduced()) return; // fall through to normal nav

        if (targetId) {
          var el = document.getElementById(targetId);
          if (!el) return;
          ev.preventDefault();
          document.startViewTransition(function () {
            el.scrollIntoView({ block: 'start' });
          });
        }
        // For full-page hrefs we intentionally let the browser navigate;
        // MPA view transitions are opt-in via @view-transition and are a no-op
        // where unsupported (Firefox/WebKit) — no error is thrown either way.
      });
    });
  }

  /* ----------------------------------------------------------------------- *
   * Lazy Lottie loader — fetch player + JSON only when in view; pause off-screen
   * --------------------------------------------------------------------- */
  var playerPromise = null;
  function loadPlayer() {
    if (playerPromise) return playerPromise;
    playerPromise = new Promise(function (resolve, reject) {
      if (window.ODLottieMini) return resolve(window.ODLottieMini);
      var s = document.createElement('script');
      // Resolve relative to this script's own location (captured at load time).
      s.src = (SCRIPT_DIR || './') + 'vendor/lottie-mini.js';
      s.async = true;
      s.onload = function () {
        if (window.ODLottieMini) resolve(window.ODLottieMini);
        else reject(new Error('lottie-mini loaded but ODLottieMini missing'));
      };
      s.onerror = function () { reject(new Error('failed to load lottie-mini.js')); };
      document.head.appendChild(s);
    });
    return playerPromise;
  }

  function initLottie() {
    var hosts = qsa('.od-lottie[data-src]');
    if (!hosts.length) return;

    function mount(host) {
      if (host.__odMounted) return;
      host.__odMounted = true;
      loadPlayer().then(function (Lottie) {
        return fetch(host.getAttribute('data-src')).then(function (r) {
          if (!r.ok) throw new Error('lottie fetch ' + r.status);
          return r.json();
        }).then(function (data) {
          host.__od = Lottie.render(host, data, { autoplay: !reduced(), loop: true });
        });
      }).catch(function (err) {
        // Never break the page; leave the host empty and log softly.
        if (window.console && console.warn) console.warn('[od-motion] lottie skipped:', err.message);
      });
    }

    if (reduced() || !IO) {
      // Render a single static frame (no rAF) and stop.
      hosts.forEach(mount);
      return;
    }

    var obs = new IO(function (entries) {
      entries.forEach(function (entry) {
        var host = entry.target;
        if (entry.isIntersecting) {
          mount(host);
          if (host.__od && host.__od.play) host.__od.play();
        } else if (host.__od && host.__od.pause) {
          host.__od.pause(); // pause off-screen to save CPU
        }
      });
    }, { threshold: 0.01 });

    hosts.forEach(function (h) { obs.observe(h); });
  }

  /* ----------------------------------------------------------------------- *
   * Metric count-up. Elements with [data-od-count] hold their FINAL value as
   * text (so no-JS, reduced-motion, and crawlers always see the real number).
   * When one scrolls into view we ease it from 0 → target once, preserving any
   * non-digit prefix/suffix (e.g. "+", "%"). No-op under reduced motion / no-IO.
   * Not announced by SR mid-animation (no aria-live); the final DOM text is the
   * authored value.
   * --------------------------------------------------------------------- */
  function parseCount(str) {
    var m = String(str).match(/^(\D*?)([\d][\d.,]*)(\D*)$/);
    if (!m) return null;
    var num = parseFloat(m[2].replace(/,/g, ''));
    if (!isFinite(num)) return null;
    return { pre: m[1], target: num, suf: m[3], raw: String(str) };
  }
  function initCountUp() {
    var els = qsa('[data-od-count]');
    if (!els.length) return;
    if (reduced() || !IO) return; // leave the authored final value in place
    function run(el) {
      var info = parseCount(el.getAttribute('data-od-count-final') || el.textContent);
      if (!info) return;
      var dur = 1200, start = null;
      el.textContent = info.pre + '0' + info.suf;
      function step(ts) {
        if (start === null) start = ts;
        var p = Math.min(1, (ts - start) / dur);
        var eased = 1 - Math.pow(1 - p, 3); // easeOutCubic
        if (p < 1) {
          el.textContent = info.pre + Math.round(info.target * eased) + info.suf;
          requestAnimationFrame(step);
        } else {
          el.textContent = info.raw; // restore exact authored text (keeps formatting)
        }
      }
      requestAnimationFrame(step);
    }
    var obs = new IO(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { run(entry.target); obs.unobserve(entry.target); }
      });
    }, { threshold: 0.4 });
    els.forEach(function (el) {
      // Remember the authored value so a re-run never keys off a mid-count number.
      if (!el.getAttribute('data-od-count-final')) {
        el.setAttribute('data-od-count-final', el.textContent);
      }
      obs.observe(el);
    });
  }

  /* ----------------------------------------------------------------------- *
   * Magnetic elements. `.od-magnetic` eases a few px toward the pointer on a
   * FINE pointer only (transform-only, compositor-friendly). Disabled entirely
   * under reduced motion or a coarse/touch pointer. Focus + activation are
   * untouched; the transform is reset on leave/blur.
   * --------------------------------------------------------------------- */
  function initMagnetic() {
    var els = qsa('.od-magnetic');
    if (!els.length || reduced()) return;
    var fine = window.matchMedia && window.matchMedia('(pointer: fine)').matches;
    if (!fine) return;
    var STRENGTH = 0.25, MAX = 6;
    function clamp(v) { return v < -MAX ? -MAX : (v > MAX ? MAX : v); }
    els.forEach(function (el) {
      el.addEventListener('pointermove', function (ev) {
        var r = el.getBoundingClientRect();
        var dx = clamp((ev.clientX - (r.left + r.width / 2)) * STRENGTH);
        var dy = clamp((ev.clientY - (r.top + r.height / 2)) * STRENGTH);
        el.style.transform = 'translate3d(' + dx.toFixed(1) + 'px,' + dy.toFixed(1) + 'px,0)';
      });
      function reset() { el.style.transform = ''; }
      el.addEventListener('pointerleave', reset);
      el.addEventListener('blur', reset);
    });
  }

  /* ----------------------------------------------------------------------- *
   * Floating "back to top" — show after threshold, smooth-scroll to top.
   *   .od-to-top is hidden + non-focusable (pointer-events:none) until JS adds
   *   `.is-visible`; reduced-motion callers get an instant jump (no smooth).
   * --------------------------------------------------------------------- */
  function initBackToTop() {
    var btn = document.querySelector('.od-to-top');
    if (!btn) return;
    var SHOW_AT = 600, ticking = false;
    function update(){ ticking=false; var y=window.pageYOffset||document.documentElement.scrollTop||0; btn.classList.toggle('is-visible', y>SHOW_AT); }
    function onScroll(){ if(!ticking){ ticking=true; requestAnimationFrame(update); } }
    window.addEventListener('scroll', onScroll, { passive:true });
    btn.addEventListener('click', function(){ window.scrollTo({ top:0, behavior: reduced() ? 'auto' : 'smooth' }); });
    update();
  }

  /* ----------------------------------------------------------------------- *
   * Boot
   * --------------------------------------------------------------------- */
  function boot() {
    try { initReveal(); } catch (e) { warn(e); }
    try { initAccordions(); } catch (e) { warn(e); }
    try { initStickyNav(); } catch (e) { warn(e); }
    try { initHighlights(); } catch (e) { warn(e); }
    try { initViewTransitions(); } catch (e) { warn(e); }
    try { initLottie(); } catch (e) { warn(e); }
    try { initCountUp(); } catch (e) { warn(e); }
    try { initMagnetic(); } catch (e) { warn(e); }
    try { initBackToTop(); } catch (e) { warn(e); }
  }
  function warn(e) { if (window.console && console.warn) console.warn('[od-motion]', e && e.message); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }

  // Expose a tiny API for programmatic use / debugging.
  window.ODMotion = { reduced: reduced, refresh: boot };
})();
