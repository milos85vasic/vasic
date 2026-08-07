---
name: Vasic Digital Reusable Module Suite
slug: vasic-digital-reusable-module-suite
tier: vasic-util-secondary
order: 28
status: mixed (many stable, independently-tested modules; several self-marked SCAFFOLD/WIP — UNVERIFIED)
license: UNVERIFIED (varies per module)
private: false
tech:
  - Go (digital.vasic.*)
  - Kotlin Multiplatform (*-KMP)
  - Redis / PostgreSQL / SQLite
  - Prometheus / OpenTelemetry
  - WebSocket / HTTP/3 (quic-go) / mDNS
  - Vector DB / Embeddings / RAG / MCP
  - YAML (RedTeam fixtures, config)
repos:
  - https://github.com/vasic-digital
diagrams:
  - Three-cluster module map (Infrastructure / AI primitives / Guardrails) with product apps on top
  - "Standard library" grid of modules, colored by maturity (stable vs scaffold)
  - Go ↔ KMP mirror pairs
  - A product (Catalogizer or HelixAgent) exploded into the modules it consumes
---

**Bir kez inşa et, her yerde yeniden kullan — bağımsız test edilmiş, birbirinden ayrık küçük Go ve KMP modüllerinden oluşan bir filo.**

## Özet

`digital.vasic.*` (Go) ve Kotlin Multiplatform ad alanları altında yayımlanan, genel amaçlı ve yeniden kullanılabilir modüllerden oluşan geniş bir aile. Her modül bağımsız, ayrı test edilmiş ve sürümlendirilmiş olup, daha büyük ürünler (Catalogizer, HelixAgent ve daha geniş filo) tarafından eşit kod tabanlı bir alt modül olarak tüketilir. Bu sayfa, tek tek ele alındığında gürültüden ibaret olacak küçük araçları bir araya getiriyor.

## Kısa açıklama

Birbirinden ayrık `digital.vasic.*` modüllerinden oluşan özenle seçilmiş bir koleksiyon — altyapı temel bileşenleri (kimlik doğrulama, önbellek, veritabanı, yapılandırma, gözlemlenebilirlik), AI/ajan yapı taşları (RAG, Vektör Veritabanı, Gömme Vektörleri, MCP, Ajanik, Planlama) ve savunma amaçlı LLM koruma mekanizmaları (Kırmızı Takım, Normalleştirme) — artı bir Kotlin Multiplatform ayna seti. Her biri genel amaçlı, test edilmiş ve yeniden kullanılabilir nitelikte.

## Uzun açıklama

vasic-digital organizasyonu, tek bir yapısal bahse dayanıyor: "Anayasa + birçok birbirinden ayrık, yeniden kullanılabilir alt modül" felsefesi. Bu yaklaşımda, genel işlevsellik asla iki kez yazılmaz. Monolitik yapılar yerine, her yeniden kullanılabilir bileşen kendi küçük modülüne —kendi deposuna, kendi testlerine, kendi belgelerine— ayrıştırılır ve tüketicilerin özel gereksinimlerinin asla sızmaması için sıkı bir şekilde birbirinden ayrık tutulur. Bu sayfa, tek tek ele alındığında kütüphane ölçeğinde kalan ve bireysel bir ürün sayfasında gürültüden ibaret olacak modülleri gruplandırıyor. Bir araya getirildiğinde ise organizasyonun gerçek güç çarpanını oluşturuyorlar: "Yeni bir ürün inşa et" yerine "kanıtlanmış parçaları bir araya getir" yaklaşımını mümkün kılan özel bir mühendislik varlığı ve bu filonun tekerleği yeniden icat etmediği —sadece çok iyi bir tekerleği her yere taşıdığı— iddiasının somut kanıtı.

Koleksiyon üç ana kümeden oluşuyor. **Altyapı temel bileşenleri** (Go), her hizmetin ihtiyaç duyduğu temel yapı taşlarını sunuyor: `kimlik doğrulama` (JWT/bcrypt), `önbellek` (Redis/TTL), `veritabanı` (göçler, ikili SQLite/PostgreSQL), `yapılandırma`, `ara katman yazılımı`, `gözlemlenebilirlik` (Prometheus/OpenTelemetry), `akış sınırlayıcı`, `güvenlik`, `depolama` (S3/MinIO), `akış` (WebSocket merkezi), `olay veriyolu`, `dosya sistemi` (çoklu protokol), `keşif`/`mdns`, `http3`, `kurtarma`, `eşzamanlılık`, `tembel yükleme` ve daha fazlası. **AI/ajan yapı taşları** (Go), AI sistemleri için temel sağlıyor: `rag`, `vektör veritabanı`, `embeddings`, `hafıza`, `konuşma` (sınırsız bağlam sıkıştırma, olay kaynağı), `mcp` (Model Context Protocol), `araç şeması`, `beceri kaydı`, `ajanik` (graf tabanlı iş akışı orkestrasyonu), `planlama` (HiPlan/MCTS/Ağaç-Düşünce), `kıyaslama` (SWE-bench/HumanEval/MMLU), `büyük dil modeli operasyonları`, `kendi kendini geliştirme` (ödül modelleme/RLHF) ve `toon` (Token Odaklı Nesne Gösterimi). **Savunma amaçlı LLM koruma mekanizmaları**, saldırıya dayanıklı araçlar sunuyor: `Kırmızı Takım` (YAML tabanlı saldırı senaryoları), `Normalleştirme` (saldırı girişlerinin standartlaştırılması). Paralel bir **Kotlin Multiplatform** seti ise temel modülleri (Kimlik Doğrulama-KMP, Veritabanı-KMP, Güvenlik-KMP, Kullanıcı Arayüzü Bileşenleri-KMP vb.) çapraz platform uygulamalar için aynalıyor.

## Neden inşa ettik

Her seferinde sıfırdan birçok ürün (Catalogizer, HelixAgent, Herald ve diğerleri) geliştirmek hem israf hem de tutarsızlık yaratıyor. Her genel kaygıyı bağımsız, test edilmiş bir modüle dönüştürmek, düzeltmelerin ve iyileştirmelerin tüm filoya yayılmasını sağlarken, her yeni ürünün kanıtlanmış bileşenlerden oluşmasını mümkün kılıyor.

## Neden oyunun kurallarını değiştiriyor

Aslında bu, AI odaklı arka uçlar geliştirmek için özel bir "standart kütüphane" — çoğu ekibin hiç inşa etmeye fırsat bulamadığı katman, çünkü beşinci kez kimlik doğrulama, önbellekleme ve RAG altyapısı çözmekle meşguller. Burada altyapı ilkeleri, AI yapı taşları ve savunma amaçlı LLM koruma mekanizmaları, bağımsız olarak test edilmiş, hazır kullanıma uygun modüller olarak yer alıyor. Bu sayede küçük bir ekip, normalde çok daha büyük bir ekibin gerektireceği hızda, ürün kalitesinde sistemler geliştirebiliyor ve genellikle peşinden gelen tekrarlama borcuna da düşmüyor.

## Yenilikçi yönleri

- Filo genelinde ayrıştırma disiplini (CONST-051): Alt modüller eşit kod tabanları olarak ele alınıyor, tüketiciye özel detaylar taşımıyor.
- AI ilkel katmanı (RAG, VectorDB, Gömme Vektörleri, MCP, Araç Şeması, Ajan Tabanlı, Planlama, LLMOps) yeniden kullanılabilir modüller olarak.
- Savunma amaçlı LLM koruma mekanizmaları kümesi (RedTeam, Normalleştirme) saldırılara karşı dayanıklılık için.
- Aynı kuralları paylaşan paralel Go + Kotlin Multiplatform modül setleri.

## Zorluklar ve çözümler

- **Dozlarca modül arasında bağlantı çürümesini önlemek:** Anayasanın ayrıştırma sözleşmesi ve çalışma zamanında tüketiciye özel detayların enjekte edilmesiyle çözüldü.
- **Birçok modülün tutarlı ve test edilmiş kalmasını sağlamak:** Ortak bir kural seti (modül başına testler/dokümanlar/Zorluklar) ve HelixConstitution yönetişim omurgasıyla çözüldü.
- **Platformlar arası erişim:** Temel modüllerin Kotlin Multiplatform aynasıyla çözüldü.

## Teknoloji yığını (neden ve nasıl)

- **Go** — modüllerin çoğu (`digital.vasic.*`).
- **Kotlin Multiplatform** — platformlar arası ayna modüller (Kimlik Doğrulama/Veritabanı/Güvenlik/Arayüz/Eşzamanlılık/Sınırlayıcı-KMP).
- **Redis / PostgreSQL / SQLite** — önbellek, veritabanı, depolama ilkeleri.
- **Prometheus / OpenTelemetry** — gözlemlenebilirlik modülü.
- **WebSocket / HTTP/3 (quic-go) / mDNS** — ağ modülleri.
- **Vector DB / embeddings / RAG / MCP** — AI ilkel modülleri.
- **YAML** — RedTeam saldırı senaryoları ve yapılandırması.

> DOĞRULANMAMIŞ / ÇALIŞMA AŞAMASINDA: Bazı kurumsal depolar "İSKELE / ÇALIŞMA AŞAMASINDA" olarak işaretlenmiş (örn. `PliniusCommon`, `I-LLM`, `HyperTune`, `AutoTemp`, `Veritas`, `Ouroborous`, `Claritas`, `LeakHub`, `GandalfSolutions`). Bunlar erken aşama/iskele olarak sunulmalı, henüz yayınlanmamış olarak belirtilmeli.

