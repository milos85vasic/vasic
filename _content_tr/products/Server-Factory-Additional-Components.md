---
name: Server Factory — Additional Components
slug: server-factory-additional-components
tier: serverfactory-tertiary
order: 33
status: mixed / early-stage (service factories are placeholder-documented — UNVERIFIED; Definitions & Utils are supporting data/tooling)
license: UNVERIFIED
private: false
tech:
  - Kotlin (service factories, on Core Framework)
  - Shell (Utils, Definitions packs)
  - Gradle
  - Docker (target runtime)
  - SSH / OpenSSH (Utils bootstrap)
  - SonarQube
repos:
  - https://github.com/Server-Factory/Web-Service-Factory
  - https://github.com/Server-Factory/SonarQube-Factory
  - https://github.com/Server-Factory/Caching-Proxy-Factory
  - https://github.com/Server-Factory/Docker-Definitions
  - https://github.com/Server-Factory/Stack-Definitions
  - https://github.com/Server-Factory/Software-Definitions
  - https://github.com/Server-Factory/Utils
diagrams:
  - Family tree (Core Framework → {Mail, Web, SonarQube, Caching-Proxy} factories)
  - Data-vs-engine split (Definitions packs feeding the factory execution engine)
  - Utils spotlight (init_ssh_access.sh bootstrap flow)
  - Maturity legend distinguishing flagship (Mail) from early-stage service factories
---

**Server Factory Provizyon Araç Zincirinin Yardımcı Bileşenleri**

## Özet

Mail Server Factory ve Çekirdek Çerçeve’nin ötesinde, Server-Factory organizasyonu birkaç daha küçük bileşeni barındırır: hizmet bazlı "fabrikalar" (Web Hizmeti, SonarQube, Önbellekleme Vekil Sunucusu), bildirimsel yapılandırma paketleri (Docker/Yığın/Yazılım Tanımları) ve paylaşılan Araçlar. Bu birleştirilmiş sayfa, onları tam olarak belirlenmiş ürünler gibi değil, çoğu erken aşamada ya da taslak belgeli olan bileşenler olarak dürüstçe ele alıyor.

## Kısa açıklama

Server Factory destek depoları grubu: Web-Service-Factory, SonarQube-Factory ve Caching-Proxy-Factory (hizmet bazlı provizyon araçları, çoğunlukla erken aşamada); Docker/Stack/Software-Definitions (çerçeve tarafından tüketilen bildirimsel yapılandırma paketleri); ve Utils (SSH erişim yardımcıları ve genel araçlar). Tümü Çekirdek Çerçeve üzerine inşa edilmiştir.

## Ayrıntılı açıklama

Bu sayfa, Server-Factory depolarının geri kalanını bir araya getiriyor çünkü tek tek ele alındıklarında çoğu küçük ya da kasıtlı olarak yetersiz belgelenmiş durumda ve her birini tamamlanmış bir ürün gibi sunmak, olgunluk düzeylerini abartılı gösterirdi. Bileşenler üç gruba ayrılıyor. **Hizmet fabrikaları**, Mail Server Factory modelini diğer sunucu rollerine uyarlıyor: **Caching-Proxy-Factory** ("Kendi önbellekleme vekil sunucunuzu çalıştırın"), önbellekleme vekil sunucusu, kendi imzaladığı sertifika ve güvenlik sertifikası alma HTTP uç noktasını temel özellikler olarak sıralıyor; **SonarQube-Factory** ("Kendi SonarQube sunucunuzu çalıştırın") yazılım geliştirme amaçlı tasarlanmış; **Web-Service-Factory** ise web siteleri ve mikro hizmetler gibi hedefleri dağıtmak için bir web sunucusunu örnekleyip yapılandırıyor. Üçü de Kotlin projeleri olarak Çekirdek Çerçeve üzerine inşa edilmiş olsa da, kamuya açık README dosyaları çoğunlukla yer tutucu ("Belirlenecek" uyumluluk, özellikler, kurulum ve kullanım için) — bu nedenle belirtilen amacın ötesindeki somut yetenekleri DOĞRULANMAMIŞ durumda. **Tanımlama paketleri** — **Docker-Definitions**, **Stack-Definitions** ve **Software-Definitions** — çerçevenin Docker görüntülerini, yığınlarını ve yazılımlarını nasıl oluşturup dağıtacağını bilmesi için tükettiği bildirimsel yapılandırma depolarıdır; bunlar uygulamalardan ziyade sürüm sabitli veri paketleridir. **Utils** ise aile için genel yardımcıları sunar; bunlar arasında, bir SSH anahtarı oluşturan ve sonraki provizyon işlemleri için parola gerektirmeyen root erişimini etkinleştirmek üzere bu anahtarı uzak bir sunucuya yükleyen `init_ssh_access.sh` betiği de yer alır. Bu bileşenler, amiral gemisi Mail Server Factory’un etrafında provizyon araç zincirini tamamlıyor.

## Neden inşa ettik

Server Factory modeli genelleştirilebilir olacak şekilde tasarlandı: Bildirimsel bir tanımdan posta sunucusu sağlayabildiğinizde, aynı motorun web sunucuları, önbellekleme vekil sunucuları ve kod kalitesi sunucularını da sağlaması gerekir — her rol için özel mantık yerine yeniden kullanılabilir tanımlama paketleri ve paylaşılan araçlarla beslenerek. Bu depolar, kanıtlanmış modelin yeni sunucu türlerine genişletilmesindeki bu genelleştirme sürecini temsil ediyor. Buradaki değerleri, modelin erişimini kanıtlamalarıdır; olgunluk düzeyleri değişkenlik gösteriyor ve bu sayfa, hangilerinin yönelim, hangilerinin tamamlanmış olduğunu kasten net bir şekilde ortaya koyuyor.

İçerik

## Neden bir oyun değiştirici (ölçülü bir yaklaşımla)

Bir bütün olarak ele alındığında, bu setler Çekirdek Çerçeve’nin farklı sunucu türlerinde yeniden kullanılabilirliğini gösterirken, bildirimsel verileri (Tanımlar) yürütmeden (fabrikalar) ayırıyor. Tek tek bakıldığında ise hizmet fabrikaları erken aşamada olup, tamamlanmış ürünler olarak değil, yönelim olarak sunulmalıdır.

## Yenilikçi yönleri

- Tek bir tedarik çerçevesi, posta/web/önbellek vekil sunucusu/SonarQube rollerini kapsayacak şekilde genelleştirildi.
- Bildirimsel Tanımlar paketleri (Docker/Yığın/Yazılım), yürütme motorundan ayrıştırıldı.
- Paylaşılan Araçlar (ör. tek komutla şifresiz SSH önyüklemesi), fabrikalar arasında yeniden kullanıldı.

## Zorluklar ve çözümler

- **Tek bir motorun farklı sunucu rollerinde kullanılması:** Her fabrika Çekirdek Çerçeve üzerine inşa edilerek çözüldü.
- **Yapılandırmanın koddan ayrılması:** Tanımlar depoları, sürüm sabitlenmiş veri paketleri olarak ele alınarak çözüldü.
- **(DOĞRULANMAMIŞ):** Hizmet fabrikalarının README dosyaları yer tutucu niteliğinde; uygulama bütünlüğü kamu belgelerinden doğrulanamıyor — erken aşama olarak sunulmalı.

## Teknoloji yığını (neden + nasıl)

- **Kotlin** — Web-Hizmet-Fabrikası, SonarQube-Fabrikası, Önbellek-Vekil Sunucusu-Fabrikası (Çekirdek Çerçeve üzerine inşa edildi).
- **Shell** — Araçlar ve Tanımlar paketleri (betikler/yapılandırma).
- **Gradle** — Fabrikalar genelinde `./gradlew test` derleme/test akışı.
- **Docker** — Hedef çalışma zamanı, Docker-Tanımlar tarafından tanımlandı.
- **SSH / OpenSSH** — Araçların şifresiz erişim önyüklemesi.
- **SonarQube** — SonarQube-Fabrikası tarafından tedarik edilen sunucu (ve Mail Server Factory’un temiz geçiş raporladığı sunucu).

> Dürüstlük notu: Bu depoların çoğu kuruluş içi çatallamalar; hizmet fabrikaları yer tutucu belgelerle sunuluyor ve anayasanın §11.4.6 maddesi uyarınca DOĞRULANMAMIŞ olarak işaretlenmiş durumda. Mail Server Factory ve Çekirdek Çerçeve’nin açıkça altında sıralanıyorlar.

