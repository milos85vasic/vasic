/* milosvasic.ru — download language chooser popup.
   Triggers: any element with data-dl="cv" | "cl" | "portfolio".
   Builds links to /downloads/Milos_Vasic_{CV|Cover_Letter}_{LANG}.pdf and
   /downloads/Portfolio_{LANG}.pdf.

   Language behaviour (per the i18n auto-publish tooling):
   - The rows offered are the languages whose PDF actually exists for that
     document (AVAIL) — never a silent 404.
   - The row matching the CURRENT UI language is marked as the current/
     recommended choice (class .dl-lang--current, [data-current="1"]) and
     receives focus, so the current UI language serves the matching-language
     PDF. When no PDF exists for the current UI language yet, it falls back to
     English (EN) as the current choice.
   Accessible: Esc + backdrop close, focus restore, scroll lock. */
(function () {
  'use strict';
  var modal = document.getElementById('dl-modal');
  if (!modal) return;
  var base = modal.getAttribute('data-base') || '/downloads/';
  var nameEl = modal.querySelector('.dl-doc-name');
  var langsWrap = modal.querySelector('.dl-langs');
  var FILES = { cv: 'Milos_Vasic_CV', cl: 'Milos_Vasic_Cover_Letter', portfolio: 'Portfolio' };
  // Languages actually present in /downloads/ per document (no silent 404s).
  // Kept in sync by the auto-publish pipeline as each language completes.
  // Only languages with a real, validated PDF on disk (DE dropped — it was
  // English mislabeled as German; portfolio now has genuine RU/SR editions).
  // More languages get appended by deploy-langs.sh as translations complete.
  var AVAIL = { cv: ['EN', 'SR', 'RU'], cl: ['EN', 'SR', 'RU'], portfolio: ['EN', 'SR', 'RU'] };
  // Native display names for each language suffix.
  var LANG_NAMES = {
    EN: 'English', SR: 'Српски', RU: 'Русский', DE: 'Deutsch', ES: 'Español',
    FR: 'Français', BE: 'Беларуская', ZH: '中文', KK: 'Қазақша', HI: 'हिन्दी',
    JA: '日本語', KO: '한국어', AR: 'العربية', TR: 'Türkçe', FA: 'فارسی'
  };
  var lastFocus = null;

  function t(key, fallback) {
    var d = window.MV_I18N || {};
    var code = document.documentElement.getAttribute('lang') || 'en';
    var tab = d[code] || d.en || {};
    return tab[key] || fallback;
  }
  // Current UI language as an uppercase PDF suffix (e.g. "de" -> "DE").
  function curLang() {
    var l = document.documentElement.getAttribute('lang') || 'en';
    return l.slice(0, 2).toUpperCase();
  }
  // The language to serve for the current UI: the matching-language PDF if it
  // exists for this document, otherwise fall back to EN.
  function pick(avail) {
    var c = curLang();
    return avail.indexOf(c) !== -1 ? c : 'EN';
  }

  function render(doc) {
    var fbase = FILES[doc] || FILES.cv;
    var avail = AVAIL[doc] || AVAIL.cv;
    var current = pick(avail);
    langsWrap.innerHTML = '';
    avail.forEach(function (lang) {
      var a = document.createElement('a');
      a.className = 'dl-lang' + (lang === current ? ' dl-lang--current' : '');
      a.setAttribute('data-lang', lang);
      a.setAttribute('href', base + fbase + '_' + lang + '.pdf');
      a.setAttribute('download', '');
      if (lang === current) a.setAttribute('data-current', '1');
      a.innerHTML = '<span>' + (LANG_NAMES[lang] || lang) + '</span>' +
                    '<span class="mono">' + lang + ' · PDF</span>';
      langsWrap.appendChild(a);
    });
    return current;
  }

  function open(doc) {
    var name = t('dl.cv', 'Curriculum Vitae (CV)');
    if (doc === 'cl') name = t('dl.cl', 'Cover Letter');
    else if (doc === 'portfolio') name = t('dl.portfolio', 'Portfolio');
    nameEl.textContent = name;
    render(doc);
    lastFocus = document.activeElement;
    modal.hidden = false;
    document.body.classList.add('mv-article-lock');
    requestAnimationFrame(function () { modal.classList.add('open'); });
    var cur = modal.querySelector('.dl-lang--current') || modal.querySelector('.dl-x');
    if (cur) cur.focus();
    document.addEventListener('keydown', onKey);
  }
  function close() {
    modal.classList.remove('open');
    document.body.classList.remove('mv-article-lock');
    document.removeEventListener('keydown', onKey);
    setTimeout(function () { modal.hidden = true; }, 200);
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }
  function onKey(e) { if (e.key === 'Escape') close(); }

  document.addEventListener('click', function (e) {
    var trig = e.target.closest('[data-dl]');
    if (trig) { e.preventDefault(); open(trig.getAttribute('data-dl')); return; }
    if (e.target.closest('[data-dl-close]')) { e.preventDefault(); close(); }
  });
  window.MVDownloads = { open: open, close: close };
})();
