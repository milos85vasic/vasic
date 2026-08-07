---
name: Catalogizer
slug: catalogizer
tier: vasic-util-secondary
order: 21
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - Gin
  - TypeScript
  - React
  - Tailwind
  - WebSockets
  - SQLCipher
  - PostgreSQL
  - Redis
  - SMB/FTP/NFS/WebDAV
  - Prometheus
  - OpenTelemetry
  - Docker
  - Tauri/Rust
  - S3
  - Google Cloud Storage
repos:
  - https://github.com/vasic-digital/Catalogizer
  - https://github.com/vasic-digital/Media-Types-TS
  - https://github.com/vasic-digital/Catalogizer-API-Client-TS
  - https://github.com/vasic-digital/Media-Player-React
  - https://github.com/vasic-digital/Media-Browser-React
  - https://github.com/vasic-digital/Collection-Manager-React
  - https://github.com/vasic-digital/Dashboard-Analytics-React
  - https://github.com/vasic-digital/Auth-Context-React
diagrams:
  - Layered architecture (React UI ↔ Go API ↔ SQLCipher) with multi-protocol fan-out
  - Resilience sequence (SMB outage → circuit breaker → offline cache → backoff reconnect)
  - Enrichment pipeline (detected file → classifier → external providers → catalog entry)
  - Module map (Catalogizer over the 21 digital.vasic.* submodules)
---

**高度なマルチプロトコル・メディアコレクション管理 —— 所有するすべてを検出、分類、拡充**

## 概要

Catalogizerは、セルフホスティング可能なメディアコレクション管理システムです。SMB、FTP、NFS、WebDAV、ローカルファイルシステムを横断してメディアを自動検出・分類・整理し、リアルタイム監視、暗号化ストレージ、外部メタデータの拡充機能を備え、高性能なGo APIをバックエンドに持つ、モダンなReact UIを提供します。

## 短い説明

プロダクションレベルのマルチプロトコル・メディアライブラリ管理システム。Go/Gin REST APIは、SMB/FTP/NFS/WebDAV/ローカルソースから50種類以上のメディアを検出し、TMDB/IMDB/MusicBrainz/Steamなどからメタデータを拡充。リアルタイムのReactウェブアプリを、暗号化されたSQLCipherデータベース上で提供します。

## 長い説明

ほとんどのメディア管理ツールは、まず「すべてを一つのディスクに、一つの形式で、一つの種類にまとめろ」と要求します。しかし、Catalogizerはその逆の発想から始まります。あなたのコレクションはすでに存在し、NAS共有や互換性のないプロトコルに分散している――それをそのまま受け入れるのです。Catalogizerは、ストレージが既に使用しているプロトコル（SMB/CIFS、FTP/FTPS、NFS、WebDAV、ローカルファイルシステム）をサポートし、単一の統合クライアント抽象化レイヤーを通じて、Windows共有、FTPアーカイブ、WebDAVマウントを同一のものとして扱います。これにより、アプリケーションコードを変更することなく、ソースを混在・入れ替え・廃止できます。Goバックエンド（Gin REST API）はこれらのソースを常時監視し、ファイルが出現すると50種類以上のメディア（映画、テレビ番組、音楽、ゲーム、ソフトウェア、ドキュメンタリーなど）を検出・分類。TMDB、IMDB、TVDB、MusicBrainz、Spotify、Steamなどの外部プロバイダーからメタデータを取得し、ファイル名だけの状態から、アートワーク、キャスト、メタデータを備えた完全なカタログエントリへと拡充します。結果はWebSocketを介してTypeScript Reactフロントエンドにストリーミングされ、手動での更新ではなく、取り込みと同時にライブラリがリアルタイムで更新されます。また、すべてのメタデータは、JWTベースのロールベース認証で保護された暗号化SQLCipherデータベースに永続化されます。

ほとんどのカタログツールは、共有が切断されるとすぐに機能しなくなりますが、Catalogizerは障害時でも有用性を維持するよう設計されています。一時的なSMB障害は、指数バックオフ再接続、デッドホストへの過剰なアクセスを防ぐサーキットブレーカー、継続的なヘルスモニタリング、オフラインメタデータキャッシュによって吸収されます。これにより、ユーザーのリクエストは最後の正常状態から応答され、「一つのNASが再起動しただけでアプリ全体が停止する」のではなく、「一つのソースが劣化しているが、他は正常に動作する」という状態を実現します。カタログ管理にとどまらず、コレクションの運用ツールとしても機能します。成長傾向や品質・バージョンの追跡分析、プロフェッショナルなPDFレポート生成、PDFから画像/テキスト/HTMLへの変換サービス、お気に入りのエクスポート/インポート（JSON/CSV）、S3やGoogleクラウドストレージ、ローカルフォルダへの同期機能を備えています。また、Catalogizerは単に巨大なモノリスではなく、21の再利用可能な`digital.vasic.*` GoサブモジュールとTypeScriptクライアントパッケージから意図的に構成されており、それぞれが独立してテスト・バージョン管理されています。これにより、Catalogizerを支える堅牢な認証、ファイルシステム、ストリーミング、可観測性のコンポーネントは、より広範な製品ファミリーにも活用されています。品質保証も自己申告ではありません。ChallengesフレームワークとHelixQAが、すべての謳われた機能を、証拠に基づく検証によって裏付けます。

コンテンツ

## なぜ開発したのか

既存のメディア管理ツールは、単一のストレージバックエンドと単一のメディアタイプを前提としています。しかし実際のコレクションは、複数のNAS共有やプロトコルにまたがり、共有が切断されると機能が低下し、映画、音楽、ゲーム、ソフトウェアが混在しています。Catalogizerは、すべてのプロトコルを平等に扱い、不安定なネットワークストレージにも耐え、すべてのデータを包括する、権威ある豊富な情報を持つ暗号化カタログを提供するために開発されました。

## なぜゲームチェンジャーなのか

通常は複数のツールを重ねて実現するものを、Catalogizerは一つの自己ホスティング可能な暗号化パッケージに集約します。ストレージバックエンドを問わずに統一的に取り込むプロトコル非依存のインジェスト、ストレージ障害時にカタログを維持し続ける耐障害性、複数のプロバイダーからの豊富なメタデータで生ファイルを閲覧可能なライブラリに変えるエンリッチメント機能。モジュール分割アーキテクチャの真価は、その複利効果にあります。ファイルシステムクライアントの強化や新しいプロバイダープラグインの追加は一度行えば、すべての利用者に恩恵が及び、Catalogizerは周辺のエコシステムと共に着実に進化します。つまり、単なるメディアインデックスではなく、真に「メディアシステム」の違いを体現するもの――それはあなたが所有し、不安定なインフラにも耐え、その内部は約束ではなく実証されたものです。

## 革新的なポイント

- 統一インターフェースによるマルチプロトコルファイルシステムクライアント（SMB/FTP/NFS/WebDAV/ローカル）。
- ストレージ障害時でもカタログを利用可能にするオフラインキャッシュとサーキットブレーカー。
- 21の再利用可能な`digital.vasic.*` GoサブモジュールおよびTSクライアントモジュールへの完全な抽出。
- 保存時暗号化カタログ（SQLCipher）とUIへのリアルタイムWebSocket同期。
- ChallengesフレームワークとHelixQA統合によるエビデンスベースの品質保証。

## 課題と解決策

- **不安定なネットワークストレージ**：指数バックオフ、サーキットブレーカー、ヘルスチェック、ソースが利用不能な場合にキャッシュメタデータを提供するエビクションポリシー付きオフラインキャッシュで解決。
- **プロトコルの多様性**：すべてのプロトコルを共通の`digital.vasic.filesystem`クライアントで抽象化し、上位レイヤーがプロトコルを意識しないように解決。
- **データセキュリティ**：SQLCipherによる保存時暗号化に加え、JWT/RBAC認証とリクエストサニタイズミドルウェアで解決。
- **大規模な保守性**：すべての汎用ロジックをモノリスではなく独立してテスト可能なサブモジュールに抽出することで解決。

## テックスタック（選定理由と実装方法）

- **Go + Gin** – 高性能なREST APIコア（`catalog-api`）。継続的な監視ワークロードにおける並行処理とスループットを重視して選定。
- **TypeScript + React + Tailwind（Vite）** – リアルタイム更新に対応したレスポンシブな`catalog-web` UI。
- **WebSocket** – バックエンドハブとUI間のライブデータ同期。
- **SQLCipher（暗号化SQLite）** – 保存時暗号化メタデータストア。`digital.vasic.database`を介したSQLite/PostgreSQLのデュアルサポート。
- **SMB/FTP/NFS/WebDAVクライアント** – `digital.vasic.filesystem`によるマルチプロトコルインジェスト。
- **外部メタデータAPI（TMDB、IMDB、TVDB、MusicBrainz、Spotify、Steam）** – エンリッチメント用プロバイダープラグイン。
- **Prometheus + OpenTelemetry** – `digital.vasic.observability`によるメトリクス/トレーシング。
- **Docker / ビルダーコンテナ** – 再現性のあるビルド（Tauri/Rustは`catalogizer-builder`を経由）。
- **Redis** – `digital.vasic.cache` / `ratelimiter`によるキャッシュとレート制限。
- **S3 / Googleクラウドストレージ** – クラウド同期とチェックポイントストレージ。

