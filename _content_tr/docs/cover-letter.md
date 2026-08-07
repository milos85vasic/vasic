---
doc: cover-letter
title: Cover Letter — Miloš Vasić, AI Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: General-purpose letter — no employer, project outcome, or metric is fabricated. The published edition is placeholder-free; per-application tailoring (specific role/company) is done from this master in a separate, unpublished copy.
---

# Ön Yazı

Sayın İşe Alım Ekibi,

AI üretim sistemlerinin geliştirilmesine odaklanan mühendislik pozisyonlarına olan ilgimi belirtmek için yazıyorum. Ben, AI yazılımlarının göz alıcı olmayan ama yük taşıyan kısmını inşa eden bir AI mühendisiyim: LLM altyapısı, otonom ajanlar ve orkestrasyon katmanları ile bunları üretimde güvenilir kılan QA ve yönetişim katmanları.

Son yıllarda, birbiriyle bağlantılı bir AI geliştirme ürünleri ailesi tasarladım ve hayata geçirdim. Helix serisi, tüm yaşam döngüsünü kapsıyor — HelixAgent (birden fazla modelin tartışıp üzerinde uzlaştıkları yanıtı gönderdiği toplu bir LLM hizmeti), HelixCode (işin SSH tarafından yönetilen çalışanlar arasında dağıtıldığı, kontrol noktası/geri alma özelliğine sahip dağıtık bir AI geliştirme platformu), HelixLLM (OpenAI ve Anthropic uyumlu çıkarım hizmetlerini HTTP/3 üzerinden tek bir ikili dosya olarak sunan bir sistem) ve LLM altyapı üçlüsü LLMProvider, LLMOrchestrator ve LLMsVerifier (43 sağlayıcı üzerinde tek bir arayüz, başsız CLI ajanları için kontrol düzlemi ve doğrulama kaynağı). Bunların etrafında, Catalogizer (çok protokollü, şifreli medya yönetimi) ve Courses-Creator (AI markdown’dan videoya ders oluşturma hattı) gibi ürün kalitesinde araçlar geliştirdim. Tüm bunlar, küçük, bağımsız test edilmiş Go ve Kotlin Multiplatform modüllerinden oluşan bir filonun üzerinde yükseliyor.

Benim çalışmalarımı farklı kılan, ciddiye aldığım bir disiplin: **blöf karşıtı mühendislik.** Tüm mühendislik ekibimizde ortak kullanılan, Git alt modülü olarak dağıtılan ve 140’tan fazla depoda miras alınan evrensel bir Constitution uyguluyorum. Bu sistem, mekanik olarak uygulanabilir tek bir kuralı hayata geçiriyor: Bir özellik, testleri geçtiğinde değil, gerçek bir kullanıcı tarafından kullanılabildiğinde ve bunun kanıtı olduğunda tamamlanmış sayılır. Buna ek olarak, HelixQA adını verdiğim, Android, Web ve Masaüstü üzerinde otonom LLM ve bilgisayarla görü ekran oturumları çalıştıran ve ekran görüntüsü, logcat veya video olmadan BAŞARILI sonucunu onaylamayan bir blöf karşıtı QA orkestratörü kullanıyorum. Sadece bitmiş *gibi görünen* değil, gerçekten bitmiş sistemler inşa ediyorum.

Teknik açıdan ağırlıklı olarak Go ile çalışıyorum; Kotlin/KMP, TypeScript/React, Python, Swift ve Shell dillerini ve araçlarını kullanarak REST/gRPC/HTTP/3 hizmetleri, PostgreSQL/SQLite/Redis/ClickHouse veri katmanları ve Docker/Kubernetes/Prometheus operasyonları üzerinde çalışıyorum. Bir sistemin sağlayıcı soyutlamasından ve veri çekiminden, çalıştığının kanıtını sunan kanıt zincirine kadar tüm süreçlerini yönetmekten keyif alıyorum.

Bu birikimimi — derin AI sistem mühendisliği ile gerçek, doğrulanabilir kalite disiplinini — ekibinize taşımak için fırsat bulabilmeyi umuyorum. İlginiz için teşekkür ederim; portföyüm ve halka açık depolarıma milosvasic.ru ve vasic.digital adreslerinden ulaşabilirsiniz.

Saygılarımla,
Miloš Vasić
milos85vasic@gmail.com

