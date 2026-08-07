# Issue #50 — html lang attribute fix (milosvasic.ru localized pages)
Date: 2026-08-06

## Root cause
milosvasic.ru/_layouts/default.html line 2 used {{ site.lang }} (always 'en');
milosvasic Jekyll page emitters set no page-level 'lang' front matter.

## Fix
- _layouts/default.html:2 -> <html lang="{{ page.lang | default: site.lang | default: 'en' }}" ...>
- _tools/gen/product.go: renderProductJekyll gains lang param; front matter emits 'lang: %s' via htmlLang(lang)
- _tools/gen/portfolio.go: renderPortfolioJekyll front matter emits 'lang: %s' via htmlLang(lang)
- _tools/gen/home.go: renderHomeJekyll front matter emits 'lang: %s' via htmlLang(doc.Lang)

## BEFORE (rendered _site, pre-fix)
products/ru/helixcode.html : <html lang="en"   (WRONG)
products/de/helixcode.html : <html lang="en"   (WRONG)
products/helixcode.html    : <html lang="en"   (ok)
index.html                 : <html lang="en"   (ok)
portfolio/index.html       : <html lang="en"   (ok)

## AFTER (rendered _site, post-fix)
products/ru/helixcode.html                 <html lang="ru"
products/de/helixcode.html                 <html lang="de"
products/helixcode.html                    <html lang="en"
index.html                                 <html lang="en"
portfolio/index.html                       <html lang="en"
portfolio/ru/index.html                    <html lang="ru"
portfolio/de/index.html                    <html lang="de"

## vasic.digital (unchanged, still correct)
products/ru/helixcode.html                 <html lang="ru"
products/de/helixcode.html                 <html lang="de"
products/helixcode.html                    <html lang="en"
index.html                                 <html lang="en"

## Tests
go build ./... (from _tools/gen): OK
go test -count=1 ./... (from _tools/gen): ok  vasic.digital/tools/gen
