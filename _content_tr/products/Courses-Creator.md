---
name: Courses-Creator
slug: courses-creator
tier: vasic-util-secondary
order: 22
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - TypeScript
  - React
  - Electron
  - React Native
  - PostgreSQL
  - Python
  - LLM providers (OpenAI, Anthropic, Ollama)
  - TTS (Bark, SpeechT5)
  - MCP
  - Docker Compose
  - nginx
  - Prometheus
  - Grafana
repos:
  - https://github.com/vasic-digital/Courses-Creator
diagrams:
  - Pipeline flow (markdown → LLM enrichment → TTS + music → video assembly → publish)
  - One-backend-three-clients topology (desktop/mobile/web over shared API)
  - Deployment stack (Docker Compose services)
  - Optional-AI toggle (basic vs enhanced path by provider keys)
---

**Markdown girdisi, profesyonel video kursu çıktısı — AI-geliştirilmiş, çoklu platform.**

## Özet

Courses-Creator, markdown betiklerini AI destekli geliştirmelerle profesyonel video kurslarına dönüştüren bir araç setidir: çoklu LLM içerik zenginleştirmesi (OpenAI/Anthropic/Ollama), yüksek kaliteli TTS ve fon müziği ile masaüstü, mobil ve web oynatıcıları — hepsi Docker dağıtımı ve Prometheus/Grafana izleme sistemiyle birlikte.

## Kısa açıklama

Markdown dosyalarını etkileşimli video kurslarına dönüştürür. Bir Go işleme motoru, çoklu LLM sağlayıcıları aracılığıyla içeriği zenginleştirir, anlatım (Bark/SpeechT5 TTS) ve müzik üretir, Electron masaüstü, React Native mobil ve React web oynatıcılarına tam Docker dağıtımı ve izleme sistemiyle sunar.

## Detaylı açıklama

Bir video kursu üretmek, normalde küçük bir prodüksiyon stüdyosunun tüm iş yükünü gerektirir: senaryo yazımı, anlatım kaydı, müzik temini, kurgu, kodlama ve ardından kursu izleyebilecek her platform için oynatıcı geliştirme. Courses-Creator, bu sürecin tamamını tek bir girdi —bir markdown betiği— ve tek bir komutla sıkıştırır. Merkezinde, tam bir video/ses iş akışı yürüten bir Go çekirdek işlemci bulunur: yazılı içeriği çoklu LLM sağlayıcıları (OpenAI, Anthropic ve yerel Ollama) aracılığıyla geliştirir, metinden sese dönüştürme motorlarıyla (Bark, SpeechT5) doğal anlatım sentezler, fon müziği ekler ve parçaları tamamlanmış kurs videolarına dönüştürür. Yazarın görevi fikir ve kelimeler düzeyinde kalır; sistem seslendirme, müzik ve prodüksiyonu üstlenir. Ayrıca bir kursun faydalı olması için izlenebilir olması gerekir; bu nedenle dağıtım, tasarım gereği çoklu platformdur: bir Electron masaüstü oluşturma uygulaması, bir React Native mobil oynatıcı ve bir React web oynatıcı — hepsi aynı REST API ve arka plan iş sistemi tarafından beslenir. Tek bir arka uç, üç birinci sınıf istemci, her yüzey için yeniden uygulama yok.

Önemli olan, bunun bir prodüksiyon altyapısı olması, gösteri amaçlı bir demo değil. Arka uç, PostgreSQL kalıcılığı, arka plan iş işleme (böylece uzun TTS/video renderları hiçbir zaman API’ı engellemez), araç destekli geliştirme için MCP sunucu uygulamaları, Prometheus metrikleri, JWT kimlik doğrulamasını ve bir nginx ters proxy’yi içerir — ve tüm bunlar, tek adımda ayağa kaldırabileceğiniz bir Docker Compose dağıtımı ve Grafana/Prometheus izleme profilleriyle birlikte gelir. AI, bir bağımlılık değil, bir geliştirme katmanıdır: her LLM sağlayıcısı opsiyoneldir; bu nedenle temel işlemler için sıfır API anahtarıyla çalışır ve anahtarlar sağlandığı anda premium zenginleştirme devreye girer. Bu tek karar, aynı aracı hem dizüstü bilgisayarda çevrimdışı çalışan bir hobi kullanıcısı hem de tercih ettiği sağlayıcıyı entegre eden bir işletme için kullanılabilir kılar — ve altındaki tüm medya iş akışı, inanç yerine birim, entegrasyon ve uçtan uca testlerle desteklenir.

## Neden geliştirdik

Video kurslarını manuel olarak üretmek yavaştır: yazım, anlatım, müzik ve kurgu her biri çaba ve uzman araçlar gerektirir. Courses-Creator, bu süreci markdown tabanlı bir iş akışına indirgeyerek tek bir kaynak betiğin üretilmiş bir kursa dönüşmesini sağlar; AI ise insanların elle yapacağı işleri otomatik olarak tamamlar.

İçerik

## Neden bir oyun değiştirici?

Kurs üretimini, uzmanlık gerektiren çok araçlı bir zanaatten tekrarlanabilir bir yazılım hattına dönüştürüyor: içerik oluşturma, AI zenginleştirmesi, anlatım ve müzik üretimi ile çoklu platform oynatma, tek bir dağıtılabilir yığında bir araya geliyor. API anahtarsız çalışmaya zarif geçiş, sessiz süper güç — aynı kod tabanı, bütçe odaklı bir solo yaratıcıdan premium sağlayıcı sözleşmesi olan bir işletmeye kadar herkese hizmet ediyor, arada hiçbir şey yeniden yazılmadan.

## Yenilikçi olan ne?

- Çoklu LLM zenginleştirme eklentileriyle (OpenAI/Anthropic/Ollama) Markdown’dan videoya hat.
- Yerleşik TTS (Bark, SpeechT5) ve arka plan müziği üretimi.
- Araç destekli geliştirme için işleme motoru içinde MCP sunucu uygulamaları.
- Tek bir arka uçla üç birinci sınıf istemciye (Electron masaüstü, React Native mobil, React web) hizmet.

## Zorluklar ve çözümler

- **Yoğun medya işleme:** Go hattı ve arka planda çalışan iş süreçleriyle çözüldü; böylece uzun TTS/video işleri API’yi bloke etmiyor.
- **İsteğe bağlı ama güçlü AI:** LLM sağlayıcıları isteğe bağlı ve takılabilir hale getirilerek, temel işlevlere zarif bir geri dönüş sağlandı.
- **Çoklu platform dağıtımı:** Ortak bir REST API ve üç ayrı oynatıcı uygulamasıyla çözüldü.
- **İşletilebilirlik:** Docker Compose profilleri, Prometheus/Grafana ve yerleşik JWT kimlik doğrulama ile sağlandı.

## Teknoloji yığını (neden + nasıl)

- **Go** — çekirdek işlem motoru, REST API, iş çalıştırıcı, hat (972K+ bayt, baskın dil).
- **TypeScript / React** — web oynatıcı ve ortak kullanıcı arayüzü.
- **Electron** — masaüstü içerik oluşturma uygulaması.
- **React Native** — mobil oynatıcı.
- **PostgreSQL** — kurs/iş kalıcılığı.
- **LLM sağlayıcıları (OpenAI, Anthropic, Ollama)** — içerik zenginleştirme.
- **TTS (Bark, SpeechT5)** — anlatım sentezi.
- **MCP sunucuları** — motor içinde araç entegrasyonu.
- **Docker Compose + nginx** — tam yığın dağıtım ve ters proxy.
- **Prometheus + Grafana** — izleme.

> Not: Genel README hızlı başlangıçta `your-org` klonu için URL yer tutucu kullanılır.

