# tv-cdp-setup

TradingView Desktop (Windows MSIX/Store版) に Chrome DevTools Protocol (CDP) を有効化し、Claude Code MCP と連携するセットアップスクリプト。

## 前提条件

- Windows 10/11
- TradingView Desktop (Microsoft Store 版インストール) ※ tradingview.com からのダウンロード版は不可
- Node.js 18+
- Windows 開発者モード ON（設定 → システム → 開発者向け → 開発者モード）

## 使い方

```powershell
# 1. このリポジトリをクローン
git clone https://github.com/ktsukamoto7-crypto/tv-cdp-setup.git
cd tv-cdp-setup

# 2. スクリプト実行（管理者不要）
Set-ExecutionPolicy -Scope Process Bypass
.\setup_tv_cdp.ps1
```

## セットアップ後

```powershell
# tradingview-mcp をクローン & tv CLI を有効化
git clone https://github.com/tradesdontlie/tradingview-mcp.git
cd tradingview-mcp
npm install
npm link   # tv コマンドをグローバルに登録

# Claude Code に MCP サーバーを登録
claude mcp add tradingview -s user -- node C:\Users\$env:USERNAME\tradingview-mcp\src\server.js
```

1. スタートメニューから TradingView を起動
2. Claude Code を起動 → TradingView MCP が自動接続

## TI リプレイ使い方

```powershell
# matched parquet を results/ に置いて実行
python tv_replay_markers.py --file results/case_17223_matched.parquet --date 2026-02-12

# 前の日のマーカーをクリアしてから描画
python tv_replay_markers.py --file results/case_17223_matched.parquet --date 2026-02-09 --clear
```

- 緑テキスト = WIN、赤テキスト = LOSE
- `^L` = LONG entry、`vS` = SHORT entry
- TV のリプレイバーで時間を進めながら各エントリーの文脈を確認

## 仕組み

TradingView の MSIX パッケージは `--remote-debugging-port` 引数を受け付けない。  
このスクリプトは `app.asar` 内の `index.js` に `app.commandLine.appendSwitch('remote-debugging-port', '9222')` を注入し、AppX として再登録することで CDP を有効化する。
