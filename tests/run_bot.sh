#!/usr/bin/env bash
# Runs the bot on every level in scenes/levels/ and fails if any run doesn't finish
# or prints a script error.
#
#   tests/run_bot.sh god            # god mode: proves every level can be completed (CI gate)
#   tests/run_bot.sh                # normal: balance report over a few seeds (deaths are reported, not fatal)
#   HEROES="0 1" tests/run_bot.sh   # which heroes (index in resources/level_list.tres); god mode: all, normal: the first
#   GODOT=/path/to/godot tests/run_bot.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-normal}"
if [ "$MODE" = "god" ]; then SEEDS="7"; EXTRA="god"; else SEEDS="1 2 3"; EXTRA=""; fi
nheroes=$(grep -E '^heroes = ' resources/level_list.tres | grep -o 'res://' | wc -l)
[ "$nheroes" -lt 1 ] && nheroes=1
if [ "$MODE" = "god" ]; then HEROES="${HEROES:-$(seq -s ' ' 0 $((nheroes - 1)))}"; else HEROES="${HEROES:-0}"; fi
mkdir -p test-logs
fail=0
rows=""
for h in $HEROES; do
for scene in scenes/levels/level_*.tscn; do
  lv=$(basename "$scene" .tscn)
  for s in $SEEDS; do
    log="test-logs/${lv}_${MODE}_hero${h}_seed${s}.log"
    timeout 600 "$GODOT" --headless --path . --fixed-fps 60 --disable-vsync res://tests/sim.tscn -- "$lv" seed="$s" hero="$h" timeout=400 $EXTRA quiet > "$log" 2>&1
    code=$?
    result=$(grep '^RESULT' "$log" | tail -1)
    [ -z "$result" ] && result="RESULT level=$lv code=$code reason=\"crashed (no result line)\""
    errors=$(grep -c "SCRIPT ERROR" "$log" || true)
    echo "$result hero=$h script_errors=$errors"
    rows="$rows| $lv | $h | $s | $code | $(echo "$result" | sed -E 's/.*reason="([^"]*)".*/\1/') | $(echo "$result" | grep -oE 'seconds=[0-9.]+' | cut -d= -f2) | $(echo "$result" | grep -oE 'hits_taken=[0-9]+' | cut -d= -f2) | $errors |\n"
    if [ "$errors" != "0" ]; then fail=1; grep -A3 "SCRIPT ERROR" "$log" | head -20; fi
    if [ "$MODE" = "god" ] && [ "$code" != "0" ]; then fail=1; fi
    if [ "$code" = "1" ] || [ "$code" = "3" ]; then fail=1; fi   # timeouts / crashes always fail
  done
done
done
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### Bot playthrough ($MODE)"; echo; echo "| level | hero | seed | exit | result | game seconds | hits taken | script errors |"; echo "|---|---|---|---|---|---|---|---|"; printf "$rows"; } >> "$GITHUB_STEP_SUMMARY"
fi
exit $fail
