---
name: Parallels-Utils
slug: parallels-utils
tier: serverfactory-tertiary
order: 32
status: active (niche, macOS-specific Shell/Python toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~5.3K bytes)
  - Python 3 (~3K bytes)
  - Parallels (macOS)
  - Settings files (.settings)
repos:
  - https://github.com/Server-Factory/Parallels-Utils
diagrams:
  - Image lifecycle (build → compress → publish → retrieve → run)
  - One provider endpoint → many workstations pulling the same image matrix
  - Settings-file map (location/provider/sync) feeding the scripts
---

**Parallels VM görüntülerinizi sıkıştırın, yayınlayın ve her makinede yeniden kullanın.**

## Özet

Parallels-Utils, Parallels (macOS) sanal makine görüntülerini yönetmek için geliştirilmiş bir Server Factory araç setidir: geliştirme ve test için kullanılan görüntü "matrislerini" sıkıştırma ve senkronize etme, uzak bir uç noktaya yayınlama ve bu görüntüleri birden fazla iş istasyonu veya sunucuda alma/çalıştırma işlemlerini gerçekleştirir. Tek başına kullanılabildiği gibi Server Factory’un bir parçası olarak da çalışabilir.

## Kısa açıklama

Parallels VM görüntülerinin macOS üzerindeki yaşam döngüsünü yönetmek için tasarlanmış bir Shell/Python araç setidir. Parallels görüntülerini sıkıştırır ve senkronize eder, uzak bir uç noktaya yayınlar, ardından bu görüntüleri birden fazla bilgisayarda alır ve çalıştırır — basit ayar dosyalarıyla yönetilir, bağımsız olarak veya Server Factory içinde kullanılabilir.

## Ayrıntılı açıklama

Parallels-Utils, macOS tabanlı geliştirme süreçlerinde karşılaşılan pratik bir DevOps sorununu çözer: ekipler, geliştirme ve test için farklı işletim sistemleri/yapılandırmalardan oluşan Parallels sanal makine "matrisleri" oluşturur ve bu görüntülerin sıkıştırılması, yayınlanması, alınması ve birden fazla makinede tutarlı şekilde çalıştırılması gerekir. Araç seti, tam da bu yaşam döngüsünü sağlar. Bir senkronizasyon mekanizması Parallels görüntülerini sıkıştırır ve güncel tutar; bir yayınlama mekanizması görüntüleri uzak bir uç noktaya yükler; bir alma mekanizması ise herhangi bir iş istasyonu veya sunucunun bu yayınlanmış görüntüleri çekip VM olarak çalıştırmasını mümkün kılar. Yapılandırma kasıtlı olarak basit ve dosya tabanlıdır: `image_location.settings` görüntülerin dosya sistemindeki konumunu tanımlar, `image_provider.settings` yayınlanan görüntülerin temel URL’unu belirler, `image_sync.sh` ise yükleme betiğini tanımlar — örnekler `Examples` dizini altında sunulur. Operatörler, görüntüleri yayınlamak için `publish_images.sh`, VM’leri başlatmak için ise `run.sh` komutlarını kullanır. Araç seti, ilgili macOS sürümü için Parallels ve Python 3 gerektirir. Çift kullanım amacıyla tasarlanmıştır: daha büyük bir Server Factory projesinin parçası olarak çalışabildiği gibi tamamen bağımsız olarak da kullanılabilir; bu da kuruluşun ayrıştırma felsefesini yansıtır. Hatta kısa bir video eğitimi bağlantısı da sunar. Server-Factory ailesinin bir parçası olarak, Qemu-Utils (Linux/QEMU eşdeğeri) ile tamamlayıcıdır ve ekosisteme hem macOS/Parallels hem de çapraz platform/QEMU arka uçlarında VM görüntüsü yönetimi sunar.

## Neden geliştirdik

Bir ekip içinde tutarlı VM geliştirme/test ortamlarını paylaşmak zahmetlidir — görüntüler büyük boyutludur ve her makinenin aynı matrise sahip olması gerekir. Parallels-Utils, sıkıştırma, yayınlama ve alma işlemlerini otomatikleştirerek her yerde yeniden üretilebilir bir Parallels VM seti sağlar.

## Neden devrim niteliğinde

Ağır ve hantal Parallels görüntülerini, herhangi bir makinenin çekebileceği ve çalıştırabileceği yayınlanabilir, senkronize edilebilir bir yapıya dönüştürür — böylece standart geliştirme/test ortamı, her mühendisin elle yeniden oluşturması gereken bir şey olmaktan çıkar, çekip kullanabileceğiniz bir şeye dönüşür. Bunu, önemsiz ayar dosyası yapılandırmasıyla ve Server Factory’un geri kalanına bağımlılık olmadan gerçekleştirir; kuruluşun ayrıştırma felsefesine sadık kalarak hem kendi başına kullanışlı, hem de daha büyük araç zincirinin iyi bir parçasıdır.

İçerik

## Yenilikçi Yönler

- Geliştirme/test aşamaları için Parallels görüntü "matrislerinin" sıkıştırılması ve senkronizasyonu.
- Görüntülerin birçok bilgisayarda yeniden kullanılabilmesini sağlayan yayınla/al/ iş akışı.
- Örneklerle birlikte sunulan ayar dosyası tabanlı yapılandırma (konum/sağlayıcı/senkronizasyon).
- Çift kullanım: Bağımsız çalışma veya Server Factory bileşeni olarak.

## Zorluklar ve Çözümler

- **Büyük görüntü dağıtımı:** Sıkıştırma ve uzak uç noktaya yayınla + al iş akışı ile çözüldü.
- **Makineler arası tekrarlanabilirlik:** Her ana makinenin aynı görüntü setini çözümlemesini sağlayan sağlayıcı/konum ayarları ile çözüldü.
- **Kullanım kolaylığı:** Basit `publish_images.sh` / `run.sh` betikleri ve örnek ayar dosyaları ile çözüldü.

## Teknoloji Yığını (Neden ve Nasıl)

- **Shell** — yayınla/çalıştır/senkronize et betikleri (birincil dil, ~5,3K bayt).
- **Python 3** — destekleyici araçlar (zorunlu bağımlılık, ~3K bayt).
- **Parallels (macOS)** — yönetilen sanallaştırma altyapısı.
- **Ayar dosyaları (`.settings`)** — konum/sağlayıcı/senkronizasyon için bildirimsel yapılandırma.

> Not: GitHub, depo Server-Factory organizasyonu içinde bir çatallanma olarak işaretlenmiştir. Niş, macOS’a özgü bir çözümdür. AI ile ilişkili değildir.

