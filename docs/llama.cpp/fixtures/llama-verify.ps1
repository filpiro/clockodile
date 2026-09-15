param(
  [Parameter(Mandatory)] [string] $Model,
  [string] $Tag = 'reasoning-off',
  [string[]] $Extra = @(),
  [switch] $NoReasoningFlag
)
$ErrorActionPreference = 'Stop'
$fx = 'C:\Users\filippo.pirola.PL\Development\App\clockodile\docs\llama.cpp\fixtures'
$port = 18080
$base = "http://127.0.0.1:$port"
$log = "$env:TEMP\llama-$Tag.log"

$argv = @('-m', $Model, '--host', '127.0.0.1', '--port', $port, '--parallel', '1', '--ctx-size', '8192', '--sleep-idle-seconds', '60') + $Extra
if (-not $NoReasoningFlag) { $argv += @('--reasoning', 'off') }
$p = Start-Process llama-server -ArgumentList $argv -PassThru -NoNewWindow `
  -RedirectStandardError $log -RedirectStandardOutput "$log.out"
try {
  $t0 = Get-Date
  do { Start-Sleep -Milliseconds 250
       $code = curl.exe -s -o NUL -w '%{http_code}' "$base/health" } while ($code -ne '200')
  "startup_to_health_s=$([math]::Round(((Get-Date) - $t0).TotalSeconds, 2))"

  function Send($name, $out) {
    $t = curl.exe -s -o "$fx\$out" -w '%{time_total}' -H 'Content-Type: application/json' `
      --data-binary "@$fx\$name.request.json" "$base/v1/chat/completions"
    "$out time_s=$t"
  }
  Send 'summary.constrained'   "summary.constrained.$Tag.response.json"
  Send 'summary.constrained'   "summary.constrained.$Tag.warm.response.json"
  Send 'summary.unconstrained' "summary.unconstrained.$Tag.response.json"
  Send 'summary.truncated'     "summary.truncated.$Tag.response.json"

  Start-Sleep -Seconds 70
  "is_sleeping_before_cold=" + ((curl.exe -s "$base/props" | ConvertFrom-Json).is_sleeping)
  Send 'summary.constrained'   "summary.constrained.$Tag.cold.response.json"
} finally {
  Stop-Process -Id $p.Id -Force
}
