---
doc: cv
title: Curriculum Vitae — Miloš Vasić
role: AI Engineer / Software Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
  company: https://vasic.digital
  github_orgs:
    - https://github.com/vasic-digital
    - https://github.com/HelixDevelopment
    - https://github.com/Server-Factory
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: Skills and projects are evidence-based (repository READMEs + analysis). Experience and Education are sourced verbatim from the candidate's own verified record at milosvasic.ru/README.md — real employers, roles, and dates; nothing fabricated (Constitution §11.4.6).
---

# Miloš Vasić

**AI Mühendisi — LLM altyapısı, otonom ajanlar ve bunları güvenilir kılan yönetişim.**

- E-posta: milos85vasic@gmail.com
- Web: https://milosvasic.ru · https://vasic.digital
- GitHub: vasic-digital · HelixDevelopment · Server-Factory

---

## Özet

Uçtan uca AI geliştirme sistemleri inşa eden bir AI/yazılım mühendisi — çoklu sağlayıcı LLM altyapısından otonom ajanlara ve bunları güvenilir kılan QA ve yönetişim katmanlarına kadar. Demo sunmuyorum; platform teslim ediyorum. 15 yılı aşkın profesyonel mühendislik deneyimim (2009’dan bu yana) mobil SDK’lar, gerçek zamanlı donanım entegrasyonları ve dağıtık arka uç sistemleri üzerineydi; şimdi tüm bu birikim tek bir odak noktasında buluşuyor: otonom AI geliştirmeyi ölçekte güvenilir kılmak.

Monolitler değil, filolar tasarlıyorum — düzinelerce küçük, birbirinden bağımsız, ayrı ayrı test edilmiş modül üzerine kurulu büyük ürün uygulamaları. Her bir modül, ortak bir mühendislik Constitution’ini devralır ve sahtekârlığa karşı korumalı, kanıta dayalı bir QA disipliniyle doğrulanır. Ana dilim Go; Kotlin/KMP, TypeScript/React, Python, Swift ve Shell dillerini de kullanıyorum. Mekanik olarak uygulanan temel ilkem şu: bir özellik, ancak gerçek bir kullanıcı tarafından kullanılabildiğinde ve bunun kanıtı yakalandığında tamamlanmış sayılır.

**Masaya getirdiğim şey:** bir AI yeteneğini araştırma fikrinden, yönetişimli, kendi kendini doğrulayan, üretime hazır bir sisteme dönüştürme becerisi — her modelin güvenilir olmadan önce gerçekten çalıştığını kanıtlayan LLM yönlendirmesi, tahmin yürütmek yerine tartışan ve uzlaşmaya varan ajanlar, bağlamı kaybetmeyen bellek ve RAG katmanları, ve "testler yeşil"in asla sessizce "özellik bozuk" anlamına gelmediği, baştan sona entegre bir ekosistem.

## Temel Yetkinlikler

- **AI / LLM sistemleri:** çoklu sağlayıcı LLM soyutlaması (40+ sağlayıcı), MCP araç entegrasyonu, RAG, vector veritabanları ve embeddings, ajan orkestrasyonu (başsız CLI ajanları, grafik tabanlı iş akışları, çok turlu tartışma/uzlaşma), planlama (HiPlan/MCTS/Ağaç-Yapılı-Düşünme), LLMOps, kıyaslama (SWE-bench/HumanEval/MMLU), LLM doğrulama, savunma amaçlı LLM korumaları, bilgisayarla görü + LLM görüsü.
- **Arka uç mühendisliği:** Go (Gin), gRPC + Protobuf, HTTP/3 (QUIC), WebSockets, dağıtık sistemler (TLA+ biçimsel şartnameleri dahil), yüksek verimli REST hizmetleri ve eşzamanlı çalışanlar.
- **Veri:** PostgreSQL, SQLite, SQLCipher (depolama sırasında şifreleme), Redis, Neo4j, ClickHouse, nesne depolama (MinIO/S3/GCS/Azure).
- **Ön yüz / çoklu platform:** TypeScript/React (Tailwind, Redux Toolkit, i18next), Angular, Electron, React Native, Kotlin Multiplatform, Android/Android TV (Kotlin), iOS (Swift), Tauri/Rust.
- **Altyapı / DevOps:** Docker ve Compose, Kubernetes + Helm, Prometheus + Grafana, OpenTelemetry, QEMU/Libvirt/Parallels; CI/CD (GitHub Actions aracılığıyla), Gradle, Make.
- **QA / kalite mühendisliği:** sahtekârlığa karşı korumalı, kanıta dayalı QA (HelixQA), mutasyon kapılı zorluk testleri, `go test -race`, görsel regresyon testleri, ADB cihaz testleri, SonarQube, güvenlik taramaları (semgrep/gosec/trivy/snyk/gitleaks/nancy).
- **Mühendislik yönetişimi:** Constitution alt modül olarak; kalıtım ve yayılım kapıları; 140’tan fazla depodan oluşan bir filoda belge ve kapsama disiplini.

İçerik

## Seçilmiş Projeler

### Yönetişim ve Kalite Güvencesi
- **HelixConstitution** — Git alt modülü olarak dağıtılan ve 140’tan fazla depoda miras alınan evrensel bir mühendislik kural kitabı: mühendislik yasaları, kod gibi gönderilir ve sürüm sabitlenir. Tek bir alt modül güncellemesi, tüm filodaki kuralları yükseltir ve yayılım kontrolleri, tüketen her depoyu gerekli madde için kelimenin tam anlamıyla tarar — her kontrol, kapının kendisinin sahte olmadığını kanıtlayan bir mutasyon meta testi ile eşleştirilir. "İnsanların uymayı umduğu en iyi uygulamalar"ı, miras alınan, denetlenebilir ve mekanik olarak uygulanan bir anti-blöf yasasına dönüştürür.
- **HelixQA** — anti-blöf kalite güvencesi orkestrasyonu (Go), tek bir tavizsiz kural üzerine inşa edilmiştir: ölçüt, "testler geçer" değil, "kullanıcılar özelliği kullanabilir"dir. Yazılı YAML test bankalarını *ve* tamamen otonom LLM ve görsel kalite güvencesi oturumlarını çalıştırır; gerçek uygulamayı açar, belgelenmiş her özelliği doğrular, Android/Android TV/Web/Masaüstü genelinde belgelenmemiş hataları arar ve çalışma zamanı kanıtı — ekran görüntüleri, logcat, video, yığın izleri — ve AI düzeltmeye hazır biletler olmadan BAŞARILI notu vermez.

### AI Geliştirme ve LLM Altyapısı
- **HelixAgent** — tek bir modele güvenmeyi reddeden üretim düzeyinde LLM topluluk hizmeti (Go/Gin): bir istemi birçok sağlayıcıya dağıtır, yapılandırılmış çok turlu tartışma (Öneri → Eleştiri → İnceleme → Sentez) yürütür ve canlı doğrulama puanlarına göre yönlendirme yapar; yüksek erişilebilirlik veri katmanı, gözlemlenebilirlik ve koruma mekanizmalarıyla OpenAI uyumlu bir API arkasında çalışır. *Go, Gin, PostgreSQL, Redis, Prometheus/Grafana/OpenTelemetry, MCP, Neo4j/ClickHouse/Kafka.*
- **HelixCode** — SSH tarafından yönetilen bir işçi filosu üzerinde akıllı, bağımlılık farkında görevlere bölünen dağıtık AI geliştirme platformu; kesintiye uğrayan bir görevde hiçbir şey kaybolmasın diye kontrol noktaları oluşturur ve geri alır; donanım farkında model seçimi ve REST/CLI/TUI/MCP arkasında tam plan/oluştur/test/yeniden yapılandırma yaşam döngüsü. *Go, Gin, PostgreSQL, Redis, SSH, MCP, llama.cpp/Ollama.*
- **HelixLLM** — tek bir ikili, altı dağıtım modu: OpenAI ve Anthropic uyumlu HTTP/3 çıkarımı, dizüstü bilgisayardan çok sunuculu kümeye kadar ölçeklenir; yerel llama.cpp çıkarımı (CUDA/Metal/ROCm) ve otomatik keşif yapan, doğrulama puanlı bulut yedekleme zinciriyle her zaman yerel bir modele düşer. *Go, HTTP/3 QUIC, gRPC/SSE/Kafka, llama.cpp.*
- **LLMProvider / LLMOrchestrator / LLMsVerifier** — LLM altyapısının omurgası: 43 sağlayıcı üzerinde tek arayüz, devre kesiciler, sağlık izleme, gecikmeli yeniden denemeler ve dürüst (sabit yedekleme içermeyen) model keşfi; hibrit boru+dosya protokolü üzerinden başsız CLI ajanlarını (OpenCode, Claude Code, Gemini, Junie, Qwen Code) başlatan ve yöneten iş parçacığı güvenli kontrol düzlemi; ve zorunlu "Kodumu görüyor musun?" kapısıyla yalnızca gerçekten çalıştığı kanıtlanan modellerin kullanılabilir veya dışa aktarılabilir olarak işaretlendiği bir doğrulama gerçek kaynağı.
- **HelixMemory / HelixSpecifier** — dört en iyi sınıf arka uç (Mem0, Cognee, Letta, Graphiti) tek bir arayüz altında birleştiren birleşik bilişsel bellek motoru; paralel arama ve çapraz kaynak yeniden sıralama ile; ve işin boyutuna göre kendi törenini ölçekleyen, spesifikasyonları çok ajanlı tartışmayla destekleyen bir spesifikasyon odaklı geliştirme füzyon motoru.
- **HelixTrack** — özgür dünya için JIRA + Confluence alternatifi (Helix-Track serisinin amiral gemisi): Go mikro hizmetleri, HTTP/3 üzerinde birleşik eylem yönlendirmeli API, beklemedeki veriler için SQLCipher şifrelemesi ve yerel Web/Masaüstü/Android/iOS istemcileri.

İçerik

### Ürün düzeyinde araçlar (vasic-dijital araçları)
- **Catalogizer** — çok protokollü, şifreli, kendi sunucunuzda barındırılabilir medya koleksiyonu yönetimi (Go/Gin + React), güvenilmez ağ depolamasına karşı dayanıklı, 21 yeniden kullanılabilir alt modül üzerine inşa edilmiştir.
- **Courses-Creator** — AI kurs hattı için Markdown’dan videoya dönüştürme aracı, TTS ve masaüstü/mobil/web oynatıcıları ile birlikte.
- **VisionEngine** — bilgisayarlı görü + çok sağlayıcılı LLM görsel algılama arayüzü, navigasyon grafikleri ile.
- **DocProcessor** · **Docs Chain** · **Herald** · **task_bridge** · **Vasic Digital Yeniden Kullanılabilir Modül Paketi** — kalite güvencesi özellik haritalama, içerik tabanlı belge/veritabanı senkronizasyonu, doğal dil bildirimleri, görev/panolar arası senkronizasyon ve `digital.vasic.*` standart kütüphane filosu.

### Altyapı otomasyonu (Server Factory)
- **Mail Server Factory** — bildirimsel JSON → 12 bağlantı türü ve 25 Linux dağıtımı üzerinde tam olarak sağlanmış, Docker tabanlı posta sunucuları; 439 geçerli testi ve temiz bir SonarQube geçiş kapısını raporlar.
- **Server Factory Çekirdek Çerçevesi**, **Qemu-Utils**, **Parallels-Utils** — ortak sağlama motoru ve sanal makine görüntüleme araçları.

## Diller ve araçlar (hızlı liste)

Go · Kotlin · Kotlin Multiplatform · TypeScript · JavaScript · Python · Swift · Java · Rust · Shell · PL/pgSQL · TLA+ · Gin · gRPC · HTTP/3 · React · Angular · Electron · React Native · PostgreSQL · SQLite · SQLCipher · Redis · Neo4j · ClickHouse · Docker · Kubernetes · Prometheus · Grafana · OpenTelemetry · QEMU · GitHub Actions · Gradle · Make

## Deneyim

*2009 yılından bu yana yazılım mühendisi olarak, yazılım geliştirme yaşam döngüsünün tamamında — planlama, geliştirme, ekip liderliği ve dağıtım — çalıştım. Aşağıdaki tam geçmiş, adayın doğrulanmış kaydından (milosvasic.ru) alınmıştır.*

### Tam zamanlı pozisyonlar

- **SDK Geliştiricisi — Harness** (harness.io), Belgrad, Sırbistan · 03/2020 – 12/2024. Şirketin Özellik Bayrağı bölümüne yönelik SDK ailesinde baş geliştirici olarak görev yaptım; tüm büyük mobil platformlar ve ötesine odaklandım. Müşteriler ve ortaklar arasında AWS, Google ve çeşitli bankalar yer aldı. *Teknolojiler: Android, iOS, Flutter, React Native, TypeScript, JavaScript, Java, Kotlin, Swift, Go, Ruby.*
- **Yazılım Mühendisi — Leica Geosystems** (leica-geosystems.com), Heerbrugg, İsviçre · 02/2016 – 02/2020. Öncelikli olarak Leica Geosystems’un çığır açan 3D tarayıcıları için iOS ve Android mühendisliği — donanımla gerçek zamanlı iletişim, veri işleme ve senkronizasyon. Ortak: Autodesk. *Teknolojiler: Android, iOS, Java, Kotlin, Swift, C++.*
- **SDK Geliştiricisi — Bosch** (bosch.rs), Belgrad, Sırbistan · 01/2010 – 01/2016. Bağlantılı Araçlar SDK projesi için baş SDK geliştiricisi — OBD2 veri yoluyla gerçek zamanlı Bluetooth iletişimi, yüksek performanslı veri işleme ve kalıcılık. *Teknolojiler: Android, Java, Kotlin.*

İçerik

### Diğer Çalışmalar

- **TN-TECH** (tn-tech.co.rs), Novi Sad, Sırbistan · yarı zamanlı, 03/2017’den itibaren. Globex Data (Kanada ve İsviçre) için çalışmalar — Sekur (SekurMessenger), SekurMail, SekurSuite — ve BusRide platformu. *Teknolojiler: Android, Java, Kotlin, C++, Qt.*
- **Increment Loop** (incrementloop.com), Belgrad, Sırbistan · yarı zamanlı, 09/2023’ten itibaren. Yuno uygulaması. *Teknolojiler: Android, Kotlin.*
- **Açık kaynak / kendi kuruluşları** — HelixTrack, Server Factory (Mail Server Factory, Parallels-Utils, Qemu-Utils) ve Vasic Digital (Android-Toolkit, Network-Binder), yukarıda Seçilmiş Projeler başlığı altında detaylandırılmıştır.

## Yayınlar

- **Temel Kotlin** — kendi yayını; en son gözden geçirilmiş baskı Eylül 2022 (Temel Kotlin, 3. Baskı). Ayrıca Packt Yayıncılık (Birleşik Krallık) için yazarlık yapmıştır.

## Eğitim

- **Yüksek Lisans, Çağdaş Bilişim Teknolojileri** — Singidunum Üniversitesi, Belgrad, Sırbistan · 2014.
- **Lisans, Bilişim ve Bilgisayar Bilimleri** — Singidunum Üniversitesi, Belgrad, Sırbistan · 2008.

