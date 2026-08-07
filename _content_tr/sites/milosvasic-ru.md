---
site: milosvasic.ru
type: personal-site
title: Miloš Vasić — AI Engineer
tagline: I build AI development systems — and the discipline that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Miloš Vasić

## Kahraman

**AI mühendisi; doğrulanabilir AI geliştirme sistemleri inşa ediyorum.**

AI mühendisliğinin, güvenilir bir ürünü etkileyici bir demodan ayıran kısmını inşa ediyorum: Bir sağlayıcının çökmesi durumunda ayakta kalan çoklu sağlayıcılı LLM altyapısı, işi yolunda tutan otonom ajanlar ve orkestrasyon, bir AI sisteminin yapabilecekleri konusunda sessizce yalan söylemesini engelleyen yönetişim ve kalite güvence katmanları. Büyük bir dil modelini gerçekten piyasaya sürülebilir bir şeye dönüştürmek çoğunlukla bir disiplin meselesidir ve ben bu disiplinde uzmanım. Kuzey yıldızım tek bir kuraldır: Bir özellik, ancak gerçek bir kullanıcı tarafından kullanılabildiğinde ve bunu kanıtlayan belgeler elde edildiğinde tamamlanmış sayılır.

## Özet

Çalışmalarım ağırlıklı olarak **Go** alanında, iş gereksinimlerine göre **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** ve **Shell** üzerinde yürütülüyor. En çok önem verdiğim şey, işin *nasıl yapılandırıldığıdır*: Bir yığın tek seferlik uygulama değil, düzinelerce küçük, birbirinden bağımsız, ayrı ayrı test edilmiş modülün üzerine oturan büyük ürün uygulamalarından oluşan bir filo. Tüm bunlar, ortak bir mühendislik **Constitution**’ini Git alt modülü olarak miras alıyor. Bu tek mimari tercihi, tüm çalışmanın birikimli olmasını sağlıyor: Düzeltmeler ve iyileştirmeler her şeye aynı anda yayılıyor, yeni ürünler halihazırda kanıtlanmış parçalardan bir araya getiriliyor ve her ilan edilen yetenek, bir iddiaya değil, kanıt üreten bir teste dayanıyor. Ölçekte tek bir kişi tarafından güvenilebilir şekilde inşa edilmiş mühendislik bu. Bu sayfa, bu genel bakıştan başlayarak tek tek projelere iniyor; her biri kendi ürün sayfasına bağlantı veriyor.

## Çalışma Yöntemim — Yönetişim ve Kalite Güvence Öncelikli

Ürünlerden önce, onları ayakta tutan disiplin:

- **HelixConstitution** — 140’tan fazla depodan oluşan bir filoya Git alt modülü olarak dağıtılan, evrensel ve miras alınabilir bir mühendislik kural kitabı tutuyorum. Bu kitap, blöf karşıtı kanıt kapılarını, yanlış pozitif bağışıklığını, veri/konak güvenliğini ve kapsama kurallarını kodluyor; projeler bu kuralları sıkılaştırabilir ama asla gevşetemez. Her yönetişim kapısı, kendi işlevselliğini kanıtlayan bir mutasyon testi ile eşleştirilmiş durumda. → HelixConstitution ürün sayfasına bakın.
- **HelixQA** — Blöf karşıtı kalite güvence orkestrasyonu inşa ediyorum. Yazılı test bankaları ve tamamen otonom, LLM ve görüntü tabanlı kalite güvence oturumlarını Android, Android TV, Web ve Masaüstü üzerinde çalıştırıyor; yalnızca çalışma zamanı kanıtı yakalandığında BAŞARILI sonucu veriyor. → HelixQA ürün sayfasına bakın.

## Helix Ailesi Boyunca Çalışmalarım

Helix serisi, AI geliştirme yaşam döngüsünün tamamını kapsıyor. Öncelik sırasına göre:

- **HelixTrack** — Özgür dünyaya yönelik bir JIRA alternatifi; Helix-Track serisinin amiral gemisi.
- **HelixAgent** — Çok turlu model tartışması ve doğrulama tabanlı sağlayıcı seçimi ile çalışan bir topluluk LLM hizmeti.
- **HelixCode** — SSH tarafından yönetilen çalışanlar arasında iş bölümü yapan, otomatik kontrol noktası/geri alma özelliğine sahip dağıtık bir AI geliştirme platformu.
- **HelixLLM** — HTTP/3 üzerinden OpenAI ve Anthropic uyumlu API’ler sunan altı modlu tek bir ikili dosya; yerel llama.cpp çıkarımı ve puanlanmış yedek zinciri ile.
- **HelixCluster** — Veri merkezi GPU’larından uçtaki taşınabilir cihazlara kadar AI hesaplamaları için dağıtık bir işletim sistemi.
- **LLMProvider** — Devre kesiciler, yeniden denemeler ve sağlık kontrolleri ile donatılmış 43 sağlayıcı için tek bir arayüz.
- **LLMOrchestrator** — Tüm başsız CLI kodlama ajanları için tek bir kontrol düzlemi.
- **LLMsVerifier** — Doğrula, izle, optimize et: LLM/sağlayıcı/doğrulama meta verileri için tek gerçek kaynak.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — Ajan belleği, yönetişimli ajan becerileri, şartname odaklı geliştirme, AI uygulama inşası, doğrulanmış kitap çevirisi, sıfır güven terminali, federatif Git, sıfır tuğla OTA güncellemeleri ve kendi sunucunuzda barındırılan bulut oyunları.

İçerik

## **vasic-digital araçları kapsamındaki çalışmalarım**

Geliştirdiğim ve sürdürdüğüm, her biri tam bir ürün sayfasına sahip, üretim kalitesinde araçlar:

- **Catalogizer** — Çok protokollü (SMB/FTP/NFS/WebDAV/yerel), şifreli, kendi sunucunuzda barındırılabilir medya koleksiyonu yönetimi; Go/Gin API ve React arayüzüyle.
- **Courses-Creator** — Çoklu LLM zenginleştirmesi, TTS ve masaüstü/mobil/web oynatıcıları içeren Markdown’dan videoya ders iş akışı.
- **VisionEngine** — Klasik bilgisayarlı görü ile çoklu sağlayıcı LLM görü teknolojilerini birleştiren, ayrıştırılmış bir Go araç seti; arayüz analizi ve gezinme grafikleri için.
- **DocProcessor** — Belgeleri, QA otomasyonu için doğrulanabilir özellik haritasına dönüştüren araç (LLM veya sezgisel çıkarım ile).
- **Docs Chain** — İçerik tabanlı hash’lenmiş, çift yönlü, atomik belge/veritabanı senkronizasyon motoru.
- **Herald** — Doğal dil desteği ve üç aşamalı niyet çözümlemesiyle güvenilir çok kanallı bildirim sistemi.
- **task_bridge** — Ayrıştırılmış, çift yönlü görev/panel senkronizasyon motoru (P1 iskeleti; senkronizasyon mantığı geliştirme aşamasında).
- **Vasic Digital Yeniden Kullanılabilir Modül Paketi** — `digital.vasic.*` "standart kütüphanesi"; altyapı, AI ilkel yapı taşları ve güvenlik kısıtlayıcı modüllerinden oluşuyor.

## **Altyapı mirası (Server Factory)**

AI serisinden önce geliştirdiğim DevOps araç zinciri: **Mail Server Factory** (bildirimsel JSON → tam olarak sağlanmış Docker tabanlı posta sunucuları; 439 geçer notlu test ve temiz bir SonarQube geçidi), üzerine inşa edildiği **Server Factory Çekirdek Çerçevesi** ve sanal makine görüntü araçları (**Qemu-Utils**, **Parallels-Utils**) ile destekleyici hizmet fabrikaları.

## **Tek cümleyle**

Ben yeşil tikler teslim etmem — çalıştıklarına dair kanıtları ve bu şekilde kalmalarını sağlayan yönetişim mekanizmalarıyla birlikte AI sistemleri sunarım.

## **İletişim**

Dünya genelinde üst düzey AI/platform mühendisliği pozisyonlarına açığım.

- **E-posta:** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [milos85vasic](https://github.com/milos85vasic)
- **Telegram:** [@milos85vasic](https://t.me/milos85vasic)

