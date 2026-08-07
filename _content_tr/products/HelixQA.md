---
name: HelixQA
slug: helixqa
tier: helix-primary
order: 20
status: beta
license: Apache-2.0
private: false
tech:
  - Go 1.24+
  - YAML test banks (pkg/testbank)
  - Crash/ANR detectors (ADB, pgrep)
  - Evidence collection (screenshots/logcat/video/stack traces)
  - Autonomous session (LLM + computer vision)
  - LLMsVerifier
  - LLMOrchestrator
  - VisionEngine (GoCV + LLM Vision)
  - DocProcessor
  - Anti-bluff gates + mutation ratchet
repos:
  - https://github.com/HelixDevelopment/helixqa
  - https://github.com/vasic-digital/HelixQA
diagrams:
  - Autonomous QA-session loop — the 4 phases (Setup → Doc-Driven Verification → Curiosity-Driven Exploration → Report & Cleanup) as a cycle, with evidence artefacts dropping out at each step.
  - Anti-bluff evidence pipeline — test step → detector + vision oracle → captured evidence (screenshot/logcat/video/stack trace) → PASS, with a "no evidence → critical defect" reject branch.
  - Cross-platform navigator — one orchestrator fanning to ADB (Android/TV), Playwright (Web), X11 (Desktop) action executors.
  - Constitution → HelixQA governance — §11.4.169's 13 mandatory test types with helix_qa highlighted as the QA pillar, feeding the 15-row coverage matrix.
---

# HelixQA

**Anti-blöf QA orkestrasyonu — her GEÇER sonucunun, gerçek bir kullanıcının özelliği kullanabildiğine dair yakalanmış kanıt taşıdığı, otonom ve çapraz platform oturumları.**

## Özet

HelixQA, çapraz platform testleri (Android, Android TV, Web, Masaüstü) için geliştirilmiş bir anti-blöf QA orkestrasyon çerçevesidir. YAML test bankalarını, gerçek zamanlı çökme tespitini, adım adım kanıt yakalamayı ve LLM-artı-bilgisayarla-görü otonom QA oturumlarını bir araya getirerek özelliklerin gerçekten uçtan uca çalıştığını kanıtlar. Constitution’un zorunlu QA test türüdür (§11.4.169).

## Kısa açıklama

Yazılı test bankalarını ve tam otonom, LLM ve görüntü işleme tabanlı QA oturumlarını platformlar arasında çalıştıran bir anti-blöf QA orkestratörü (Go). Çökmeleri tespit eder, her adımı yakalanmış kanıtlarla (ekran görüntüleri, logcat, video, yığın izleri) doğrular ve AI düzeltme hatları için kanıt zengini biletler otomatik olarak oluşturur.

## Uzun açıklama

HelixQA, tek ve tavizsiz tasarım odağı Constitution’un §11.4 Operatif Kuralı olan bir Go çerçevesidir: yayınlama kriteri "testler geçti" değil, "kullanıcılar özelliği kullanabiliyor"dur. Bu nedenle, her GEÇER sonucu, yürütme sırasında yakalanmış pozitif çalışma zamanı kanıtı taşımalıdır — kanıt yoksa yeşil ışık yok, istisna yok. Hem yazılı hem de bilinmeyen durumları kapsayan iki tamamlayıcı modda çalışır. İlk olarak, **yazılı test bankaları** — platform hedeflemesi, öncelik, sıralı adımlar (ad/eylem/beklenen), etiketler ve dokümantasyon referansları içeren `TC-XXX` vakalarından oluşan YAML paketleri — adım adım doğrulama, gerçek zamanlı çökme/ANR tespiti (Android için ADB, web/masaüstü için süreç izleme), merkezi kanıt toplama ve AI düzeltme hatları için otomatik olarak oluşturulmuş Markdown biletleri ile yürütülür. İkinci olarak, **tam otonom QA oturumu** uygulamayı LLM destekli ajanlara ve bilgisayarla görüye devreder ve dört disiplinli aşamada kontrolsüz olarak çalıştırır: kurulum (LLM’lerin seçimi, proje belgelerinden özellik haritasının oluşturulması, CLI ajanlarının başlatılması, görüntü işleme motorunun hazırlanması), her belgelenmiş özelliğin dolaşıldığı belge odaklı doğrulama, kenar durumları ve belgelenmemiş davranışları bilinçli olarak test eden merak odaklı keşif, ardından her bulgunun video zaman damgalı kanıtlarla ilişkilendirildiği Markdown/HTML/JSON formatında raporlama ve temizlik.

En kritik nokta, kendi ödevini notlandırmamasıdır: Dört harici Go alt modülünü (LLMsVerifier, LLMOrchestrator, VisionEngine, DocProcessor) entegre eder ve ortak `challenges` ile `containers` altyapısını kullanır. Böylece uygulamayı gezen bileşen, çalışıp çalışmadığını değerlendiren bileşenle aynı değildir. Kendi paketi, `make anti-bluff` (statik tarama + davranış çapa manifestosu + mutasyon mandalı) ve yerleşik §1.1 mutasyonuna sahip 8 aşamalı bir orkestratör Challenge ile başkalarına uyguladığı aynı kriterlere tabi tutulur. 15 satırlık test türü kapsama matrisi, her ilan edilen yeteneği somut bir yürütülebilir varlığa ve belirli bir yakalanmış kanıt biçimine bağlar — böylece çerçevenin kendisi hakkındaki iddiaları, test ettiği ürünlere verdiği kararlar kadar kanıta dayalıdır.

İçerik

## Neden inşa ettik

Geleneksel Kalite Güvencesi (QA), "doğrulama başarılı" uyarısını yeşil ışık olarak kabul eder. İşte tam da bu yüzden Constitution'un *blöf* olarak adlandırdığı başarısızlık sınıfı gözden kaçar: kullanıcıya göre çalışmayan bir özellik, raporlarda sorunsuz görünür. HelixQA, özellikle QA için bu durumu imkânsız kılmak üzere tasarlandı. Bir doğrulamanın BAŞARILI olarak değerlendirilmesi için gerçek çalışma sırasında elde edilmiş fiziksel kanıt (ekran görüntüsü, logcat, video, yığın izi, rapor) gerektirir ve kanıt olmadan verilen yeşil özet satırını, eksik bir özellikle eşdeğer kritik bir hata olarak kabul eder. Ayrıca, birçok platformda kapsamlı manuel QA'nın ölçeklenememe sorununu da çözer: oturumları tamamen otonom hale getirerek.

## Neden oyunun kurallarını değiştiriyor

Neredeyse hiçbir araçta bir arada bulunmayan iki unsuru birleştiriyor: titiz, kanıta dayalı QA geçiş kontrolü ve otonom, kendi kendine çalışan keşif. Bir LLM artı görsel algılama aracısı, *gerçek* uygulamayı açar, belgelenmiş her özelliği doğrular, kimsenin test yazmadığı belgelenmemiş hataları avlar *ve* bunu yaparken mahkeme kalitesinde bir kanıt zinciri üretir. Böylece "test ettik" ifadesi, "işte video, işte logcat, işte bilet" haline gelir. Ayrıca Constitution tarafından adlandırılan QA alt modülü olduğu için, benimsenmesi tek bir ekibin QA dürüstlüğünü artırmakla kalmaz; aynı hamlede tüm ürün ailesindeki kalite tabanını yükseltir.

## Yenilikçi yönleri

- **Blöf karşıtı kanıt sözleşmesi** – Her kontrolün BAŞARILI sonucu, çalışma zamanı sırasında elde edilmiş kanıtlarla bağlanır; yeşil bir CI satırı gerekli görülse de asla yeterli kabul edilmez ve kanıtsız yeşil özet, kritik bir hata olarak değerlendirilir.
- **Otonom belge odaklı + merak odaklı keşif** – Belgelenmiş her özelliği doğrular, ardından senaryo dışına çıkarak gerçek kullanıcıların karşılaştığı sınır durumları (boş girişler, hızlı etkileşimler, belgelenmemiş yollar) araştırır; hiçbir elle yazılmış test paketinin öngöremeyeceği durumları tespit eder.
- **Görsel kehanet** – GoCV mekanik görüntü işleme ve LLM Görsel API, çalışan arayüzü *gerçekten görerek*, token ve özellik düzeyindeki doğrulamaların gözden kaçırdığı görsel hataları yakalar.
- **Yapıya dayalı, metne dayalı olmayan test bankaları** – Banka dizeleri yapıyı tanımlar ve çalışma zamanında LLM tarafından oluşturulan soru istemlerini yönlendirir (CONST-046). Böylece tek bir banka, arayüz metni çevrildiğinde bile farklı yerellerde çalışmaya devam eder.
- **AI onarım hatları için hazır biletler** – Otomatik oluşturulan Markdown sorunları, tam kanıt paketiyle birlikte gelir ve bir insan triyajcısı yerine doğrudan bir onarım aracısına iletilmeye hazırdır.

## Tüm ürünlerde nasıl kullanılıyor (sunduğu güçler)

**Zorunlu kalite sütunu** olarak (Constitution §11.4.169, `helix_qa` alt modülünü gerekli test türlerinden biri olarak adlandırır), HelixQA ailesindeki her ürüne aynı güçleri kazandırır:

- **Otonom QA oturumları:** Tek bir `helixqa autonomous --project … --platforms android,desktop,web` komutu, gerçek uygulamaları hedef bir kapsama alanına yönlendiren, rapor, bilet ve videolar üreten bir LLM artı görsel algılama aracısını serbest bırakır; süreçte insan müdahalesine gerek kalmaz.
- **Test bankaları / paketleri:** YAML bankaları (en az 30 ile 219. tur tabanı), platforma özel, öncelik sıralı ve doğruladıkları belgelerle satır satır izlenebilir.
- **Kaydedilmiş kanıtlar:** Ekran görüntüleri, logcat, video, yığın izleri ve tam zaman çizelgesi – her rapordan merkezi olarak erişilebilir ve bağlanabilir, böylece her karar sonradan yeniden izlenebilir ve denetlenebilir.
- **Bağımsız kararlar (§11.4.141 bağımsızlık ilkesi):** LLM destekli `issuedetector` ve görsel kehanet aracısı, uygulamayı gezen aracıdan bağımsız olarak çalışan uygulamanın davranışını değerlendirir; böylece bir sistemin kendi işini doğru olarak işaretlemesi klasik hatası yapısal olarak engellenir.
- **Geçiş kontrolü + mutasyon kilidi:** `make qa-all` / `make anti-bluff` ve `challenges/scripts/helixqa_orchestrator_challenge.sh` (8 aşamalı, §1.1 yerleşik mutasyon) komutları, HelixQA'un kendi dürüstlüğünü sürekli olarak kanıtlamasını sağlar. Ayrıca, son teslim tarihleri altında disiplini devre dışı bırakmak için kasıtlı olarak `--skip-helixqa` gibi bir kaçış yolu bırakılmamıştır.

İçerik

## En Büyük Teknik Zorluklar ve Bunları Nasıl Çözdük

- **QA sürecindeki yanlış pozitiflerin önlenmesi** — blöf yakalayan araç, kendisi blöfe dönüşmemeli → her adım, yakalanan kanıtlara karşı doğrulanır; kanıt olmadan GEÇER notu, GEÇER yerine hata olarak puanlanır; davranış-çapa manifestosu, her ilan edilen yeteneği çalıştırılabilir bir teste bağlar (CONST-035), böylece bir yetenek, onu uygulayan bir şey olmadan iddia edilemez.
- **Tek bir beyinle heterojen platformların yönetilmesi** — Android, Android TV, Web ve Masaüstü’nün ortak bir giriş modeli yok → tek bir `navigator` paketi, platforma özel ActionExecutor’ları (ADB, Playwright, X11) ve platforma özgü çökme dedektörlerini (android/web/masaüstü) soyutlar; böylece orkestrasyon mantığı tek sefer yazılır ve platform farklılıkları kenarlarda kalır.
- **Otonom ajanların kaotik değil, kullanışlı hale getirilmesi** — denetimsiz bir LLM, bir uygulamada sonsuza dek dolaşabilir → LLMsVerifier doğru modelleri puanlar ve seçer, LLMOrchestrator başsız CLI ajanlarını (opencode, claude-code, gemini, junie, qwen-code) yönetir, DocProcessor keşfe hedef veren özellik haritasını oluşturur ve VisionEngine her kararı, modelin hayal gücü yerine ekrandaki gerçek piksellere dayandırır.
- **Yerelleştirme güvenli test bankaları** — İngilizce UI metnini sabit kodlayan bir test paketi, on beş dilde bozulur → bankalar yalnızca yapıyı tanımlar ve kullanıcıya yönelik metinler, çalışma zamanında LLM/kaynak yüklenir (CONST-046); böylece aynı banka, yerel ayardan bağımsız olarak aynı davranışı doğrular.
- **Kapıların sahte olmadığının kanıtlanması** — kendisi başarısız olamayan bir blöf önleme kapısı, nihai blöftür → eşleştirilmiş §1.1 mutasyonları, bir türün kanıt toplama veya blöf önleme iddiasını kaldırır ve kapının BAŞARISIZ olmasını zorunlu kılar; zaman içinde bu garantinin sessizce aşınmasını önleyen bir mutasyon mandalı da devreye girer.

## Teknoloji Yığını

- **Go 1.24+ orkestratörü** — *neden:* QA, ürünlerin çalıştığı her yerde çalışmalı; bu nedenle tek bir statik olarak bağlanmış, hızlı ve taşınabilir ikili, çalışma zamanı ağır bir alternatife tercih edilir; *nasıl:* `cmd/helixqa` CLI, birleştirilebilir alt komutlar sunar: `run` / `list` / `report` / `autonomous` / `version`.
- **YAML test bankaları (`pkg/testbank`)** — *neden:* test paketleri bildirimsel ve okunabilir olmalı, insanlar Go’a dokunmadan düzenleyebilmeli; *nasıl:* `version`/`name`/`test_cases[]` yapısı, `id`, `category`, `priority`, `platforms`, sıralı `steps[]` ve `documentation_refs[]` içerir; bu sayede özellik belgelerine izlenebilirlik sağlanır.
- **Çökme/ANR dedektörleri (`pkg/detector`)** — *neden:* en önemli hatalar, etkileşim sırasında canlı olarak meydana gelenlerdir, sonradan yapılan bir doğrulama değil; *nasıl:* Android için ADB (`pidof`/`logcat`/`screencap`), web/masaüstü için `pgrep` kullanılır; test çalışırken süreç izlenir.
- **Kanıt toplama (`pkg/evidence`, `pkg/session`)** — *neden:* blöf önleme sözleşmesi, ancak her GEÇER notunun fiziksel kanıtla desteklenmesi halinde gerçektir; *nasıl:* ekran görüntüleri, logcat, video ve yığın izleri, her raporun geri bağlandığı bir `SessionRecorder` zaman çizelgesine kaydedilir.
- **Otonom oturum (`pkg/autonomous`, `pkg/navigator`, `pkg/issuedetector`)** — *neden:* dört platformda kapsamlı manuel QA ölçeklenemez; bu nedenle keşfin kendisi otonom olmalı; *nasıl:* 4 aşamalı bir `SessionCoordinator`, ActionExecutor’lar (ADB/Playwright/X11) ve görsel, UX, erişilebilirlik ve işlevsel hataları kapsayan LLM hata tespiti.
- **Harici alt modüller** — *neden:* yeniden kullanım ve bağımsızlık (CONST-051), ayrıca — kritik olarak — gezgin ile değerlendiricinin ayrılması; *nasıl:* LLMsVerifier (model puanlama), LLMOrchestrator (başsız CLI ajanları), VisionEngine (GoCV + LLM Vision), DocProcessor (özellik haritası/kapsam), her biri bağımsız olarak sahiplenilen bileşenler.
- **Blöf önleme kapıları + mutasyon mandalı** — *neden:* HelixQA’un, §1.1 sözleşmesini her şeyde uyguladığı gibi kendisine de uygulanmasını sağlamak; *nasıl:* `make anti-bluff` taraması, bir davranış-çapa manifestosu ve mutasyon mandalı, `helixqa_orchestrator_challenge.sh` ile 8 aşamalı bir uçtan uca doğrulayıcı.
- **15 satırlık kapsam matrisi (`docs/test-coverage.md`)** — *neden:* CONST-050(B), hiçbir boşluk bırakmayan, tamamen hesaplanabilir bir test türü kümesi zorunlu kılar; *nasıl:* her satır, somut bir çalıştırılabilir varlığa ve belirli bir kanıt toplama biçimine bağlanır; böylece kapsam, bir iddia değil, kontrol edilen bir gerçek haline gelir.

İçerik

## Durum ve dürüstlük notları

- **Durum: beta.** Aktif olarak geliştirilmekte (README durum afişi 219. tur). Kendi "anti-blöf" çubuğuna tabi tutuluyor.
- **Lisans: Apache-2.0.** Kurulum: `go install digital.vasic.helixqa/cmd/helixqa@latest`.

**Öncelik katmanı:** Helix-birincil — Helix ailesinin özelliklerin gerçekten çalıştığını doğrulama yönteminin zorunlu kalite/anti-blöf dayanağı.

