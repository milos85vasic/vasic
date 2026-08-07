---
site: vasic.digital
type: company-site
title: Vasic Digital — AI-Native Software Engineering
tagline: We build AI development systems — and the governance that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Vasic Digital

## ヒーロー

**AIネイティブのソフトウェアエンジニアリング。信頼を前提に構築。**

誰でも午後のひとときでアプリをLLMに接続することはできる。しかし、AIシステムがデモに終わるか、信頼できるプロダクトになるかを決めるのは、モデルを取り巻くすべての要素だ。障害時にも耐えるプロバイダー抽象化、エージェントをタスクに集中させるオーケストレーション、モデルのハッタリを見抜く検証、そしてシステム全体の挙動を証明するガバナンス。Vasic Digitalが構築するのは、まさにその難題だ。私たちはAI開発システム――モデル、エージェント、オーケストレーション、インフラを設計・提供し、大規模言語モデルを信頼性の高いソフトウェアへと変える。さらに、それらを律するガバナンスレイヤーも一体として提供する。すべては一つの妥協なき原則に支えられている。テストが通っただけでは「完了」ではない。実際のユーザーが使えるようになり、その証拠が記録されて初めて「完了」なのだ。

## 会社概要

Vasic Digitalは、AI開発のための相互に連携するプロダクト群と再利用可能なモジュールを構築する、専門性の高いエンジニアリングチームだ。一つの巨大なシステムではなく、独立したテストを経た数十の小規模モジュールを基盤に、その上に大規模なプロダクトアプリケーションを展開する「艦隊」方式を採用。実績ある部品は再構築することなく、すべてのプロダクトで再利用される。基盤となる言語は**Go**で、これに**Kotlin / Kotlin Multiplatform**、**TypeScript/React**、**Python**、**Swift**、**Shell**が用途に応じて補完される。Goは高スループットのサービスやライブラリに、Kotlinはプロビジョニングツールやクロスプラットフォームのモバイル開発に、TypeScriptは型付きフロントエンドに、PythonはAI/MLの接着剤として活用される。

この艦隊を一つに結びつけるのは、理想ではなく機械的に実装された規律だ。すべてのプロジェクトは共通のエンジニアリング**Constitution**をGitサブモジュールとして継承するため、一度ルールを強化すれば140以上のリポジトリに瞬時に反映される。また、プロダクトが謳う機能はすべて、自動化された証拠生成テストによって裏付けられなければ「リリース」とは認められない。これは単なるマーケティング用の文言ではない。私たちの仕事が動く根幹そのものだ。この積み重ねが真の強みとなる。汎用的な機能は独立したテスト済みモジュールに集約されているため、一つの修正や改善が全プロダクトに波及し、新たなシステムはすでに信頼を勝ち得た部品の組み合わせで構築される。

## 私たちの仕事

**AIベースの開発。**私たちはAIシステムの基盤をエンドツーエンドで構築する。

- **マルチプロバイダーLLMアクセス**――40以上のプロバイダー（Anthropic/Claude、OpenAI、DeepSeek、Gemini、Mistral、Cohere、Groq、xAI/Grok、Qwen、Perplexity、OpenRouter、Together AI、Replicate、Cerebras、Cloudflare Workers AI、SiliconFlow、そしてフォールバックとしてのローカルOllama）を一つのインターフェースで統合。リトライ、サーキットブレーカー、ヘルスチェックを備える。
- **エージェントオーケストレーション**――ヘッドレスのCLIコーディングエージェント制御プレーン、グラフベースのエージェントワークフロー、マルチラウンドの「AIディベート」による合意形成、DAG/パイプラインランタイム。
- **LLM検証**――信頼性レイヤーとして、必須の理解度ゲート（「私のコードが見えますか？」）に加え、レイテンシ、ストリーミング、関数呼び出し、ビジョン、embeddingsテストをスコアリング。検証済みの設定のみをエクスポート。
- **検索と記憶**――RAG、vectorデータベース、embeddings、そして無限コンテキスト圧縮を備えた融合型エージェントメモリエンジン（Mem0 + Cognee + Letta）。
- **防御的LLM**――ガードレール、PII検出、敵対的レッドチームフィクスチャ、入力の正規化。

**Helixプロダクトファミリー**
当社のフラッグシップラインは、AI開発ライフサイクル全体をカバーします：

- **HelixTrack** ― Helix-TrackラインのフラッグシップであるJIRAに対するフリーワールドの代替ソリューション。
- **HelixAgent** ― 複数のモデルが議論し、合意した回答を出力するアンサンブル型LLMサービス。
- **HelixCode** ― SSH管理のワーカーに作業を分散し、チェックポイント／ロールバック機能を備えた分散型AI開発プラットフォーム。
- **HelixLLM** ― 単一バイナリ、6つのモード：OpenAIおよびAnthropic互換の推論機能を、ラップトップからクラスターまで、HTTP/3上で提供。
- **HelixCluster** ― データセンターのGPUからエッジ端末まで、AIコンピューティングのための分散型オペレーティングシステム。
- **LLMProvider / LLMOrchestrator / LLMsVerifier** ― プロバイダー抽象化レイヤー、エージェント制御プレーン、検証のための信頼できる情報源。
- **HelixMemory、HelixSkills、HelixSpecifier、HelixBuilder、HelixTranslate、HelixTerminator、HelixGitpx、HelixOTA、HelixPlay** ― メモリ管理、ガバナンスされたスキル、仕様駆動型開発、アプリケーション構築、検証済み翻訳、ゼロトラスト端末、連合型Git、安全なOTAアップデート、セルフホスト型クラウドゲーミング。

**ツールとユーティリティ（vasic-digital utils）**
単体で機能するプロダクトレベルのツール群：
**Catalogizer**（マルチプロトコル対応の暗号化メディアコレクション管理）、**Courses-Creator**（Markdownから動画AIコースを生成するプロダクションツール）、**VisionEngine**（コンピュータビジョンとLLMビジョンによるUI認識）、**DocProcessor**（ドキュメントから機能マップを生成するQA支援ツール）、**Docs Chain**（コンテンツハッシュによる双方向ドキュメント／データベース同期）、**Herald**（自然言語によるマルチチャネル通知）、**task_bridge**（タスクとボードの双方向同期）、そして**Vasic Digital再利用可能モジュールスイート** ― インフラストラクチャ、AIプリミティブ、ガードレールモジュールを集約した`digital.vasic.*`「標準ライブラリ」。

**インフラストラクチャ自動化（Server Factory）**
当社のDevOpsのルーツを反映：**Mail Server Factory**と**Server Factoryコアフレームワーク**は、宣言型JSONをさまざまな接続方式やLinuxディストリビューションに対応した完全プロビジョニング済みのDocker化サーバーへと変換。さらに、VMイメージツール（Qemu-Utils、Parallels-Utils）やサポートサービスファクトリーも提供。

## テクノロジー

実際のスタックに基づく技術：

- **言語**：Go（主力）、Kotlin & Kotlin Multiplatform、TypeScript、Python、Swift、Shell。分散システムの分野ではPL/pgSQLやTLA+による形式仕様も活用。
- **AI / LLM**：マルチプロバイダー対応（43以上のアダプター）、Model Context Protocol（MCP）、RAG、vectorデータベースおよびembeddings、プランニングアルゴリズム（HiPlan、MCTS、Tree of Thoughts）、LLMOps、ベンチマーク（SWE-bench／HumanEval／MMLU）、TTS（Bark、SpeechT5）。
- **バックエンド**：Gin（Go）、gRPC + Protocol Buffers、HTTP/3（QUIC）、WebSocket、AngularおよびReactフロントエンド、Kafka／RabbitMQメッセージング。
- **データ**：PostgreSQL、SQLite、SQLCipher（保存時暗号化）、Redis、Neo4j、ClickHouse、オブジェクトストレージ（MinIO／S3／GCS／Azure）。
- **インフラ／DevOps**：Docker & Compose、Kubernetes + Helm、Prometheus + Grafana、OpenTelemetry、QEMU／Libvirt／Parallels、CI/CD（GitHub Actions、Gradle、Make経由）。
- **テスト／QA**：アンチブラフのHelixQAフレームワーク、モジュールごとのチャレンジハーネス（ミューテーションゲート付き）、`go test -race`、ビジュアルリグレッションツール、ADBデバイステスト、SonarQubeゲート、セキュリティスキャン（semgrep、gosec、trivy、snyk、gitleaks、nancy）。

## 品質とガバナンス — 私たちの差別化要因

艦隊全体を一貫性と信頼性のあるものにする二つの柱：

- **HelixConstitution** — 汎用的でプロジェクトに依存しないエンジニアリング規約集。Gitサブモジュールとして提供され、140以上のリポジトリにまたがる全プロジェクトに継承される。これは譲れない規律をコード化したもので、ブラフ防止のエビデンスゲート、偽陽性耐性、データとホストの安全性、ドキュメントとカバレッジのルールなどが含まれる。プロジェクトはこれらを拡張することはできるが、弱めることは許されない。一つのサブモジュールのバージョンアップで全てのルールが更新され、伝播ゲートは文字通り艦隊全体にわたって必要な条項をgrep検索し、各ゲートにはそのゲート自体が偽物でないことを証明するミューテーションテストがペアで組み込まれている。ガバナンスは単なる理想ではなく、監査可能な事実となる。
- **HelixQA** — ブラフ防止のQAオーケストレーション。YAMLテストバンクを実行し、Android、Android TV、Web、デスクトップにまたがる完全自律型のLLM＋コンピュータビジョンQAセッションを展開。実行時のエビデンス（スクリーンショット、logcat、動画、スタックトレース）がなければPASSと評価されることはない。「テスト済み」は「これが動画、logcat、チケットです」に変わる。

## ポジショニングステートメント

LLMにアプリを接続することは誰にでもできる。Vasic Digitalが作るのは難しい部分だ。検証可能で再利用可能、そして正直なAIシステム — プロバイダーに依存しないAI基盤、その上に構築されるHelix製品のライフサイクル、そして実際に動作することを保証する憲法＋エビデンスの規律。私たちは緑のチェックマークを信じてほしいとは言わない。その背後にあるエビデンスをお見せする。

## お問い合わせ

検証可能なものを一緒に作りましょう。

- **メール：** [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub：** [github.com/vasic-digital](https://github.com/vasic-digital)

