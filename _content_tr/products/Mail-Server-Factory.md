---
name: Mail Server Factory
slug: mail-server-factory
tier: serverfactory-tertiary
order: 29
status: production (reports 439 tests at 100% pass and a clean SonarQube gate)
license: UNVERIFIED
private: false
tech:
  - Kotlin (2.0.21)
  - Shell
  - Docker
  - QEMU
  - JSON (declarative config)
  - Gradle 8.14.3 / Java 17
  - Caffeine
  - G1GC-tuned JVM
  - Prometheus-compatible metrics
  - Sieve
repos:
  - https://github.com/Server-Factory/Mail-Server-Factory
  - https://github.com/Server-Factory/Mail-Server-Factory-Website
diagrams:
  - JSON-in → Factory engine → installed Docker mail stack (Postfix/Dovecot/TLS)
  - Connection-type fan-out (local/SSH/Docker/K8s/AWS SSM/Azure/GCP/Libvirt) to targets
  - Distribution matrix (Western/Russian/Chinese families) with unattended-install badges
  - Security layer callouts (AES-256-GCM, firewall ports, TLS/HSTS, RBAC, audit log)
---

**Posta sunucunuzu patron gibi yönetin — JSON ile tanımlayın, her yere dağıtın.**

## Özet

Mail Server Factory, üretime hazır, otomatik posta sunucusu sağlama aracıdır. Kullanıcı basit bir JSON yapılandırması yazar; Fabrika bu yapılandırmayı yorumlar ve hedef işletim sisteminde tüm kurulum ve başlatma işlemlerini gerçekleştirerek, 12 bağlantı türü üzerinden Docker tabanlı, gevşek bağlı bir posta yığını dağıtır.

## Kısa açıklama

Kotlin/Shell tabanlı bir araç olan Mail Server Factory, JSON tanımlamasını tamamen kurulu, Dockerize bir posta sunucusuna dönüştürür. 12 bağlantı türünü (SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt ve diğerleri), eksiksiz bir güvenlik çerçevesini, 25 Linux dağıtımını destekler ve 439 başarılı testle birlikte gelir.

## Uzun açıklama

Gerçek ve güvenli bir posta sunucusu kurmak, sistem yönetiminde klasik bir geçiş ritüeli — ve aynı zamanda en güvenilir şekilde can sıkıcı olanlardan biridir. Postfix, Dovecot, TLS sertifikaları, DNS kayıtları, güvenlik duvarı kuralları ve dağıtıma özgü tuhaflıkların hepsi kusursuz bir şekilde hizalanmalıdır; tek bir yanlış yönerge sessizce geri dönen e-postalar ya da açık bir röle anlamına gelebilir. Mail Server Factory, bu zor kazanılmış, hataya açık uzmanlık bilgisinin tamamını yazılıma dönüştürür. Her bir bileşeni yabancı bir işletim sistemi üzerinde elle yapılandırmak yerine, son kullanıcı istenen sonucu basit bir JSON belgesi olarak yazar; Fabrika bu belgeyi okur ve hedef işletim sisteminde gerekli kurulum ve başlatma adımlarını tam olarak uygulayarak, her bileşeni gevşek bağlı şekilde çalışan Docker tabanlı bir posta yığını oluşturur — bu tasarım seçimi, yığının yatay ölçeklenebilir kalmasını sağlar ve herhangi bir bileşenin izole şekilde yükseltilmesine ya da değiştirilmesine olanak tanır. Ayrıca, araç kasıtlı olarak erişimden bağımsızdır: 12 bağlantı türü, aynı aracın ve aynı JSON belgesinin yerel bir makineyi, SSH üzerinden uzak bir sunucuyu, Docker ya da Kubernetes çalışma ortamını, AWS SSM / Azure Seri Konsol / GCP OS Login üzerinden bulut örneklerini ya da Libvirt üzerinden sanal makineleri hedeflemesine imkân verir — aynı bildirimsel tanımlama, nereye yönlendirirseniz oraya sağlanır. Batı (Ubuntu, Debian, CentOS, Fedora, AlmaLinux, Rocky, openSUSE), Rus (ALT, Astra, ROSA) ve Çin (openEuler, openKylin, Deepin) ailelerinden 25 Linux dağıtımını destekler; preseed/kickstart/cloud-init/autoyast ile otomatik kurulum ve testler için QEMU tabanlı sanal makine otomasyonu sunar. Kurumsal özellikler kapsamlıdır: AES-256-GCM şifreleme, zorunlu parola ve SSH anahtarı politikaları, posta portları (25/587/465/993/995) için otomatik güvenlik duvarı yapılandırması, TLS/SSL ile sertifika doğrulama ve HSTS, denetim günlüğü ve RBAC. Operasyonel özellikler arasında JVM ayarlamaları (G1GC), Caffeine önbellekleme, bağlantı havuzu, Prometheus uyumlu metrikler, yapılandırılmış günlükleme, sıcak yeniden yükleme yapılandırması ve gizli bilgi yönetimi yer alır. Proje, %100 başarı oranıyla 439 testi ve temiz bir SonarQube kalite kapısını raporlar. Server-Factory organizasyonunun amiral gemisidir.

## Neden Geliştirdik

Güvenli ve üretim ortamına uygun bir posta sunucusu kurmak, hataya açık ve işletim sistemi özelinde gerçekleştirilen bir süreç olarak bilinir. Mail Server Factory, bu uzmanlığı bildirimsel bir JSON modeli ve bir yürütme motoru aracılığıyla yakalar; böylece doğru yapılandırılmış, güvenli ve Docker tabanlı bir posta altyapısı, herhangi bir desteklenen hedef sistemde elle adım adım çalışmaya gerek kalmadan yeniden oluşturulabilir.

## Neden Oyun Değiştirici

Posta sunucusu sağlama işlemini, uzmanlık gerektiren, günler süren ve tam olarak doğru yapılması zorunlu bir uğraştan, bir yapılandırma dosyası yazma eylemine indirger — ardından bu eylemi 12 bağlantı türü ve 25 Linux dağıtımı üzerinde taşınabilir hale getirir ve kurulumdan itibaren kurumsal güvenlik varsayılanlarıyla güçlendirir. Sonuç, tekrarlanabilir ve *doğrulanabilir* niteliktedir: Aynı JSON her seferinde aynı güvenli altyapıyı üretir ve projenin 439 başarılı test sonucu ile temiz SonarQube geçidi, işi yapan motorun kendisinin itibarına güvenmek yerine hesap verebilir olmasını sağlar.

## Yenilikçi Yönleri

- Bildirimsel JSON → hedef işletim sisteminde yorumlanarak kurulum/başlatma.
- Tek bir araç altında 12 bağlantı türü (yerel, SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt ve diğerleri).
- 25 dağıtım desteği ile kesintisiz kurulum (preseed/kickstart/cloud-init/autoyast) ve QEMU tabanlı otomasyon.
- Bağımsız ölçeklendirme/güncelleme için gevşek bağlı Docker tabanlı altyapı.

## Zorluklar ve Çözümler

- **İşletim sistemi/dağıtım çeşitliliği:** Dağıtım bazlı reçeteler, kesintisiz kurulum yapılandırmaları ve QEMU tabanlı çapraz dağıtım testleriyle çözüldü.
- **Birçok dağıtım hedefine ulaşma:** Ortak bir kurulum motoru altında 12 takılabilir bağlantı türüyle çözüldü.
- **Varsayılan olarak güvenlik:** AES-256-GCM, zorunlu anahtar/parola politikaları, otomatik güvenlik duvarı kuralları ve TLS/HSTS ile çözüldü.
- **Doğruluğa güven:** 439 testten oluşan bir test paketi (tam başarı oranı) ve temiz SonarQube geçidiyle çözüldü.

## Teknoloji Yığını (Neden ve Nasıl)

- **Kotlin** — Fabrika motoru ve kurulum adımı mantığı (179K bayt; Kotlin 2.0.21).
- **Shell** — Sağlama betikleri, ISO/QEMU yöneticileri ve işletim sistemi otomasyonu (bayt cinsinden baskın).
- **Docker** — Dağıtılmış, gevşek bağlı posta altyapısı için çalışma zamanı.
- **QEMU** — Çapraz dağıtım kurulum ve testleri için sanal makine otomasyonu.
- **JSON** — Kullanıcıya yönelik bildirimsel yapılandırma biçimi.
- **Gradle 8.14.3 / Java 17** — Derleme araç zinciri.
- **Caffeine** — Çok bölgeli önbellekleme; **G1GC ayarlı JVM** performans için.
- **Prometheus uyumlu metrikler** — İzleme; Grafana/ELK uyumlu.
- **Sieve** — Posta filtreleme kuralları (dil istatistiklerinde küçük yer kaplar).

> Not: GitHub, depoyu Server-Factory organizasyonu içinde bir çatallama olarak işaretler. AI ürün serisinden önce geliştirilmiştir; bir AI aracı olarak değil, olgun bir DevOps/sağlama amiral gemisi olarak sunulur.

