---
name: HelixTerminator
slug: helixterminator
tier: helix-primary
order: 8
status: beta
license: Apache-2.0
private: false
tech:
  - Go microservices
  - Flutter / Dart (BLoC)
  - PostgreSQL
  - Kafka
  - RabbitMQ
  - Redis
  - SPIFFE/SPIRE + mTLS
  - Ed25519
  - Kubernetes + Helm + Terraform
  - OpenTelemetry
  - Grafana
  - Jaeger
  - Loki
repos:
  - https://github.com/HelixDevelopment/terminator
diagrams:
  - Three-channel architecture — Flutter clients ↔ gateway ↔ Go service mesh ↔ host agent / SSH proxy.
  - Zero-trust security flow — PKI issuing a short-lived SSH cert, vault-stored secret, mTLS between services.
  - Live collaboration panel — observer / co-pilot / owner sharing one terminal with CRDT sync.
  - AI-assist callout — terminal output with an inline "explain this output / draft runbook" overlay.
---

# HelixTerminator

**Ekipler için sıfır güven terminal platformu — her SSH oturumu güvenli, paylaşılabilir ve AI destekli.**

## Özet

HelixTerminator, kurumsal terminal ve SSH oturum yönetim platformu olarak Go mikro hizmetler sistemi üzerine inşa edilmiş, çoklu platformda çalışan Flutter istemcilerine sahiptir. Uzaktan oturumları sıfır güven modeliyle aracılık eder, kaydeder ve güvence altına alır; gerçek zamanlı iş birliği imkânı sunar ve terminal üzerinde AI desteği sağlar.

## Kısa Açıklama

HelixTerminator, sıfır güven prensiplerine dayalı bir kurumsal terminal/SSH yönetim platformudur: Go mikro hizmetlerden oluşan bir arka uç ve altı farklı platformda çalışan Flutter istemcileri. Sunucuları yönetir, bağlantılar aracılık eder, oturumları kaydeder, gerçek zamanlı iş birliği sağlar ve AI destekli komut yardımı, çıktı açıklaması ve olay müdahalesi sunar.

## Detaylı Açıklama

HelixTerminator, kurumsal düzeyde bir terminal ve uzaktan erişim platformudur. İki ana modülden oluşur — Terminal Platformu ve Bağlantı Aracısı — ve tek bir Flutter istemcisiyle altı platformu hedefleyen bir Go mikro hizmetler kataloğu üzerinden çalışır. Amacı, geçici SSH araçlarını tamamen ortadan kaldırmaktır: Artık her dizüstü bilgisayar için ayrı istemciler, özel anahtar dağılımı ve denetim boşlukları olmayacak; bunların yerine, uzaktan erişimi kişisel bir alışkanlık olmaktan çıkarıp altyapı olarak gören, yönetilebilir, denetlenebilir ve iş birliğine dayalı tek bir sistem gelecek.

Arka uç, uzaktan erişimin tüm yaşam döngüsünü baştan sona yönetir. Sunucular ve gruplar bastion/sıçrama sunucusu zincirleriyle yönetilir; bir SSH proxy’si parola, açık anahtar ve sertifika kimlik doğrulamasını aracılık eder; terminal I/O proxy’si oturumu WebSocket üzerinden aktarır; SFTP kesintisiz aktarımları destekler; bağlantı yönlendirme, kod parçacıkları ve çalışma alanı yönetimi ile oturum kayıtları, güvenilir bir şekilde yeniden oynatılabilen imzalı asciinema oynatıcıları halinde bir araya getirilir. Güvenlik, sonradan düşünülmüş bir ek değil, tasarım gereği sıfır güvendir: Bir kasası sıfır bilgi gizli depolama sağlar; bir PKI hizmeti kısa ömürlü SSH sertifikaları üreterek çalınabilecek kalıcı kimlik bilgilerinin önüne geçer; donanım destekli anahtar zincirleri (Secure Enclave/Android Keystore/DPAPI/HSM) anahtarları disk dışında tutar; FIDO2/WebAuthn ve OIDC/SAML kimlik doğrulama ön planda yer alır; ekleme yapılamayan, Merkle zincirli bir denetim günlüğü ise kurcalamaya karşı dayanıklı SOC 2/ISO 27001 kanıtları üretir. Bunun üzerine, gerçek zamanlı iş birliği özelliği sayesinde birden fazla operatör, gözlemci/yardımcı/sahip rolleriyle tek bir canlı oturumu paylaşabilir; CRDT arabellek senkronizasyonu ile tutarlılık sağlanır.

Terminalin kendisi üzerinde çalışan bir AI hizmeti, komut otomatik tamamlama, çıktının sade bir dille açıklanması, anomali tespiti, çalıştırma kitabı oluşturma ve olay anında pratik yardım gibi özellikler ekleyerek terminali sadece bir veri kanalı olmaktan çıkarıp kritik anlarda bir yardımcıya dönüştürür. Tüm platform, konteyner tabanlıdır — Kubernetes, Helm, Terraform ve OpenTelemetry, Grafana, Jaeger, Loki gibi eksiksiz bir gözlemlenebilirlik yığınına sahiptir — ve HelixTrack köprüsü ile yerel bir HelixLLM aracılığıyla daha geniş Helix ailesine entegre olur. Tüm bunlar, sahtecilik önleme doğrulama kapılarıyla desteklenen Helix Constitution altında çalışır.

## Neden inşa ettik

Ekipler, dağınık SSH istemcileri üzerinden uzaktan altyapıyı yönetirken ortak bir denetim izi, tutarlı bir gizli bilgi yönetimi ve bir olaya canlı müdahalede iş birliği yapma imkânı bulamıyor. HelixTerminator, uzaktan erişimi kişisel bir dizüstü bilgisayar aracından ziyade yönetişimli, sıfır güvenli ve ekip odaklı bir platforma dönüştürmek için geliştirildi.

## Neden oyunun kurallarını değiştiriyor

Tüm tedarik listesini tek bir platformda topluyor. SSH istemcisi, gizli bilgiler kasası, bastiyon/PKI katmanı, oturum kaydı, uyumluluk denetimi ve canlı iş birliği; ekiplerin normalde ayrı ayrı satın alıp birbirine bağladığı, her birinin kendi boşlukları olan bileşenlerdi. HelixTerminator bunları tek bir yönetişimli sistem olarak sunuyor, ardından bu araçların hiçbirinin tek başına yapamadığı bir şeyi gerçekleştiriyor: terminalin üzerine doğrudan bir AI katmanı yerleştirerek, olay anında yabancı çıktıları açıklıyor ve işlem kılavuzları hazırlıyor. Daha önce pratik olmayan bu yetenek, sıfır güvenli, değiştirilmesi kanıtlanabilir şekilde kaydedilmiş, operatörler arasında canlı paylaşılan ve AI destekli bir uzaktan erişim oturumunu tek bir ekrandan sunuyor.

## Yenilikçi yönleri

- **Çift modüllü tasarım** (Terminal Platformu + Bağlantı Aracısı), bir hizmet kayıt defteri üzerinden koordine edilerek platformun ve aracılık katmanının bağımsız olarak ölçeklenmesini ve gelişmesini sağlıyor.
- **Uçtan uca sıfır güvenli güvenlik**: PKI tarafından üretilen kısa ömürlü SSH sertifikaları, sıfır bilgi kasası, donanım destekli anahtar zincirleri ve Merkle zincirli denetim günlüğü — kalıcı kimlik bilgisi yok, doğrulanamaz iz yok.
- **CRDT tabanlı tampon senkronizasyonu ve açık gözlemci / yardımcı pilot / sahibi rolleriyle gerçek zamanlı oturum iş birliği**, birden fazla operatörün aynı terminalde birbirinin ayağına basmadan çalışabilmesini sağlıyor.
- **Canlı terminal üzerine entegre AI destekli operasyonlar**: operatörün tam ihtiyaç duyduğu noktada otomatik tamamlama, çıktı açıklaması, anomali tespiti ve olay/yönerge yardımı.
- **Tek kod tabanından altı platformu destekleyen çapraz platform Flutter istemcisi**, masaüstü, mobil ve web deneyimlerinin uyum içinde kalmasını sağlıyor.

## En büyük teknik zorluklar ve çözümlerimiz

- **Çalınabilecek kalıcı kimlik bilgisi olmadan uzaktan erişimi güvence altına almak** — uzun ömürlü anahtarlar, klasik ihlal vector noktasıdır. Talep üzerine kısa ömürlü SSH sertifikaları veren bir PKI hizmeti, sunucunun bile okuyamadığı gizli bilgileri saklayan sıfır bilgi kasası ve özel verilerin diskte açıkta kalmamasını sağlayan donanım destekli anahtar depolama (Secure Enclave / Android Keystore / DPAPI / HSM) ile çözüldü.
- **Birden fazla operatörün aynı oturumu sürerken tamponu bozmamasını sağlamak** — paylaşılan bir terminalde eşzamanlı düzenlemeler, tutarlılık açısından zor bir problemdir. CRDT tabanlı tampon senkronizasyonu ile çözüldü; merkezi bir hakem olmadan yakınsama sağladığı için ADR-006 uyarınca operasyonel dönüşüme tercih edildi.
- **Uyumluluk kanıtlarının sessizce değiştirilmesini imkânsız kılmak** — düzenlenebilir bir denetim günlüğü hiçbir şeyi kanıtlamaz. Ekleme yapılamayan, Merkle zincirli bir günlükle çözüldü; herhangi bir müdahale hash zincirini bozarak SOC 2 / ISO 27001 / FedRAMP kanıtlarının dışa aktarılabilir olmasını sağlıyor.
- **Üç ayrı kod tabanı olmadan masaüstü, mobil ve web’de tutarlı bir kullanıcı deneyimi sunmak** — BLoC modeli üzerine inşa edilen tek bir Flutter/Dart istemcisiyle çözüldü; tek bir kaynak koddan altı platforma hitap etmek için ADR-001 uyarınca Electron yerine Flutter tercih edildi.

İçerik

## Teknoloji Yığını

- **Go mikroservisleri** — arka uç filosu (SSH proxy, terminal, vault, PKI, denetim ve daha fazlası); eşzamanlılık modeli ve küçük çalışma zamanı ayak izi sayesinde aynı anda çok sayıda uzun ömürlü akış oturumunu barındıran hizmetler için ideal (ADR-002: Go, Rust/Node’a tercih edildi).
- **Flutter / Dart (BLoC)** — altı platformda tek bir istemci kod tabanı; BLoC ile durum yönetimi öngörülebilir hale getirildi; Flutter, ayrı yerel ve web ön uçları sürdürme ihtiyacını ortadan kaldırmak için Electron’a tercih edildi (ADR-001).
- **PostgreSQL** — birincil veri deposu; olgun ve iyi anlaşılmış işlemsel çekirdeği nedeniyle CockroachDB’ye tercih edildi (ADR-004).
- **Kafka + RabbitMQ** — oturum parçalarını ve olayları taşıyan mesajlaşma ve akış katmanı (ADR-003); dayanıklı bir günlük ile esnek kuyruklamanın birleşimi.
- **Redis** — terminal kaydırma tamponlarını ve düşük gecikme süresinin dayanıklılıktan daha önemli olduğu sıcak oturum durumlarını barındırır.
- **SPIFFE/SPIRE + mTLS** — kriptografik iş yükü kimliği sağlar (ADR-005); böylece hizmetler arası trafik karşılıklı olarak doğrulanır, sıfır güven ilkesi ağ örgüsü içinde de uygulanır, yalnızca kenarda değil.
- **Ed25519 (EdDSA)** — JWT’leri ve oturum kayıtlarını imzalar (ADR-009); kaydedilen oturumların doğrulanabilirliğini sağlayan hızlı ve modern imzalar sunar.
- **Kubernetes + Helm + Terraform** — konteyner tabanlı dağıtım, tekrarlanabilir ve sürüm kontrollü altyapı (ADR-007/008).
- **OpenTelemetry, Grafana, Jaeger, Loki** — izleme, metrikler, kontrol panelleri ve günlükler için gözlemlenebilirlik yığını; **Falco, Trivy, Cosign, Sealed Secrets** — çalışma zamanı tehdit tespiti, görüntü tarama, yapıt imzalama ve tedarik zinciri boyunca şifreli gizli bilgi dağıtımı.

## Durum ve Dürüstlük Notları

- **Durum: beta.** Önemli ve aktif olarak geliştirilen bir kod tabanı (oluşturulma tarihi: 04.07.2026). Projenin MVP araştırma paketindeki sayısal spesifikasyon rakamları (uç nokta, tablo ve hizmet sayıları), `docs/research/mvp/` dizinindeki tasarım/şartname hedefleridir; tam olarak uygulandıkları doğrulanmamıştır ve bu nedenle yukarıda sunulanlar, gönderilmiş metrikler değil, mimari kapsam olarak değerlendirilmelidir. Gecikme/SLO ve "üretime hazır" iddiaları bağımsız olarak doğrulanmamıştır.
- **Lisans: Apache-2.0** (GitHub API’a göre).

**Öncelik katmanı:** Helix-birincil.

