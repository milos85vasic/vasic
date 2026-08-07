---
name: HelixTranslate
slug: helixtranslate
tier: helix-primary
order: 10
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - QUIC / HTTP/3 (quic-go)
  - gRPC + Protocol Buffers
  - Gorilla WebSocket
  - PostgreSQL
  - SQLite
  - Redis
  - unidoc/unioffice + unipdf
  - Cobra
  - LLMsVerifier bridge
  - Docker / Podman
repos:
  - https://github.com/HelixDevelopment/HelixTranslate
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Provider-routing / no-silent-fallback flow (signature) — request → is provider explicit? → is a verified model available? → strongest-verified selection with deterministic fallback chain; every "no" branch terminating in a red honest hard error, with local runtimes crossed out.
  - Verification-gated model selection — LLMsVerifier scores models (responsiveness / code / feature-richness / reliability) → only verified, positively-scored models enter the eligible pool → HelixTranslate picks the top one.
  - Real-time monitoring pipeline — Translation CLI → typed WebSocket events → Monitoring Server → live Web Dashboard, with remote SSH workers feeding distributed translation.
  - Multi-format ebook flow — FB2/EPUB/PDF/DOCX/HTML/TXT in → parse → translate (verified model) → multi-pass polish → regenerate target format.
---

# HelixTranslate

**Doğrulanmış model kitap çevirisi — tasarım gereği dürüst, asla sessiz yedekleme değil.**

## Özet

HelixTranslate, Go tabanlı, yüksek performanslı bir e-kitap çeviri platformudur. 100’den fazla dil arasında kitap çevirisi yapmak için doğrulanmış LLM sağlayıcılarını kullanır. Gerçek zamanlı WebSocket izleme sistemi ve sessiz yedeklemeye asla izin vermeyen katı bir yönlendirme politikasıyla çalışır; sorun yaşandığında sessizce düşük performansa geçmek yerine yüksek sesle hata verir.

## Kısa açıklama

Go tabanlı evrensel e-kitap çeviri araç seti. FB2, EPUB, TXT, HTML, PDF ve DOCX formatlarındaki kitapları, 100’den fazla dilde en güçlü doğrulanmış LLM (LLMsVerifier köprüsü üzerinden) kullanarak çevirir. REST/HTTP-3 ve gRPC API’leri, dağıtık işleme ve gerçek zamanlı WebSocket izleme paneli sunar.

## Uzun açıklama

HelixTranslate, Go tabanlı, kurumsal düzeyde bir sistemdir ve kitapları dil arasında çevirmek için LLM sağlayıcılarını kullanır. Paragraflar veya kısa metinler değil, baştan sona kitap uzunluğundaki eserleri çevirir. Birden fazla e-kitap formatını (FB2, EPUB, TXT, HTML, PDF, DOCX) ayrıştırır ve yeniden oluşturur, 100’den fazla dili otomatik olarak algılar. Hem CLI araçlarını hem de API sunucularını (REST üzerinden HTTP/3, gRPC ve bir WebSocket olay akışı) destekler; böylece terminal tabanlı bir iş akışına da hizmet tabanlı bir ağa da eşit şekilde uyum sağlar. Sisteminin belirleyici özelliği, *model seçimi* yaklaşımıdır: Sağlayıcıyı sabit kodlamak ve sağlıklı kalmasını ummak yerine, HelixTranslate tüm model yetkisini LLMsVerifier köprüsüne (`pkg/bridge`) devreder. Bu köprü, en güçlü *doğrulanmış* API modelini seçer ve belirleyici, puan sıralı bir yedekleme zinciri sunar. Model uygunluğu, yanıt verme hızı, kod kalitesi, özellik zenginliği ve güvenilirlik gibi ağırlıklı kriterlerle belirlenir. Yani çevirinizi yapan model, bir yapılandırma dosyasında görünmekle değil, işe yaradığını kanıtlayarak yerini kazanır.

Kritik nokta, sistemin kod düzeyinde uyguladığı "sessiz yedekleme yok" kuralıdır: Eğer hiçbir sağlayıcı API anahtarı mevcut değilse ya da operatör açıkça mevcut olmayan bir sağlayıcı talep ederse, sistem sessizce başka bir sağlayıcıya geçmek veya yerel bir çalışma zamanına düşmek yerine dürüst bir şekilde sert bir hata döndürür. Bu kural, özel bir ön derleme kontrolü ve eşleştirilmiş mutasyon testi ile sabitlenmiştir. Yerel çalışma zamanları (Ollama, llama.cpp) kasıtlı olarak varsayılan yoldan çıkarılmıştır; böylece doğrulanmamış bir motor, doğrulanmış bir modelin yerine asla sessizce geçemez. Çeviri çekirdeğinin etrafında gerçek zamanlı bir WebSocket izleme alt sistemi bulunur: Çeviri CLI, canlı bir web paneline yönlendirilen bir izleme sunucusuna tip belirli olaylar gönderirken, uzak SSH çalışanları iş yükünü dağıtık olarak dağıtır. Bunun üzerine tutarlılık için çok geçişli düzeltme, hazırlık aşamasında kalite analizi, uzun metinlerde maliyeti kontrol altına almak için çeviri önbelleği ve görsel odaklı kalite güvencesi katmanları eklenir. Tüm platform, bir "blöf karşıtı mühendislik anayasası"na tabidir: Testler, gerçek kullanıcı tarafından görülebilir sonuçları kanıtlamalıdır ve yeşil onay işaretleriyle hiçbir şey kanıtlanamaz; zorunlu mutasyon testleriyle desteklenmelidir.

## Neden inşa ettik

Uzun metinli kitapları güvenilir ve *dürüst* bir şekilde çevirmek için — asla "kalitesi düşmüş ama mevcut" bir çeviri sunmamak. Tasarım ilkesi, eksik veya doğrulanamayan bir çevirinin yüksek sesli, kesin bir hata olması gerektiği ve model seçiminin her zaman gerçekten doğrulanmış bir sağlayıcıya yönelmesi, sabit kodlanmış bir tahmine ya da sessiz bir yerel yedeklemeye düşmemesi üzerine kurulu.

## Neden oyunun kurallarını değiştiriyor

Çoğu LLM çeviri hattı sessizce başarısız olur — daha zayıf bir modele geçer, yerel çalışma zamanına düşer ya da test paketi yeşil yanarken kısmi çıktı verir ve kimse kalitedeki düşüşü fark etmez. HelixTranslate, bu başarısızlık modunu yapısal olarak imkansız kılar: Model seçimi doğrulama kapısından geçer, yedekleme zinciri belirleyici ve tamamen şeffaftır, "anahtar yok / doğrulanmış model yok" durumu sessiz bir omuz silkme yerine dürüst bir hata mesajıyla sonuçlanır. Bu tek tasarım kararı, "Bu çeviri gerçekten yetkin, doğrulanmış bir modelde mi çalıştı?" sorusunu kontrol edemediğiniz bir umuttan, sistemin sizin adınıza garanti ettiği bir güvenceye dönüştürür.

## Yenilikçi yönler

- **Doğrulama kapılı model yönlendirmesi** LLMsVerifier köprüsü aracılığıyla — en güçlü *doğrulanmış* model otomatik olarak seçilir, böylece operatörler niyetlerini belirtir, sağlayıcı adlarını değil, ve asla çalışmayabilecek bir sağlayıcıyı elle seçmez.
- **Kodda zorunlu kılınan sessiz yedekleme yok garantisi** — dört açık yönlendirme kolu (taklit / açık doğrulayıcı / açık sağlayıcı / köprü varsayılanı), her biri sessiz geçiş yapmak yerine kesin hata verir, ayrıca varsayılan yoldan yerel çalışma zamanları kasıtlı olarak kaldırılmıştır, böylece daha zayıf bir şeye düşülecek bir şey kalmaz.
- **Mekanik uygulama** — `CM-NO-LOCAL-RUNTIME` ön derleme kapısı ve eşleştirilmiş mutasyon testi, derleme aşamasında varsayılan yolda asla yerel çalışma zamanı istemcisinin oluşturulmadığını doğrular: Garanti asla bozulmaz çünkü bozulursa derleme başarısız olur.
- **Belirleyici, puan sıralı yedekleme zinciri** — *doğrulanmış* modeller arasında sağlayıcıdan sağlayıcıya geçişe izin verilir ve tamamen şeffaftır; bu, yasaklanan sessiz yedeklemeden temelde farklıdır: Hangi yetkin modelin işi üstlendiğini her zaman bilirsiniz.
- **Gerçek zamanlı WebSocket izleme** — Tip belirtilmiş çeviri olayları canlı olarak bir kontrol paneline aktarılır, dağıtılmış SSH çalışanları sayesinde kitap uzunluğundaki bir işlem görünür ve paralel yürütülür, kara kutu olmaz.
- **Blöf karşıtı test rejimi** — Mutasyon testi, olumsuz iddialar, gerçek sistem çalıştırmaları ve görsel odaklı kalite güvencesi birlikte, "testler geçti"nin asla "özellik gerçekten çalışmıyor"u sessizce gizleyememesini sağlar.

## En büyük teknik zorluklar ve çözümlerimiz

- **Dürüst bir çeviri hattı garantisi (sessiz kalite düşüşü olmaması).** Tüm model yetkisinin LLMsVerifier köprüsünde merkezileştirilmesiyle çözüldü; böylece tek bir karar noktası denetlenir, her biri tahmin yapmak yerine yüksek sesle hata veren dört açık yönlendirme kolu kodlanır, yerel çalışma zamanı yedekleri varsayılan yoldan tamamen kaldırılır ve bu kural, bir derleme kapısı ile mutasyon testi aracılığıyla sabitlenir; garanti kaldırılırsa derleme başarısız olur.
- **"Testler yeşil, özellikler bozuk."** Bu başarısızlık modu anayasada açıkça tanımlanır ve Anti-Bluff Test rejimiyle yenilir: Uygulama ayrıntıları yerine somut, kullanıcıya görünen iddialar, gerçek sistemlerin devrede olduğu (taklitler yalnızca birim testlerinde kullanılır), zorunlu mutasyon testi (özelliği kasıtlı olarak bozun, test *mutlaka* kırmızıya dönsün) ve çıktıyı gerçekten inceleyen görsel doğrulamalı kalite güvencesi.
- **Uzun metinli, çoklu format kalitesi.** Kitap uzunluğundaki girdiler tutarlılık ve bütçeyi zorlar; çok aşamalı düzeltmeyle çözüldü, işin boyutunu önceden belirleyen hazırlık aşaması analizi ve aynı pasaj için iki kez ödeme yapılmasını önleyen çeviri önbelleği.

İçerik

## Teknoloji Yığını

- **Go** — eşzamanlılık ilkeleri, birden fazla bölümü aynı anda ayrıştırma, çevirme ve aktarma işlemlerine doğal olarak uyduğu için seçildi; yüksek eşzamanlılık destekli arka uç, `digital.vasic.translator` modülü.
- **Gin** — hızlı ve minimal bir HTTP yönlendiricisi olarak, REST API yüzeyini sunmak için tercih edildi.
- **QUIC / HTTP/3 (quic-go)** — REST API için düşük gecikmeli, modern bir taşıma katmanı sağlamak ve kusurlu ağlarda bile dayanıklılığını korumak amacıyla seçildi.
- **gRPC + Protocol Buffers** — güçlü tür denetimine sahip, yüksek performanslı bir hizmet arayüzü olarak, programatik çağrıları destekleyen REST ile birlikte çalışması için tercih edildi.
- **Gorilla WebSocket** — izleme paneline canlı olarak beslenen, gerçek zamanlı ve tür güvenli çeviri olay akışını taşımak için seçildi.
- **PostgreSQL, SQLite, Redis** — kasıtlı üç katmanlı ayrım: PostgreSQL kalıcı ilişkisel veriler için, SQLite yerleşik/yerel durumlar için (aynı zamanda köprünün doğrulanmış modeller deposunu, `data/verified_models.db`, destekler) ve Redis ise sıcak önbellek olarak kullanılır.
- **unidoc/unioffice + unipdf** — zorlu formatların üstesinden gelmek için seçildi: DOCX ve PDF ayrıştırma ve yeniden oluşturma işlemleri, böylece çoklu formatlı e-kitaplar sadakatle dönüştürülür.
- **Cobra** — `unified-translator` ve yan araçlarını güçlendiren CLI çatısı olarak tercih edildi.
- **golang-jwt (JWT HS256)** — durum bilgisi taşımayan API kimlik doğrulama için seçildi; IP başına belirteç kova sınırlaması ve TLS/QUIC taşıma güvenliği ile birlikte kullanılarak yüzeyin güvenliği artırıldı.
- **LLMsVerifier köprüsü (`pkg/bridge`)** — kilit nokta: en güçlü doğrulanmış modeli ve belirleyici yedek zincirini sağlar, ayrıca sessiz yedekleme yapılmayacağı garantisinin tek uygulama noktasıdır.
- **Testify** — Go test paketi için seçildi; `provider_routing_test.go` dosyası ve dürüstlük kurallarını koruyan mutasyon kapıları dahil.
- **Docker / Podman (köksüz) + Compose** — kapsayıcı tabanlı, dağıtık dağıtım (`docker-compose.distributed.yml`) için seçildi; daha sıkı bir güvenlik duruşu için köksüz Podman kullanıldı.

## Durum ve Dürüstlük Notları

- **Durum: beta.** İşlevsel platform; `VERSION`/Makefile/`AGENTS.md` dosyalarında sürüm bilgisi tutarsız olduğundan, kararlı kabul edilmiyor.
- **Lisans: Belirlenmedi.** README dosyası MIT lisansını belirtse de, bu bilgi bir LICENSE dosyasıyla doğrulanmış değil — beyan etmeden önce teyit edin.
- İzleme paneli uç noktaları yalnızca yerel erişime açık, genel erişime kapalı. Belgelerdeki WebSocket performans rakamları hedef olarak belirtilmiş, doğrulanmış değil. `ARCHITECTURE.md` dosyasında kaldırılmış Ollama/yerel motorlar hâlâ listeleniyor (güncel değil).

**Öncelik katmanı:** Helix-ana (LLM-altyapı kümesi). Helix platform ailesi içinde, HelixTrack’dan sonra gelir.

