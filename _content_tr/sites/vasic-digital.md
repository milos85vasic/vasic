---
site: vasic.digital
type: company-site
title: Vasic Digital — AI-Native Software Engineering
tagline: We build AI development systems — and the governance that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Vasic Digital

## Kahraman

**AI tabanlı yazılım mühendisliği, güvenilmek için inşa edildi.**

Herhangi biri bir uygulamayı bir LLM’a bir öğleden sonra bağlayabilir. Asıl zor olan —bir AI sisteminin demo mu yoksa güvenilir bir ürün mü olduğuna karar veren— kısım, modelin etrafındaki her şeydir: bir kesintiyi atlatabilen sağlayıcı soyutlaması, ajanları görevde tutan orkestrasyon, modelin blöfünü yakalayan doğrulama ve tüm sistemin düzgün çalıştığını kanıtlayan yönetişim. İşte bu zor kısım, Vasic Digital’un inşa ettiği şeydir. Büyük dil modellerini güvenilir yazılımlara dönüştüren modelleri, ajanları, orkestrasyonu ve altyapıyı —ve onları dürüst tutan yönetişim katmanını— tasarlayıp sunuyoruz. Tüm bunların temelinde tek bir tavizsiz kural yatar: bir özellik, testleri geçtiğinde "tamamlanmış" sayılmaz; gerçek bir kullanıcı onu kullanabildiğinde ve bunun kanıtı kaydedildiğinde tamamlanır.

## Hakkımızda

Vasic Digital, birbiriyle bağlantılı bir AI geliştirme ürünleri ve yeniden kullanılabilir modüller ailesi inşa eden odaklanmış bir mühendislik pratiğidir. Tek bir monolit yerine, işler bir filo şeklinde organize edilir: düzinelerce küçük, bağımsız olarak test edilmiş, birbirinden ayrık modülün üzerine inşa edilen büyük ürün uygulamaları —böylece kanıtlanmış parçalar her üründe yeniden inşa edilmek yerine tekrar kullanılır. Omurga dil **Go** olup, işe göre **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** ve **Shell** ile desteklenir: Go yüksek verimli hizmetler ve kütüphaneler için, Kotlin tedarik araçları ve çapraz platform mobil için, TypeScript tip güvenli ön yüzler için, Python ise AI/ML entegrasyonu için kullanılır.

Filoyu bir arada tutan şey, disiplinin bir hedef olmaktan çıkıp mekanik bir hale gelmesidir. Her proje, paylaşılan bir mühendislik **Constitution**’ini Git alt modülü olarak devralır —böylece bir kural bir kez sıkılaştırıldığında 140’tan fazla depoya yayılır— ve bir ürünün sunduğu her yetenek, otomatik, kanıt üreten bir testle desteklenmeden "yayınlanmış" sayılmaz. Bu, işin üzerine eklenen bir pazarlama dili değil, işin üzerinde çalıştığı işletim modelidir. Gerçek avantaj, birikimli etkisidir: çünkü genel endişeler birbirinden ayrık, bağımsız olarak test edilmiş modüllerde yaşar, bir düzeltme veya iyileştirme tek bir yerde yapılır ve tüm ürünleri bir anda yükseltir; her yeni sistem, güvenini zaten kazanmış parçalardan bir araya getirilir.

## Ne Yaparız

**AI tabanlı geliştirme.** AI sistemleri için baştan sona altyapı inşa ediyoruz:

- **Çoklu sağlayıcı LLM erişimi** — 40’tan fazla sağlayıcıya (Anthropic/Claude, OpenAI, DeepSeek, Gemini, Mistral, Cohere, Groq, xAI/Grok, Qwen, Perplexity, OpenRouter, Together AI, Replicate, Cerebras, Cloudflare Workers AI, SiliconFlow ve yerel Ollama yedek olarak) tek bir arayüz üzerinden yeniden denemeler, devre kesiciler ve sağlık kontrolleriyle erişim sağlayan birinci sınıf bir soyutlama.
- **Ajan orkestrasyonu** — başsız CLI kodlama ajan kontrol düzlemleri, grafik tabanlı ajansal iş akışları, çok turlu "AI tartışması" uzlaşısı ve DAG/pipeline çalışma zamanları.
- **LLM doğrulaması** — zorunlu anlama kapısı ("Kodumu görüyor musun?") ile modelleri puanlayan, gecikme, akış, fonksiyon çağırma, görüntü ve embeddings testlerini içeren bir güven katmanı; yalnızca doğrulanmış bir yapılandırma dışa aktarılır.
- **Bilgi erişimi ve hafıza** — RAG, vector veritabanları, embeddings ve sonsuz bağlam sıkıştırma özelliğine sahip birleşik ajan-hafıza motorları (Mem0 + Cognee + Letta).
- **Korumalı LLM** — güvenlik bariyerleri, PII tespiti, düşmanca kırmızı takım senaryoları ve girdi normalleştirme.

**Helix Ürün Ailesi.** Amiral gemimiz, AI geliştirme yaşam döngüsünün tamamını kapsar:

- **HelixTrack** — Helix-Track hattının amiral gemisi JIRA’a ücretsiz bir alternatif.
- **HelixAgent** — Birden fazla modelin tartışarak üzerinde uzlaştığı yanıtı sunan bir LLM topluluk hizmeti.
- **HelixCode** — İş yükünü SSH tarafından yönetilen çalışanlara dağıtan, kontrol noktaları ve geri alma özelliğine sahip dağıtık bir AI geliştirme platformu.
- **HelixLLM** — Tek bir ikili, altı mod: Dizüstü bilgisayardan kümeye kadar OpenAI ve Anthropic uyumlu çıkarım, HTTP/3 üzerinden.
- **HelixCluster** — Veri merkezi GPU’larından taşınabilir uç cihazlara kadar AI hesaplamaları için dağıtık bir işletim sistemi.
- **LLMProvider / LLMOrchestrator / LLMsVerifier** — Sağlayıcı soyutlaması, ajan kontrol düzlemi ve doğrulama kaynağı gerçekliği.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — Bellek yönetimi, denetimli beceriler, şema odaklı geliştirme, uygulama oluşturma, doğrulanmış çeviri, sıfır güven terminali, federatif Git, güvenli OTA güncellemeleri ve kendi sunucunuzda bulut oyunculuğu.

**Araçlar ve Yardımcı Programlar (vasic-digital utils).** Kendi başına ayakta durabilen ürün kalitesinde araçlar: **Catalogizer** (çok protokollü, şifreli medya koleksiyonu yönetimi), **Courses-Creator** (markdown’dan videoya AI kurs üretimi), **VisionEngine** (bilgisayarla görü + LLM tabanlı kullanıcı arayüzü algısı), **DocProcessor** (dokümantasyondan kalite güvencesi için özellik haritası çıkarma), **Docs Chain** (içerik tabanlı çift yönlü belge/veritabanı senkronizasyonu), **Herald** (doğal dilde çok kanallı bildirimler), **task_bridge** (çift yönlü görev/panolar arası senkronizasyon) ve **Vasic Digital Yeniden Kullanılabilir Modül Paketi** — `digital.vasic.*` altyapı, AI temel bileşenleri ve güvenlik kılavuz modüllerinin "standart kütüphanesi".

**Altyapı Otomasyonu (Server Factory).** DevOps köklerimiz: **Mail Server Factory** ve **Server Factory Çekirdek Çerçevesi**, bildirimsel JSON’u farklı bağlantı türleri ve Linux dağıtımları üzerinde tam olarak sağlanmış, Dockerize sunuculara dönüştüren araçlar. Ayrıca sanal makine görüntü araçları (Qemu-Utils, Parallels-Utils) ve destekleyici hizmet fabrikaları.

## Teknolojiler

Gerçek yığına dayalı temel unsurlar:

- **Diller:** Go (baskın), Kotlin & Kotlin Multiplatform, TypeScript, Python, Swift, Shell; dağıtık sistemler çalışmalarında PL/pgSQL ve hatta TLA+ biçimsel şartnameleri.
- **AI / LLM:** Çoklu sağlayıcı erişimi (43+ adaptör), Model Context Protocol (MCP), RAG, vector veritabanları ve embeddings, planlama algoritmaları (HiPlan, MCTS, Tree of Thoughts), LLMOps, kıyaslama (SWE-bench/HumanEval/MMLU) ve TTS (Bark, SpeechT5).
- **Arka Uç:** Gin (Go), gRPC + Protocol Buffers, HTTP/3 (QUIC), WebSockets, Angular ve React ön uçları, Kafka/RabbitMQ mesajlaşma.
- **Veri:** PostgreSQL, SQLite, SQLCipher (depolanırken şifreli), Redis, Neo4j, ClickHouse ve nesne depolama (MinIO/S3/GCS/Azure).
- **Altyapı / DevOps:** Docker & Compose, Kubernetes + Helm, Prometheus + Grafana, OpenTelemetry, QEMU/Libvirt/Parallels ve CI/CD (GitHub Actions, Gradle ve Make üzerinden).
- **Test / Kalite Güvencesi:** Sahtekarlığa karşı HelixQA çerçevesi, mutasyon kapılarıyla modül başına Challenge testleri, `go test -race`, görsel regresyon araçları, ADB cihaz testleri, SonarQube kapıları ve güvenlik taramaları (semgrep, gosec, trivy, snyk, gitleaks, nancy).

## Kalite ve yönetişim — fark yaratan unsurlarımız

Tüm filoyu tutarlı ve güvenilir kılan iki temel unsur var:

- **HelixConstitution** — evrensel, projeye özgü olmayan bir mühendislik kural kitabı. Git alt modülü olarak sunulan ve 140’tan fazla depodan oluşan filodaki her projeye miras bırakılan bu sistem, pazarlık kabul etmez bir disiplin kodlar: blöf karşıtı kanıt kapıları, yanlış pozitiflere karşı bağışıklık, veri ve sunucu güvenliği, dokümantasyon ve kapsam kuralları. Bir proje bu kuralları genişletebilir, ama asla zayıflatamaz. Tek bir alt modül güncellemesiyle kurallar her yerde yenilenir; yayılım kapıları, gerekli maddeleri filodaki tüm depolarda kelimesi kelimesine tarar ve her kapı, kendi geçerliliğini kanıtlayan bir mutasyon testi ile desteklenir. Yönetişim, bir hedef olmaktan çıkıp denetlenebilir bir gerçekliğe dönüşür.
- **HelixQA** — blöf karşıtı kalite güvence orkestrasyonu. Yazılı YAML test bankalarını ve tamamen otonom, LLM artı bilgisayarlı görü çalışmalarını Android, Android TV, Web ve Masaüstü platformlarında koşturur. Çalışma zamanı kanıtı (ekran görüntüleri, logcat, video, yığın izleri) olmadan bir BAŞARILI sonucu vermez. "Test ettik" demek yerine, "işte video, logcat ve talep kaydı" der.

## Konumlandırma beyanı

Herhangi biri bir uygulamayı LLM’a bağlayabilir. Vasic Digital ise zor olan kısmı inşa eder: Doğrulanabilir, yeniden kullanılabilir ve dürüst AI sistemleri — sağlayıcıdan bağımsız bir AI altyapısı, bunun üzerine inşa edilen bir Helix ürünleri yaşam döngüsü ve gönderilen her şeyin gerçekten çalıştığını garanti eden, anayasa artı kanıt disiplini. Yeşil onay işaretine güvenmenizi istemiyoruz. Onun arkasındaki kanıtı size gösteriyoruz.

## İletişim

Doğrulanabilir bir şeyler inşa edelim.

- **E-posta:** [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [github.com/vasic-digital](https://github.com/vasic-digital)

