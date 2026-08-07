---
name: HelixPlay
slug: helixplay
tier: helix-primary
order: 18
status: beta
license: TBD
private: false
tech:
  - Go (1.26 root / 1.25+ submodules)
  - Wails v2
  - Flutter 3.29+
  - Angular 17+ (Go → WASM)
  - WebRTC / Pion v4
  - QUIC / quic-go
  - Custom UDP
  - Hardware encoders (NVENC / QSV / AMF / VideoToolbox)
  - Platform capture (DXGI / ScreenCaptureKit / PipeWire)
  - Docker / Podman
  - mDNS / rendezvous
repos:
  - https://github.com/HelixDevelopment/HelixPlay
diagrams:
  - Media pipeline — Capture → Encode → Packetize → Transmit → Decode → Render, annotated with per-stage technologies.
  - Triple-stack convergence — Wails / Flutter / Angular clients all pointing at one Go core.
  - Self-hosted topology — a GPU host + host agent streaming over WebRTC/QUIC to phone, TV, laptop, and browser.
  - White-label layer — one platform, multiple branded tenant skins.
---

# HelixPlay

**Herhangi bir GPU cihazını kendi bulut oyun sisteminize dönüştürün.**

## Özet

HelixPlay, herhangi bir GPU donanımlı cihazı uzaktan yayın sunucusuna dönüştüren, masaüstü, mobil, TV ve tarayıcı istemcilerine konsol kalitesinde oyun deneyimi sunan, kendi kendine barındırılabilir bir bulut oyun platformudur. 46 alt modülden oluşan Go merkezli bir monorepo olarak tasarlanmış olup üç katmanlı bir istemci yapısına sahiptir ve iş ortakları için beyaz etiketli olarak sunulabilir.

## Kısa açıklama

HelixPlay, kendi kendine barındırılabilen, açık kaynaklı ve beyaz etiketli bir bulut oyun platformudur. Herhangi bir GPU donanımlı cihazı uzaktan yayın sunucusuna dönüştürür ve WebRTC/QUIC üzerinden masaüstü, mobil, TV ve tarayıcı istemcilerine konsol kalitesinde oyun deneyimi sunar. Platform, Go çekirdeği ve Wails/Flutter/Angular istemci yığını üzerine kuruludur.

## Uzun açıklama

HelixPlay, 46 Git alt modülünden oluşan Go merkezli bir monorepo olarak geliştirilmiş bir bulut oyun platformudur. Sahip olduğunuz herhangi bir oyun bilgisayarını, masaüstü, mobil, TV ve tarayıcı istemcilerine konsol kalitesinde deneyim sunan bir yayın sunucusuna dönüştürür. Platform, kendi kendine barındırılabilir, açık kaynaklı ve iş ortakları için beyaz etiketli olarak sunulabilir. Temel felsefesi nettir: donanım sizin, hizmet sizin, marka sizin; araya üçüncü taraf bulutlar girmez.

Platformun ayırt edici tasarım tercihi, üç katmanlı istemci bütünleşmesidir. Bu zorlu mimari seçim, her alanda karşılığını verir. Wails masaüstü uygulaması, Flutter mobil/TV uygulaması ve Angular web istemcisi, *tek* bir Go çekirdeği üzerine inşa edilmiştir. Çekirdek, tarayıcı için WASM’a derlenir; böylece davranışlar tek bir yerde yazılır ve üç farklı koldan çatallanmak yerine tüm platformlarda paylaşılır. Bunun altında gerçek zamanlı medya akışı yer alır: Yakalama → Kodlama → Paketleme → İletim → Kod Çözme → Görüntüleme. Bu süreç, platforma özgü yakalama (DXGI / ScreenCaptureKit / PipeWire) ve donanım kodlayıcıları (NVENC / QSV / AMF / VideoToolbox) ile entegre edilmiştir. Böylece GPU cihazı ağır iş yükünü üstlenir. İletim ise gecikmeyi en aza indirmek için WebRTC (Pion v4), QUIC (quic-go) ve özel UDP veri paketleri üzerinden gerçekleştirilir. Arka uç çekirdeği, oturumları, kiracıları, katalogları ve kimlik doğrulamasını yönetir; bir ana bilgisayar aracısı ise yakalama, kodlama ve iletim işlemlerini uç noktada gerçekleştirir. mDNS/rendezvous mekanizması, istemcilerin sunucularını manuel ayarlamaya gerek kalmadan bulmasını sağlar.

HelixPlay, baştan sona beyaz etiketli SaaS için tasarlanmıştır. Kiracı bazlı tema, katalog filtreleme, OAuth2 ve faturalandırma özellikleri sayesinde iş ortakları, ince bir yeniden tasarım yerine tamamen markalı bir hizmet sunabilir. Platform, son detayına kadar konteyner tabanlıdır: her hizmet, veritabanı, derleme, test ve tarama işlemi konteynerler içinde çalışır. Bu da tüm platformun yeniden üretilebilir ve doğrulanabilir şekilde dağıtılmasını sağlar. Helix ailesinin geri kalanı gibi, bu platform da "blöf karşıtı" bir anayasaya sahiptir. Yeşil test, gerçek ve son kullanıcı tarafından kullanılabilir bir davranışı garanti eder; geçen bir simülasyon değil.

## Neden geliştirdik?

Ticari bulut oyun hizmetleri kapalı, merkezi ve kiralık. HelixPlay, GPU donanımlı bir cihaza sahip herkesin kendi yayın sunucusunu çalıştırabilmesi için geliştirildi. Açık kaynaklı, kendi kendine barındırılabilir ve beyaz etiketli bir alternatif sunarak üçüncü taraf hizmetlere bağımlılığı ortadan kaldırıyor.

İçerik

## Neden bir oyun değiştirici?

Ticari hizmetlerin birbirinden ayırdığı üç unsuru bir araya getiriyor: kendi kontrolünüzdeki donanımda kendi sunucunuzu barındırma, üç istemci yığınını tek bir Go çekirdeğiyle çalıştırarak özelliklerin her yerde aynı anda devreye girmesi ve beyaz etiketli çok kiracılı yapı. Sonuç olarak, bir iş ortağı *kendi* GPU’ları üzerinde tamamen markalı bir bulut oyun hizmeti başlatabiliyor — deneyimi, kullanıcıları ve ekonomiyi sahipleniyor — başkasının bulutunda kapasite kiralayıp onun sınırları içinde yaşamak yerine.

## Yenilikçi olan ne?

- **Üçlü istemci yığını yakınsaması** — Wails, Flutter ve Angular, tek bir Go çekirdeği (tarayıcıda WASM) üzerinde çalışıyor; böylece masaüstü, mobil, TV ve web, üç ayrı ve birbirinden uzaklaşan uygulama yerine tek bir uygulama paylaşıyor.
- **Kendi sunucunuzda barındırılabilir, beyaz etiketli SaaS** — kiracı başına tema, katalog filtreleme, OAuth2 ve faturalandırma sistemleri entegre olarak geliyor; platform, bir demo değil, markalaştırılabilir bir ürün olarak teslim ediliyor.
- **Modern düşük gecikmeli iletim** — WebRTC (Pion), QUIC ve özel UDP, platforma özel donanım kodlayıcı seçimiyle (NVENC / QSV / AMF / VideoToolbox) eşleştirilerek, kolaylık yerine tepki hızı önceliklendiriliyor.
- **46 modüllü ayrıştırılmış mimari** — temiz bir şekilde ayrılmış bileşenler ve tamamen konteyner tabanlı yapı: her hizmet, veritabanı, derleme, test ve tarama bir konteyner içinde çalışıyor.

## En büyük teknik zorluklar ve çözümlerimiz

- **Farklı donanımlar arasında düşük gecikmeli yayın.** Her işletim sistemi ve GPU, yakalama ve kodlamayı farklı şekilde sunuyor; gecikme ise affetmiyor. Platforma duyarlı bir yakalama/kodlama yolu — DXGI / ScreenCaptureKit / PipeWire üzerinden NVENC / QSV / AMF / VideoToolbox’a besleme — WebRTC / QUIC / UDP üzerinden taşınarak her makinenin piksel verilerine en hızlı yerel yolunu kullanması sağlandı.
- **Masaüstü, mobil, TV ve web’de tek bir ürün.** Üçlü istemci yığını (Wails, Flutter, Angular) ile çözüldü; bu istemciler, tarayıcı için WASM’e derlenen tek bir Go çekirdeğini paylaşıyor. Böylece bir düzeltme veya özellik bir kez yazılıp dört yüzeyde birden görünüyor, dört kez taşınmak yerine.
- **Çok kiracılı beyaz etiketli işletim.** Çekirdek arka uçta kiracı başına tema, katalog filtreleme, OAuth2 ve faturalandırma sistemlerinin doğrudan entegre edilmesiyle çözüldü; böylece kiracı izolasyonu ve markalaşma, müşteri başına çatallama yerine platformun temel özellikleri haline geldi.

## Teknoloji yığını

- **Go (1.26.2 ana sürüm / 1.25+ alt modüller)** — paylaşılan çekirdek arka uç ve ana bilgisayar aracısı; hem yerel ikili dosyalara hem de WASM’e derlenebilen tek bir dil. Bu da tek çekirdekli, çok istemcili tasarımı mümkün kılan unsur.
- **Wails v2** — masaüstü istemcisi; Go çekirdeğini gömülü bir web görünümüne bağlayarak masaüstü uygulamasının çekirdek mantığını yeniden uygulamak yerine doğrudan kullanmasını sağlıyor.
- **Flutter 3.29+** — mobil/TV istemcisi; Go çekirdeğine FFI üzerinden çağrı yaparak telefon ve televizyonlarda yerel bir arayüz sunuyor, ikinci bir arka uca ihtiyaç duymadan.
- **Angular 17+** — web istemcisi; aynı Go çekirdeğini WASM’e derleyerek tarayıcıyı ikinci sınıf değil, birinci sınıf bir yüzey haline getiriyor.
- **WebRTC / Pion v4, QUIC / quic-go, özel UDP** — üç gerçek zamanlı iletim protokolü; platformun her ağ ve istemci için mevcut en düşük gecikmeli yolu seçmesini sağlıyor.
- **Donanım kodlayıcılar (NVENC / QSV / AMF / VideoToolbox)** ve **platform yakalama (DXGI / ScreenCaptureKit / PipeWire)** — GPU hızlandırmalı yakalama ve kodlama yolu; platforma özel seçilerek kodlamanın asla CPU darboğazına takılmaması sağlanıyor.
- **Konteynerler (Docker/Podman)** — her hizmet, veritabanı, derleme, test ve tarama konteyner içinde çalışıyor; böylece tüm sistem dağıtım ve doğrulama açısından yeniden üretilebilir hale geliyor.
- **mDNS / buluşma** — sıfır yapılandırma ana bilgisayar keşfi; istemcilerin ağdaki yayın ana bilgisayarını otomatik olarak bulmasını sağlıyor.

İçerik

## Durum ve dürüstlük notları

- **Durum: beta.** README dosyasındaki gecikme hedefleri (LAN için ≤30 ms / WAN için ≤50 ms p999), "konsol sınıfı / PS4 Pro sınıfı" çerçevesi ve test matrisindeki hücre sayısı, projenin kendi beyan ettiği tasarım hedefleridir; bağımsız olarak ölçülmemiş olup bu şekilde sunulmaktadır.
- **Lisans: Belirlenmedi.** GitHub API aracılığıyla herhangi bir LICENSE dosyası tespit edilemedi — DOĞRULANMAMIŞ / beyan edilmemiş.

**Öncelik seviyesi:** Helix-birincil.

