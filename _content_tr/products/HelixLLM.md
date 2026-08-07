---
name: HelixLLM
slug: helixllm
tier: helix-primary
order: 4
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - HTTP/3 QUIC
  - TLS 1.3
  - llama.cpp
  - LLMsVerifier
  - gRPC
  - SSE
  - Kafka
  - Prometheus
  - OpenTelemetry
repos:
  - https://github.com/HelixDevelopment/HelixLLM
diagrams:
  - Mode-system diagram — one binary deploying as full on a laptop vs. gateway/brain/knowledge/agents/control split across cluster hosts.
  - Fallback-chain flow — request → ranked cloud providers (429/5xx skip arrows) → guaranteed llama.cpp local fallback, annotated with LLMsVerifier scoring.
  - Compatibility layer — OpenAI and Anthropic client SDKs both hitting the same HTTP/3 gateway.
  - RAG + ReAct agent loop — document ingestion → vector search → agent tool-calling with conversation sessions.
---

# HelixLLM

**Tek bir ikili, altı mod — Dizüstü bilgisayarınızdan çoklu sunucu kümesine OpenAI- ve Anthropic-uyumlu çıkarım.**

## Özet

HelixLLM, Go tabanlı, kurumsal düzeyde dağıtık bir LLM sistemidir: Tek bir ikili dosya ile mod sistemi, tek bir geliştirme makinesinden çoklu sunucu üretim ortamına kadar ölçeklenebilir. HTTP/3 üzerinden tamamen OpenAI- ve Anthropic-uyumlu API'ler sunar; yerel llama.cpp çıkarımı, puanlanmış çoklu sağlayıcı yedekleme zinciri, bir RAG işlem hattı ve ReAct ajan sistemi içerir.

## Kısa Açıklama

HelixLLM, tek bir ikili dosyadan oluşan, Go tabanlı dağıtık bir LLM sistemidir. HTTP/3 üzerinden OpenAI- ve Anthropic-uyumlu API'ler sunar, yerel llama.cpp çıkarımı gerçekleştirir, ücretsiz bulut sağlayıcılarını otomatik olarak keşfedip bir yedekleme zincirine puanlar ve bir RAG bilgi işlem hattı ile araç çağırma özelliğine sahip ReAct ajan ekler — altı farklı modda dağıtılabilir.

## Ayrıntılı Açıklama

HelixLLM, Go ve Gin ile geliştirilmiş, kurumsal düzeyde dağıtık bir LLM sistemidir. Temel özelliği, tek bir yapının her ölçekte kullanılabilmesidir. Tek bir ikili dosyaya derlenir ve dağıtım sırasında mod sistemi, bu ikilinin ne olacağını belirler: Dizüstü bilgisayarda `full` modunda tümleşik bir örnek olarak çalıştırılabilir ya da `gateway`, `brain`, `knowledge`, `agents` ve `control` modlarına ayrılarak birden fazla sunucuya yayılabilir — aynı kod, yeniden yazılmadan, geliştiricinin makinesinden üretim kümesine kadar yeniden düzenlenir.

İki farklı lehçeyi akıcı bir şekilde konuşur: Tamamen OpenAI- ve Anthropic-uyumlu API'ler sunar; böylece her iki ekosistemden mevcut SDK istemcileri değişiklik yapmadan çalışır. Tüm bunlar HTTP/3 (QUIC) üzerinden, otomatik HTTP/2 yedekleme ve TLS 1.3 ile sunulur. Yerel çıkarım, CUDA, Metal ve ROCm desteğine sahip llama.cpp aracılığıyla gerçekleşir; böylece aynı yapı Nvidia, Apple ve AMD donanımlarında hızlandırma sağlar. Dikkat çeken özellik, çoklu sağlayıcı yedekleme zinciridir; bu özellik, ücretsiz bulut çıkarımının bilinen güvenilmezliğini yönetilebilir, kendi kendini onaran bir kaynak haline getirir: HelixLLM, 7'den fazla bulut sağlayıcısından (Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together) ücretsiz modelleri otomatik olarak keşfeder, bunları LLMsVerifier ile 5 dakikada bir puanlar ve sıralı zincir üzerinden yönlendirir; 429/5xx hatalarında otomatik yedekleme yapar — yerel llama.cpp her zaman garanti edilen son çare olarak devreye girer, böylece bir istek hiçbir zaman uygun bir sağlayıcı bulunamadığından dolayı başarısız olmaz.

Saf çıkarımın ötesinde HelixLLM, tam bir uygulama platformudur: Aynı ikili dosya içinde bir RAG bilgi işlem hattı (içeri alma, parçalama, gömme, vector arama) ve araç çağırma, konuşma oturumları ve RAG entegrasyonu içeren bir ReAct ajan sistemi sunar. Mod sistemi, ağ katmanında da avantaj sağlar — `full` modunda tüm katmanlar, sıfır ağ ek yüküyle doğrudan süreç içi Go çağrılarıyla iletişim kurarken, aynı ikili dosya farklı sunuculara dağıtıldığında gRPC, SSE ve Kafka üzerinden koordinasyon sağlar. Brotli/gzip içerik anlaşması, OpenAI ve Anthropic formatlarıyla birebir uyumlu SSE akışı, API anahtarı ve JWT kimlik doğrulaması ile hız sınırlaması, Prometheus metrikleri, OpenTelemetry izleme ve geniş bir üretim altyapısı Go alt modülleri setiyle tamamlanır.

İçerik

## Neden inşa ettik

Ekiplerin taşınabilir, standartlara uyumlu ve dayanıklı bir çıkarım aracına ihtiyacı var — istemcileri yeniden yazmadan, tek bir sağlayıcıya ya da makineye bağımlı kalmadan. HelixLLM, aynı ikili dosyanın yerel geliştirme için çalışabilmesini ve çok sunuculu bir üretim kümesine ölçeklenebilmesini sağlayacak şekilde tasarlandı; zaten kullandıkları OpenAI ve Anthropic lehçelerini konuşarak.

## Neden oyunun kurallarını değiştiriyor

Tüm çıkarım yığınını — ağ geçidi, yerel çıkarım, bulut yedekleme, RAG ve ajanlar — tek bir ikili dosyada, bir mod anahtarıyla kontrol edilen bir yapıya indiriyor. Böylece dağıtacağınız mimari, yeniden platforma geçiş projesi değil, çalışma zamanında alınacak bir karar haline geliyor. Daha önce bir sorun olarak görülen şeyi bir özellik haline getiriyor: Bulut sağlayıcılarının güvenilirliği, sürekli ölçülen birinci sınıf bir endişe olarak ele alınıyor. Puanlanan, kendi kendini onaran bir yedekleme zinciriyle her birkaç dakikada bir sağlayıcılar yeniden sıralanıyor ve her zaman yerel çıkarıma düşerek çalışmaya devam ediyor. Bu yetenek, tek bir uç noktaya güvenmenizi sağlıyor — standartlara uyumlu, dizüstü bilgisayardan kümeye taşınabilir ve tek bir yukarı akış sağlayıcısının hız sınırlamasına takılması ya da çökmesiyle karanlığa gömülme riski taşımıyor.

## Yenilikçi olan ne

- **Altı modlu tek bir ikili dosya:** Tümü bir arada ya da dağıtılmış roller olarak çalışır — `full` modunda doğrudan süreç içi Go çağrıları, bölündüğünde ise gRPC/SSE/Kafka kullanır. Böylece dağıtım topolojisi, kod değişikliği ya da istemediğiniz bir ağ yükü olmadan değişir.
- **Puanlanan, otomatik keşifli çoklu sağlayıcı yedekleme zinciri:** 7’den fazla ücretsiz sağlayıcı arasında LLMsVerifier ile sürekli sıralanır, otomatik 429/5xx hatası yönlendirmesi yapar ve son çare olarak garantili llama.cpp’ye düşer — ücretsiz katman kapasitesi, güvenilir kapasiteye dönüşür.
- **Hem OpenAI hem de Anthropic uyumlu arayüzler:** HTTP/3 üzerinden sunulur, otomatik HTTP/2 yedeklemesiyle çalışır. Böylece her iki ekosistemden istemciler, değişiklik yapmadan bağlanabilir.
- **Tek kod tabanından yerel çıkarım:** CUDA, Metal ve ROCm’yi destekler — aynı derleme, Nvidia, Apple ve AMD donanımlarında hızlandırılmış olarak çalışır.

## En büyük teknik zorluklar ve çözümlerimiz

- **Tek bir sunucudan çoklu sunucuya ölçeklenme, yeniden yazım gerektirmeden.** Çoğu sistem, "yerel geliştirme" ile "dağıtılmış üretim" arasında keskin bir sınır çizer ve bu sınırı aşmak mimariyi yeniden tasarlamak anlamına gelir. Biz bu sınırı tek bir ikili dosya üzerindeki mod sistemiyle ortadan kaldırdık: Aynı katmanlar, `full` modunda doğrudan süreç içi çağrılarla konuşurken, dağıtılmış modlarda şeffaf bir şekilde gRPC/SSE/Kafka’a geçer. Böylece ölçeklendirme, bir port değil, yapılandırma değişikliği haline gelir.
- **Güvenilmez, hız sınırlamalı ücretsiz bulut sağlayıcıları.** Ücretsiz katman çıkarımı hızlıdır, ta ki 429 hatası alana ya da isteğin ortasında kaybolana kadar. Biz bunu, mevcut modelleri otomatik olarak keşfederek, LLMsVerifier ile puanlayarak, hız sınırlama başlıklarını proaktif olarak izleyerek ve sağlayıcılar hız sınırına yaklaşmadan önce yönlendirme yaparak güvenilir hale getirdik. Otomatik olarak sıralı zincirde yerel llama.cpp’ye düşer — böylece havuzun kararsızlığı çağrıyı yapanı etkilemez.
- **İki ekosistem arasında istemci uyumluluğu.** Yeni bir çıkarım arka ucuna geçmek için istemcileri yeniden yazmak söz konusu bile olamaz. Biz hem OpenAI hem de Anthropic API şekillerini — hatta farklı SSE akış biçimlerine kadar — uyguladık. Böylece her iki ekosistemden SDK’lar HelixLLM’a yönlendirildiğinde sorunsuz çalışır.

İçerik

## Teknoloji Yığını

- **Go + Gin** — Tüm mod sistemi için tek bir ikili dosya ve eşzamanlılık odaklı çalışma zamanı seçildi: Dizüstü bilgisayar sunucusu veya küme rolü olabilen tek bir derleme. Sistemin tamamını ve ağ geçidinin HTTP katmanını barındırır.
- **HTTP/3 (QUIC) + TLS 1.3, HTTP/2 geri dönüşü ile** — Modern, düşük gecikmeli ve bağlantı dayanıklılığına sahip taşıma katmanı olarak seçildi. Sunucu yüzeyinde otomatik müzakere ile sunulur; QUIC desteği olmayan istemciler sessizce HTTP/2’ye geçer.
- **llama.cpp (CUDA/Metal/ROCm)** — Tek bir kod tabanından Nvidia, Apple ve AMD donanımlarında hızlandırılmış taşınabilir yerel çıkarım için seçildi. Aynı zamanda, geri dönüş zincirinin asla tıkanmamasını sağlayan garanti edilmiş son çare sağlayıcı olarak da işlev görür.
- **LLMsVerifier** — "Şu anda hangi sağlayıcı iyi?" sorusunu bir sayıya dönüştürmek için seçildi. Bulut geri dönüş zincirini 5 dakikada bir puanlar ve sıralar; böylece yönlendirme, eski varsayımlar yerine canlı kaliteyi takip eder.
- **Bulut sağlayıcıları (Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together)** — Birçok kaynaktaki ücretsiz kapasiteyi toplamak için seçildi. Otomatik olarak keşfedilir ve tek bir hata toleranslı zincire sıralanır; böylece hiçbir sağlayıcı tek başarısızlık noktası olmaz.
- **gRPC + SSE + Kafka** — Dağıtık dağıtımlar için modlar arası taşıma katmanları olarak seçildi: gRPC hizmetler arası çağrılar, SSE akış iletimi ve Kafka roller arasındaki bağlantısız olay akışı için kullanılır.
- **Vektör deposu / embeddings** — RAG bilgi işlem hattının baştan sona güçlendirilmesi için seçildi: Belgelerin alınması, parçalanması, gömülmesi ve model yanıtlarını desteklemek üzere aranması.
- **Prometheus + OpenTelemetry** — Dağıtılan modlar ne olursa olsun bir isteğin izlenmesini sağlayan ölçümler ve dağıtık izleme için seçildi.
- **vasic-digital Go alt modülleri** — Sertleştirilmiş üretim altyapısı bileşenlerinin yeniden kullanılmasını sağlamak için seçildi; böylece sistemin temeli daha geniş yığınla tutarlı kalır.

## Durum ve Dürüstlük Notları

- **Durum: beta.** İşlevsel, aktif olarak geliştirilen dağıtık çıkarım sistemi.
- **Lisans: Belirlenmedi.** Depo meta verilerinde lisans bilgisi yok (`licenseInfo` null) — bu durum DOĞRULANMAMIŞ olup lisans beyan edilmeden önce çözülmesi gerekir.
- Referans depo şu anda `github.com/HelixDevelopment/llm` adresine yönlendiriliyor; `HelixLLM` yolu da buraya yönlendirme yapıyor. README dosyasındaki kapsama eşiği ve alt modül sayısı verileri kendi beyanına dayanıyor.

**Öncelik seviyesi:** Helix-öncelikli.

