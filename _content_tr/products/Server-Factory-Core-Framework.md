---
name: Server Factory Core Framework
slug: server-factory-core-framework
tier: serverfactory-tertiary
order: 30
status: stable (foundational framework; internal API specifics UNVERIFIED)
license: UNVERIFIED
private: false
tech:
  - Kotlin (~990K bytes)
  - Shell (minimal supporting scripts)
  - Gradle
repos:
  - https://github.com/Server-Factory/Core-Framework
diagrams:
  - Hub-and-spoke (Core Framework at center, factories as spokes)
  - Layered stack (Core Framework → factory product → target system)
  - Shared-engine benefit (one fix in Core → propagates to all factories)
---

**Her Server Factory'un Arkasındaki Ortak Motor**

## Özet

Core Framework, Server Factory ailesi tedarik araçlarının temelini oluşturan Kotlin çatısıdır. Mail Server Factory gibi projelerin üzerine inşa edildiği ortak motoru ve soyutlamaları sağlayarak, her "fabrika"nın sıfırdan tedarik ilkeleri geliştirmek yerine tek bir sınanmış temeli yeniden kullanmasını mümkün kılar.

## Kısa açıklama

Server Factory ekosisteminin temelindeki ortak Kotlin çatısı. Alt projeler (Mail Server Factory, Web Service Factory, SonarQube Factory ve diğerleri) tarafından kullanılan ortak tedarik motorunu, bağlantı soyutlamalarını ve kurulum adımı mekanizmalarını sunar.

## Uzun açıklama

Core Framework, tüm Server-Factory ailesini mümkün kılan sessiz mühendislik parçasıdır: Her bir "fabrika" ürününün (Mail Server Factory, Web Service Factory, SonarQube Factory, Caching Proxy Factory) üzerinde inşa edildiği yeniden kullanılabilir motor. Server Factory yaklaşımı bildirimsel niteliktedir — kullanıcı, istediği altyapıyı bir konfigürasyon olarak tanımlar ve fabrika bu tanımı yorumlayarak hedef sistemde yazılımı kurar ve başlatır. Core Framework ise bu modelin ortak mekanizmalarının gerçekten yaşadığı yerdir: Her türlü hedefe ulaşan bağlantı ve taşıma soyutlamaları, yazılımın *nasıl* tedarik edildiğini kodlayan kurulum adımı modeli ve her fabrikanın aksi takdirde kendisi için yazması gerekecek ortak altyapı. Çok ürünlü araç zincirlerinin sonunda karşılaştığı yapısal bir sorunun yanıtıdır: Ortak motor nereye konmalı? Bu soruya bir kez doğru yanıt vermek, ailenin dört farklı tedarikçiye bölünmek yerine tutarlı kalmasını sağlar. Bu işlevselliği tek bir Kotlin çatısı altında merkezileştirerek, aile tedarik mantığının ürünler arasında tekrarlanmasını önler ve davranış tutarlılığını korur: Core Framework’te iyileştirilen bir bağlantı türü veya kurulum ilkesi, tüm alt projelerde fayda sağlar. Neredeyse tamamen Kotlin’dan oluşur (yaklaşık 990K baytlık Kotlin ve ince bir Shell katmanı), bu da onun bir kod kütüphanesi olarak rolünü yansıtır; bir betik koleksiyonu değil. Alt projeler, onu temel bağımlılık olarak referans gösterir (Parallels-Utils, Qemu-Utils, Utils ve Tanımlar paketleri, Core Framework deposunu ekosistemin merkezi olarak gösterir). README dosyası kasıtlı olarak minimal tutulmuştur — diğer projeler için bir altyapı görevi görür ve `version.txt`/`version_code.txt` üzerinden sürümlendirilir. Daha sonraki AI çalışmalarından önce geliştirilmiş olması, kuruluşun olgun DevOps araç zinciri mirasının bir parçası olduğunu gösterir.

## Neden inşa ettik

Her tedarik aracının aynı çekirdeğe ihtiyacı vardır: Hedeflere bağlanma yolları ve yazılımı kurma/konfigüre etme adımları. Bunu her ürün için yeniden inşa etmek, davranışların parçalanmasına ve hataların artmasına yol açardı. Core Framework, tüm fabrikaların tek bir güvenilir motoru paylaşmasını sağlayarak bu sorunu ortadan kaldırır.

## Neden oyunun kurallarını değiştiriyor

Tüm ailedeki en yüksek kaldıraç noktasıdır: Burada güçlendirilen bir bağlantı türü veya iyileştirilen bir kurulum ilkesi, bu doğruluğu ve yeteneği tüm fabrikalara anında aktarır. Böylece tüm araç zinciri, tek bir yatırımdan faydalanır. "Bir kez inşa et, her yerde kullan" felsefesinin en çok getiri sağladığı yer — altyapı otomasyonunun temel katmanı — burasıdır. Doğru yerdeki bir düzeltme, aşağı akıştaki her şeyi düzeltir.

İçerik

## Yenilikçi Yönler

- Bağlantı ve kurulum adımı mantığını soyutlayan, yeniden kullanılabilir tek bir sağlama çerçevesi.
- Motor (Çekirdek Çerçeve) ile ürüne özgü fabrikalar arasındaki net ayrım.
- Yeniden üretilebilir tüketim için sürüm sabitlenmiş dağıtım (`version.txt`/`version_code.txt`).

## Zorluklar ve Çözümler

- **Sağlama mantığının tekrarlanmasının önlenmesi:** Tüm fabrikalar tarafından tüketilen tek bir çerçeveye ortak mekanizmaların aktarılmasıyla çözüldü.
- **Ürünler arasında tutarlı davranış:** Bağlantı türleri ve adımların her yerde aynı şekilde çalışmasını sağlayan ortak soyutlamalarla çözüldü.
- **(DOĞRULANMAMIŞ):** Belirli dahili API’ler genel README’de belgelenmemiştir; arayüz detayları, "fabrikalar tarafından tüketilen ortak çerçeve" ifadesinin ötesinde doğrulanmamış olarak kabul edilmelidir.

## Teknoloji Yığını (Neden ve Nasıl)

- **Kotlin** — Tüm çerçeve (~990K bayt); Server Factory ailesinin dili.
- **Shell** — Asgari destekleyici betikler.
- **Gradle** — Derleme araç zinciri (ailenin `./gradlew` kullanımıyla tutarlı).

> Not: GitHub, depoyu Server-Factory organizasyonu içinde bir çatallama olarak işaretler. AI merkezli değildir; sağlama araç zincirinin omurgası olarak sunulmuştur.

