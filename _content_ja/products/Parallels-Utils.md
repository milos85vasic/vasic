---
name: Parallels-Utils
slug: parallels-utils
tier: serverfactory-tertiary
order: 32
status: active (niche, macOS-specific Shell/Python toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~5.3K bytes)
  - Python 3 (~3K bytes)
  - Parallels (macOS)
  - Settings files (.settings)
repos:
  - https://github.com/Server-Factory/Parallels-Utils
diagrams:
  - Image lifecycle (build → compress → publish → retrieve → run)
  - One provider endpoint → many workstations pulling the same image matrix
  - Settings-file map (location/provider/sync) feeding the scripts
---

**あらゆるマシンでParallels VMイメージを圧縮、公開、再利用**

## 概要

Parallels-Utilsは、Parallels（macOS）仮想マシンイメージを管理するためのServer Factoryツールキットです。開発やテストに使用されるイメージ「マトリックス」の圧縮と同期、リモートエンドポイントへの公開、複数のワークステーションやサーバーでの取得・実行をサポートします。単体でもServer Factoryの一部としても利用可能です。

## 簡単な説明

macOS上のParallels VMイメージのライフサイクルを管理するShell／Pythonツールキット。Parallelsイメージの圧縮・同期、リモートエンドポイントへの公開、複数のコンピュータでの取得・実行を、シンプルな設定ファイルで制御します。Server Factoryの一部としても、単体でも利用可能です。

## 詳細な説明

Parallels-Utilsは、macOSベースの開発における実践的なDevOps課題を解決します。チームは開発やテスト用に異なるOSや設定を持つParallels仮想マシンの「マトリックス」を構築しますが、それらのイメージを圧縮し、公開し、複数のマシンで一貫して取得・実行する必要があります。このツールキットは、まさにそのライフサイクルを提供します。同期機能はParallelsイメージを圧縮し、常に最新の状態に保ちます。公開機能はイメージをリモートエンドポイントにアップロードし、取得機能により、どのワークステーションやサーバーでも公開されたイメージを取得してVMとして実行できます。

設定は意図的にシンプルでファイル駆動型です。`image_location.settings`はファイルシステム上のイメージの保存場所を、`image_provider.settings`は公開イメージのベースとなるURLを、`image_sync.sh`はアップロードスクリプトを定義します。サンプルは`Examples`ディレクトリに同梱されています。オペレーターは`publish_images.sh`でイメージを公開し、`run.sh`でVMを起動します。必要な環境は、対応するmacOSバージョンのParallelsとPython 3です。

ツールキットは二つの用途に対応する設計です。Server Factoryプロジェクトの一部としても、完全に独立して動作させることもでき、組織の疎結合哲学を反映しています。さらに、短いビデオチュートリアルのリンクも提供されています。Server-Factoryファミリーの一員として、Qemu-Utils（Linux／QEMU向けの同等ツール）を補完し、macOS／Parallelsとクロスプラットフォーム／QEMUの両方のバックエンドでVMイメージ管理を実現します。

## 開発の背景

チーム内で一貫したVM開発・テスト環境を共有するのは面倒です。イメージは容量が大きく、すべてのマシンで同じマトリックスを用意する必要があります。Parallels-Utilsは、圧縮、公開、取得を自動化し、標準的なParallels VMのセットをどこでも再現可能にします。

## 革新的な理由

重く扱いにくいParallelsイメージを、公開・同期可能なアーティファクトセットに変え、どのマシンでも取得して実行できるようにします。これにより、標準的な開発・テスト環境は、各エンジニアが手作業で再構築するものから、単に取得するだけのものへと変わります。設定ファイルによる簡単な設定と、Server Factoryへの依存性ゼロを実現し、組織の疎結合哲学を貫いています。単体でも有用であり、より大きなツールチェーンの中でも良き市民として機能します。

コンテンツ

## 革新的なポイント

- Parallelsのイメージ「マトリックス」を圧縮し、開発・テスト環境向けに同期。
- イメージの公開・取得ワークフローにより、複数のコンピュータ間で再利用可能。
- 設定ファイル駆動の構成（ロケーション／プロバイダー／同期）と付属のサンプル。
- 単体利用とServer Factoryコンポーネントとしての二重利用が可能。

## 課題と解決策

- **大容量イメージの配布**：圧縮とリモートエンドポイントへの公開・取得ワークフローで解決。
- **マシン間での再現性**：プロバイダー／ロケーション設定により、すべてのホストが同一のイメージセットを解決。
- **使いやすさ**：シンプルな`publish_images.sh`／`run.sh`スクリプトと設定ファイルのサンプルで解決。

## 技術スタック（選定理由と使用方法）

- **Shell** — 公開／実行／同期スクリプト（主言語、約5.3KB）。
- **Python 3** — サポートツール（必須依存関係、約3KB）。
- **Parallels（macOS）** — 管理対象の仮想化バックエンド。
- **設定ファイル（`.settings`）** — ロケーション／プロバイダー／同期のための宣言型設定。

> 注：GitHubはServer-Factory組織内のフォークとしてマークされています。macOS専用のニッチなプロジェクトであり、AIとは無関係です。

