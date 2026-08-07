---
name: HelixConstitution
slug: helixconstitution
tier: helix-primary
order: 19
status: shipped
license: TBD
private: false
tech:
  - Git-submodule inheritance
  - find_constitution.sh (parent-walk + superproject recursion)
  - install_upstreams.sh (multi-provider push)
  - §1.1 mutation meta-tests
  - Propagation gates (CM-COVENANT-114-NNN-PROPAGATION)
  - submodules-catalogue.md
  - Multi-format export (md/html/pdf/docx)
repos:
  - https://github.com/HelixDevelopment/HelixConstitution
  - https://github.com/vasic-digital/HelixConstitution
diagrams:
  - Constitution inheritance layers — a three-tier stack (universal base submodule → project layer → subdirectory overrides) with arrows showing "extend, never weaken."
  - Fleet propagation — one Constitution repo at the centre, submodule links radiating to 140+ consuming repos, each stamped with a green CM-COVENANT-…-PROPAGATION check.
  - Anti-bluff evidence pipeline — code change → four-layer gate (source / build / runtime / mutation) → captured-evidence artefact → PASS, with a "no evidence = bluff = blocker" reject branch.
  - Multi-upstream push topology — a single git push fanning out to GitHub / GitLab / GitFlic / GitVerse.
---

# HelixConstitution

**Her projenin miras aldığı evrensel mühendislik anayasası — blöf karşıtı yasa, mekanik olarak uygulanan, tek bir Git alt modülü olarak paylaşılan.**

## Özet

HelixConstitution, her Helix/vasic-digital projesine bir Git alt modülü olarak eklenen, projeye özgü olmayan tek kural kitabıdır. Bu kitap, tartışmasız mühendislik disiplinini (blöf karşıtlığı, yalnızca kanıta dayalı doğrulama, veri/konak güvenliği, dokümantasyon ve test kapsamı) kodlar ve 140’tan fazla depoya yayar. Tüm ailenin tutarlılığını sağlayan yönetişim omurgasıdır.

## Kısa açıklama

Evrensel, miras alınabilir bir Constitution, Git alt modülü olarak sunulur. Her kullanan projenin otomatik olarak miras aldığı ve genişletebileceği ancak asla zayıflatamayacağı zorunlu, tartışmasız kuralları tanımlar: blöf karşıtı kanıt kapıları, yanlış pozitif bağışıklığı, veri ve konak güvenliği, kapsam ve dokümantasyon disiplini.

## Uzun açıklama

HelixConstitution, bir Git alt modülü olarak eklemeyi seçen her proje arasında paylaşılan mühendislik uygulamaları için tek ve kesin doğruluk kaynağıdır — mühendislik yasası, kod gibi dağıtılmış ve sürüm sabitlenmiş haldedir. Merkezinde yer alan `Constitution.md`, sürekli sürümlendirilmiş, numaralandırılmış maddelerden (~1 MB, §11.4.x ahit ailesi, şu anda §11.4.170’e kadar) ve her bir aracın işletim kılavuzlarından (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) oluşur. Bu kılavuzlar, ahit belgesini referans alarak insanların ve her CLI aracının tek ve aynı kural kitabını okumasını sağlar. Miras alma kasıtlı olarak üç katmanlıdır: evrensel temel (bu alt modül), proje katmanı (projenin kendi Constitution/CLAUDE/AGENTS uzantıları) ve isteğe bağlı alt dizin katmanı — yukarıdan aşağıya değerlendirilir. Bir proje kuralları sıkılaştırabilir, ancak mimari olarak zayıflatması yasaktır. Sonuç, paylaştıkları disiplinin sabitlenmiş olması sayesinde sessizce birbirinden uzaklaşamayan 140’tan fazla depodan oluşan bir filodur.

Belge, tavizsiz bir şekilde alan bağımsızdır: Belirli bir satıcı, donanım SKU’su, port veya kütüphane sürümünü adlandıran her şey, tüketici projenin kendi Constitution’una taşınmalıdır. Evrensellik asla varsayılmaz — bir kuralın temele girmesi için dört aşamalı açık bir testten geçmesi gerekir. Felsefi omurgası, birbiriyle kenetlenmiş ahitlerden oluşan blöf karşıtı bir yapıdır: §1.1 yanlış pozitif bağışıklığı, §11.4 son kullanıcı kalite ahdi, §11.4.6 tahmin yasağı, §11.4.69 pozitif kanıt sınıflandırması. Bunların birleşik etkisi tek bir katı çizgidir: Yayınlama ölçütü asla "testler geçti" değil, "gerçek bir kullanıcı özelliği kullanabiliyor"dur ve her yeşil sonuç, yakalanmış fiziksel kanıta atıfta bulunmalıdır, aksi takdirde geçerli sayılmaz. Bir yardımcı `submodules-catalogue.md` (142 depo) ise "bunu zaten yapan bir şeyimiz var mı?" sorusunu, yeni bir kod satırı yazılmadan önce katalog öncelikli, yeniden uygulamadan genişletme refleksine dönüştürür. Yardımcı betikler, alt modülü herhangi bir iç içe derinlikten bulur ve her işlemi dört bağımsız Git sağlayıcısına dağıtır; böylece tek yetkili kural kitabı kaybolması da imkansız hale gelir.

İçerik

## Neden inşa ettik

Aynı sahibe ait çok sayıda büyük ürün uygulaması ve düzinelerce bağımsız yeniden kullanılabilir alt modül, aynı zor kazanılmış kuralları tekrar tekrar türetmeye devam ediyordu — ve aynı başarısızlık sınıfıyla karşılaşıyordu: Özellik son kullanıcı için bozuk olmasına rağmen testlerin ve durum raporlarının başarı bildirdiği durumlar ("BAŞARI-blöf" ve "BAŞARISIZLIK-blöf"). Constitution'daki her adli kayıt, gerçek bir olaya işaret eder (örneğin, 20 Mayıs 2026'daki D3 ses yönlendirme BAŞARI-blöfünde doğrulama "Kullanılan Kodlayıcı" alanı boş olmasına rağmen yeşil yandı, ya da 25 Haziran 2026'daki dev butonlu arayüz, gerçek ekran bozuk olmasına rağmen belirteç eşitlik testlerini geçti). Constitution, bu tür sahte başarıları bir kez, evrensel olarak ve mekanik olarak imkansız hale getirmek için var — böylece disiplin projeler arasında kaybolmaz ya da sessizce unutulmaz.

## Neden bir oyun değiştirici

Mühendislik kültürünü, insanların umut ettiği belgelerden miras alınan, sürümlendirilmiş, mekanik olarak uygulanan bir yasaya dönüştürüyor — bir stil kılavuzu ile derleyici arasındaki fark gibi. Tek bir alt modül güncellemesi, kuralları tüm filoya aynı anda, atomik ve izlenebilir şekilde yükseltir. Tek bir anti-blöf sözleşmesi, güvenle değil yapısal olarak *garanti* edilir: Her tüketici depoda mevcuttur; bir yayılım kapısı, sözleşme numarasını tüm filoda kelimenin tam anlamıyla arar ve eşleştirilmiş bir mutasyon testi, kapının kendisinin blöf yapmadığını kanıtlar — böylece uygulama bile uygulanır hale gelir. Yönetişim, kimsenin okumadığı bir wiki sayfasındaki bir heves olmaktan çıkıp, bir CI işine işaret edebileceğiniz denetlenebilir, test edilebilir bir gerçekliğe dönüşür.

## Yenilikçi olan ne

- **Constitution-alt modül olarak** — mühendislik yasası, koda tıpkı kod gibi dağıtılır ve sürüm sabitlenir; kasıtlı `v1.0.0` tarzı etiketler ve proje bazında sabitleme ile her depo, hangi yasa revizyonuna bağlı olduğunu *tam olarak* bilir.
- **Anti-blöf ilk sınıf, adli bir doktrin olarak** — her madde, kelimesi kelimesine bir operatör talimatına ve sıklıkla da onu motive eden gerçek dünyadaki olaya kadar izlenir; böylece kural kitabı, bir görüşler toplamı değil, içtihat hukuku gibi okunur.
- **Kuralların meta-test edilmesi (§1.1)** — her kapı, BAŞARI→BAŞARISIZLIK dönüşümünü zorunlu kılan bir mutasyonla eşleştirilir; böylece "kapı sahte değil" iddiası değil, her çalıştırmada kanıtlanır; hiçbir zaman başarısız olamayan bir kapı, hiç kapı olmamasından daha kötü kabul edilir.
- **Kazanılmış evrensellik** — bir kuralın gerçekten evrensel mi yoksa sadece projeye özgü mü olduğunu belirlemek için açık bir dört aşamalı test uygulanır; böylece temel, yalın, taşınabilir ve satıcı sızıntısından arınmış kalır.

## Tüm ürünlerde nasıl kullanılıyor (sağladığı yetenekler)

Bir **zorunlu yönetişim sütunu** olarak HelixConstitution, aile tarafından danışılan bir belge değil — ailenin üzerine inşa edildiği yük taşıyan yapıdır:

- **Yönetişim omurgası:** Her Helix/vasic-digital projesi, onu bir alt modül olarak ekler ve `CLAUDE.md` / `AGENTS.md` / `QWEN.md` ya da kendi `Constitution.md` dosyasından içe aktarır; kurallar, ilk commit’ten itibaren koşulsuz olarak uygulanır, proje bazında muafiyet yoktur.
- **Kapılar ve zorunluluklar:** Dört katmanlı kapsam modelini tanımlar — kaynak mevcut, derlemeyi geçer, çalışma zamanında davranır, kapı blöf değil — bir özelliğin tamamlanmış sayılabilmesi için bu dört seviyeyi geçmesi gerekir; ayrıca büyüyen bir zorunluluklar listesi: kimlik bilgileri yönetimi (§11.4.10), belgelerin her zaman senkronize olması (§11.4.60), konteyner-alt modül zorunluluğu (§11.4.76), CodeGraph (§11.4.78), zorunlu test türü kapsamı (§11.4.169) ve daha fazlası.
- **Yayılım:** `CM-COVENANT-114-NNN-YAYILIM` kapıları, *kelimesi kelimesine* madde metninin tüketici filosunda mevcut olduğunu doğrular; böylece bir sözleşme, mülkün bir köşesinde sessizce düşürülemez; uyumsuzluk, kaçış bayrağı olmaksızın sert bir yayın engelleyicisidir.
- **Keşif:** `submodules-catalogue.md`, "X’i yapan bir şeyimiz zaten var mı?" sorusunu yeni bir modül oluşturulmadan önce tek bakışta yanıtlar hale getirir, yinelenen çabayı kaynağında ortadan kaldırır.
- **AI ajanlarının tutarlılığı:** Aynı yasa, her CLI ajanı için (Claude Code, Codex/Cursor/Aider/OpenCode/Crush/Kimi AGENTS.md aracılığıyla, Qwen Code QWEN.md aracılığıyla) aynı şekilde ifade edilir; böylece koda hangi araç dokunursa dokunsun, tek ve aynı sözleşmeye uyar.

İçerik

## En Büyük Teknik Zorluklar ve Çözümlerimiz

- **Keyfi derinlikteki alt modülün konumlandırılması** — Üç alt modül derinliğine gömülü bir kural, nerede olduğunu bilmese bile yasayı bulmak zorunda → `find_constitution.sh`, üst dizinlerde yukarı doğru yürüyerek git üst proje işaretçisini özyinelemeli olarak takip eder, `CONSTITUTION_DIR` geçersiz kılma seçeneğine ve iki desteklenen düzenleme (`constitution/`, `submodules/constitution/`) uyum sağlar; böylece iç içe geçme ne kadar derin olursa olsun çözümleme her zaman belirleyicidir.
- **Dört Git sağlayıcısı arasında tek bir depoyu yetkili tutma** — Senkronizasyonu kaybolan yansılar işe yaramaz → `install_upstreams.sh`, bildirimsel `Upstreams/*.sh` uzak depolarını okur ve `origin`'i birden fazla gönderim URL’si ile yapılandırır; böylece tek bir `git push` komutu GitHub (birincil), GitLab, GitFlic ve GitVerse’e atomik olarak dağıtılır ve hiçbir yansı geride kalmaz.
- **Kural şişkinliğini / evrensel tabana proje sızıntısını önleme** — Her "bunu buraya ekle" cazibesi taşınabilirliği aşındırır → Kazanılmış evrensellik dört aşamalı testi ve §11.4.17 evrensel-proje sınıflandırması *her* yeni kurala uygulanır; projeye özgü kaygılar, ait oldukları proje katmanına geri itilir.
- **Miras kapısının gerçekten işe yaradığını kanıtlama** — Asla başarısız olmadığını görmediğiniz bir kapıya güvenemezsiniz → `meta_test_inheritance.sh`, bir nöbetçi meta testi olarak §11.4 çapasını kasten siler ve kapının bunu yakaladığını doğrular; böylece uygulama mekanizmasının kendisi, sessiz bozulmalara karşı sürekli yeniden doğrulanır.

## Teknoloji Yığını

- **Git-alt modül mirası** — *neden:* Git alt modülleri, bir kural kitabının hem yetkili hem de tüketici başına sürüm sabitlenmiş olmasını sağlayan tek mekanizmadır; sessiz kopyala-yapıştır yerine açık, incelenebilir bir sürüm yükseltmesiyle güncellenir; *nasıl:* Tüketen projeler alt modülü ekler ve ajan dosyalarını `@import` ile alır; üç katman, her sınırda "genişletir, zayıflatmaz" sözleşmesiyle yukarıdan aşağıya değerlendirilir.
- **`find_constitution.sh`** — *neden:* Kurallar, derinlemesine iç içe geçmiş kodlar bunları güvenilir şekilde bulamazsa işe yaramaz; yolların sabit kodlanması, bir proje yeniden düzenlendiğinde bozulur; *nasıl:* Üst dizinlerde yürüyüş ve `git rev-parse --show-superproject-working-tree` özyinelemesi, `CONSTITUTION_DIR` geçersiz kılma seçeneğiyle desteklenir; her iki desteklenen düzenlemeyi de çözer.
- **`install_upstreams.sh` + `Upstreams/`** — *neden:* Dört sağlayıcı yedekliliği, bakımı için ekstra çaba gerektiriyorsa gerçek değildir; aksi halde yansılar çürür; *nasıl:* Bildirimsel her uzak depo için `.sh` dosyaları, tek bir çoklu-URL `origin` olarak somutlaştırılır; dört gönderim tek bir komuta indirgenir.
- **§1.1 mutasyon meta testleri** — *neden:* Asla başarısız olamayan bir kapı, hiç yoktan daha kötüdür çünkü sahte güven üretir; *nasıl:* Her kapı, PASS→FAIL’e dönüşmesi gereken bir sed-çıkar/yeniden adlandırma mutasyonuyla eşleştirilir ve ardından geri yüklenir; böylece her kapı, her çalıştırmada hâlâ etkili olduğunu kanıtlar.
- **Yayılım kapıları (`CM-COVENANT-114-NNN-YAYILIM`)** — *neden:* Bir sözleşme, yalnızca amiral gemisi depoda değil, *her* tüketicide doğrulanabilir şekilde mevcutsa evrenseldir; *nasıl:* Tüketiciler arasında kelime bazında madde numarası araması, kendisinin de başarısız olabileceğini kanıtlayan eşleştirilmiş bir §1.1 mutasyonuyla desteklenir.
- **`submodules-catalogue.md` (§11.4.74)** — *neden:* Çoğaltma karşıtı disiplini ihlal etmenin en hızlı yolu, zaten sahip olduklarınızı bilmemektir; *nasıl:* 142 depodan oluşan, yetenek gruplarına ayrılmış bir envanter; yeni bir şey oluşturulmadan önce katalog kontrolü izleyiciye kaydedilir.
- **Çoklu format dışa aktarımı** — *neden:* Aynı yasa, insanlar tarafından okunabilir, araçlar tarafından ayrıştırılabilir ve arşivler tarafından korunabilir olmalıdır; *nasıl:* Her resmi belge, tek bir kaynaktan `.md` / `.html` / `.pdf` / `.docx` olarak yayılır.

İçerik

## Durum ve Dürüstlük Notları

- **Durum: gönderildi.** Filo genelinde (kamu kanon ve yansıtma depoları) aktif olarak sürümlendirilmekte ve bir alt modül olarak kullanılmaktadır.
- **Lisans: Belirlenmedi** — incelenen kaynak materyalde açıkça belirtilmemiştir; yayınlamadan önce depodaki LİSANS dosyası ile teyit ediniz.
- Ek yukarı akış yansıtmaları: GitLab `helixdevelopment1/helixconstitution`, GitFlic `helixdevelopment/helixconstitution`, GitVerse `helixdevelopment/HelixConstitution`.

**Öncelik seviyesi:** Helix-birincil — Helix ailesindeki her şeyin nasıl inşa edildiğinin zorunlu yönetişim sütunu.

