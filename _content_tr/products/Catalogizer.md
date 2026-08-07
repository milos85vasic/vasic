---
name: Catalogizer
slug: catalogizer
tier: vasic-util-secondary
order: 21
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - Gin
  - TypeScript
  - React
  - Tailwind
  - WebSockets
  - SQLCipher
  - PostgreSQL
  - Redis
  - SMB/FTP/NFS/WebDAV
  - Prometheus
  - OpenTelemetry
  - Docker
  - Tauri/Rust
  - S3
  - Google Cloud Storage
repos:
  - https://github.com/vasic-digital/Catalogizer
  - https://github.com/vasic-digital/Media-Types-TS
  - https://github.com/vasic-digital/Catalogizer-API-Client-TS
  - https://github.com/vasic-digital/Media-Player-React
  - https://github.com/vasic-digital/Media-Browser-React
  - https://github.com/vasic-digital/Collection-Manager-React
  - https://github.com/vasic-digital/Dashboard-Analytics-React
  - https://github.com/vasic-digital/Auth-Context-React
diagrams:
  - Layered architecture (React UI ↔ Go API ↔ SQLCipher) with multi-protocol fan-out
  - Resilience sequence (SMB outage → circuit breaker → offline cache → backoff reconnect)
  - Enrichment pipeline (detected file → classifier → external providers → catalog entry)
  - Module map (Catalogizer over the 21 digital.vasic.* submodules)
---

**Gelişmiş Çoklu Protokol Medya Koleksiyonu Yönetimi — Sahip Olduğunuz Her Şeyi Tespit Edin, Kataloglayın ve Zenginleştirin**

## Özet

Catalogizer, kendi sunucunuzda barındırabileceğiniz bir medya koleksiyonu yönetim sistemi olup SMB, FTP, NFS, WebDAV ve yerel dosya sistemleri üzerinden medyayı otomatik olarak tespit eder, kategorilere ayırır ve düzenler. Gerçek zamanlı izleme, şifreli depolama, harici meta veri zenginleştirme ve yüksek performanslı Go API altyapısıyla desteklenen modern bir React arayüzüne sahiptir.

## Kısa Açıklama

Üretim seviyesinde, çoklu protokol destekli bir medya kütüphanesi yöneticisi. Go/Gin REST API, SMB/FTP/NFS/WebDAV/yerel kaynaklar üzerinden 50’den fazla medya türünü algılar, TMDB/IMDB/MusicBrainz/Steam ve benzeri platformlardan zenginleştirir ve şifreli bir SQLCipher veritabanı üzerinden gerçek zamanlı React web uygulaması sunar.

## Uzun Açıklama

Çoğu medya yöneticisi, önce teslim olmanızı ister: Her şeyi tek bir diskte, tek bir formatta, tek bir türde toplamalısınız; ancak ondan sonra yardım ederler. Catalogizer ise tam tersi bir yaklaşımla başlar — koleksiyonunuz zaten olduğu yerde, birbiriyle anlaşamayan NAS paylaşımları ve protokoller arasında dağılmış halde duruyor — ve sizi orada karşılar. Depolama sistemlerinin kullandığı protokolleri konuşur: SMB/CIFS, FTP/FTPS, NFS, WebDAV ve yerel dosya sistemi. Tüm bunlar, tek bir birleşik istemci soyutlaması arkasında toplanır; böylece bir Windows paylaşımı, bir FTP arşivi ve bir WebDAV bağlantısı, üst katmanlar için aynı görünür ve uygulama koduna dokunmadan karıştırılabilir, değiştirilebilir ya da devre dışı bırakılabilir. Go arka ucu (Gin REST API), bu kaynakları sürekli izler, dosyalar ortaya çıktıkça 50’den fazla medya türünü (film, dizi, müzik, oyun, yazılım, belgesel) algılar ve sınıflandırır. Her bir öğeyi TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam ve daha fazlası gibi harici sağlayıcılardan zenginleştirir; böylece basit bir dosya adı, sanat eserleri, oyuncu kadrosu ve meta verilerle donatılmış eksiksiz bir katalog kaydına dönüşür. Sonuçlar, WebSocket üzerinden TypeScript React ön yüzüne akar; böylece kütüphane, veri alımı sırasında canlı olarak güncellenir, manuel yenileme gerektirmez. Tüm meta veriler, JWT tabanlı rol bazlı kimlik doğrulama ile korunan şifreli bir SQLCipher veritabanında saklanır.

Çoğu kataloglayıcı, bir paylaşım devre dışı kaldığı anda sessizce çökerken, Catalogizer, kesintilerde bile işlevselliğini sürdürmek üzere tasarlanmıştır. Geçici bir SMB hatası, üstel geri çekilmeyle yeniden bağlantı, ölü bir sunucuya sürekli istek göndermeyi durduran devre kesici, sürekli sağlık izleme ve çevrimdışı meta veri önbelleği ile emilir. Bu önbellek, son bilinen sağlam durumdan kullanıcı isteklerine yanıt vermeye devam eder — fark, "tek bir NAS yeniden başladığı için tüm uygulama çöktü" ile "bir kaynakta sorun var, geri kalan her şey çalışıyor" arasındadır. Kataloglamanın ötesinde, koleksiyonunuz için operasyonel bir araç olarak da işlev görür: büyüme eğilimleri ve kalite/sürüm takibi için analizler, profesyonel PDF rapor oluşturma, PDF’dan görsel/metin/HTML dönüştürme hizmeti, favorilerin dışa/içe aktarımı (JSON/CSV) ve S3, Google Bulut Depolama ya da yerel klasörlere bulut senkronizasyonu. Ayrıca, tesadüfen büyük bir monolit değil; kasıtlı olarak 21 yeniden kullanılabilir `digital.vasic.*` Go alt modülü ve TypeScript istemci paketlerinden oluşur. Her biri bağımsız olarak test edilmiş ve sürümlendirilmiştir; böylece Catalogizer’u çalıştıran aynı savaşta test edilmiş kimlik doğrulama, dosya sistemi, akış ve gözlemlenebilirlik bileşenleri, daha geniş ürün ailesine de güç sağlar. Kalite güvencesi, kendi beyanına dayalı değildir: Challenges çerçevesi ve HelixQA, her ilan edilen yeteneği, kanıta dayalı doğrulama ile sahtekârlık karşıtı bir yaklaşımla denetler.

## Neden inşa ettik

Mevcut medya yöneticileri tek bir depolama altyapısı ve tek bir medya türü varsayar. Gerçek koleksiyonlar ise birçok NAS paylaşımına ve protokole dağılır, bir paylaşım devre dışı kaldığında bozulur ve film, müzik, oyun ve yazılım gibi farklı türleri bir arada barındırır. Catalogizer, tüm protokolleri eşit şekilde ele almak, güvenilmez ağ depolamalarına karşı dayanıklı kalmak ve her şeyin üzerinde tek bir yetkili, zenginleştirilmiş ve şifrelenmiş katalog sunmak için inşa edildi.

## Neden oyunun kurallarını değiştiriyor

Normalde ayrı ayrı bir yığın araca ihtiyaç duyulan her şeyi, kendi barındırabileceğiniz, şifrelenmiş tek bir pakette topluyor: Her depolama altyapısını eşit gören protokolden bağımsız içerik alma, depolama kesintilerinde katalogun çökmek yerine canlı kalmasını sağlayan dayanıklılık ve ham dosyaları gezilebilir, nitelikli bir kütüphaneye dönüştüren zengin çoklu sağlayıcı entegrasyonu. Modüler mimarinin getirisi katlanarak artar: Dosya sistemi istemcisindeki bir güvenlik iyileştirmesi ya da yeni bir sağlayıcı eklentisi tek seferde uygulanır ve her kullanıcıya fayda sağlar. Böylece Catalogizer, etrafındaki ekosistem geliştikçe sürekli olarak daha da iyileşir. Kısacası, bir medya dizini ile bir medya *sistemi* arasındaki farktır — sahibi siz olan, güvenilmez altyapılara rağmen ayakta kalan ve vaat değil, kanıtlanmış bir iç yapıya sahip olan bir sistem.

## Yenilikçi yönleri

- Tek bir arayüz altında birleştirilmiş çoklu protokol dosya sistemi istemcisi (SMB/FTP/NFS/WebDAV/yerel).
- Depolama kesintilerinde katalogun kullanılabilir kalmasını sağlayan çevrimdışı önbellek + devre kesici.
- 21 yeniden kullanılabilir `digital.vasic.*` Go alt modülü ve TS istemci modüllerine tam ayrıştırma.
- Dinlenme halinde şifrelenmiş katalog (SQLCipher) ve kullanıcı arayüzüne gerçek zamanlı WebSocket senkronizasyonu.
- Zorluklar çerçevesi ve HelixQA entegrasyonu ile kanıta dayalı kalite güvencesi.

## Zorluklar ve çözümler

- **Güvenilmez ağ depolama:** Üstel geri çekilme, devre kesici, sağlık kontrolleri ve kaynaklara ulaşılamadığında önbelleğe alınmış meta verileri sunan bir silme politikalı çevrimdışı önbellek ile çözüldü.
- **Protokol çeşitliliği:** Her protokol, `digital.vasic.filesystem` istemcisi altında ortak bir soyutlama ile ele alınarak üst katmanların protokolden bağımsız çalışması sağlandı.
- **Veri güvenliği:** Dinlenme halinde SQLCipher şifrelemesi, JWT/RBAC kimlik doğrulama ve istek temizleme ara katmanı ile çözüldü.
- **Büyük ölçekte sürdürülebilirlik:** Tüm genel mantık, tek bir bütün yerine bağımsız olarak test edilen alt modüllere ayrıştırılarak çözüldü.

## Teknoloji yığını (neden + nasıl)

- **Go + Gin** — Sürekli izleme iş yükleri için eşzamanlılık ve verimlilik sağlayan yüksek performanslı REST API çekirdeği (`catalog-api`).
- **TypeScript + React + Tailwind (Vite)** — Gerçek zamanlı güncellemeli, duyarlı `catalog-web` kullanıcı arayüzü.
- **WebSockets** — Arka uç merkezi ile kullanıcı arayüzü arasında canlı veri senkronizasyonu.
- **SQLCipher (şifrelenmiş SQLite)** — Dinlenme halinde şifrelenmiş meta veri deposu; `digital.vasic.database` üzerinden çift SQLite/PostgreSQL desteği.
- **SMB/FTP/NFS/WebDAV istemcileri** — `digital.vasic.filesystem` aracılığıyla çoklu protokol içerik alma.
- **Harici meta veri API'leri (TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam)** — Zenginleştirme için sağlayıcı eklentileri.
- **Prometheus + OpenTelemetry** — `digital.vasic.observability` üzerinden metrikler/izleme.
- **Docker / derleyici kapsayıcısı** — Yeniden üretilebilir derlemeler (`catalogizer-builder` üzerinden yönlendirilen Tauri/Rust).
- **Redis** — `digital.vasic.cache` / `ratelimiter` üzerinden önbellekleme ve hız sınırlama.
- **S3 / Google Bulut Depolama** — Bulut senkronizasyonu ve kontrol noktası depolama.

