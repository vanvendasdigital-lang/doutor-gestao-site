# Gera sitemap.xml com as URLs canonicas, publicas e indexaveis do site.
#
# NAO inclui:
#   - Paginas de paginacao (artigos/page/2../20/, artigos/categoria/*/page/2../)
#     — so a pagina 1 de cada listagem entra, as demais sao so navegacao.
#   - Paginas legais (politica-de-cookie, politica-de-privacidade,
#     termos-e-condicoes) — baixo valor de busca.
#   - curso-auditor-iso-9001-2015-vendas/ — landing alternativa so pra
#     trafego pago (titulo/copy diferentes do curso principal); nao faz
#     sentido indexar organicamente ao lado do curso "de verdade".
#   - downloads/ — sao arquivos (PDF/XLSX), nao paginas HTML.
#
# As datas (lastmod) dos artigos vem do campo dateSort real de cada um;
# as das paginas institucionais/produtos vem da ultima modificacao real
# no git (git log -1), levantada manualmente em 04/11/2026.
#
# Rode depois de build-artigos.ps1 e build-artigo-paginas.ps1, sempre que
# publicar conteudo novo.
#
# Como rodar (a partir da pasta redesign-prototype):
#   powershell -ExecutionPolicy Bypass -File build-sitemap.ps1

$ErrorActionPreference = "Stop"
$root = $PWD.Path
$baseUrl = "https://doutorgestao.com.br"

$dataPath = Join-Path $root "data\artigos-data.json"
if (-not (Test-Path $dataPath)) {
  Write-Error "Nao encontrei data\artigos-data.json. Rode a partir da pasta redesign-prototype."
  exit 1
}
$items = Get-Content -Raw -Encoding UTF8 $dataPath | ConvertFrom-Json

function Get-CategorySlug([string]$name) {
  $s = $name.ToLower()
  $accentMap = @{
    'á'='a'; 'à'='a'; 'ã'='a'; 'â'='a'; 'ä'='a'
    'é'='e'; 'è'='e'; 'ê'='e'; 'ë'='e'
    'í'='i'; 'ì'='i'; 'î'='i'; 'ï'='i'
    'ó'='o'; 'ò'='o'; 'õ'='o'; 'ô'='o'; 'ö'='o'
    'ú'='u'; 'ù'='u'; 'û'='u'; 'ü'='u'
    'ç'='c'
  }
  foreach ($k in $accentMap.Keys) { $s = $s -replace [regex]::Escape($k), $accentMap[$k] }
  $s = $s -replace '[^a-z0-9]+', '-'
  $s = $s.Trim('-')
  return $s
}

$urls = New-Object System.Collections.ArrayList
function Add-Url($loc, $lastmod, $changefreq, $priority) {
  [void]$urls.Add([PSCustomObject]@{ loc = $loc; lastmod = $lastmod; changefreq = $changefreq; priority = $priority })
}

# --- Paginas institucionais ---
Add-Url "$baseUrl/" "2026-10-30" "weekly" "1.0"
Add-Url "$baseUrl/cursos/" "2026-10-29" "monthly" "0.9"
Add-Url "$baseUrl/resultados/" "2026-10-23" "monthly" "0.6"
Add-Url "$baseUrl/quem-somos/" "2026-10-30" "monthly" "0.5"
Add-Url "$baseUrl/faq/" "2026-10-23" "monthly" "0.5"

# --- Paginas de curso/produto (lastmod = ultima modificacao real no git) ---
$products = @(
  @{ path = "amostra-iso-37001/"; date = "2026-10-03" }
  @{ path = "amostra-iso-37301/"; date = "2026-10-02" }
  @{ path = "amostra-sgi-9001-14001-45001/"; date = "2026-10-26" }
  @{ path = "colecao-curso-iso-45001/"; date = "2026-10-13" }
  @{ path = "colecao-curso-iso-9001-2015/"; date = "2026-10-30" }
  @{ path = "colecao-iso-14001-2026/"; date = "2026-10-29" }
  @{ path = "colecao-iso-37001-2025/"; date = "2026-10-13" }
  @{ path = "colecao-iso-37301-2021/"; date = "2026-10-02" }
  @{ path = "colecao-iso-9001-2026/"; date = "2026-10-29" }
  @{ path = "colecao-sgi-9001-14001-45001/"; date = "2026-10-26" }
  @{ path = "como-se-tornar-auditor-iso/"; date = "2026-10-23" }
  @{ path = "curso-auditor-interno-iso-9001-2015/"; date = "2026-10-30" }
  @{ path = "curso-iso-45001-2024-interpretacao-aplicacao/"; date = "2026-11-11" }
  @{ path = "ebook-iso-37001-antissuborno/"; date = "2026-10-23" }
  @{ path = "ebook-iso-37301-compliance/"; date = "2026-10-23" }
  @{ path = "ebook-iso-9001-2026-transicao/"; date = "2026-10-29" }
  @{ path = "kit-auditoria-interna-iso-14001-2026/"; date = "2026-10-29" }
  @{ path = "kit-auditoria-interna-iso-45001/"; date = "2026-10-23" }
  @{ path = "kit-auditoria-interna-iso-9001-2026/"; date = "2026-10-15" }
  @{ path = "kit-auditor-iso-45001/"; date = "2026-10-23" }
  @{ path = "laboratorio-decisoes-antissuborno/"; date = "2026-10-13" }
)
foreach ($p in $products) {
  Add-Url "$baseUrl/$($p.path)" $p.date "monthly" "0.8"
}

# --- Listagem de artigos (so pagina 1) ---
Add-Url "$baseUrl/artigos/" (Get-Date -Format "yyyy-MM-dd") "daily" "0.9"

# --- Uma entrada por categoria (so pagina 1 de cada) ---
$categoryGroups = $items | Group-Object category
foreach ($g in $categoryGroups) {
  $slug = Get-CategorySlug $g.Name
  Add-Url "$baseUrl/artigos/categoria/$slug/" (Get-Date -Format "yyyy-MM-dd") "weekly" "0.5"
}

# --- Os 200 artigos, com a data real de publicacao como lastmod ---
foreach ($item in $items) {
  Add-Url "$baseUrl$($item.link)" $item.dateSort "monthly" "0.6"
}

# --- Gera o XML ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('<?xml version="1.0" encoding="UTF-8"?>' + "`n")
[void]$sb.Append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n")
foreach ($u in $urls) {
  [void]$sb.Append("  <url>`n")
  [void]$sb.Append("    <loc>$($u.loc)</loc>`n")
  [void]$sb.Append("    <lastmod>$($u.lastmod)</lastmod>`n")
  [void]$sb.Append("    <changefreq>$($u.changefreq)</changefreq>`n")
  [void]$sb.Append("    <priority>$($u.priority)</priority>`n")
  [void]$sb.Append("  </url>`n")
}
[void]$sb.Append('</urlset>' + "`n")

$outPath = Join-Path $root "sitemap.xml"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), $utf8NoBom)

Write-Output "OK: sitemap.xml gerado com $($urls.Count) URLs."
