---
name: Mail Server Factory
slug: mail-server-factory
tier: serverfactory-tertiary
order: 29
status: production (reports 439 tests at 100% pass and a clean SonarQube gate)
license: UNVERIFIED
private: false
tech:
  - Kotlin (2.0.21)
  - Shell
  - Docker
  - QEMU
  - JSON (declarative config)
  - Gradle 8.14.3 / Java 17
  - Caffeine
  - G1GC-tuned JVM
  - Prometheus-compatible metrics
  - Sieve
repos:
  - https://github.com/Server-Factory/Mail-Server-Factory
  - https://github.com/Server-Factory/Mail-Server-Factory-Website
diagrams:
  - JSON-in → Factory engine → installed Docker mail stack (Postfix/Dovecot/TLS)
  - Connection-type fan-out (local/SSH/Docker/K8s/AWS SSM/Azure/GCP/Libvirt) to targets
  - Distribution matrix (Western/Russian/Chinese families) with unattended-install badges
  - Security layer callouts (AES-256-GCM, firewall ports, TLS/HSTS, RBAC, audit log)
---

**メールサーバーをボス級に運用──JSONで記述し、どこにでもデプロイ**

## 概要

Mail Server Factoryは、本番環境対応の自動メールサーバー構築ツールです。ユーザーがシンプルなJSON設定ファイルを記述すると、Factoryがそれを解釈し、対象OS上で必要なインストールと初期化をすべて実行。12種類の接続方式に対応した、Dockerベースの疎結合メールスタックをデプロイします。

## 簡単な説明

Kotlin／Shellツールで、JSONの記述をもとに完全にインストールされたDocker化メールサーバーを構築します。12種類の接続方式（SSH、Docker、Kubernetes、AWS SSM、Azure、GCP、Libvirtなど）に対応し、包括的なセキュリティフレームワーク、25種類のLinuxディストリビューションをサポート。439件のテストをパスしています。

## 詳細説明

本格的でセキュアなメールサーバーを立ち上げることは、システム管理における古典的な通過儀礼の一つであり──同時に、最も確実に苦痛を伴う作業の一つでもあります。Postfix、Dovecot、TLS証明書、DNSレコード、ファイアウォールルール、そしてディストリビューションごとの癖をすべて完璧に揃える必要があり、一つでも設定を誤れば、メールが静かにバウンスされたり、オープンリレーになってしまったりします。Mail Server Factoryは、こうした長年の経験とエラーを生みやすいノウハウをすべてソフトウェアに封じ込めました。見知らぬOS上で各コンポーネントを手作業で設定する代わりに、エンドユーザーはJSONドキュメントで望む結果を記述するだけ。FactoryはそのJSONを読み込み、対象OS上で必要なインストールと初期化手順を正確に実行し、Docker上で動作するメールスタックを立ち上げます。各コンポーネントは疎結合設計となっており、水平スケーラビリティを確保しつつ、個々のコンポーネントを独立してアップグレードや置き換えが可能です。また、意図的にリーチに依存しない設計となっており、12種類の接続方式を通じて、同じツールと同じJSONでローカルマシン、SSH経由のリモートホスト、DockerやKubernetesランタイム、AWS SSM／Azureシリアルコンソール／GCP OSログイン経由のクラウドインスタンス、Libvirt上のVMなど、どこにでも同じ宣言的記述をデプロイできます。

サポートするLinuxディストリビューションは25種類に及び、西側系（Ubuntu、Debian、CentOS、Fedora、AlmaLinux、Rocky、openSUSE）、ロシア系（ALT、Astra、ROSA）、中国系（openEuler、openKylin、Deepin）の各ファミリーに対応。preseed／kickstart／cloud-init／autoyastによる無人インストールや、テスト用のQEMUベースVM自動化も可能です。

エンタープライズ機能も充実しており、AES-256-GCM暗号化、パスワードおよびSSH鍵ポリシーの強制、メールポート（25／587／465／993／995）用の自動ファイアウォール設定、TLS／SSL（証明書検証とHSTS対応）、監査ログ、RBACを備えています。運用面では、JVMチューニング（G1GC）、Caffeineキャッシュ、コネクションプーリング、Prometheus互換メトリクス、構造化ログ、設定のホットリロード、シークレット管理などをサポート。プロジェクトは439件のテストを100％パスし、SonarQubeクオリティゲートもクリーンな状態です。Server-Factory組織のフラッグシッププロジェクトとなっています。

コンテンツ

## なぜ開発したのか

セキュアで本番環境に対応したメールサーバーの構築は、エラーが発生しやすくOSに依存することで知られています。Mail Server Factoryは、その専門知識を宣言的なJSONモデルと実行エンジンに集約し、正確でセキュアなDocker化されたメールスタックを、手動でのステップバイステップ作業なしに、サポート対象のあらゆるターゲット上で再現可能にします。

## なぜ画期的なのか

メールサーバーのプロビジョニングを、専門家による数日間の「完璧を期す」作業から、設定ファイルの記述という行為へと格下げし、さらにその行為を12種類の接続方式と25のLinuxディストリビューションに対応させ、企業レベルのセキュリティデフォルトを最初から備えた形でポータブルにします。その結果は再現性があり、*検証可能*です。同じJSONからは常に同じセキュアなスタックが生成され、プロジェクトが報告する439件の合格テストとクリーンなSonarQubeゲートにより、作業を担うエンジン自体が評判に頼るのではなく、厳密に検証されています。

## 革新的な点

- 宣言的なJSON → ターゲットOS上での解釈型インストール／初期化。
- 1つのツールで対応する12種類の接続方式（ローカル、SSH、Docker、Kubernetes、AWS SSM、Azure、GCP、Libvirtなど）。
- 25種類のディストリビューションに対応した無人インストール（preseed/kickstart/cloud-init/autoyast）とQEMUによる自動化。
- 疎結合のDocker化スタックによる独立したスケーリング／アップグレード。

## 課題と解決策

- **OS／ディストリビューションの多様性**：ディストリビューションごとのレシピ、無人インストール設定、QEMUベースのクロスディストリビューションテストで解決。
- **多数のデプロイターゲットへの対応**：共通のインストールエンジンの下で12種類のプラガブルな接続方式を実装。
- **デフォルトでのセキュリティ**：AES-256-GCM、強制的な鍵／パスワードポリシー、自動ファイアウォールルール、TLS／HSTSで解決。
- **正確性への信頼**：439件のテストスイート（100％合格）とクリーンなSonarQubeゲートで解決。

## 技術スタック（理由と方法）

- **Kotlin** — Factoryエンジンおよびインストールステップロジック（179Kバイト；Kotlin 2.0.21）。
- **Shell** — プロビジョニングスクリプト、ISO／QEMUマネージャー、OS自動化（バイト数で支配的）。
- **Docker** — デプロイされた疎結合メールスタックのランタイム。
- **QEMU** — クロスディストリビューションインストールおよびテストのためのVM自動化。
- **JSON** — ユーザー向けの宣言的設定フォーマット。
- **Gradle 8.14.3／Java 17** — ビルドツールチェーン。
- **Caffeine** — マルチリージョンキャッシュ；**G1GCチューニング済みJVM**によるパフォーマンス向上。
- **Prometheus互換メトリクス** — モニタリング；Grafana／ELK対応。
- **Sieve** — メールフィルタリングルール（言語統計では小規模）。

> 注：GitHubは、Server-Factory組織内でのフォークリポジトリを示します。AI製品ラインよりも前のもので、AIユーティリティではなく、成熟したDevOps／プロビジョニングのフラッグシップとして位置付けられています。

