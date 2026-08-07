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

# カバーレター

採用チームの皆様

この度は、AIのプロダクションシステム構築に特化したエンジニアリング職への応募の機会をいただき、心より感謝申し上げます。私はAIエンジニアとして、AIソフトウェアの地味ながらも基盤を支える部分を手がけてまいりました。具体的には、LLMインフラ、自律エージェントとそのオーケストレーション、そしてそれらを本番環境で信頼に足るものとするためのQAやガバナンスレイヤーなどです。

過去数年にわたり、私は相互に連携するAI開発製品群を設計・リリースしてきました。Helixラインは、開発ライフサイクル全体をカバーしています。HelixAgent（複数のモデルが議論し、合意した回答を出力するアンサンブル型LLMサービス）、HelixCode（SSHで管理されるワーカーに作業を分散し、チェックポイントとロールバック機能を備えた分散型AI開発プラットフォーム）、HelixLLM（HTTP/3上でOpenAIおよびAnthropic互換の推論を提供するシングルバイナリ）、そしてLLMインフラストラクチャの3点セットであるLLMProvider、LLMOrchestrator、LLMsVerifier（43のプロバイダーを統合するインターフェース、ヘッドレスCLIエージェント用のコントロールプレーン、検証のための真実の情報源）などです。これらを支えるプロダクトレベルのツールとして、Catalogizer（マルチプロトコル対応の暗号化メディア管理）やCourses-Creator（AIのマークダウンからビデオ教材を生成するパイプライン）などを開発しました。これらはすべて、小規模で疎結合、かつ独立してテストされたGoやKotlin Multiplatformモジュール群の上に構築されています。

私の仕事を際立たせているのは、**「ブラフなきエンジニアリング」**という、私が真摯に取り組んでいる原則です。140以上のリポジトリに継承されるGitサブモジュールとして配布される普遍的なエンジニアリングConstitutionを維持しており、これによって「テストが通ったから完成」ではなく、「実際のユーザーが使える状態になり、その証拠が記録されていること」を機械的に強制しています。さらに、HelixQAというブラフなきQAオーケストレーターを併用しており、Android、Web、デスクトップ環境で自律的にLLMとコンピュータービジョンのセッションを実行し、スクリーンショット、ログキャット、または動画がなければPASS判定を下しません。私は「完成したように見える」システムではなく、「確実に完成している」システムを構築します。

技術面では主にGoを使用し、Kotlin/KMP、TypeScript/React、Python、Swift、Shellなどの技術を駆使して、REST/gRPC/HTTP/3サービス、PostgreSQL/SQLite/Redis/ClickHouseデータレイヤー、Docker/Kubernetes/Prometheusオペレーションにわたるシステムを扱っています。プロバイダーの抽象化やデータ取得から、そのシステムが機能していることを証明するエビデンスのトレイルまで、一貫してシステム全体を管理することに慣れています。

このような、深いAIシステムエンジニアリングと、真に検証可能な品質へのこだわりを、貴チームにもたらす機会をいただければ幸いです。ご検討のほどよろしくお願いいたします。私のポートフォリオと公開リポジトリは、milosvasic.ruおよびvasic.digitalにてご覧いただけます。

敬具
Miloš Vasić
milos85vasic@gmail.com

