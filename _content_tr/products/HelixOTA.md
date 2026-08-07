---
name: HelixOTA
slug: helixota
tier: helix-primary
order: 9
status: in-development
license: Apache-2.0
private: false
tech:
  - Go
  - Gin
  - Kotlin / KMP
  - HTTP/3 QUIC
  - PostgreSQL
  - MinIO / S3
  - AOSP update_engine + AVB/dm-verity
  - React
  - OpenTelemetry
  - Prometheus / Grafana
repos:
  - https://github.com/HelixDevelopment/helix_ota
diagrams:
  - Three-planes architecture — control plane (Go/Gin) ↔ data plane (PostgreSQL/MinIO/OTel) ↔ device (KMP agent + update_engine), with the two extractable seams highlighted.
  - Staged rollout funnel — 5% → 10% → 30% → … → 100% with halt/advance thresholds.
  - Zero-brick A/B slot swap — slot A active, slot B updated + verified, automatic rollback on boot failure.
  - Six ota-* submodules as decoupled building blocks feeding the umbrella system.
---

# HelixOTA

**Evrensel, bağımsız kablosuz güncellemeler — tasarım gereği sıfır tuğla riski.**

## Özet

Helix OTA, evrensel ve derinlemesine bağımsız bir kablosuz (OTA) güncelleme sistemi: bir Go kontrol düzlemi ve işletim sistemi başına istemci ajanlarından oluşur. Tek bir karttan milyonlarca cihaza kadar değişen filolara güvenli, aşamalı yazılım/güncelleme dağıtımı için tasarlanmıştır. İlk hedefi, Orange Pi 5 Max üzerinde çalışan Android 15’tir.

## Kısa açıklama

Helix OTA, evrensel bir kablosuz güncelleme sistemi — bir Go kontrol düzlemi ve işletim sistemi başına istemci ajanları — olup sıfır sistem bozulması, doğrulanmış yüklemeler ve ayrıntılı aşamalı dağıtımlar için tasarlanmıştır. İlk hedefi Orange Pi 5 Max üzerinde çalışan Android 15 olup, Linux ve Windows uyarlamaları da planlanmaktadır.

## Uzun açıklama

Helix OTA, evrensel, genel ve derinlemesine bağımsız bir kablosuz (OTA) güncelleme sistemi olup tek bir tavizsiz vaat üzerine inşa edilmiştir: güncelleme, çalışan bir cihazı asla tuğlaya dönüştürmemelidir. Bir Go sunucu **kontrol düzlemi**, işletim sistemi başına istemci **SDK’ları/ajanları** ve bir yönetim **gösterge paneli**nden oluşur. Platforma özgü yeniden inşa yerine, takılabilir işletim sistemi adaptörleri aracılığıyla *herhangi* bir işletim sistemine gömülebilecek şekilde baştan tasarlanmıştır. İlk dağıtım hedefi, Orange Pi 5 Max üzerinde çalışan Android 15 (tüm varyantları) olup, derleme hattı yanıp sönen görüntülerin yanı sıra doğrulanmış bir OTA `.zip` dosyası ve zorunlu hash dosyalarını üretir; böylece hiçbir dosya, doğrulanabilir bir parmak izi olmadan cihaza ulaşmaz. Linux, Windows ve diğer işletim sistemleri, aynı adaptör arayüzünün arkasında, yalnızca adaptörleri bekliyor — yeniden yazım değil.

Tasarım, operatör tarafından belirlenen ve mimari değişmezler olarak kabul edilen katı garantiler etrafında şekillenir: sıfır sistem bozulması, dağıtımdan önce her dosyanın zorunlu doğrulaması, ayrıntılı dağıtım (tümü birden veya %5/%10/%30…%100 aşamalı, durdurma ve ilerletme kontrolüyle), filonun tam görünürlüğü ve tek bir masaüstü karttan sahadaki milyonlarca cihaza kadar doğrusal ölçeklenebilirlik. Kilitli mimari, cihaz tarafında yerel Android A/B güncellemeleri — AOSP `update_engine` ile AVB/dm-verity ve otomatik önyükleme hatası geri alma — ile özelleştirilmiş, bağımsız bir Go kontrol düzlemini birleştirir; böylece güvenlik hem donanıma yakın önyükleme yolunda hem de sunucuda bulunur, tek bir kırılgan katmanda değil. İki arayüz kasıtlı olarak çıkarılabilir tutulmuştur: gerçek evrenselliğin vaadini taşıyan bir işletim sistemi adaptörü arayüzü ve aşamalı kampanyaları işletim sisteminden bağımsız hale getiren bir dağıtım motoru arayüzü. Tüm sistem, altı adet bağımsız sürümlendirilmiş `ota-*` alt modüle ayrılmıştır — tek parça bir yapı yerine yeniden kullanılabilir yapı taşları.

Helix OTA şu anda şartname/araştırma ve test kapsamı geliştirme aşamasındadır; depoda yetkili tasarım külliyatı, dokümantasyon dışa aktarım hattı ve alt modül iskeleti bulunur. Şeffaflık ilkesi gereği, henüz tamamlanmış bir üretim sunucusu ve ajanı bulunmadığı açıkça belirtilmiştir. Bugün sunulan, dürüstçe etiketlenmiş bir plan ve onun iskeletidir.

## Neden inşa ettik

OTA genellikle cihaz ve işletim sistemi bazında yeniden icat edilir ve kötü bir güncelleme tüm bir filoyu kullanılamaz hale getirebilir. Helix OTA, herhangi bir işletim sisteminin adaptörler aracılığıyla benimseyebileceği, evrensel ve güvenlik odaklı tek bir güncelleme sistemi olarak tasarlandı; geri alma ve doğrulama garantileri mimariye entegre edildi, sonradan eklenen özellikler olarak değil.

## Neden oyunun kurallarını değiştiriyor

"Cihazı asla kullanılamaz hale getirmeme" ve "güncellemeleri kademeli ve gözlemlenebilir şekilde yayma" ilkelerini, yük altında umut edilen en iyi çaba özellikleri olarak değil, hem önyükleme yoluna hem de kontrol düzlemine mimari olarak işlenmiş değişmezler olarak ele alıyor. Ayrıca, dağıtım motorunu ve işletim sistemi katmanını değiştirilebilir dikişler olarak tasarlayarak, aynı kontrol düzlemi bugün Android’i çalıştırabilirken, ileride yalnızca bir adaptör ekleyerek diğer işletim sistemlerini de desteklemeye hazır hale geliyor — çatallama, yeniden yazma veya güvendiğiniz güvenlik garantilerini baştan icat etme zorunluluğu yok.

## Yenilikçi yönleri

- **İki çıkarılabilir dikiş** — bir işletim sistemi adaptörü dikişi ve işletim sisteminden bağımsız bir dağıtım motoru — "evrensel" kavramını pazarlama jargonundan çıkarıp kod tabanının yapısal bir özelliğine dönüştürüyor.
- **Derinlemesine savunma güvenliği**: Cihaz tarafında yerel A/B (`update_engine`) + AVB/dm-verity + otomatik önyükleme hatası geri alma, *üstüne* sunucu tarafında gerçekleştirilen yapı doğrulama katmanları — bir güncellemenin kalıcı olabilmesi için birden fazla bağımsız kontrol noktasından geçmesi gerekiyor.
- **Katalog öncelikli, ayrıştırılmış** yapı: Altı yeniden kullanılabilir, bağımsız olarak sürümlendirilmiş `ota-*` alt modüle ayrıştırma; tek parça bir monolit yutmak yerine ihtiyacınıza göre seçip kullanabileceğiniz bir yapı.
- **HTTP/3 (QUIC) birincil taşıma protokolü**, otomatik HTTP/2 geri dönüşü ve anlaşmalı Brotli/gzip sıkıştırması ile — modern, düşük gecikmeli teslimat; başarısızlık yerine sorunsuz bir şekilde uyum sağlıyor.
- **Blöf karşıtı mühendislik**: Tasarım ve durum açıkça spesifikasyon aşamasında olarak işaretleniyor; henüz inşa edilmemiş hiçbir şey teslim edilmiş gibi iddia edilmiyor — dürüstlük, dipnotlardaki bir sorumluluk reddinden değil, mühendislik değerlerinin temel bir unsuru olarak dayatılıyor.

## En büyük teknik zorluklar ve çözümlerimiz

- **Kötü bir güncellemenin cihazı asla kullanılamaz hale getirmemesini garanti etmek** — OTA’nin en zor vaadi. Cihaz tarafında yerel Android A/B zorunluluğu ile çözüldü: `update_engine` etkin olmayan slota yazarken, çalışan slot aktif kalıyor; AVB/dm-verity önyükleme zincirini kriptografik olarak doğruluyor ve yeni slot önyüklemeyi başaramazsa cihaz otomatik olarak geri alıyor — tüm bunlar, bozuk bir yükün sunucuyu terk etmeden önce yakalanmasını sağlayan zorunlu ön dağıtım yapı doğrulama mekanizmasıyla destekleniyor.
- **Tek sistem, birçok işletim sistemi** — çekirdeğe Android varsayımlarını yerleştirmemekle çözüldü. Takılabilir bir işletim sistemi adaptörü dikişi, platforma özgü detayları izole ederken, işletim sisteminden bağımsız bir dağıtım motoru dikişi de kampanya mantığını taşınabilir tutuyor; her biri ayrı bir alt modül olarak tutulduğundan, yeni bir işletim sistemi eklemek tüm sistemi ameliyat etmek yerine basit bir ilave haline geliyor.
- **Kademeli, durdurulabilir dağıtımlar** — yüzde bazlı kohortlar, başarı/hata eşikleri ve açık durdur/ilerlet kontrolü ile çalışan özel bir dağıtım motoru ile çözüldü; bu motor, taşıma protokolünden bağımsız olarak kampanyaları yürütebilmesi için kasıtlı olarak HTTP bağlantısından arındırıldı.

İçerik

## Teknoloji Yığını

- **Go + Gin** — eşzamanlılık modeli ve hafif dağıtım ayak izi nedeniyle seçildi; kontrol düzlemini, dağıtım motorunu ve yapı doğrulayıcılarını çalıştırır, REST `/api/v1` birincil arayüzünü sunar.
- **Kotlin/KMP** — cihaz üzerindeki Android OTA aracısının mantığı farklı hedefler arasında paylaşabilmesi için seçildi; cihaz döngüsünün tamamını (sorgula / indir / doğrula / uygula / raporla) yönetir.
- **HTTP/3 (QUIC) → HTTP/2** — QUIC, düşük gecikmeli ve mobil bağlantılarda kesintiye dayanıklı teslimat için birincil taşıma katmanı olarak seçildi; otomatik HTTP/2 geri dönüşüyle hiçbir cihazın bağlantısız kalmaması sağlanır; **Brotli/gzip** yük boyutlarını küçültmek için isteğe bağlı olarak müzakere edilir.
- **PostgreSQL** — cihaz kayıtları, kampanyalar ve telemetri arasında ilişkisel bütünlüğün sağlanması için seçildi; burada filonun doğru durumu, ham yazma hızından daha önemlidir.
- **MinIO / S3** — büyük yazılım görüntülerinin ilişkisel katmandan bağımsız olarak standart nesne depolama alanında saklanması için yapı blob deposu olarak seçildi.
- **AOSP `update_engine` + AVB/dm-verity + `boot_control`** — Android’in kendi sınanmış Sanal A/B ve doğrulanmış önyükleme mekanizmalarının yeniden kullanılması, özel bir güncelleyici geliştirmekten daha güvenli olduğu için seçildi; cihaz üzerinde yuva değişimlerini ve kriptografik önyükleme doğrulamasını yönetir.
- **React** — operatörlerin oturum açtığı, yapıları yüklediği, dağıtımları yönettiği ve filonun sağlığını tek bir yerden izlediği yönetim paneli için seçildi.
- **OpenTelemetry + Prometheus/Grafana** — üretici bağımsız ölçümleme için seçildi; bir dağıtımın her aşamasının metrikler ve paneller aracılığıyla gözlemlenebilir olmasını sağlar, tahmin yürütmeye gerek bırakmaz.

## Durum ve Dürüstlük Notları

- **Durum: geliştirme aşamasında.** Projenin kendi "blöf karşıtı" yönetişim ilkelerine göre, **henüz çalışan bir üretim sunucusu veya aracısı yoktur** — bu, bir şartname/araştırma ve test kapsamı oluşturma aşamasıdır. Depo, yetkili tasarım külliyatını, belgeler dışa aktarma hattını ve alt modül iskeletini barındırır.
- Altı adet herkese açık yeniden kullanılabilir alt modül (`ota-protocol`, `ota-artifact-validator`, `ota-rollout-engine`, `ota-update-engine-bridge`, `ota-android-agent`, `ota-telemetry-schema`) `github.com/HelixDevelopment/` altında yer almaktadır.
- Depodaki test kapsamı ve gecikme süreleri, projenin kendi devam eden kayıt defteridir, bağımsız olarak doğrulanmamıştır. README’de atıfta bulunulan HelixConstitution maddeleri **DOĞRULANMAMIŞTIR**.
- **Lisans: Apache-2.0.**

**Öncelik katmanı:** Helix-birincil.

