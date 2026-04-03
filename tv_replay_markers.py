"""
tv_replay_markers.py
TradingView の tv CLI を使って matched parquet のトレードをチャート上に描画し、
リプレイを開始するスクリプト。

Usage:
    python tv_replay_markers.py --file results/case_17223_matched.parquet --date 2026-02-12
    python tv_replay_markers.py --file results/case_17223_matched.parquet --date 2026-02-12 --clear

Requirements:
    pip install pandas pyarrow
    tradingview-mcp をインストールして `npm link` で tv コマンドを使えるようにすること
    TradingView Desktop が CDP 有効で起動していること (setup_tv_cdp.ps1 実行済み)
"""

import argparse
import json
import subprocess
import sys
import pandas as pd


def tv(tool: str, params: dict) -> dict:
    """tv CLI 経由で MCP ツールを呼び出す"""
    cmd = ["tv", tool, "--json", json.dumps(params)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            raise RuntimeError(f"tv CLI error: {result.stderr.strip()}")
        return json.loads(result.stdout.strip())
    except FileNotFoundError:
        print("ERROR: tv command not found.")
        print("  cd tradingview-mcp && npm link")
        sys.exit(1)


def load_trades(parquet_path: str, date_str: str) -> pd.DataFrame:
    df = pd.read_parquet(parquet_path)
    df["entry_utc"] = pd.to_datetime(df["entry_time_est"]).dt.tz_convert("UTC")
    target = pd.Timestamp(date_str).date()
    day = df[df["entry_utc"].dt.date == target].copy()
    day = day.sort_values("entry_utc")
    return day


def draw_markers(day: pd.DataFrame) -> None:
    for _, r in day.iterrows():
        ts = int(r["entry_utc"].timestamp())
        direction = "L" if r["direction"] == "LONG" else "S"
        arrow = "^" if direction == "L" else "v"
        pips = r["pips"]
        wl = "W" if pips > 0 else "X"
        color = "#00C853" if pips > 0 else "#FF1744"
        text = f"{arrow}{direction} {pips:+.1f}p {wl}"
        jst_time = pd.Timestamp(ts, unit="s", tz="UTC").tz_convert("Asia/Tokyo").strftime("%H:%M:%S")

        result = tv("draw_shape", {
            "shape": "text",
            "point": {"time": ts, "price": round(float(r["entry_rate"]), 3)},
            "text": text,
            "overrides": {"color": color, "fontsize": 12},
        })
        status = "OK" if result.get("success") else "FAIL"
        print(f"  {status}  {text}  @ {r['entry_rate']:.3f}  ({jst_time} JST)")


def main():
    parser = argparse.ArgumentParser(description="Draw TI trade markers on TradingView")
    parser.add_argument("--file", required=True, help="Path to matched parquet file (e.g. results/case_17223_matched.parquet)")
    parser.add_argument("--date", required=True, help="Date to replay (YYYY-MM-DD)")
    parser.add_argument("--clear", action="store_true", help="Clear existing drawings before drawing")
    parser.add_argument("--no-replay", action="store_true", help="Skip starting replay mode")
    args = parser.parse_args()

    # 1. Load trades
    print(f"Loading {args.file} for {args.date}...")
    day = load_trades(args.file, args.date)
    if len(day) == 0:
        print(f"No trades found for {args.date}")
        sys.exit(1)
    print(f"Found {len(day)} trades")

    # 2. Clear existing drawings
    if args.clear:
        print("Clearing drawings...")
        tv("draw_clear", {})
        print("  OK")

    # 3. Start replay
    if not args.no_replay:
        print(f"Starting replay at {args.date}...")
        result = tv("replay_start", {"date": args.date})
        print(f"  {'OK' if result.get('success') else 'FAIL'}")

    # 4. Draw markers
    print("Drawing markers...")
    draw_markers(day)

    # 5. Summary
    wins = (day["pips"] > 0).sum()
    losses = len(day) - wins
    avg = day["pips"].mean()
    print(f"\nDone. {len(day)} trades | W:{wins} L:{losses} | avg {avg:+.2f}p")
    print("Green=WIN  Red=LOSE  ^L=LONG  vS=SHORT")


if __name__ == "__main__":
    main()
