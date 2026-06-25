# Research Brief: Best Practices for (A) a Developer CV/Portfolio Site & (B) a Software Services Company Site

> Evidence-based, cited brief to drive the design of two sites for a senior software engineer (Serbian; targets RU + EU + global; owns `milosvasic.ru` and `vasic.digital`).
> Prepared 2026-06-17. Every recommendation carries a trailing source link. **27 distinct sources cited** (see list at end).

---

## A) DEVELOPER CV / PORTFOLIO WEBSITE
*Audience: technical recruiters & engineering hiring managers, 2026.*

### A1. What modern HR/recruiters look for

- **Lead with quantifiable impact, not responsibilities.** Recruiters read the experience section first and want real metrics (scale, users, performance, revenue), not task lists. [jobscan.co](https://www.jobscan.co/blog/software-engineer-recruiter-insights/)
- **Show a clear career arc** (e.g. Junior to Senior) that links past roles logically to the target role. [jobscan.co](https://www.jobscan.co/blog/software-engineer-recruiter-insights/)
- **Name concrete tools and stack** — languages, frameworks, databases, version control (Git/GitHub is expected), and methodologies (Agile, TDD). Recruiters scan for specific keywords. [careers.uw.edu](https://careers.uw.edu/blog/2025/08/01/entry-level-software-engineer-resume-what-recruiters-want-to-see/)
- **Demonstrate problem-solving explicitly** — how you debugged, optimized, or improved systems. Analytical thinking is weighted as heavily as raw tech knowledge. [careers.uw.edu](https://careers.uw.edu/blog/2025/08/01/entry-level-software-engineer-resume-what-recruiters-want-to-see/)
- **Include GitHub/portfolio links** so recruiters can see real code; highlight open-source contributions and continuous learning. [jobscan.co](https://www.jobscan.co/blog/software-engineer-recruiter-insights/)
- **Don't omit soft skills** — communication and cross-functional collaboration matter even for deep technical roles; tie technical wins to business outcomes. [jobscan.co](https://www.jobscan.co/blog/software-engineer-recruiter-insights/)
- **Design for scanners (F-pattern):** recruiters read top-left, then down the left edge. Front-load key info, put crucial words first in each heading/bullet, use bold for key phrases, prefer bullets over paragraphs. Right-side content gets skipped. [nngroup.com](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/)

### A2. ATS-friendly downloadable PDF CV — formatting rules

- **File format:** A clean, *text-based* PDF now parses as cleanly as DOCX in the major 2026 ATS platforms (Workday, Greenhouse, Lever). Use a single-column text-based PDF as default; fall back to DOCX only if the posting requests it. Never use .jpg/.png/.pages or image-only/scanned PDFs. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/) · [resumemate.io](https://www.resumemate.io/blog/pdf-vs-word-for-resume-2026-which-format-ats-actually-prefers/)
- **PDF safety test:** open the PDF and select/copy all text. If it copies as clean ordered text, it is text-based and ATS-safe; if garbled, it was exported as an image and will fail parsing. [jobshinobi.com](https://www.jobshinobi.com/blog/resume-scanner-pdf-vs-docx-which-is-better)
- **Single column only.** Multi-column/side-by-side layouts cause "data collision" — the parser reads content out of order and scrambles it. [jobscan.co](https://www.jobscan.co/blog/resume-tables-columns-ats/)
- **No tables, text boxes, charts, images, or skill bars.** Write "Java (Expert)" as text, not a visual proficiency bar. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/)
- **Keep contact info out of headers/footers** — many parsers ignore that layer entirely, making your name/email/phone invisible. Put all vital info in the main body. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/)
- **Use standard web-safe fonts** (Arial, Calibri, Helvetica, Georgia, Garamond, Verdana, Cambria, Times New Roman). Body 10–12pt, headers 14–16pt, max two font families. No decorative fonts or emoji icons (📞) — they render as [NULL]/gibberish. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/) · [scale.jobs](https://scale.jobs/blog/10-tips-for-ats-friendly-resumes-in-2025)
- **Use conventional section headings** ("Work Experience", "Education", "Skills"). Avoid creative labels ("My Journey", "The Toolkit") — the ATS misclassifies or drops them. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/)
- **Consistent date format** ("Jan 2021 – Mar 2023" or "01/2021 – 03/2023"); avoid apostrophes ("Jan '21") and missing months. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/)
- **Pull keywords from the job description and integrate naturally — do NOT keyword-stuff.** Modern ATS spam filters detect repetitive out-of-context lists and lower your ranking. [scale.jobs](https://scale.jobs/blog/10-tips-for-ats-friendly-resumes-in-2025)

> **Design implication:** the on-screen portfolio can be visually rich, but the downloadable CV must be a separate, deliberately *plain*, single-column, text-based PDF. Generate the PDF from a clean ATS template, not by "print to PDF" of the styled web page.

### A3. Portfolio structure that converts

- **Recommended section order:** Hero/About → Featured Projects → Skills → Experience → Contact, ideally a clean content-rich single page with sticky nav for jumping between sections. [freecodecamp.org](https://www.freecodecamp.org/news/level-up-developer-portfolio/) · [colorlib.com](https://colorlib.com/wp/developer-portfolios/)
- **Hero:** one clear value proposition + one CTA. Effective 2025 heroes balance clarity, speed, accessibility and measured interactivity. Make the work itself the hero if it is visual. [doortoonline.com](https://doortoonline.com/blog/website-hero-section-designs-2025) · [elementor.com](https://elementor.com/blog/best-web-developer-portfolio-examples/)
- **Projects are the core.** Per project, document: why you built it, challenges, lessons, your process, and what you'd do differently — don't just link to code. Include a concise description, tech-stack list, and links to live site + repo. Prefer a filterable layout. [freecodecamp.org](https://www.freecodecamp.org/news/level-up-developer-portfolio/) · [colorlib.com](https://colorlib.com/wp/developer-portfolios/)
- **About Me with personality** — a genuine narrative beats generic copy. [freecodecamp.org](https://www.freecodecamp.org/news/level-up-developer-portfolio/)
- **Cut these:** tutorial-clone projects, skill progress bars, the portfolio site listed as its own project, unrelated non-dev projects, and copied/generic templates. [freecodecamp.org](https://www.freecodecamp.org/news/level-up-developer-portfolio/)
- **Polish last:** add animations, transitions, dark mode only after fundamentals are solid; unpolished effects damage credibility. Use a custom domain. [freecodecamp.org](https://www.freecodecamp.org/news/level-up-developer-portfolio/)
- **Apply the F-pattern to the page** — front-load info, prominent headings with crucial words first, descriptive link text (not "click here"). [nngroup.com](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/)

### A4. Showcasing open-source / many repos without overwhelming

- **Curate to a small set of deep case studies.** "Quality over quantity" is the explicit rule; variety of skills shown matters more than count. 3–5 detailed projects is the recommended depth. [nngroup.com](https://www.nngroup.com/articles/ux-design-portfolios/)
- **Use a two-tier "Featured" vs "More" structure:** feature your best 4–6 projects prominently; relegate the long tail to a secondary list or an "all repos" page with one-line descriptions. [github.com](https://github.com/katiehuangx/How-to-Create-a-GitHub-Portfolio)
- **GitHub pins max out at 6 items** (repos + gists combined) — treat the pinned set as your canonical "featured" tier and mirror it on the site. [docs.github.com](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/pinning-items-to-your-profile)
- **Favor substantial, working, well-documented, role-relevant repos;** prune/hide trivial or abandoned ones so visitors see only signal. [dev.to](https://dev.to/noahelijah25/how-to-build-and-showcase-a-strong-github-portfolio-575o)
- **Per-project metadata to surface:** problem/goal, your specific role, tech stack, how you solved it, challenges/rejected approaches, and the outcome/impact. Stars and a tech-stack line signal traction, but the role + outcome narrative differentiates. [nngroup.com](https://www.nngroup.com/articles/ux-design-portfolios/) · [nucamp.co](https://www.nucamp.co/blog/coding-bootcamp-job-hunting-integrating-github-repositories-into-your-portfolio)
- **Add filtering/tagging by stack or domain** so recruiters can scan for relevance instead of all work indiscriminately. A standalone site (vs raw GitHub profile) gives you that control. [datacolumn.iaa.ncsu.edu](https://datacolumn.iaa.ncsu.edu/blog/2025/02/12/how-to-make-a-github-portfolio-website)

### A5. Cover letter best practices (concise, role-agnostic + customizable)

- **One page max, concise and factual.** Avoid flowery language; back every claim with an example. [careerservices.fas.harvard.edu](https://careerservices.fas.harvard.edu/resources/harvard-college-guide-to-resumes-cover-letters/)
- **Tailor to the specific organization** — research first, highlight the most applicable skills. This is what produces responses. [careerservices.fas.harvard.edu](https://careerservices.fas.harvard.edu/resources/harvard-college-guide-to-resumes-cover-letters/)
- **Address a specific person** when identifiable. [careerservices.fas.harvard.edu](https://careerservices.fas.harvard.edu/resources/harvard-college-guide-to-resumes-cover-letters/)
- **True letter structure:** intro → body → conclusion, professional closing. **Open with a concrete hook** (a specific project that maps to the job). **Body balances technical + soft skills** with quantifiable accomplishments tied to business outcomes. [jobscan.co](https://www.jobscan.co/cover-letter-examples/software-engineer)
- **Template strategy (role-agnostic + customizable):** keep a fixed intro/closing skeleton; swap a tailored opening hook (specific project ↔ specific company need) and 2–3 accomplishment bullets per application. [careerservices.fas.harvard.edu](https://careerservices.fas.harvard.edu/resources/harvard-college-guide-to-resumes-cover-letters/) · [tealhq.com](https://www.tealhq.com/cover-letter-example/software-engineer)

### A6. Accessibility (WCAG 2.2 AA) — must-haves

Target **WCAG 2.2 AA** (current W3C Recommendation since Oct 2023, backward-compatible with 2.1). [w3.org](https://www.w3.org/TR/WCAG22/)

- **Text contrast ≥ 4.5:1** for normal text, **≥ 3:1** for large text (≥18pt, or ≥14pt bold). [w3.org](https://www.w3.org/WAI/WCAG22/quickref/?levels=aa)
- **Non-text contrast ≥ 3:1** for UI components (buttons, form borders, icons) and meaningful graphics. [w3.org](https://www.w3.org/WAI/WCAG22/quickref/?levels=aa)
- **Full keyboard operability** — every function works via keyboard alone, no keyboard traps. [w3.org](https://www.w3.org/WAI/WCAG22/quickref/?levels=aa)
- **Visible focus indicators** (SC 2.4.7) plus WCAG 2.2's Focus Appearance (2.4.13) and Focus Not Obscured (2.4.11): focus must be clearly visible, ≥3:1 contrast vs unfocused state, and not hidden behind sticky headers. [w3.org](https://www.w3.org/TR/WCAG22/) · [testparty.ai](https://testparty.ai/blog/wcag-focus-appearance-minimum)
- **Reflow** — content works at 320 CSS px wide with no loss of info or 2-D scrolling (responsive to mobile/zoom). [w3.org](https://www.w3.org/WAI/WCAG22/quickref/?levels=aa)
- **Respect `prefers-reduced-motion`** — reduce/replace non-essential animation (parallax, autoplay) for users with vestibular disorders (SC 2.3.3). Low effort, high impact. [developer.mozilla.org](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) · [web.dev](https://web.dev/articles/prefers-reduced-motion)
- **Semantic HTML + meaningful alt text** on project images/screenshots; proper landmark/heading structure. [w3.org](https://www.w3.org/TR/WCAG22/)

### A7. Performance expectations (2025–2026)

Core Web Vitals, measured at the **75th percentile** of real-user loads, split mobile/desktop. INP replaced FID in 2024. [web.dev](https://web.dev/articles/vitals)

- **LCP (Largest Contentful Paint) ≤ 2.5 s** (loading). [web.dev](https://web.dev/articles/vitals)
- **INP (Interaction to Next Paint) ≤ 200 ms** (responsiveness). [web.dev](https://web.dev/articles/vitals)
- **CLS (Cumulative Layout Shift) ≤ 0.1** (visual stability). [web.dev](https://web.dev/articles/vitals)
- **To "pass," ≥75% of real-user visits must hit the "good" band on all three** metrics at URL level. [web.dev](https://web.dev/articles/defining-core-web-vitals-thresholds)
- **Lighthouse is lab data, not the ranking signal.** Target ≥90 Lighthouse Performance as a diagnostic, but Google ranks on field/CrUX data, which can differ. Use Lighthouse to find fixes, not as pass/fail. [debugbear.com](https://www.debugbear.com/docs/core-web-vitals-ranking-factor)
- **SEO:** CWV are a confirmed page-experience ranking factor used largely as a tie-breaker between comparable-quality pages — they help you edge out competitors but don't override content quality. [developers.google.com](https://developers.google.com/search/docs/appearance/page-experience)

---

## B) SOFTWARE SERVICES COMPANY WEBSITE
*Audience: prospective B2B clients.*

### B1. What makes a dev-shop/agency site convert leads

- **Benchmark:** the average B2B site converts ~2–4% of visitors to leads (B2B SaaS closer to 1%). Below 2% means the friction is in messaging/hero/trust signals *before* the CTA — fix those first. [grafit.agency](https://www.grafit.agency/blog/best-practices-for-building-a-high-performing-b2b-website-in-2026)
- **Credibility must land in the first viewport** — B2B buyers juggle multiple vendor tabs and decide on credibility fast. [nngroup.com](https://www.nngroup.com/reports/b2b-websites-usability/)
- **Put a trust signal within view of every major CTA.** The moment of highest doubt is right before clicking "Book a Demo" — a short quote or logo beside the button is where it pays off. [trustsignals.com](https://www.trustsignals.com/blog/77-trust-signals-to-increase-your-online-conversion-rate)
- **Match the signal to funnel position:** social-proof metrics in hero, testimonials near CTAs, security/assurance cues near forms (29% of form abandonment is driven by security concerns). [blog.thewdgagency.com](https://blog.thewdgagency.com/trust-signals-that-convert-types-of-proof-b2b-websites-need-to-turn-visitors-into-leads)
- **NN/g "pyramid of trust":** satisfy low-commitment trust needs before asking for high-commitment actions; don't demand a long form before demonstrating competence. [nngroup.com](https://www.nngroup.com/reports/b2b-websites-usability/)

**Case studies — the #1 trust asset:**
- Case studies are the single most powerful trust signal because they present *independently evaluable* measurable outcomes. Structure each as customer need → how you solved it → actual results with hard numbers. [nngroup.com](https://www.nngroup.com/reports/b2b-websites-usability/)
- Use a "before / during / after" arc with real metrics (% time saved, $ earned). For one firm, ~half of leads viewed a case study before making contact. [cxl.com](https://cxl.com/blog/b2b-case-studies/)
- Case studies ranked #1 (2024) and #2 (2025) in Content Marketing Institute surveys — a durable top format, not a fad. [stryvemarketing.com](https://www.stryvemarketing.com/blog/design-b2b-case-studies/)
- Standardize on: problem → solution → result with metrics, named client + role, a scannable card preview leading to a full study. [proofmap.com](https://proofmap.com/insights/b2b-case-studies-examples-from-the-top-58-growing-saas-companies-in-2025)

**Social proof:**
- Adding a single client logo lifted landing-page conversions by **69%** in a comScore A/B test. [cxl.com](https://cxl.com/blog/is-social-proof-really-that-important/)
- Make testimonials credible: photo + full name + company + role. Anonymous quotes carry little weight; video is more convincing. [cxl.com](https://cxl.com/blog/is-social-proof-really-that-important/)
- Surface verified third-party ratings (G2, Capterra, Clutch for agencies). Clutch is where buyers shortlist dev shops (500k+ leaders/month) and ranks firms on verified reviews, portfolio comprehensiveness, profile completeness, and reputation — mirror those four on your own site and link out. [clutch.co](https://clutch.co/resources/b2b-buyer-data)

**CTAs:**
- Keep a primary CTA above the fold (60%+ of attention is above the fold) AND repeat it mid-page. [saashero.net](https://www.saashero.net/design/b2b-saas-landing-cta-practices/)
- Match wording to journey stage: "Download the report" (awareness) → "Watch a demo" (consideration) → "Book a demo"/"Get a custom quote" (decision). [martal.ca](https://martal.ca/cta-best-practices-lb/)
- Embed a testimonial/metric/logo beside the CTA to answer "does this actually work?" at the decision point. [orangeowl.marketing](https://orangeowl.marketing/b2b-marketing/the-power-cta-in-b2b-marketing/)

### B2. Enterprise "cutting-edge" visual language (2025–2026, durable not faddish)

- **Bento grids** (cards of varying sizes in one grid) are ideal for "about us", service overviews, case-study previews, and feature highlights — they organize heterogeneous content cleanly without looking gimmicky. [gezar.dk](https://gezar.dk/en/blog/web-design-trends-2026)
- **Typography as primary identity:** oversized headlines, custom/variable typefaces, layered and kinetic type reacting on scroll. A foundational shift (type as brand), not a passing motif. [figma.com](https://www.figma.com/resource-library/web-design-trends/)
- **Motion: restrained and functional.** Micro-animations and scroll-triggered reveals to guide attention, kept subtle and performance-safe. Enterprise-credible motion serves comprehension, not decoration. [figma.com](https://www.figma.com/resource-library/web-design-trends/)
- **Dark vs light:** dark mode is effectively expected for data-heavy/technical products and signals "premium"; offering a light/dark toggle is the accessibility-conscious default. A dark technical aesthetic reads as credible for a dev shop. [theedigital.com](https://www.theedigital.com/blog/web-design-trends) · [figma.com](https://www.figma.com/resource-library/web-design-trends/)
- **Durable through-line:** pair modern/AI functionality with deliberate, hand-crafted human design — polished, intentional craft signals competence to a trust-driven B2B audience. [sayenkodesign.com](https://www.sayenkodesign.com/web-design-trends-2026-whats-worth-using-on-your-business-website/)
- **Bias toward restraint** (clear layouts, strong type, purposeful motion) over maximalist/dopamine excess; lean to whitespace + clarity, and use bento density only where it organizes content. [studiomeyer.io](https://studiomeyer.io/en/blog/webdesign-trends-2026-reality-check)

### B3. Same projects, two audiences — client vs recruiter framing

- **For clients:** lead with business impact and ROI — revenue up, cost/time down, reliability/performance gains in their bottom-line terms. [geeksforgeeks.org](https://www.geeksforgeeks.org/product-management/resume-portfolio-case-studies/)
- **For recruiters:** lead with process, problem-solving, decision-making, and technical/collaboration depth — "show how you think, not just what you shipped." [blog.uxfol.io](https://blog.uxfol.io/ux-case-study-structure/)
- **Both want outcomes** — keep the metric, change which leads: business KPI for clients, engineering KPI (latency, uptime, scale, deploy frequency) for recruiters. [recruiterswebsites.com](https://recruiterswebsites.com/how-to-write-effective-case-studies-for-recruiting/)
- **Tactic — maintain two cuts of each project:** a client cut (problem → solution → ROI, light on stack) and a technical cut (architecture, trade-offs, technologies, performance gains). One body of work, two framings. [influenceflow.io](https://influenceflow.io/resources/guide-to-portfolio-case-studies-showcase-your-work-land-more-opportunities-in-2026/)
- **Implementation:** on the public client site, default every case to problem → solution → business-metric result with a named client; offer an optional "technical deep dive" expand/toggle for the engineer audience, so one CMS entry serves both. [uxplanet.org](https://uxplanet.org/ux-portfolio-case-study-template-plus-examples-from-successful-hires-86d5b0faa2d6)

---

## CROSS-CUTTING

### C1. i18n for marketing/portfolio sites

**Language switcher UX**
- Display each language in its **own name (autonym)**: **Русский**, not "Russian"; **Español**, not "Spanish". [nngroup.com](https://www.nngroup.com/articles/language-switching-ecommerce/)
- Place a persistent switcher **top-right** on desktop (top-left fallback); on mobile, above the fold or in the nav menu. [nngroup.com](https://www.nngroup.com/articles/language-switching-ecommerce/)
- **Autodetect from `Accept-Language` as default, but always keep a visible manual override** and persist the explicit choice (cookie/localStorage) so it isn't re-asked. [nngroup.com](https://www.nngroup.com/articles/language-switching-ecommerce/)
- **Avoid flags as the sole language indicator** — flags are countries, not languages. Let language, country, and currency be chosen independently. [nngroup.com](https://www.nngroup.com/articles/language-switching-ecommerce/)

**hreflang (SEO)**
- Declare variants via HTML `<link rel="alternate" hreflang>`, HTTP `Link` header, or sitemap — pick one. [developers.google.com](https://developers.google.com/search/docs/specialty/international/localized-versions)
- Value = ISO 639-1 language code, optionally + ISO 3166-1 Alpha-2 region (`en`, `ru`, `de`, `sr`, `es-ES`). You **cannot** specify country alone. Add an **`x-default`** fallback. [developers.google.com](https://developers.google.com/search/docs/specialty/international/localized-versions)
- **hreflang must be bidirectional** — every variant links back to all others or the tags are ignored. Treat hreflang as a *hint*, not a directive; pair with correct canonicals. [developers.google.com](https://developers.google.com/search/docs/specialty/international/localized-versions) · [searchengineland.com](https://searchengineland.com/guide/what-is-hreflang)

**URL structure**
- For a single brand, **subdirectories (`/ru/`, `/de/`) are the pragmatic default** — they consolidate domain authority and are simplest to maintain. [weglot.com](https://www.weglot.com/guides/hreflang-tag)
- **ccTLDs send the strongest geo signal but are separate SEO sites.** Use the existing **`.ru` (`milosvasic.ru`) as a dedicated Russian-market property**, and run the main domain (`vasic.digital`) with `/lang/` subdirectories for the rest. [searchengineland.com](https://searchengineland.com/guide/what-is-hreflang) · [linkgraph.com](https://www.linkgraph.com/blog/hreflang-implementation-guide/)

**RTL**
- Set base direction via HTML `dir="rtl"` on `<html>`, **never** via CSS `direction`. Author with CSS **logical properties** (`margin-inline-start`, `text-align: start`) so layouts auto-mirror. [w3.org](https://www.w3.org/International/questions/qa-html-dir) · [developer.mozilla.org](https://developer.mozilla.org/en-US/docs/Web/CSS/direction)
- **None of this engineer's priority languages are RTL** (Serbian, Russian, German, English, Spanish, Chinese are all LTR). Build the architecture to *allow* RTL, but don't prioritize it unless expanding to MENA.

### C2. Which languages to prioritize

Web-content share (W3Techs, Jun 2026): English 49.7% · Spanish 6.0% · German 5.9% · French 4.5% · **Russian 3.5%** · Chinese 1.2%. [w3techs.com](https://w3techs.com/technologies/overview/content_language) Internet-user share differs (English ~25%, Spanish #3); Chinese ranks far higher by users than by content. [statista.com](https://www.statista.com/chart/26884/languages-on-the-internet/)

**Recommended priority + phasing:**
1. **English** — non-negotiable #1 (~49.7% of web content; lingua franca of engineering); serves as `x-default`. [w3techs.com](https://w3techs.com/technologies/overview/content_language)
2. **Russian** — direct strategic fit (owns `.ru`, targets RU market; dominant across CIS). [w3techs.com](https://w3techs.com/technologies/overview/content_language)
3. **German** — strongest EU business language by web content (5.9%); largest EU economy. [w3techs.com](https://w3techs.com/technologies/overview/content_language)
4. **Serbian** — native; cheap to produce authentically; covers home + ex-Yugoslav region.
5. **Spanish** — #2 web content (6.0%), ~8% of users; highest-leverage single language for global reach after English. [w3techs.com](https://w3techs.com/technologies/overview/content_language) · [statista.com](https://www.statista.com/chart/26884/languages-on-the-internet/)
6. **French** — 4.5% web content; EU + Francophone reach. [w3techs.com](https://w3techs.com/technologies/overview/content_language)
7. **Chinese (Simplified)** — optional later tier (huge user base but only ~1.2% web content; high localization effort). [w3techs.com](https://w3techs.com/technologies/overview/content_language)

> **Phase 1:** English + Russian + Serbian. **Phase 2:** German + Spanish. **Phase 3:** French (then optionally Chinese).

### C3. Dark/light theme switcher

- **Detect OS preference with `prefers-color-scheme`** (`light`/`dark`); you can conditionally load theme CSS via `media="(prefers-color-scheme: dark)"`. [web.dev](https://web.dev/articles/prefers-color-scheme)
- **Declare `color-scheme: light dark;` on `:root`** so native form controls/scrollbars render correctly per theme. [web.dev](https://web.dev/articles/prefers-color-scheme)
- **Provide a manual toggle that defaults to system but can override it, and persist the choice** in localStorage. [web.dev](https://web.dev/articles/prefers-color-scheme)
- **Resolution order at load:** stored explicit choice first; else fall back to `prefers-color-scheme`. [dev.to](https://dev.to/abbeyperini/dark-mode-toggle-and-prefers-color-scheme-4f3m)
- **Prevent the flash of inaccurate theme (FART/FOUC)** with a tiny **blocking inline `<script>` in `<head>` placed before any stylesheet**; it reads the stored preference and sets the theme class/attribute on `<html>` before first paint. [css-tricks.com](https://css-tricks.com/flash-of-inaccurate-color-theme-fart/)
- **Server-side option:** the `Sec-CH-Prefers-Color-Scheme` client hint lets the server inline the right CSS on repeat visits, eliminating any client-side flash. [web.dev](https://web.dev/articles/prefers-color-scheme)

---

## TOP 10 ACTIONABLE DECISIONS

1. **Ship two artifacts from the CV, not one.** A visually-rich on-screen portfolio AND a separate, deliberately plain, single-column, **text-based PDF** generated from an ATS template (standard fonts, conventional headings, contact info in the body, no tables/columns/icons). Verify with the copy-paste test. [jobscan.co](https://www.jobscan.co/blog/ats-formatting-mistakes/)
2. **Make projects the centerpiece of the portfolio, capped at 4–6 "Featured" + a "More/All repos" tier.** Mirror the 6 GitHub pins. Each featured project: role, stack, problem, approach, outcome/metric, live + repo links. Add stack/domain filtering. [nngroup.com](https://www.nngroup.com/articles/ux-design-portfolios/) · [docs.github.com](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/pinning-items-to-your-profile)
3. **Quantify everything; design for the F-pattern.** Front-load impact metrics, crucial words first in headings/bullets, left-aligned, bold key phrases, no "click here" links. [jobscan.co](https://www.jobscan.co/blog/software-engineer-recruiter-insights/) · [nngroup.com](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/)
4. **Author every case study once, render it for two audiences.** One CMS entry with a default client view (problem → solution → business ROI, named client) and an optional "technical deep dive" expansion (architecture, trade-offs, engineering KPIs). Reuse across both sites. [influenceflow.io](https://influenceflow.io/resources/guide-to-portfolio-case-studies-showcase-your-work-land-more-opportunities-in-2026/) · [uxplanet.org](https://uxplanet.org/ux-portfolio-case-study-template-plus-examples-from-successful-hires-86d5b0faa2d6)
5. **On the company site, lead with credibility in the first viewport and put a trust signal beside every CTA.** Client logos (a single logo lifted conversions 69%), named+photo testimonials, and verified Clutch/G2 ratings. [cxl.com](https://cxl.com/blog/is-social-proof-really-that-important/) · [clutch.co](https://clutch.co/resources/b2b-buyer-data)
6. **Standardize company case studies as problem → solution → result-with-hard-metrics, presented as scannable cards.** Case studies are the #1 B2B trust asset and directly drive contact. [nngroup.com](https://www.nngroup.com/reports/b2b-websites-usability/) · [cxl.com](https://cxl.com/blog/b2b-case-studies/)
7. **Use a restrained "cutting-edge" visual system:** strong variable typography as the brand, bento grids for services/case previews, subtle functional motion, generous whitespace, and a dark/light toggle (dark reads credible for a technical shop). Bias to restraint over maximalism. [figma.com](https://www.figma.com/resource-library/web-design-trends/) · [gezar.dk](https://gezar.dk/en/blog/web-design-trends-2026)
8. **Hit Core Web Vitals at the 75th percentile: LCP ≤2.5s, INP ≤200ms, CLS ≤0.1.** Use Lighthouse (target ≥90) only as a diagnostic; the real bar is field/CrUX data. [web.dev](https://web.dev/articles/vitals) · [debugbear.com](https://www.debugbear.com/docs/core-web-vitals-ranking-factor)
9. **Build to WCAG 2.2 AA:** contrast 4.5:1 text / 3:1 non-text, full keyboard operability, visible non-obscured focus, 320px reflow, semantic HTML + alt text, and `prefers-reduced-motion` honored. [w3.org](https://www.w3.org/WAI/WCAG22/quickref/?levels=aa) · [web.dev](https://web.dev/articles/prefers-reduced-motion)
10. **i18n architecture:** main domain (`vasic.digital`) with `/lang/` subdirectories + bidirectional hreflang + `x-default`; keep `milosvasic.ru` as the dedicated Russian-market ccTLD property. Switcher top-right showing autonyms, autodetect-with-override, persisted choice. Theme: `prefers-color-scheme` + `color-scheme: light dark` + persisted toggle + blocking inline anti-flash script. Phase languages: EN+RU+SR → DE+ES → FR. [developers.google.com](https://developers.google.com/search/docs/specialty/international/localized-versions) · [nngroup.com](https://www.nngroup.com/articles/language-switching-ecommerce/) · [css-tricks.com](https://css-tricks.com/flash-of-inaccurate-color-theme-fart/) · [w3techs.com](https://w3techs.com/technologies/overview/content_language)

---

## SOURCES CITED (27)

1. Jobscan — ATS formatting mistakes — https://www.jobscan.co/blog/ats-formatting-mistakes/
2. Jobscan — tables/columns break ATS parsing — https://www.jobscan.co/blog/resume-tables-columns-ats/
3. Jobscan — software engineer recruiter insights — https://www.jobscan.co/blog/software-engineer-recruiter-insights/
4. Jobscan — software engineer cover letter examples — https://www.jobscan.co/cover-letter-examples/software-engineer
5. University of Washington Careers — entry-level SWE resume — https://careers.uw.edu/blog/2025/08/01/entry-level-software-engineer-resume-what-recruiters-want-to-see/
6. Nielsen Norman Group — F-shaped reading pattern — https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/
7. Nielsen Norman Group — UX design portfolios — https://www.nngroup.com/articles/ux-design-portfolios/
8. Nielsen Norman Group — B2B websites usability — https://www.nngroup.com/reports/b2b-websites-usability/
9. Nielsen Norman Group — language switching — https://www.nngroup.com/articles/language-switching-ecommerce/
10. Harvard FAS Career Services — resumes & cover letters guide — https://careerservices.fas.harvard.edu/resources/harvard-college-guide-to-resumes-cover-letters/
11. freeCodeCamp — level up your developer portfolio — https://www.freecodecamp.org/news/level-up-developer-portfolio/
12. scale.jobs — 10 tips for ATS-friendly resumes 2025 — https://scale.jobs/blog/10-tips-for-ats-friendly-resumes-in-2025
13. Resumemate — PDF vs Word ATS 2026 — https://www.resumemate.io/blog/pdf-vs-word-for-resume-2026-which-format-ats-actually-prefers/
14. GitHub Docs — pinning items to your profile — https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/pinning-items-to-your-profile
15. W3C — WCAG 2.2 — https://www.w3.org/TR/WCAG22/
16. W3C — WCAG 2.2 AA quickref — https://www.w3.org/WAI/WCAG22/quickref/?levels=aa
17. MDN — prefers-reduced-motion — https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
18. web.dev — Web Vitals — https://web.dev/articles/vitals
19. web.dev — defining CWV thresholds — https://web.dev/articles/defining-core-web-vitals-thresholds
20. web.dev — prefers-color-scheme — https://web.dev/articles/prefers-color-scheme
21. Google Search Central — page experience — https://developers.google.com/search/docs/appearance/page-experience
22. Google Search Central — localized versions (hreflang) — https://developers.google.com/search/docs/specialty/international/localized-versions
23. DebugBear — CWV as ranking factor — https://www.debugbear.com/docs/core-web-vitals-ranking-factor
24. CXL — is social proof really that important (client logo +69%) — https://cxl.com/blog/is-social-proof-really-that-important/
25. CXL — B2B case studies — https://cxl.com/blog/b2b-case-studies/
26. Clutch — B2B buyer data — https://clutch.co/resources/b2b-buyer-data
27. Figma — web design trends — https://www.figma.com/resource-library/web-design-trends/
28. W3Techs — content languages overview — https://w3techs.com/technologies/overview/content_language
29. CSS-Tricks — flash of inaccurate color theme (FART) — https://css-tricks.com/flash-of-inaccurate-color-theme-fart/
30. Search Engine Land — hreflang guide — https://searchengineland.com/guide/what-is-hreflang

*(Additional corroborating sources referenced inline: TealHQ, Colorlib, Door To Online, Elementor, dev.to, NC State DataColumn, Nucamp, testparty.ai, grafit.agency, trustsignals.com, thewdgagency, stryvemarketing, proofmap, saashero, martal.ca, orangeowl, gezar.dk, theedigital, sayenkodesign, studiomeyer, geeksforgeeks, blog.uxfol.io, recruiterswebsites, influenceflow, uxplanet, weglot, linkgraph, Statista, jobshinobi.)*
