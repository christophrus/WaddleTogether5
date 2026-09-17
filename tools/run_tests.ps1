# Runs every game/tests/<name>_test.gd headless and prints a summary table.
# Usage: tools\run_tests.ps1 [name ...]   (no args = all, ordered tests first)
# See run_tests.sh for why the order is fixed (8.F.1).
param([string[]]$Names)
Set-Location (Join-Path $PSScriptRoot "..")
$godot = if ($env:GODOT) { $env:GODOT } else { "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe" }
$ordered = @("smoke", "save_load")
New-Item -ItemType Directory -Force tools/test_out | Out-Null

if ($Names) { $tests = $Names } else {
  $tests = @($ordered)
  Get-ChildItem game/tests/*_test.gd | ForEach-Object {
    $n = $_.BaseName -replace "_test$", ""
    if ($ordered -notcontains $n) { $tests += $n }
  }
}

$fail = 0
"{0,-24} {1,-6} {2}" -f "TEST", "CODE", "RESULT"
foreach ($t in $tests) {
  $log = "tools/test_out/$t.log"
  $env:WADDLE_TEST = $t
  & $godot --headless --path . res://game/tests/test_runner.tscn *> $log
  $code = $LASTEXITCODE
  $line = Select-String -Path $log -Pattern "RESULT:" | Select-Object -First 1
  $result = if ($line) { ($line.Line -split "RESULT: ")[1] } else { "(no RESULT line - see $log)" }
  if ($code -ne 0) { $fail = 1 }
  "{0,-24} {1,-6} {2}" -f $t, $code, $result
}
if ($fail -eq 0) { "ALL GREEN" } else { "FAILURES" }
exit $fail
