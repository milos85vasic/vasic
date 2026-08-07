---
name: VisionEngine
slug: visionengine
tier: vasic-util-secondary
order: 23
status: active
license: UNVERIFIED
private: false
tech:
  - Go (1.25+)
  - GoCV / OpenCV (build-tag-gated)
  - LLM vision providers (GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)
  - Graph algorithms (BFS)
  - DOT / JSON / Mermaid exporters
  - i18n Translator seam
repos:
  - https://github.com/HelixDevelopment/VisionEngine
  - https://github.com/vasic-digital/VisionEngine
diagrams:
  - Four-layer stack (Analyzer / NavigationGraph / LLM Vision / Config)
  - Navigation graph rendered (Mermaid) with BFS path highlighted
  - Vision fallback chain across providers
  - Build-tag split (default stub build vs -tags vision OpenCV build)
---

**Kullanıcı gibi gör — analiz ve navigasyon için bilgisayarlı görü ile LLM görüşü.**

## Özet

VisionEngine, klasik bilgisayarlı görü ile LLM tabanlı görüşü birleştiren, bağımsız bir Go araç setidir. Kullanıcı arayüzlerini analiz eder, UI öğelerini ve görsel sorunları tespit eder, uygulama ekran geçişlerinin navigasyon grafiklerini oluşturur. Çoklu sağlayıcı destekli görüş arka uçları ve OpenCV, bir derleme etiketiyle kontrol altına alınmıştır.

## Kısa açıklama

UI analizi ve navigasyon grafiği oluşturma için yeniden kullanılabilir bir Go modülü. Analiz katmanı (UI öğeleri, ekran farkları, görsel sorunlar), BFS yol bulma özelliğine sahip navigasyon grafiği ve DOT/JSON/Mermaid dışa aktarım seçenekleri sunar. Ayrıca GPT-4o, Claude, Gemini, Qwen-VL ve daha fazlası için LLM görüş adaptörleri içerir.

## Uzun açıklama

Çoğu UI test otomasyonu aslında kördür. Erişilebilirlik ağaçlarına ve DOM seçicilerine yönelir — bir makinenin arayüz algısıdır bu — ve bir insanın gerçekten deneyimlediği her şeyi kaçırır: bir düğmenin görünür olup olmadığı, düzenin bozulup bozulmadığı, ulaşılan ekranın beklenen ekran olup olmadığı. VisionEngine, otomasyona gerçek bir algı kazandırarak bu boşluğu kapatır; bir arayüzü insan gibi görmesini ve onun hakkında akıl yürütmesini sağlar. Ham piksellerden bütün bir uygulamayı anlama seviyesine kadar dört iş birliği içinde çalışan katmandan oluşur.

**Analizör**, istikrarlı bir sözleşme tanımlar — arayüzler (`Analyzer`, `VideoProcessor`) ve değer türleri (`UIElement`, `ScreenAnalysis`, `ScreenDiff`, `Rect`, `Size`, `TextRegion`, `VisualIssue`, `ScreenIdentity`, `Action`, `KeyFrame`) ile bir `StubAnalyzer` referans uygulaması sunar. Böylece tüketiciler, altlarında kaymayacak bir sözleşme üzerinden öğeleri tespit edebilir, ekranları karşılaştırabilir ve görsel sorunları ortaya çıkarabilir.

**Navigasyon Grafiği**, bakış açısını tek bir ekrandan tüm uygulamaya taşır. Uygulamayı, ekran geçişlerinin yönlü bir grafiği olarak modeller; BFS yol bulma özelliği ve üç dışa aktarım arka ucu (DOT, JSON, Mermaid) ile otomasyon yalnızca bir ekranı görmekle kalmaz, herhangi bir ekrana giden rotayı da planlayabilir. Ayrıca stres, otomasyon, entegrasyon ve güvenlik testleriyle bu yetenek kanıtlanır.

**LLM Görüş** katmanı, modern çok modlu akıl yürütme ekler: `VisionProvider` arayüzü ve OpenAI (GPT-4o), Anthropic (Claude), Gemini, Qwen-VL, Kimi, StepGUI, Astica ve Ollama için adaptörler içerir. Bu adaptörler, bir `FallbackChain` aracılığıyla birleştirilir; böylece başarısız olan, hız sınırına takılan veya zayıf bir sağlayıcı, çalışmayı durdurmak yerine bir sonrakine sorunsuz geçiş yapar.

**Yapılandırma** katmanı, ortam değişkenlerinin yüklenmesi ve doğrulanmasını yönetir. Kullanıcıya yönelik tüm hata mesajları `i18n.Translator` üzerinden yönlendirilir.

Tüm bunların benimsenmesini sağlayan asıl karar, ağır yerel bağımlılığın isteğe bağlı olmasıdır. OpenCV bağlayıcıları, `-tags vision` etiketiyle derleme aşamasında kontrol altına alınır ve varsayılan derleme, taklit uygulamalarla birlikte gelir. Böylece modül, OpenCV araç zincirine ihtiyaç duymadan herhangi bir Go 1.25+ ortamında derlenir, test edilir ve çalıştırılır. Yerel yapı yalnızca tüketici tarafından açıkça tercih edildiğinde devreye girer. Bu sayede VisionEngine, özel bir imaj gerektirmeden doğrudan bir CI çalıştırıcısına entegre edilebilir.

Tamamen bağımsız olarak tasarlanan (CONST-051(B) uyarınca) modül, tüketiciler — özellikle HelixQA — tarafından eşit kod tabanlı bir alt modül olarak dahil edilir. Böylece kanıta dayalı UI testlerine gerçek bir çift göz kazandırılır.

## Neden Geliştirdik

Yalnızca erişilebilirlik ağaçlarına veya seçicilere dayanan kullanıcı arayüzü test otomasyonu, kullanıcının gerçekte gördüğünü ıskalar. VisionEngine, gerçek görsel anlayışı —öğe tespiti, ekran karşılaştırması ve LLM görsel muhakemesi— devreye sokarak, otomasyonun bir kullanıcı arayüzünü hem algılamasını hem de onun içinde yön bulmasını sağlayan, gezilebilir bir uygulama ekranları haritası sunar.

## Neden Oyun Değiştirici

Normalde birbiriyle bağdaşmayan iki yaklaşımı —hızlı, deterministik klasik bilgisayarlı görü ve esnek, semantik LLM görüsü— tek bir arayüz altında, yedekleme zinciriyle birleştirerek, kullanıcıya birinin kesinliğini diğerinin muhakeme gücünü sunar; seçim yapmak zorunda bırakmaz. OpenCV’yi kesinlikle isteğe bağlı tutarak, bu gücün alışıldık bedelini ortadan kaldırır: Herhangi bir Go projesi, yerel görü araç zincirini derlemeye dahil etmeden gerçek kullanıcı arayüzü algısına kavuşabilir.

## Yenilikçi Yönler

- **Çift algı:** Klasik bilgisayarlı görü (OpenCV/GoCV) ile çoklu sağlayıcılı LLM görüsü, yedekleme zinciriyle desteklenir.
- **Yön bulma grafiği:** BFS tabanlı yol bulma ve DOT/JSON/Mermaid dışa aktarımı.
- **Derleme etiketiyle kontrol edilen OpenCV:** Modül, yerel bağımlılıklar olmadan derlenebilir ve test edilebilir kalır.
- **Tamamen bağımsız, uluslararasılaştırmaya uygun, eşit kod tabanlı alt modül (HelixQA tarafından kullanılır).**

## Zorluklar ve Çözümler

- **Ağır yerel bağımlılık sorunu:** `-tags vision` etiketi ve varsayılan sahte bileşenlerle çözüldü; OpenCV’siz CI/ana makinelerde bile derleme ve testler çalışır.
- **Görü sağlayıcılarının güvenilmezliği:** `VisionProvider` arayüzü ve `FallbackChain` bestecisiyle çözüldü.
- **Karmaşık uygulama akışlarının haritalanması:** Yönlü yön bulma grafiği, BFS tabanlı yol bulma ve çoklu format dışa aktarımıyla çözüldü.
- **Bağımlılık sorunu:** CONST-051(B) bağımsızlaştırma ve uluslararasılaştırma çevirmeni katmanıyla çözüldü.

## Teknoloji Yığını (Neden ve Nasıl)

- **Go (1.25+)** — Modül çekirdeği ve dört katmanı.
- **GoCV / OpenCV** — Klasik bilgisayarlı görü, derleme etiketiyle kontrol edilir.
- **LLM görü sağlayıcıları (GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)** — Çok modlu kullanıcı arayüzü muhakemesi, adaptörler aracılığıyla.
- **Graf algoritmaları (BFS)** — Yön bulma için yol planlaması.
- **DOT / JSON / Mermaid dışa aktarıcıları** — Yön bulma grafiği görselleştirmesi.
- **Uluslararasılaştırma Çevirmeni** — Kullanıcıya yönelik metinlerin bağımsızlaştırılması.

