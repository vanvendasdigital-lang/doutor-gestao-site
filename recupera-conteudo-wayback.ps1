# Recupera o texto completo dos artigos a partir de copias arquivadas no
# Wayback Machine (web.archive.org), ja que o WordPress original saiu do ar
# antes da migracao completa. Preenche o campo "fullContent" em
# data/artigos-data.json (paragrafos separados por linha em branco dupla).
# Roda so nos artigos que tem timestamp mapeado em found_slugs.tsv.
#
# Como rodar (a partir da pasta redesign-prototype):
#   powershell -ExecutionPolicy Bypass -File recupera-conteudo-wayback.ps1

$ErrorActionPreference = "Continue"
$root = $PWD.Path
$dataPath = Join-Path $root "data\artigos-data.json"
$mapPath = "C:\Users\vanes\AppData\Local\Temp\found_slugs.tsv"

$items = Get-Content -Raw -Encoding UTF8 $dataPath | ConvertFrom-Json

$map = @{}
foreach ($line in Get-Content -Encoding UTF8 $mapPath) {
  $parts = $line -split "`t"
  if ($parts.Count -eq 2) { $map[$parts[0]] = $parts[1] }
}
Write-Output ("Slugs com snapshot: " + $map.Count)

function Remove-DivById([string]$html, [string]$id) {
  $marker = 'id="' + $id + '"'
  $idx = $html.IndexOf($marker)
  if ($idx -lt 0) { return $html }
  $divStart = $html.LastIndexOf('<div', $idx)
  if ($divStart -lt 0) { return $html }

  $pos = $divStart + 4
  $depth = 1
  while ($depth -gt 0 -and $pos -lt $html.Length) {
    $nextOpen = $html.IndexOf('<div', $pos)
    $nextClose = $html.IndexOf('</div>', $pos)
    if ($nextClose -lt 0) { break }
    if ($nextOpen -ge 0 -and $nextOpen -lt $nextClose) {
      $depth++
      $pos = $nextOpen + 4
    } else {
      $depth--
      $pos = $nextClose + 6
    }
  }
  return $html.Substring(0, $divStart) + $html.Substring($pos)
}

function Extract-ArticleText([string]$html) {
  $tocIdx = $html.IndexOf('entry-content')
  if ($tocIdx -lt 0) { return $null }
  $tagEnd = $html.IndexOf('>', $tocIdx)
  if ($tagEnd -lt 0) { return $null }
  $start = $tagEnd + 1

  $endMarkers = @('Compartilhe isso:', 'Você também pode gostar', 'Deixe uma resposta', 'Deixe um comentário', 'Curtir isso:', 'Posts relacionados')
  $end = $html.Length
  foreach ($marker in $endMarkers) {
    $idx = $html.IndexOf($marker, $start)
    if ($idx -gt 0 -and $idx -lt $end) { $end = $idx }
  }
  $maxLen = 30000
  if ($end - $start -gt $maxLen) { $end = $start + $maxLen }

  $slice = $html.Substring($start, $end - $start)
  $slice = Remove-DivById $slice 'ez-toc-container'
  $text = [regex]::Replace($slice, '<script[\s\S]*?</script>', '')
  $text = [regex]::Replace($text, '<style[\s\S]*?</style>', '')
  # separa blocos por tag de fechamento de paragrafo/heading antes de remover tags
  $text = [regex]::Replace($text, '</(p|h[1-6]|li|div)>', "`n`n")
  $text = [regex]::Replace($text, '<[^>]+>', '')
  $text = [System.Net.WebUtility]::HtmlDecode($text)
  $text = [regex]::Replace($text, '[ \t]+', ' ')
  $text = [regex]::Replace($text, '(\r?\n\s*){2,}', "`n`n")
  $text = $text.Trim()

  return $text
}

$count = 0
$ok = 0
$fail = 0

foreach ($item in $items) {
  $slug = ($item.link -replace '^/','' -replace '/$','')
  if (-not $map.ContainsKey($slug)) { continue }

  $count++
  $ts = $map[$slug]
  $url = "http://web.archive.org/web/$ts/https://doutorgestao.com.br/$slug/"

  $success = $false
  for ($attempt = 1; $attempt -le 2 -and -not $success; $attempt++) {
    try {
      $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
      $text = Extract-ArticleText $resp.Content
      if ($text -and $text.Length -gt 100) {
        Add-Member -InputObject $item -NotePropertyName 'fullContent' -NotePropertyValue $text -Force
        $ok++
        $success = $true
      }
    } catch {
      Start-Sleep -Milliseconds 800
    }
  }
  if (-not $success) {
    $fail++
    Write-Output ("FALHOU: " + $slug)
  }

  if ($count % 20 -eq 0) { Write-Output ("Progresso: $count / $($map.Count)  (ok=$ok fail=$fail)") }
  Start-Sleep -Milliseconds 250
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$json = $items | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($dataPath, $json, $utf8NoBom)

Write-Output "===================="
Write-Output "Concluido. Recuperados: $ok de $count tentados (fail=$fail)."
