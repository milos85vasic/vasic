# UI status/tier/alt label translation — §11.4.140 + §11.4.141 evidence

- **Translator:** HelixTranslate engine (unified-translator) run LOCALLY via podman
  container `helixtranslate:cli` (built from /Volumes/T7/Projects/helix_translate),
  provider **zhipu**, model **glm-4.5-flash**. Driver: `_tools/gen/translate_status_labels.py`
  (contextualized per-language batch → disambiguates software-sense; glossary-protected).
- **Independent reviewer (different provider, §11.4.141):** **groq**, model
  **llama-3.3-70b-versatile**. Reviewer: `_tools/gen/review_ui_labels.py`.
  **43 corrections** applied where the translator's output was the wrong sense
  (e.g. kk shipped Жаратылды→Шығарылды; fa shipped ارسال→انتشار یافته;
  ja/ko/zh "stable"→"stable version" refinements).
- **Keys:** 9 status.* + 2 alt.* translated; 3 tier.* kept as language-neutral
  technical identifiers (verbatim EN slug). All 14 non-EN languages: 14/14 keys.
- **Scope fixed:** the non-EN status/tier/alt English-leak (both sites) + German
  pf.download / prod.tier (prod.tier "tier" → "Level"; "Tier" would read as
  "animal" in German).
