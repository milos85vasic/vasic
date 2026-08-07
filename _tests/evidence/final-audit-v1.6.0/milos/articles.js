/* =============================================================================
   Article "Read more" modal — milosvasic.ru
   Vanilla JS, no build step, no dependencies. Idempotent. Event-delegated.

   Trigger markup:
       <a href="#" data-article="my-slug">Read more →</a>
       <button data-article="my-slug">Read more</button>

   Optional i18n overrides on the trigger or <html>:
       data-i18n-loading="Loading…"   data-i18n-close="Close"   data-i18n-error="…"

   Fragments live at:  articles/<lang>/<slug>.html   (relative to site root)
   lang = document.documentElement.lang || 'en'; falls back to articles/en/<slug>.html

   Global API:  window.MVArticles = { open(slug), close(), openArticle, closeArticle }
   Also exposed: window.openArticle, window.closeArticle
   ============================================================================= */
(function () {
  "use strict";

  // Idempotent guard — safe to load the script more than once.
  if (window.MVArticles) return;

  var PREFIX = "mv-article-modal";
  var LOCK_CLASS = "mv-article-lock";

  var I18N_DEFAULTS = {
    loading: "Loading…",
    close: "Close",
    error: "Sorry, this article could not be loaded.",
    retry: "Retry",
    dialog: "Article"
  };

  var labelSeq = 0; // unique-id counter for generated h1 ids

  var state = {
    el: null,        // root modal element
    body: null,      // content container
    closeBtn: null,
    trigger: null,   // element that opened the modal (focus restore target)
    open: false,
    reqId: 0          // guards against out-of-order fetches
  };

  function i18n(key, trigger) {
    var attr = "data-i18n-" + key;
    if (trigger && trigger.getAttribute(attr)) return trigger.getAttribute(attr);
    var html = document.documentElement;
    if (html && html.getAttribute(attr)) return html.getAttribute(attr);
    return I18N_DEFAULTS[key];
  }

  function lang() {
    var l = (document.documentElement.lang || "en").trim().toLowerCase();
    return l.split("-")[0] || "en";
  }

  function buildModal() {
    if (state.el) return state.el;

    var root = document.createElement("div");
    root.className = PREFIX;
    root.setAttribute("role", "dialog");
    root.setAttribute("aria-modal", "true");
    root.setAttribute("aria-hidden", "true");
    root.setAttribute("data-open", "false");

    var scrim = document.createElement("div");
    scrim.className = PREFIX + "__scrim";
    scrim.setAttribute("data-article-close", "");

    var panel = document.createElement("div");
    panel.className = PREFIX + "__panel";

    var closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = PREFIX + "__close";
    closeBtn.setAttribute("data-article-close", "");
    closeBtn.setAttribute("aria-label", I18N_DEFAULTS.close);
    closeBtn.textContent = "✕";

    var body = document.createElement("div");
    body.className = PREFIX + "__body";
    body.tabIndex = -1;

    panel.appendChild(closeBtn);
    panel.appendChild(body);
    root.appendChild(scrim);
    root.appendChild(panel);
    document.body.appendChild(root);

    state.el = root;
    state.body = body;
    state.closeBtn = closeBtn;
    return root;
  }

  function showState(html) {
    state.body.innerHTML =
      '<div class="' + PREFIX + '__state">' + html + "</div>";
  }

  function showLoading(trigger) {
    showState('<div class="' + PREFIX + '__spinner" aria-hidden="true"></div>' +
      "<p>" + escapeHtml(i18n("loading", trigger)) + "</p>");
  }

  function showError(slug, trigger) {
    showState("<p>" + escapeHtml(i18n("error", trigger)) + "</p>" +
      '<button type="button" data-article-retry="' + escapeHtml(slug) + '">' +
      escapeHtml(i18n("retry", trigger)) + "</button>");
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function fetchFragment(slug) {
    var l = lang();
    var primary = "articles/" + l + "/" + slug + ".html";
    var fallback = "articles/en/" + slug + ".html";

    return fetch(primary, { credentials: "same-origin" }).then(function (res) {
      if (res.ok) return res.text();
      if (l !== "en") {
        return fetch(fallback, { credentials: "same-origin" }).then(function (r2) {
          if (r2.ok) return r2.text();
          throw new Error("HTTP " + r2.status);
        });
      }
      throw new Error("HTTP " + res.status);
    });
  }

  function getFocusable() {
    return Array.prototype.slice.call(
      state.el.querySelectorAll(
        'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
      )
    ).filter(function (el) { return el.offsetParent !== null || el === state.body; });
  }

  function onKeydown(e) {
    if (!state.open) return;
    if (e.key === "Escape" || e.key === "Esc") {
      e.preventDefault();
      closeArticle();
      return;
    }
    if (e.key === "Tab") {
      var f = getFocusable();
      if (!f.length) { e.preventDefault(); return; }
      var first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault(); last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault(); first.focus();
      }
    }
  }

  function openArticle(slug, trigger) {
    if (!slug) return;
    buildModal();
    state.trigger = trigger || document.activeElement || null;
    state.closeBtn.setAttribute("aria-label", i18n("close", trigger));

    var root = state.el;
    // Accessible name (WCAG 4.1.2 / axe aria-dialog-name): fall back to a
    // generic label while loading; replaced by the article <h1> once fetched.
    root.removeAttribute("aria-labelledby");
    root.setAttribute("aria-label", i18n("dialog", trigger));
    root.setAttribute("aria-hidden", "false");
    root.setAttribute("data-open", "true");
    document.body.classList.add(LOCK_CLASS);
    state.open = true;
    showLoading(trigger);

    // Move focus into the dialog.
    try { state.closeBtn.focus({ preventScroll: true }); } catch (_) { state.closeBtn.focus(); }

    var rid = ++state.reqId;
    fetchFragment(slug).then(function (htmlText) {
      if (rid !== state.reqId || !state.open) return;
      state.body.innerHTML = htmlText;
      state.body.scrollTop = 0;
      // Name the dialog from the injected article heading.
      var h1 = state.body.querySelector("h1, h2");
      if (h1) {
        if (!h1.id) h1.id = PREFIX + "__title-" + (++labelSeq);
        state.el.setAttribute("aria-labelledby", h1.id);
        state.el.removeAttribute("aria-label");
      }
      try { state.body.focus({ preventScroll: true }); } catch (_) {}
    }).catch(function () {
      if (rid !== state.reqId || !state.open) return;
      showError(slug, trigger);
    });
  }

  function closeArticle() {
    if (!state.el || !state.open) return;
    state.reqId++; // invalidate any in-flight fetch
    state.open = false;
    state.el.setAttribute("data-open", "false");
    state.el.setAttribute("aria-hidden", "true");
    document.body.classList.remove(LOCK_CLASS);

    var t = state.trigger;
    state.trigger = null;
    if (t && typeof t.focus === "function") {
      try { t.focus({ preventScroll: true }); } catch (_) { t.focus(); }
    }
  }

  // ---- Event delegation (works for dynamically added cards) ----------------
  document.addEventListener("click", function (e) {
    var trigger = e.target.closest("[data-article]");
    if (trigger) {
      e.preventDefault();
      openArticle(trigger.getAttribute("data-article"), trigger);
      return;
    }
    if (state.open) {
      var closer = e.target.closest("[data-article-close]");
      if (closer && state.el.contains(closer)) { closeArticle(); return; }
      var retry = e.target.closest("[data-article-retry]");
      if (retry) { openArticle(retry.getAttribute("data-article-retry"), state.trigger); return; }
    }
  });

  document.addEventListener("keydown", onKeydown);

  // ---- Public API ----------------------------------------------------------
  window.MVArticles = {
    open: function (slug) { return openArticle(slug, null); },
    close: closeArticle,
    openArticle: function (slug) { return openArticle(slug, null); },
    closeArticle: closeArticle,
    i18n: I18N_DEFAULTS
  };
  window.openArticle = window.MVArticles.open;
  window.closeArticle = closeArticle;
})();
