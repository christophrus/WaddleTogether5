#!/usr/bin/env bash
# Runs every game/tests/<name>_test.gd headless and prints a summary table.
# Usage: tools/run_tests.sh [name ...]     (no args = all, in the fixed order below)
#
# Order matters (8.F.1): tests that build a nest can autosave into the shared test
# save path, and the save/load test must own that file from a clean state. Ordered
# tests run first in this exact sequence; anything not listed runs afterwards
# alphabetically.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/c/Users/lorus/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
ORDERED="smoke save_load"
mkdir -p tools/test_out

if [ $# -gt 0 ]; then
  TESTS="$*"
else
  TESTS="$ORDERED"
  for f in game/tests/*_test.gd; do
    n=$(basename "$f" _test.gd)
    case " $ORDERED " in *" $n "*) ;; *) TESTS="$TESTS $n";; esac
  done
fi

fail=0
printf "\n%-24s %-6s %s\n" "TEST" "CODE" "RESULT"
printf "%-24s %-6s %s\n" "------------------------" "------" "------"
for t in $TESTS; do
  log="tools/test_out/$t.log"
  WADDLE_TEST="$t" timeout 180 "$GODOT" --headless --path . res://game/tests/test_runner.tscn > "$log" 2>&1
  code=$?
  result=$(grep -m1 "RESULT:" "$log" | sed 's/.*RESULT: //')
  [ -z "$result" ] && result="(no RESULT line - see $log)"
  [ $code -ne 0 ] && fail=1
  printf "%-24s %-6s %s\n" "$t" "$code" "$result"
  if [ $code -ne 0 ]; then
    grep -E "FAIL|ERROR|SCRIPT ERROR|Parse Error|at:" "$log" | head -20 | sed 's/^/    /'
  fi
done
echo
[ $fail -eq 0 ] && echo "ALL GREEN" || echo "FAILURES"
exit $fail
