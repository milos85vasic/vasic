---
doc: cv
title: Curriculum Vitae — Miloš Vasić
role: AI Engineer / Software Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
  company: https://vasic.digital
  github_orgs:
    - https://github.com/vasic-digital
    - https://github.com/HelixDevelopment
    - https://github.com/Server-Factory
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: Skills and projects are evidence-based (repository READMEs + analysis). Experience and Education are sourced verbatim from the candidate's own verified record at milosvasic.ru/README.md — real employers, roles, and dates; nothing fabricated (Constitution §11.4.6).
---

# Miloš Vasić

**エンジニア — LLMインフラ、自律エージェント、そしてそれらを信頼に足るものにするガバナンス**

- Email: milos85vasic@gmail.com
- Web: https://milosvasic.ru · https://vasic.digital
- GitHub: vasic-digital · HelixDevelopment · Server-Factory

---

## 概要

AI/ソフトウェアエンジニアとして、マルチプロバイダーのLLMインフラや自律エージェントから、それらの信頼性を担保するQAやガバナンスレイヤーまで、エンドツーエンドで開発システムを構築しています。私はデモを作るのではなく、プラットフォームを提供します。15年以上（2009年以降）のプロフェッショナルなエンジニアリング経験を持ち、モバイルSDK、リアルタイムハードウェア統合、分散バックエンドなどの分野で培った知見を、一つの焦点に集約しています。それは、自律的なAI開発を大規模かつ信頼性の高いものにすることです。

私はモノリスではなく、フリートを設計します。数十もの小規模で疎結合、独立してテストされたモジュールの上に成り立つ大規模なプロダクトアプリケーションを構築し、それぞれが共通のエンジニアリングConstitutionを継承し、証拠に基づく厳格なQAプロセスによって検証されます。主な使用言語はGoで、Kotlin/KMP、TypeScript/React、Python、Swift、Shellも扱います。機械的に強制される指針として、実際のユーザーが利用でき、かつその証拠が記録されて初めて、機能は完成したとみなされます。

**私の強み：** AIの機能を研究段階のアイデアから、ガバナンスされた自己検証可能な本番環境レベルのシステムへと昇華させる能力です。具体的には、モデルが実際に機能することを証明するLLMルーティング、推測ではなく議論と合意形成を行うエージェント、コンテキストを失わないメモリやRAGレイヤー、そして「テストがグリーン」が決して「機能が壊れている」を意味しないように設計されたエコシステム全体を実現します。

## コアコンピテンシー

- **AI / LLMシステム：** マルチプロバイダーLLM抽象化（40以上のプロバイダー）、MCPツール統合、RAG、vectorデータベース＆embeddings、エージェントオーケストレーション（ヘッドレスCLIエージェント、グラフワークフロー、マルチラウンドの議論/合意形成）、プランニング（HiPlan/MCTS/Tree-of-Thoughts）、LLMOps、ベンチマーキング（SWE-bench/HumanEval/MMLU）、LLM検証、防御的LLMガードレール、コンピュータビジョン＋LLMビジョン。
- **バックエンドエンジニアリング：** Go（Gin）、gRPC＋Protobuf、HTTP/3（QUIC）、WebSocket、分散システム（TLA+形式仕様を含む）、高スループットRESTサービスと並行ワーカー。
- **データ：** PostgreSQL、SQLite、SQLCipher（保存時暗号化）、Redis、Neo4j、ClickHouse、オブジェクトストレージ（MinIO/S3/GCS/Azure）。
- **フロントエンド / クロスプラットフォーム：** TypeScript/React（Tailwind、Redux Toolkit、i18next）、Angular、Electron、React Native、Kotlin Multiplatform、Android/Android TV（Kotlin）、iOS（Swift）、Tauri/Rust。
- **インフラ / DevOps：** Docker＆Compose、Kubernetes＋Helm、Prometheus＋Grafana、OpenTelemetry、QEMU/Libvirt/Parallels；CI/CD（GitHub Actions経由）、Gradle、Make。
- **QA / 品質エンジニアリング：** 証拠に基づく厳格なQA（HelixQA）、ミューテーションゲート付きチャレンジハーネス、`go test -race`、ビジュアルリグレッションテスト、ADBデバイステスト、SonarQube、セキュリティスキャン（semgrep/gosec/trivy/snyk/gitleaks/nancy）。
- **エンジニアリングガバナンス：** Constitutionをサブモジュールとして活用；継承と伝播のゲート；140以上のリポジトリにまたがるドキュメント/カバレッジ規律。

目次

## 選定プロジェクト

### ガバナンス＆品質保証
- **HelixConstitution** — Gitサブモジュールとして配布され、140以上のリポジトリに継承される普遍的なエンジニアリング規約集。エンジニアリングの「法」はコードと同様に出荷・バージョン固定され、サブモジュールの更新一つで全フリートのルールがアップグレードされる。伝播ゲートは、各消費リポジトリを文字通りgrepして必要条項を検索し、ゲート自体が偽物でないことを証明する変異メタテストとペアになっている。「人々が従いたいと思うベストプラクティス」を、継承可能で監査可能、機械的に強制される「反ブラフ法」へと変える。
- **HelixQA** — 絶対に譲らない一つの原則に基づく反ブラフ品質保証オーケストレーション（Go）：「テストが通る」ではなく「ユーザーが機能を使える」ことが基準。記述式のYAMLテストバンクと、完全自律型のLLM＆ビジョンQAセッションを実行。実際のアプリを開き、ドキュメント化された機能をすべて検証し、Android/Android TV/Web/Desktopにまたがる未ドキュメントのバグを探索。実行時証拠（スクリーンショット、logcat、動画、スタックトレース）とAI対応の修正チケットが揃わなければ、PASS判定を拒否する。

### AI開発＆LLMインフラ
- **HelixAgent** — 単一モデルを信頼しない本番レベルのアンサンブルLLMサービス（Go/Gin）。プロンプトを複数のプロバイダーに展開し、構造化された多段階ディベート（提案→批判→レビュー→統合）を実施。ライブ検証スコアに基づくルーティングと、グレースフルなフォールバックを備え、OpenAI互換のAPI、HAデータレイヤー、オブザーバビリティ、ガードレールを統合。*Go、Gin、PostgreSQL、Redis、Prometheus/Grafana/OpenTelemetry、MCP、Neo4j/ClickHouse/Kafka。*
- **HelixCode** — 分散型AI開発プラットフォーム。SSH管理のワーカーフリートを活用し、作業を依存関係を考慮したインテリジェントなタスクに分割。タスクが中断されてもチェックポイントとロールバックにより何も失われない。ハードウェアに応じたモデル選択と、REST/CLI/TUI/MCPを通じた計画・ビルド・テスト・リファクタリングの完全なライフサイクルを実現。*Go、Gin、PostgreSQL、Redis、SSH、MCP、llama.cpp/Ollama。*
- **HelixLLM** — 単一バイナリ、6つのデプロイモード。OpenAIおよびAnthropic互換のHTTP/3推論を、ラップトップからマルチホストクラスターまでスケール。ローカルのllama.cpp推論（CUDA/Metal/ROCm）と、自動検出・検証スコア付きのクラウドフォールバックチェーンを備え、常にローカルモデルへの確実なフォールバックを保証。*Go、HTTP/3 QUIC、gRPC/SSE/Kafka、llama.cpp。*
- **LLMProvider / LLMOrchestrator / LLMsVerifier** — LLMインフラの基盤。43のプロバイダーを統合する単一インターフェースに、サーキットブレーカー、ヘルスモニタリング、ジッターバックオフ再試行、そして（ハードコードされたフォールバックなしの）正直なモデル検出を実装。スレッドセーフなコントロールプレーンは、ヘッドレスのCLIエージェント（OpenCode、Claude Code、Gemini、Junie、Qwen Code）をハイブリッドなパイプ＋ファイルプロトコルで生成・駆動。さらに、「私のコードが見えますか？」という必須ゲートを持つ検証真実源泉により、実際に動作することが証明されたモデルのみが使用可能またはエクスポートされる。
- **HelixMemory / HelixSpecifier** — 4つの最先端バックエンド（Mem0、Cognee、Letta、Graphiti）を統合し、並列検索とクロスソースの再ランキングを備えた単一インターフェースの認知記憶エンジン。また、作業規模に応じて自身のセレモニーをスケールし、仕様をマルチエージェントディベートで裏付ける仕様駆動開発融合エンジン。
- **HelixTrack** — フリーなJIRA + Confluence代替（Helix-Trackラインのフラッグシップ）。Goマイクロサービスと、HTTP/3上の統一アクションルーティングAPI、保存時のSQLCipher暗号化、ネイティブWeb/Desktop/Android/iOSクライアントを搭載。

コンテンツ

### プロダクトグレードのツール（vasic-digital utils）
- **Catalogizer** — マルチプロトコル対応、暗号化、自己ホスティング可能なメディアコレクション管理ツール（Go/Gin + React）。不安定なネットワークストレージにも耐性があり、21の再利用可能なサブモジュールで構築。
- **Courses-Creator** — Markdownから動画へのAIコースパイプライン。TTSおよびデスクトップ/モバイル/ウェブプレイヤーを搭載。
- **VisionEngine** — コンピュータビジョン + マルチプロバイダーLLMビジョンUI認識機能。ナビゲーショングラフを活用。
- **DocProcessor**・ **Docs Chain**・ **Herald**・ **task_bridge**・ **Vasic Digital 再利用可能モジュールスイート** — QA機能マッピング、コンテンツハッシュ化されたドキュメント/データベース同期、自然言語通知、タスク/ボード同期、および`digital.vasic.*`標準ライブラリ群。

### インフラストラクチャ自動化（Server Factory）
- **Mail Server Factory** — 宣言型JSONから完全プロビジョニングされたDocker化メールサーバーを12種類の接続方式と25のLinuxディストリビューションに対応。439件のテスト合格とSonarQubeゲートのクリアを報告。
- **Server Factory コアフレームワーク**、**Qemu-Utils**、**Parallels-Utils** — 共有プロビジョニングエンジンおよびVMイメージツール。

## 言語とツール（簡易リスト）

Go・Kotlin・Kotlin Multiplatform・TypeScript・JavaScript・Python・Swift・Java・Rust・Shell・PL/pgSQL・TLA+・Gin・gRPC・HTTP/3・React・Angular・Electron・React Native・PostgreSQL・SQLite・SQLCipher・Redis・Neo4j・ClickHouse・Docker・Kubernetes・Prometheus・Grafana・OpenTelemetry・QEMU・GitHub Actions・Gradle・Make

## 経歴

*2009年からソフトウェアエンジニアとして、開発ライフサイクル全般（計画、開発、チームリーダー、デプロイメント）に携わる。以下の全経歴は、候補者の認証済み記録（milosvasic.ru）に基づく。*

### 常勤ポジション

- **SDK開発者 — Harness**（harness.io）、ベオグラード、セルビア（2020年3月～2024年12月）
  同社のFeature Flag部門向けSDKファミリーのリード開発者。主要なモバイルプラットフォームを中心に開発を担当。顧客・パートナーにはAWS、Google、および複数の銀行が含まれる。
  *使用技術：Android、iOS、Flutter、React Native、TypeScript、JavaScript、Java、Kotlin、Swift、Go、Ruby。*

- **ソフトウェアエンジニア — Leica Geosystems**（leica-geosystems.com）、ヘールブルッグ、スイス（2016年2月～2020年2月）
  主にiOSおよびAndroidエンジニアリングを担当。Leica Geosystemsの最先端3Dスキャナー向けに、ハードウェアとのリアルタイム通信、データ処理、同期を実装。パートナー：Autodesk。
  *使用技術：Android、iOS、Java、Kotlin、Swift、C++。*

- **SDK開発者 — Bosch**（bosch.rs）、ベオグラード、セルビア（2010年1月～2016年1月）
  Connected Vehicles SDKプロジェクトのリードSDK開発者。OBD2バスとのリアルタイムBluetooth通信、高性能データ処理および永続化を担当。
  *使用技術：Android、Java、Kotlin。*

### その他の活動

- **TN-TECH**（tn-tech.co.rs）、セルビア・ノヴィサド　・　2017年3月よりパートタイム。Globex Data（カナダおよびスイス）向け業務—Sekur（SekurMessenger）、SekurMail、SekurSuite—およびBusRideプラットフォームに従事。*技術：Android、Java、Kotlin、C++、Qt。*
- **Increment Loop**（incrementloop.com）、セルビア・ベオグラード　・　2023年9月よりパートタイム。Yunoアプリケーションの開発に携わる。*技術：Android、Kotlin。*
- **オープンソース／自主プロジェクト** — HelixTrack、Server Factory（Mail Server Factory、Parallels-Utils、Qemu-Utils）、およびVasic Digital（Android-Toolkit、Network-Binder）。詳細は上記「選択プロジェクト」を参照。

## 刊行物

- **『Fundamental Kotlin』** — 自費出版。最新改訂版は2022年9月（第3版）。また、Packt Publishing（英国）からも出版。

## 学歴

- **修士（現代情報技術）** — University Singidunum（セルビア・ベオグラード）　・　2014年。
- **学士（情報学およびコンピューティング）** — University Singidunum（セルビア・ベオグラード）　・　2008年。

