# Ticket 07: model x prompt language over email*.txt. Prints one line per request.
param([Parameter(Mandatory)] [string] $Model, [Parameter(Mandatory)] [string] $Tag)
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$base = 'http://127.0.0.1:18081'
$base_req = Get-Content "$dir\..\summary.constrained.request.json" -Raw | ConvertFrom-Json

$prompts = @{
  en = "Write a very short Italian time-tracking note in telegram style.`n`nMaximum 15 words.`nUse terse keywords and short noun/action phrases.`nNo need for a complete sentence.`nKeep only the essential work requested.`nOmit greetings, filler, examples, quotes and non-essential details.`n`nText:`n`"`"`"`n<INPUT>`n`"`"`""
  it = "Scrivi in italiano una nota di time-tracking brevissima, in stile telegrafico.`n`nMassimo 15 parole.`nUsa parole chiave e brevi frasi nome/azione.`nNon serve una frase completa.`nTieni solo il lavoro essenziale richiesto.`nOmetti saluti, riempitivi, esempi, citazioni e dettagli non essenziali.`n`nTesto:`n`"`"`"`n<INPUT>`n`"`"`""
  it2 = "Scrivi in italiano una nota di time-tracking in stile telegrafico.`n`nIl più breve possibile, massimo 15 parole.`nSolo parole chiave: verbo all'infinito + oggetto.`nNiente articoli, saluti, riempitivi, dettagli non essenziali.`nSolo il lavoro richiesto.`n`nTesto:`n`"`"`"`n<INPUT>`n`"`"`""
}

$p = Start-Process llama-server -PassThru -NoNewWindow -RedirectStandardError "$env:TEMP\llama-it-$Tag.log" -RedirectStandardOutput "$env:TEMP\llama-it-$Tag.out" `
  -ArgumentList @('-m', $Model, '--host', '127.0.0.1', '--port', '18081', '--parallel', '1', '--ctx-size', '8192', '--reasoning', 'off')
try {
  do { Start-Sleep -Milliseconds 250; $code = curl.exe -s -o NUL -w '%{http_code}' "$base/health" } while ($code -ne '200')
  foreach ($email in Get-ChildItem "$dir\email*.txt" | Sort-Object Name) {
    $text = (Get-Content $email.FullName -Raw).TrimEnd()
    foreach ($lang in 'en', 'it', 'it2') {
      $base_req.messages[0].content = $prompts[$lang].Replace('<INPUT>', $text)
      $tmp = "$env:TEMP\llama-it-req.json"
      $base_req | ConvertTo-Json -Depth 20 | Set-Content $tmp -Encoding utf8NoBOM
      $resp = curl.exe -s -H 'Content-Type: application/json' --data-binary "@$tmp" "$base/v1/chat/completions" | ConvertFrom-Json
      $ch = $resp.choices[0]
      "$Tag`t$($email.BaseName)`t$lang`t$($ch.finish_reason)`t$($ch.message.content)"
    }
  }
} finally { Stop-Process -Id $p.Id -Force }
