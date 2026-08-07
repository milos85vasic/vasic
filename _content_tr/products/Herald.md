---
name: Herald
slug: herald
tier: vasic-util-secondary
order: 27
status: active (early production consumer of Docs Chain)
license: UNVERIFIED
private: false
tech:
  - Go
  - Shell
  - Claude Code (LLM intent inference)
  - Messenger channel adapters
  - Docs Chain
  - Helix Constitution submodule
repos:
  - https://github.com/vasic-digital/Herald
diagrams:
  - Fan-out topology (event source → Herald → many channels)
  - Three-tier intent ladder (command → LLM inference → clarify)
  - Attribution flow (message → participant contract → created_by/assigned_to + @-tag)
  - Docs Chain integration for Herald's doc corpus
---

**Her uyarı doğru hedefe ulaşır — komut sözdizimi gerekmez.**

## Özet

Herald, sistem olaylarını alır ve birden fazla bildirim kanalına güvenilir bir şekilde dağıtarak her uyarının doğru yere ulaşmasını sağlar. Aboneler doğal dille etkileşimde bulunur; Herald, üç aşamalı bir disiplinle (komut hızlı yolu → LLM niyet çıkarımı → netleştirme geri dönüşü) amacı tespit eder.

## Kısa açıklama

Bir olay alım ve çok kanallı bildirim dağıtım sistemi. Herald, sistem olaylarını mesajlaşma kanalları üzerinden doğru hedeflere güvenilir bir şekilde yönlendirir ve abonelerin doğal dilde konuşmasına olanak tanır — amacı, komut hızlı yolu, LLM çıkarımı ve netleştirme geri dönüşü ile çözer.

## Uzun açıklama

Herald, bir sistem olayının gerçekten bir insanın harekete geçebileceği yere ulaşmasını garanti eden bildirim omurgasıdır — çoğu yerel uyarı sisteminin sessizce başarısız olduğu, gözden kaçan ama kritik öneme sahip katmandır. Olayları alır ve birden fazla bildirim kanalına güvenilir bir şekilde dağıtarak, uyarının kaybolduğu, yanlış kanala yönlendirildiği ya da gürültü altında kaybolup artık geç kalındığı bilindik başarısızlık senaryolarını ortadan kaldırır. Ancak güvenilir teslimat hikâyenin sadece yarısıdır; diğer yarısı, bir insanın yanıt vermek istediğinde ne olduğudur. Herald, kullanıcıların bir uyarı botuyla etkileşim kurmak için katı bir komut sözdizimini ezberlemek zorunda kaldığı alışılmış pazarlığı reddeder. Aboneler basitçe doğal dille yazar ve Herald, üç aşamalı bir disiplinle ne demek istediklerini çözer: açık komutları anında tanıyan bir hızlı yol, ardından serbest biçimli mesajlar için LLM tabanlı niyet çıkarımı (Claude Kodu aracılığıyla) ve son olarak niyet gerçekten belirsiz olduğunda soru sorarak yanıt veren, etiketleyen ve netleştiren bir `netleştirme` geri dönüşü. Bu "tanı → çıkarım → netleştir" merdiveni, tasarım felsefesinin özünü oluşturur — yaygın durum anında ve deterministik kalır, esnek durum bir model tarafından ele alınır ve belirsiz durum asla yanlış eylemi tetikleyen kör bir tahminle çözülmez. Herald ayrıca katılım ve atıf modeller: bir operatör kullanıcı adı ortam değişkeni (`HERALD_<KANAL>_OPERATÖR_KULLANICIADI`) ve bir katılımcı/atıf sözleşmesi, `oluşturan`/`atanan` alanlarını ve bildirim @etiketlemesini yönlendirir; böylece kimin ne yaptığı ve kimin bilgilendirildiği açıkça bellidir. Yönetim açısından Herald, Helix Constitution’ı birlikte bulunan bir alt modül olarak devralır ve kurallarına uyar; ayrıca Docs Chain’ın erken üretim tüketicisidir — 66 belgeden oluşan Markdown→HTML/PDF/DOCX derlemesi, Docs Chain `exec:` dönüşümleri aracılığıyla bağlanır ve temiz bir şekilde doğrulanır. Herald, öncelikle Shell/Go araçlarıyla katmanlı özellikler (V1→V2→V3→V4 üstünlük sırası) ve mesajlaşma uygulamaları ile LLM/ajan dağıtıcıları için kanal başına operatör kurulum kılavuzları sunar.

## Neden geliştirdik

Uyarılar sessizce başarısız olur — yanlış kanala gönderilir, kaybolur ya da kullanıcıların hatırlamayacağı katı bir komut sözdizimi gerektirir. Herald, güvenilir dağıtımı garanti etmek ve insanların doğal dille yanıt verebilmesini sağlamak için geliştirildi; böylece bildirimler hem güvenilir hem de harekete geçmesi kolay olur.

İçerik

## Neden Oyun Değiştirici?

Genellikle ayrı ürünler olarak satın alınan iki unsuru —güvenilir çok kanallı olay yönlendirme ve doğal dil arayüzü— tek bir sistemde birleştiriyor. Operatörler sadece konuşuyor, yazılım da ne demek istediklerini anlıyor. Üretim ortamında güvenilir kılan detay ise netleştirme geri dönüşü: Yanlış alarm vermektense sormayı tercih eden bir uyarı sistemi, gerçek duruma dokunmasına izin verebileceğiniz bir sistemdir.

## Yenilikçi Yönleri

- Üç aşamalı niyet disiplini: komut hızlı yolu → LLM çıkarımı → netleştir ve sor.
- Doğal dil abone etkileşimi (öğrenilecek komut sözdizimi yok).
- Katılımcı atıf sözleşmesi ile `oluşturan`/`atanan` + @etiketleme.
- Gerçek Docs Chain tüketicisi (66 belge içeren derlem, çoklu format, doğrulanmış).

## Zorluklar ve Çözümler

- **Belirsiz doğal dil niyeti:** Kör tahmin yerine üç aşamalı tanı/çıkar/netleştir merdiveni ile çözüldü.
- **Güvenilir dağıtım:** Uyarıların doğru hedefe ulaşmasını sağlayan alım→çok kanallı dağıtım tasarımı ile çözüldü.
- **Kanallar arası doğru atıf:** Operatör kullanıcı adı ortam değişkeni ve katılımcı atıf sözleşmesi ile çözüldü.
- **Dokümantasyon kayması:** Belgelerin Docs Chain üzerinden doğrulanmış dönüşümlerle entegre edilmesiyle çözüldü.

## Teknoloji Yığını (Neden ve Nasıl)

- **Go** — temel olay/dağıtım mantığı (kuruluş dili kalıplarına göre).
- **Shell** — operatör araçları ve kurulum betikleri.
- **Claude Kodu (LLM)** — serbest metinler için niyet çıkarım katmanı.
- **Mesajlaşma kanalı adaptörleri** — çok kanallı bildirim dağıtımı.
- **Docs Chain** — dokümantasyon oluşturma/doğrulama hattı (Markdown→HTML/PDF/DOCX).
- **Helix Constitution alt modülü** — devralınan yönetişim/kurallar.

