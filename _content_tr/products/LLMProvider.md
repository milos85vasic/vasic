---
name: LLMProvider
slug: llmprovider
tier: helix-primary
order: 13
status: beta
license: TBD
private: false
tech:
  - Go (1.25.3)
  - net/http (stdlib)
  - logrus
  - testify
  - yaml.v3
  - digital.vasic.models
  - circuit / health / retry / apikeys / discovery packages
  - 43 provider adapters + generic OpenAI-compatible adapter
repos:
  - https://github.com/HelixDevelopment/LLMProvider
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Interface hub — application → single LLMProvider interface → 43 adapters + the generic OpenAI-compatible adapter (fanning out to vendor endpoints).
  - Circuit-breaker state machine — closed → open → half-open, wrapping both Complete and the CompleteStream channel.
  - Retry timeline — exponential backoff + jitter with status-aware retry/skip decisions and context cancellation.
  - Honest discovery — live provider /v1/models + TTL cache; failure path returns nothing (old hardcoded tier crossed out), contrasted with the credential single-source (apikeys).
---

# LLMProvider

**Tek bir arayüz, 43 sağlayıcı — devre kesici, yeniden deneme ve sağlık kontrolü entegre olarak.**

## Özet

LLMProvider, yeniden kullanılabilir bir Go modülüdür ve birleşik bir `LLMProvider` arayüzü ile bu arayüz etrafında üretim dayanıklılık desenlerini tanımlar — devre kesici, sağlık izleme, geri çekilmeyle yeniden deneme, tembel yükleme — ve tek bir sözleşme altında 43 somut sağlayıcı uygulaması sunar. Ayrıca OpenAI uyumlu genel bir adaptör ve dürüst, sabit geri dönüş içermeyen model keşfi sağlar.

## Kısa açıklama

Tek bir `LLMProvider` arayüzü (`Complete`, `CompleteStream`, `HealthCheck`, `GetCapabilities`, `ValidateConfig`) sunan yeniden kullanılabilir bir Go modülü. 43 sağlayıcı adaptörü ve OpenAI uyumlu genel bir adaptör üzerinde hata toleransı ilkeleri — devre kesici, sağlık izleyici, rastgele gecikmeli yeniden deneme, tembel başlatma — içerir. İş parçacığı güvenli.

## Uzun açıklama

LLMProvider, her LLM tüketen servisin ihtiyaç duyduğu ama neredeyse kimsenin düzgün inşa etmediği soyutlama katmanıdır — gerçek trafikle karşılaştığında hayatta kalabilen bir sistemle demo arasındaki farkı yaratan gözden uzak altyapı. Tek bir yetenek bilincine sahip arayüz — `Complete`, `CompleteStream`, `HealthCheck`, `GetCapabilities`, `ValidateConfig` — tanımlar. Böylece uygulama kodu, hangi 43 arka uç çağrıya yanıt verirse versin, tek bir sözleşmeyi hedefler. Ardından, kırılgan sağlayıcı çağrılarını üretim ortamında nefesinizi tutmadan çalıştırabileceğiniz bir hale getiren operasyonel sağlamlaştırma sunar. Üç durumlu bir devre kesici (kapalı → açık → yarı açık), herhangi bir sağlayıcıyı — *akış kanalı dahil* — şeffaf bir şekilde sarar. Boş bir akış, doğru şekilde bir hata olarak sayılır. Böylece tek bir sorunlu arka uç, tüm servisi çökertmeden devre kesiciyi açabilir. Merkezi bir `CircuitBreakerManager`, tüm devre kesicileri aynı anda izler. Yapılandırılabilir bir sağlık izleyici, sağlayıcıları eşik ve aralık kontrolleriyle sürekli olarak sağlıklı / bozulmuş / sağlıksız / bilinmeyen durumlarında tarar. Böylece bozulma, bir kesintiyle keşfedilmek yerine gözlemlenir. Yeniden deneme mantığı, üstüne rastgele gecikme eklenmiş üstel geri çekilme kullanır ve durum farkındalığına dayalı kararlar alır — yeniden denenmeye değer hataları (429, 5xx, geçici ağ hataları) yeniden dener, 4xx hataları veya iptal edilmiş bir bağlam için gereksiz döngü harcamaz. Gecikmeler sınırlandırılır, böylece geri çekilme fırtınası kontrolden çıkmaz. Tembel başlatma deseni ise her sağlayıcının yapılandırmasını ilk gerçek kullanımına kadar erteler — bu bilinçli bir tasarım seçimi olup, 43 sağlayıcının kaydının neredeyse bedava olmasını sağlar.

Modül, 43 somut sağlayıcı paketi ile birlikte, *herhangi bir* `/v1/chat/completions` uç noktasına karşı tam arayüzü uygulayan `generic` OpenAI uyumlu bir adaptör sunar — Bearer kimlik doğrulaması, SSE akışı ve doğru `[DONE]` işleme dahil. Böylece özel bir paketi olmayan bir sağlayıcı, adaptörü URL’ye yönelttiğiniz anda birinci sınıf bir vatandaş haline gelir. Kimlik bilgileri tek bir yerde (`apikeys`, katı bir `ApiKey_<Sağlayıcı>` kuralıyla) çözümlenir. Bu sayede, "test paketinde sabit kodlu anahtar geçer, gerçek anahtar hiç bağlanmamış, ürün üretimde bozulur" türündeki tüm hatalar kaynağında engellenir. Model keşfi, kasıtlı ve neredeyse inatla dürüsttür: TTL önbelleği ardında canlı sağlayıcı API’lerini sorgular ve — yönetişim gereği — eski sabit geri dönüş katmanı tamamen silinmiştir. Canlı keşif başarısız olduğunda, LLMProvider *hiçbir şey* döndürmez, böylece arayan taraf asla geçerli görünen ama çağrılamayan bir model kimliğiyle karşılaşmaz. Tüm bu yapı, eşzamanlı kullanım için iş parçacığı güvenli olarak inşa edilmiştir.

## Neden inşa ettik

Naive LLM çağrıları üretim ortamında başarısız olur — sağlayıcılar hız sınırlamasına takılır, performans düşer ya da çöker ve tek bir sorunlu arka uç, tüm servisi beraberinde götürebilir. Model katalogları sürüklenir, sabit kodlanmış listeler artık çalışmayan çağrı kimlikleri verir. LLMProvider, arayüzü, dayanıklılık kalıplarını ve dürüst keşfi merkezi hale getirerek her tüketicinin hataya dayanıklılık ve doğruluk özelliklerini bedavaya miras almasını sağlar.

## Neden oyunun kurallarını değiştiriyor

"Bir LLM sağlayıcısını entegre etme" işini tek bir hamleye indiriyor — tek bir arayüzü uygulayın ya da jenerik adaptörü bir uç noktaya yönlendirin — ardından bu sağlayıcıyı otomatik ve şeffaf bir şekilde devre kesici, sağlık izleme ve rastgele gecikmeli yeniden deneme ile sarar. Dayanıklılık, her ekibin (kötü bir şekilde, teslim tarihinin baskısı altında, ilk kesintiden sonra) yeniden icat ettiği bir şey olmaktan çıkıp, kütüphanenin 43 arka uç boyunca varsayılan davranışı haline gelir. Güvenilirlik mühendisliği bir kez yazılır, sıkı testlerden geçer ve onu içe aktaran herkes tarafından bedavaya miras alınır.

## Yenilikçi olan ne

- **Tek yetenek bilincine sahip arayüz** — tamamlama, akış, sağlık, yetenekler ve yapılandırma doğrulaması, her arka ucun aynı şekilde uymak zorunda olduğu tek bir sözleşmeye indirgenir.
- **Şeffaf devre kesici sarma — akışlar dahil.** Kesici, `CompleteStream`'in kanalını sadece istek/yanıt değil, korur ve boş bir akışı gerçekte olduğu gibi bir başarısızlık olarak ele alır — kilitlenme güvenli, kilit dışı dinleyici bildirimiyle.
- **43 sağlayıcı paketi + jenerik OpenAI uyumlu adaptör** — özel paketler ince kalır ve `/v1/chat/completions` konuşan herhangi bir listelenmemiş satıcı, adaptörü ona yönelttiğiniz anda çalışır.
- **Tek kimlik doğrulama otoritesi (`apikeys`)** — tam olarak bir yer `ApiKey_<Sağlayıcı>` ortam değişkenlerini okur, yapısal olarak "yeşil testler, bozuk ürün" uyumsuzluğunu ortadan kaldırır, sadece uyarı vermek yerine.
- **Dürüst model keşfi (sabit kodlanmış yedek yok)** — TTL önbelleğinin ardındaki canlı sağlayıcı API'leri; başarısızlık durumunda `nil` döner, asla çağrılamayacak kimlikler veren eski veya uydurma bir katalog sunmaz.
- **Tembel başlatma ile `sync.Once`** — yapılandırma ilk kullanıma kadar ertelenir, böylece 43 sağlayıcıyı kaydetmek, gerçekten birini çağırana kadar neredeyse hiçbir maliyet oluşturmaz.
- **Blöf karşıtı, çok dilli Challenge yığını** — devre, sağlık ve yeniden deneme davranışını beş farklı bölgede test eden gerçek bir çalıştırıcı, eşleştirilmiş mutasyon testi ile kontrol edilir (mutasyona uğramamış kod sıfır çıkmalı; enjekte edilen bir mutasyon 99 çıkış kodunu zorunlu kılmalı), böylece geçen bir test paketi, çalışan davranışın kanıtı olur.

## En büyük teknik zorluklar ve çözümlerimiz

- **Zincirleme sağlayıcı hataları.** Tek bir kararsız arka uç, tüm servisi beraberinde sürüklememeli. Üç durumlu devre kesici (kapalı → açık → yarı açık) ile çözüldü; bu kesici herhangi bir sağlayıcıyı *ve onun akışını* şeffaf bir şekilde sarar, sürekli başarısızlık durumunda açılır, yarı açık durumda iyileşmeyi dener ve merkezi bir `CircuitBreakerManager` tarafından koordine edilir.
- **Geçici hatalar ve hız sınırlamaları.** Durum bilincine sahip üstel geri çekilme artı rastgele gecikme ile çözüldü — `min(BaşlangıçGecikmesi·Çarpan^(n-1), MaksGecikme) ± rastgele gecikme` — böylece yeniden denemeler senkronize bir izdihama dönüşmek yerine yayılır. Tam olarak yeniden denenmesi gerekenler (429, 500, 502, 503, 504 ve ağ hataları) yeniden denenir, iptal edilmiş bir bağlam veya diğer 4xx hataları için boşuna deneme yapılmaz.
- **Kayıtlı ama kullanılmayan birçok sağlayıcıya ölçeklendirme.** 43 sağlayıcı kayıtlıyken, herhangi bir serviste bunların sadece birkaçı aktif olsa, erken başlatma tamamen israf olurdu. `sync.Once` ile korunan tembel başlatma ile çözüldü; böylece sadece gerçekten çağırdığınız sağlayıcılar kurulum maliyetini öder.
- **Geçersiz model kimlikleri dağıtma.** Sabit kodlanmış keşif yedeği katmanı tamamen kaldırılarak (CONST-036'ya göre) ve canlı keşif başarısızlığında hiçbir şey döndürülmeyerek çözüldü — ayrıca, çağırının önbelleği değiştirememesi veya başka bir okuyucu ile yarışa girmemesi için savunmacı kopya döndürme. Doğruluk, bir kural olarak değil, yapısal olarak sağlanır.
- **Akış + eşzamanlılık doğruluğu.** İnce başarısızlık modu, kesicinin kilidi ile dinleyici geri çağırmaları arasında bir kilitlenmedir. Dinleyicilerin anlık görüntüsü alınarak ve 5 saniyelik zaman aşımı altında kilit dışı bildirim yapılarak çözüldü; ayrıca sıfırlama sırasında kilit açılır ve bildirim yapılır — her bileşen eşzamanlı kullanım için tasarlanmış ve `-race` paketi ile sabitlenmiştir.

## Teknoloji Yığını

- **Go (1.25.3)** — birinci sınıf eşzamanlılık, statik ikili dosyalar ve güçlü standart kütüphane desteğiyle seçildi; modülü, arayüzü, tüm dayanıklılık bileşenlerini ve 43 adaptörü içeriyor.
- **`net/http` (standart kütüphane)** — kasıtlı olarak bağımlılıktan arındırılmış HTTP: her sağlayıcıya özel istemcileri, genel OpenAI uyumlu adaptörü ve canlı keşif çağrılarını güçlendiriyor; böylece denetlenmesi veya yamalanması gereken üçüncü taraf bir aktarım katmanı bulunmuyor.
- **logrus** — yapılandırılmış, seviye tabanlı günlükleme: devre kesicinin durum geçişleri ve keşif yolunda operatörlerin ihtiyaç duyduğu görünürlüğü sağlıyor.
- **testify** — test paketini çalıştırıyor ve kritik önem taşıyan mutasyon-dal sabitlemesini gerçekleştiriyor; böylece başarılı bir test çalıştırması gerçekten bir anlam ifade ediyor.
- **yaml.v3** — uluslararasılaştırma paketlerini ve yapılandırmayı, insanlar tarafından düzenlenebilir bir formatta ayrıştırıyor.
- **`digital.vasic.models`** — paylaşılan `LLMRequest` / `LLMResponse` / `ProviderCapabilities` tipleri tek bir yerde tutuluyor; böylece her adaptör aynı söz dağarcığını kullanıyor (belgelenmiş bir çalışma zamanı bağımlılığı).
- **Birinci taraf paketler** — `circuit`, `health`, `retry`, `apikeys`, `discovery`, `providers/` (43 sağlayıcı + `generic`) ve `i18n`: dayanıklılık ve entegrasyon yüzeyi, tek bir monolit yerine küçük, bağımsız olarak test edilebilir birimlere ayrılmış durumda.
- **`.env` + `~/api_keys.sh` (`ApiKey_<Sağlayıcı>` kuralı)** — kimlik bilgileri için tek ve net bir kaynak; böylece testlerde ve üretim ortamında anahtarlar aynı şekilde bağlanıyor.
- **Makefile yarış koşulu paketi (`-race -p 1`) + Challenge çalıştırıcısı** — sahtekârlığa karşı omurga: yarış dedektörü, eşzamanlılık doğruluğunu kanıtlıyor; Challenge çalıştırıcısı ise gerçek davranışı kaos, DDoS, ölçeklendirme, stres, canlı keşif ve askıya alınmama senaryolarıyla test ediyor.

## Durum ve Dürüstlük Notları

- **Durum: beta.** Bağımsız olarak yeniden kullanılabilir bir modül; GitHub deposu herkese açık.
- **Lisans: Belirlenmedi.** Tutarsız — `doc.go` MIT lisansını belirtirken, Apache-2.0 tarzında bir LICENSE dosyası mevcut; yayınlamadan önce doğrulanmalı.
- LLMsVerifier, model kataloğu için yukarı akıştaki tek gerçek kaynak. `helix-deps.yaml` bildirimi güncel değil (`deps: []` olarak belirtilmiş olmasına rağmen belgeler `digital.vasic.models` bağımlılığını gösteriyor); keşif modülündeki "Tier 2 (models.dev)" planlanmış bir iskelet olup aktif değil.

**Öncelik seviyesi:** Helix-birincil (LLM-altyapı kümesi — bağımsız olarak yeniden kullanılabilir modül). HelixTrack’dan sonra geliyor.

