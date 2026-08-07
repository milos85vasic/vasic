---
name: HelixGitpx
slug: helixgitpx
tier: helix-primary
order: 17
status: shipped
license: TBD
private: false
tech:
  - Go monorepo
  - Angular 19 + Nx
  - Kotlin Multiplatform + Compose
  - Kubernetes + Helm + Argo CD + Kustomize
  - OPA (Rego)
  - Docusaurus
  - Astro
  - mise
repos:
  - https://github.com/HelixDevelopment/HelixGitpx
diagrams:
  - Hub-and-spoke federation — one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
  - Conflict-resolution flow — divergent mirrors → policy/AI resolver → reconciled single truth.
  - Delivery stack — Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.
---

# HelixGitpx

**Her yerde yansıtılan tek bir gerçek kaynağı — bir düzine sunucuda federasyonlu Git.**

## Özet

HelixGitpx (Helix Git Proxy eXtended), federasyonlu bir Git vekil sunucusu olup tek bir gerçek kaynağı birçok Git sunucusunda yansıtarak kaçınılmaz çakışmaları politika ve AI destekli akışlarla çözer. v1.0.0 GA sürümüne ulaştı.

## Kısa açıklama

HelixGitpx, federasyonlu bir Git vekil sunucusu olarak tek bir gerçek kaynağı onlarca Git sunucusunda — GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit ve diğerleri — yansıtır ve eşitleme çakışmalarını politika ve AI destekli akışlarla çözer. v1.0.0 GA sürümü olarak yayınlandı.

## Ayrıntılı açıklama

HelixGitpx — "Helix Git Proxy eXtended" — federasyonlu bir Git vekil sunucusu olup tek bir gerçek kaynağı birçok Git sunucusunda yansıtarak aynı depoyu birden fazla yerde barındırmanın kaçınılmaz kıldığı çakışmaları çözer. Desteklediği sunucular, Git ekosisteminin tamamını andıran bir harita gibidir: GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut ve genel Git-over-HTTPS. Basit bir `git push` komutunun bir düzine uzak sunucuya gönderilmesi ya doğrudan başarısız olur ya da daha kötüsü, yansımaların sessizce birbirinden uzaklaşmasına yol açar. HelixGitpx ise politika ve AI destekli çözüm akışlarıyla bu sapmaları tek bir yetkili gerçekliğe geri döndürür.

Proje, temel aşamadan genel kullanıma kadar tam bir yol haritası sunan `m1-foundation` ile `m8-ga` arasındaki kilometre taşlarıyla v1.0.0 GA sürümüne ulaştı. Üç katmanlı bir ürün olarak tasarlandı: federasyon motorunu barındıran Go monorepo (bir platform, on sekiz hizmet, kod üretimi ve iskele araçları); Angular 19 + Nx web uygulaması; ve Kotlin-Multiplatform + Compose istemci kabukları, ortak kod tabanından Android, iOS ve Masaüstü için yerel deneyimler sunar. Platform dağıtımı, Kubernetes çekirdeğine özgü olarak — Helm grafikleri, Argo CD uygulamaları, Kustomize katmanları, SQL ve OPA politikaları — gerçekleştirilir. CI boru hatları, kazara dağıtımı önlemek için açıkça tetiklenir. Kamu belgeleri, bir Docusaurus sitesi (docs.helixgitpx.io) ve bir Astro pazarlama sitesi (helixgitpx.io) olarak yayınlanır.

Yönetim, katı ve anayasal ilkelerle yürütülür; bu bir formalite değil, bir özelliktir: projenin yük taşıyan belgesi Constitution’dur. Bu belgenin II. Maddesi, her modülde ve her etkileşimde yedi tür test matrisinin %100 kapsama oranını zorunlu kılar. Taklitler yalnızca birim testlerinde kullanılabilir ve tek bir atlanmış test bile kabul edilmez. Tek seferlik bir doğrulayıcı, tüm yapı kontrollerini, `go vet` ve `go test` komutlarını çalışma alanının tamamında yürütür. Her gönderim, yapılandırılmış tüm sunuculara dağıtılır — böylece "yansımalar eşleşiyor" durumu, sistem tarafından her commit’te zorunlu kılınır, bir insanın hatırlamasına bırakılmaz.

## Neden geliştirdik?

Bir depoyu birçok Git sunucusunda — yedeklilik, egemenlik veya bölgesel platformlara erişim için — tutarlı halde korumak kırılgan ve manuel bir süreçtir; farklılaşan yansımaların uzlaştırılması zordur. HelixGitpx, çoklu sunucu yansıtmayı ilk sınıf, çakışma farkındalığına sahip bir yetenek haline getirmek için geliştirildi.

İçerik

## Neden bir oyun değiştirici?

"Birçok uzak depoya gönder ve umut et" şeklindeki kırılgan, manuel statükoyu, tek bir yetkili doğruluk kaynağına ve otomatik, politika artı AI tabanlı çakışma çözümüne sahip yönetilen bir federasyona dönüştürüyor. Üstelik bunu, çoğu araç tarafından sessizce göz ardı edilen bölgesel platformları (GitFlic, GitVerse, Gitee) da kasıtlı olarak dahil ederek, alışılmadık derecede geniş bir yelpazedeki sunucularda gerçekleştiriyor. Böylece yedeklilik, veri egemenliği ve bu ekosistemlere erişim, bakım yükü olmaktan çıkıp tek seferde yapılandırdığınız bir yeteneğe dönüşüyor.

## Yenilikçi olan ne?

- **Yukarı akışların genişliği** — GitHub ve GitLab’dan GitFlic, GitVerse ve Gitee gibi bölgesel platformlara kadar on iki ve üzeri Git barındırıcısı, tek bir proxy arkasında standartlaştırılmış.
- **Politika ve AI destekli çakışma çözümü** — Ayrışmalar, elle aynaları karşılaştıran bir insan tarafından değil, bir politika motoru ve AI çözücüsü tarafından uzlaştırılıyor.
- **Tek doğruluk kaynağına dayalı federasyon** — Tüm yukarı akışların dahil olduğu bir gönderim modeli; tek bir yetkili repo gerçek kaynaktır ve her barındırıcı, bu kaynağa senkronize edilmiş bir ayna olarak tutulur.
- **Anayasa düzeyinde sıkı testler** — Yedi test türünde %100 kapsama, atlama yok, tek seferlik bir "yeşil-suite" betiğiyle kanıtlanmış; inançla değil, somut olarak doğrulanmış.

## En büyük teknik zorluklar ve çözümleri

- **Birçok yukarı akışta ayrışma ve çakışmalar.** Aynı repo, on iki farklı yerde barındırıldığında, iki farklı sunucu farklı yazımları kabul ettiği anda sapmaya başlar. Çözüm: Tek bir doğruluk kaynağına sabitlenmiş politika ve AI destekli çözüm akışları, artı tüm yukarı akışların senkronize edildiği bir gönderim sistemiyle her ayna, o tek kaynağa yakınsar.
- **Farklı Git barındırıcıları için tek tip destek.** Her barındırıcı kendi kimlik doğrulama yöntemine, tuhaflıklarına ve API’a sahip. Çözüm: `Upstreams/` altında barındırıcıya özel yapılandırma betikleri ve bu farklılıkları soyutlayan bir platform katmanı; yeni bir barındırıcı eklemek, yeniden yazım değil, yapılandırma meselesi.
- **Her birleştirmeden önce doğruluğun kanıtlanması.** Çözüm: Zorunlu yedi test türünden oluşan bir matris ve `verify-everything.sh` adlı tek seferlik bir kontrol kapısı; tüm test setini çalıştırır, kümeye ulaşılamadığında temiz bir şekilde kısa devre yapar, böylece doğruluk hem yerel hem de CI ortamında kanıtlanabilir.

## Teknoloji yığını

- **Go monorepo** — Çekirdek proxy ve federasyon motoru: Bir platform artı 18 hizmet, kod üretimi ve iskele, tüm motor tek bir repoda bir bütün olarak derlenip test edilecek şekilde tutuluyor.
- **Angular 19 + Nx** — Web uygulaması; Nx, büyük bir ön yüz için gereken monorepo derleme/önbellekleme yapısını sağlıyor.
- **Kotlin Multiplatform + Compose** — Tek bir paylaşılan kod tabanından üretilen yerel Android, iOS ve Masaüstü istemci kabukları; üç platform, üç farklı uygulama değil.
- **Kubernetes + Helm + Argo CD + Kustomize** — Bulut yerel teslimat: Helm sürümü paketler, Kustomize ortama özel katmanlar ekler, Argo CD ise GitOps aracılığıyla küme durumunu Git ile eşleştirir.
- **OPA (Rego)** — Hem çakışma çözümü hem de erişim kontrolü için kod olarak politika; yetkilendirme kararları bildirimsel ve denetlenebilir kalır.
- **Docusaurus** — Kamuya açık belgeler sitesi (docs.helixgitpx.io); **Astro** — Pazarlama sitesi (helixgitpx.io); her araç içeriğine uygun seçilmiş.
- **mise** — Sabitlenmiş, yeniden üretilebilir bir araç zinciri; her katkıda bulunan ve CI çalıştırıcısı tam olarak aynı sürümlerle derleme yapar.

## Durum ve dürüstlük notları

- **Durum: teslim edildi.** Projenin README dosyası, `m1-temel` ile `m8-ga` arasındaki kilometre taşlarının etiketlendiği v1.0.0 GA sürümünü ilan ediyor. ("v1.0.0 GA", projenin kendi README dosyasındaki iddiadır.)
- **Lisans: belirlenecek.** GitHub ve API raporları `MIT` lisansını gösterirken, README dosyasının Lisans bölümünde Apache-2.0 (kod) / CC-BY-SA-4.0 (dokümantasyon) belirtilmiş — yayınlamadan önce gerçek LICENSE dosyasıyla çelişkiler giderilmeli.
- Belgeler (docs.helixgitpx.io) ve pazarlama (helixgitpx.io) URL’leri README dosyasından alınmış olup bağımsız olarak doğrulanmadı — canlı durum **TEYİT EDİLMEMİŞ**.

**Öncelik seviyesi:** Helix-birincil.

