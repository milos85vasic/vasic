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

**単一の真実の源泉を、あらゆる場所にミラーリング——数十のホストにまたがる連合型Git**

## 概要

HelixGitpx（Helix Git Proxy eXtended）は、単一の真実の源泉を複数の上流Gitホストにミラーリングし、避けられない競合をポリシーおよびAI支援のフローで解決する連合型Gitプロキシです。v1.0.0 GAに到達しました。

## 短い説明

HelixGitpxは、単一の真実の源泉を10以上のGitホスト——GitHub、GitLab、Gitea、Bitbucket、Azure DevOps、AWS CodeCommitなど——にミラーリングし、同期の競合をポリシーおよびAI支援のフローで解決する連合型Gitプロキシです。v1.0.0 GAとしてリリースされました。

## 長い説明

HelixGitpx（「Helix Git Proxy eXtended」）は、単一の真実の源泉を複数の上流Gitホストにミラーリングし、同一リポジトリが複数の場所に存在する瞬間に必然的に発生する競合を解決する連合型Gitプロキシです。対応する上流ホストはGitエコシステム全体を網羅するかのようで、GitHub、GitLab、GitFlic、GitVerse、Gitea、Gitee、Bitbucket、Azure DevOps、AWS CodeCommit、Forgejo、SourceHut、そして汎用的なGit-over-HTTPSなどが含まれます。単純な`git push`を十数か所のリモートに行うと、失敗するか、あるいはさらに悪いことにミラーが静かに乖離してしまう可能性がありますが、HelixGitpxはポリシーおよびAI支援の解決フローを介して、乖離を一つの権威ある真実へと調停します。

プロジェクトはv1.0.0 GAに到達し、`m1-foundation`から`m8-ga`までのマイルストーンがタグ付けされています——基盤から一般提供までの完全なロードマップです。製品は三層構造で設計されており、連合エンジンを担うGoモノレポ（プラットフォーム、18のサービス、コード生成、スキャフォールディングツール）、Angular 19 + Nxウェブアプリケーション、そしてKotlin-Multiplatform + Composeクライアントシェルが共通コードからAndroid、iOS、デスクトップ向けのネイティブ体験を提供します。プラットフォームのデリバリーはKubernetesネイティブを核とし——Helmチャート、Argo CDアプリケーション、Kustomizeオーバーレイ、SQL、OPAポリシー——CIパイプラインは明示的なディスパッチによって制御され、誤ってデプロイされることはありません。公開ドキュメントはDocusaurusサイト（docs.helixgitpx.io）として提供され、Astroによるマーケティングサイト（helixgitpx.io）と併せて公開されています。

ガバナンスは厳格かつ憲法主導であり、それは形式ではなく機能です。プロジェクトの基幹文書であるConstitutionの第2条は、7種類のテストマトリックスを*変更されたモジュールごとに100%のカバレッジで*実施することを義務付けており、モックはユニットテストでのみ許可され、テストのスキップは一切認められません。ワンショットの検証ツールがすべてのアーティファクトチェックに加え、`go vet`と`go test`をワークスペース全体で実行し、すべてのプッシュは設定されたすべての上流ホストに展開されます——「ミラーが同期している」ことは、人間が確認するのではなく、システムがコミットごとに強制するものなのです。

## なぜ開発したのか

複数のGitホストにまたがってリポジトリの整合性を保つことは——冗長性、主権、あるいは地域プラットフォームへのアクセスのためであっても——脆弱で手作業に頼る部分が多く、乖離したミラーの調停は困難です。HelixGitpxは、複数の上流ホストへのミラーリングを、競合を認識した第一級の機能として実現するために開発されました。

コンテンツ

## なぜゲームチェンジャーなのか

「複数のリモートにプッシュして祈る」という脆弱で手動の現状を、統制された連合体へと変革します。単一の信頼できる情報源と、自動化されたポリシー＋AIによる競合解決を実現し、さらに通常のツールが無視しがちな地域プラットフォーム（GitFlic、GitVerse、Giteeなど）も意図的にカバー。これにより、冗長性やデータ主権、それらのエコシステムへのリーチが、維持管理の負担から、一度設定するだけの単一機能へと進化します。

## 革新的なポイント

- **アップストリームの幅広さ** – GitHubやGitLabから、GitFlic、GitVerse、Giteeなどの地域プラットフォームまで、10を超えるGitホストを一つのプロキシで統一。
- **ポリシー＆AI支援の競合解決** – 分岐はポリシーエンジンとAIリゾルバーによって自動調整され、手作業でのミラーリング比較は不要。
- **単一情報源連合** – すべてのアップストリームに対するプッシュモデルで、一つの権威あるリポジトリが真実となり、すべてのホストは同期されたミラーとして機能。
- **厳格な憲法強制テスト** – 7種類のテストをタイプごとに100%カバーし、スキップなし。信頼ではなく、ワンショットのグリーンスイートスクリプトで証明。

## 最大の技術的課題とその解決策

- **多数のアップストリーム間での分岐と競合**。同じリポジトリが複数の場所に存在すると、二つのホストが異なる書き込みを受け入れた瞬間に乖離が発生。解決策は、単一の情報源を基盤としたポリシー＆AI支援の解決フローと、すべてのアップストリームを同期させるプッシュにより、すべてのミラーがその真実に収束する仕組み。
- **多様なGitホストへの均一サポート**。各ホストには独自の認証、癖、APIが存在。解決策は、`Upstreams/`配下のアップストリームごとの設定スクリプトと、それらの違いを抽象化するプラットフォーム層。新しいホストの追加は設定作業で済み、書き直しは不要。
- **マージ前の正確性の証明**。解決策は、必須の7種類のテストマトリックスと、`verify-everything.sh`ワンショットゲート。フルチェックセットを実行し、クラスターにアクセスできない場合はクリーンに短絡。これにより、CIだけでなくローカルでも正確性が証明可能。

## テックスタック

- **Goモノレポ** – コアプロキシと連合エンジン：プラットフォーム＋18のサービス、コード生成、スキャフォールディングを一つのリポジトリに集約。エンジン全体が単一のユニットとしてビルド・テストされる。
- **Angular 19 + Nx** – ウェブアプリケーション。Nxが大規模フロントエンドに必要なモノレポのビルド／キャッシュ構造を提供。
- **Kotlin Multiplatform + Compose** – ネイティブAndroid、iOS、デスクトップクライアント。一つの共有コードベースから生成され、3つのプラットフォームが3つの実装を意味しない。
- **Kubernetes + Helm + Argo CD + Kustomize** – クラウドネイティブデリバリー：Helmがリリースをパッケージ化、Kustomizeが環境ごとにオーバーレイ適用、Argo CDがGitOpsでクラスター状態をGitと同期。
- **OPA (Rego)** – 競合解決とアクセス制御のためのポリシー・アズ・コード。認可判断を宣言的かつ監査可能に。
- **Docusaurus** – 公式ドキュメントサイト（docs.helixgitpx.io）；**Astro** – マーケティングサイト（helixgitpx.io）。それぞれのコンテンツタイプに最適なツールを採用。
- **mise** – 固定された再現可能なツールチェーン。すべての貢献者とCIランナーが同一バージョンでビルド。

内容

## ステータスおよび正確性に関する注意事項

- **ステータス：出荷済み。** プロジェクトのREADMEでは、マイルストーン`m1-foundation`から`m8-ga`までがタグ付けされたv1.0.0 GAと宣言されている。（「v1.0.0 GA」はプロジェクトのREADMEによる主張。）
- **ライセンス：未確定。** GitHubおよびAPIのレポートでは`MIT`と記載されているが、READMEのライセンスセクションではApache-2.0（コード）およびCC-BY-SA-4.0（ドキュメント）と記述されている。公開前に実際のLICENSEファイルと照合すること。
- ドキュメント（docs.helixgitpx.io）およびマーケティング（helixgitpx.io）のURLはREADMEに基づくものであり、独立して取得されたものではない。稼働状況は**未検証**。

**優先度区分：** Helix-プライマリ。

