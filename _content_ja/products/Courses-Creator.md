---
name: Courses-Creator
slug: courses-creator
tier: vasic-util-secondary
order: 22
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - TypeScript
  - React
  - Electron
  - React Native
  - PostgreSQL
  - Python
  - LLM providers (OpenAI, Anthropic, Ollama)
  - TTS (Bark, SpeechT5)
  - MCP
  - Docker Compose
  - nginx
  - Prometheus
  - Grafana
repos:
  - https://github.com/vasic-digital/Courses-Creator
diagrams:
  - Pipeline flow (markdown → LLM enrichment → TTS + music → video assembly → publish)
  - One-backend-three-clients topology (desktop/mobile/web over shared API)
  - Deployment stack (Docker Compose services)
  - Optional-AI toggle (basic vs enhanced path by provider keys)
---

**マークダウンを入力し、プロフェッショナルなビデオコースを出力 — AI強化、マルチプラットフォーム対応**

## 概要

Courses-Creatorは、マークダウン形式のスクリプトをAI強化機能を搭載したプロフェッショナルなビデオコースに変換するツールキットです。マルチLLMコンテンツ強化（OpenAI／Anthropic／Ollama）、高品質なTTSとBGMを生成し、デスクトップ、モバイル、ウェブプレイヤーに対応。すべてDockerデプロイメントとPrometheus／Grafanaモニタリング機能を備えています。

## 短い説明

マークダウンを魅力的なビデオコースに変換。Go処理エンジンが複数のLLMプロバイダーを通じてコンテンツを強化し、ナレーション（Bark／SpeechT5 TTS）とBGMを生成。Electronデスクトップ、React Nativeモバイル、Reactウェブプレイヤーに配信し、完全なDockerデプロイメントとモニタリングを実現します。

## 長い説明

通常、ビデオコースの制作には小規模なスタジオ並みの作業が必要です。スクリプトの作成、ナレーションの録音、BGMの選定、編集、エンコード、そして学習者が利用するすべてのプラットフォーム向けプレイヤーの構築。Courses-Creatorは、この一連の工程を一つの入力——マークダウンスクリプト——と一つのコマンドに集約します。その核となるのはGoコアプロセッサーで、完全なビデオ／オーディオパイプラインを実行。複数のLLMプロバイダー（OpenAI、Anthropic、ローカルOllama）を通じて文章コンテンツを強化し、テキスト読み上げエンジン（Bark、SpeechT5）で自然なナレーションを合成、BGMを重ね合わせ、完成したコースビデオに組み立てます。著者の仕事はアイデアと文章に集中でき、システムが音声、音楽、制作を担当します。そして、コースが実際に視聴されてこそ意味があるため、配信はマルチプラットフォーム対応を前提に設計。Electronデスクトップクリエーターアプリ、React Nativeモバイルプレイヤー、Reactウェブプレイヤーの3つを、同じREST APIとバックグラウンドジョブシステムで統一的に提供。一つのバックエンドで、三つの一流クライアントを実現し、プラットフォームごとの再実装は不要です。

重要なのは、これが単なるデモではなく、本格的な制作インフラである点です。バックエンドにはPostgreSQL永続化機能、長時間のTTS／ビデオレンダリングでもAPIをブロックしないバックグラウンドジョブ処理、ツール強化型のMCPサーバー実装、Prometheusメトリクス、JWT認証、そしてnginxリバースプロキシが組み込まれています。そして、これらすべてがDocker Composeデプロイメントとして提供され、Grafana／Prometheusモニタリングプロファイルをワンストップで立ち上げ可能です。AIは強化レイヤーであり、依存関係ではありません。すべてのLLMプロバイダーはオプションなので、基本操作ではAPIキーがなくても動作し、キーを追加すればプレミアム強化機能が有効になります。この単一の設計により、オフラインでノートPCを使うホビイストから、自社のプロバイダーを統合するエンタープライズまで、同じツールが幅広く利用可能です。そして、その基盤となるメディアパイプライン全体は、ユニットテスト、統合テスト、エンドツーエンドテストで検証されており、信頼性は保証されています。

## なぜ開発したのか

手作業でコースビデオを制作するのは時間がかかります。スクリプトの作成、ナレーション、音楽の選定、編集にはそれぞれ専門的なツールと労力が必要です。Courses-Creatorは、このプロセスをマークダウン駆動のパイプラインに集約し、一つのソーススクリプトから完成したコースを生成。AIが、人間が手作業で行うべきギャップを埋めます。

コンテンツ

## なぜゲームチェンジャーなのか

コース制作を、専門家向けの複雑なマルチツール作業から、再現可能なソフトウェアパイプラインへと変革します。執筆、AIによるコンテンツ強化、ナレーション・音楽生成、マルチプラットフォーム再生まで、すべてが一つのデプロイ可能なスタックに統合されています。APIキー操作を必要としない優雅なフォールバック機能こそが、静かな超能力です。同じコードベースが、予算に敏感な個人クリエイターと、プレミアムプロバイダー契約を結ぶエンタープライズの双方に対応し、その間に書き直しは一切不要です。

## 革新的なポイント

- プラガブルなマルチLLM強化機能を備えたMarkdown-to-videoパイプライン（OpenAI／Anthropic／Ollama）。
- 組み込みのTTS（Bark、SpeechT5）およびBGM生成機能。
- ツール拡張強化のためのMCPサーバー実装をプロセッシングエンジン内に統合。
- 単一のバックエンドで3つの第一級クライアント（Electronデスクトップ、React Nativeモバイル、Reactウェブ）に対応。

## 課題と解決策

- **大容量メディア処理**：Goパイプラインとバックグラウンドジョブ処理により解決。長時間のTTS／ビデオジョブがAPIをブロックしない。
- **オプションながら強力なAI**：LLMプロバイダーをオプションかつプラガブルにし、基本機能への優雅なフォールバックを実現。
- **マルチプラットフォーム配信**：共有のREST APIと3つの専用プレイヤーアプリで対応。
- **運用性**：Docker Composeプロファイル、Prometheus／Grafana、および組み込みのJWT認証により解決。

## テックスタック（理由と方法）

- **Go** — コアプロセッサエンジン、REST API、ジョブランナー、パイプライン（972K+バイト、主要言語）。
- **TypeScript／React** — ウェブプレイヤーおよび共通UI。
- **Electron** — デスクトップクリエイターアプリ。
- **React Native** — モバイルプレイヤー。
- **PostgreSQL** — コース／ジョブの永続化。
- **LLMプロバイダー（OpenAI、Anthropic、Ollama）** — コンテンツ強化。
- **TTS（Bark、SpeechT5）** — ナレーション合成。
- **MCPサーバー** — エンジン内でのツール統合。
- **Docker Compose + nginx** — フルスタックデプロイメントおよびリバースプロキシ。
- **Prometheus + Grafana** — モニタリング。

> 注：公開READMEのクイックスタートでは、`your-org`クローン用のプレースホルダーURLを使用しています。

