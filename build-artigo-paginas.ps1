# Gera as 200 paginas individuais de artigo (ex: /auditoria-interna-iso-9001-2/index.html)
# a partir de data/artigos-data.json.
#
# Cada item pode ter um campo "relatedProducts": [{ "title": "...", "url": "..." }, ...]
# — quando presente, a pagina do artigo mostra um CTA sutil levando para a(s)
# pagina(s) de vendas relacionada(s). Esse campo e adicionado via
# patch-artigos-relacionados.ps1 (rode-o antes, se for atualizar os vinculos).
#
# Como rodar (a partir da pasta redesign-prototype):
#   powershell -ExecutionPolicy Bypass -File build-artigo-paginas.ps1

$ErrorActionPreference = "Stop"
$root = $PWD.Path

$dataPath = Join-Path $root "data\artigos-data.json"
if (-not (Test-Path $dataPath)) {
  Write-Error "Nao encontrei data\artigos-data.json. Rode a partir da pasta redesign-prototype."
  exit 1
}

$items = Get-Content -Raw -Encoding UTF8 $dataPath | ConvertFrom-Json

function Html-Attr([string]$s) {
  if ($null -eq $s) { return "" }
  return $s -replace '&','&amp;' -replace '"','&quot;' -replace '<','&lt;' -replace '>','&gt;'
}

function Get-Slug([string]$link) {
  $slug = $link -replace '^https://doutorgestao\.com\.br/','' -replace '^/','' -replace '/$',''
  return $slug
}

function Get-CoverClass([string]$slug) {
  $sum = 0
  foreach ($c in $slug.ToCharArray()) { $sum += [int]$c }
  $variant = ($sum % 5) + 1
  if ($variant -eq 1) { return "" }
  return " cover-v$variant"
}

function Get-BodyHtml($item) {
  if ($item.fullContent) {
    $paragraphs = $item.fullContent -split "`n`n" | Where-Object { $_.Trim() -ne '' }
    $html = ($paragraphs | ForEach-Object { "<p>$(Html-Attr $_.Trim())</p>" }) -join "`n      "
    return $html
  }
  return "<p>$(Html-Attr $item.excerpt)</p>"
}

function Related-Cta-Html($item) {
  $products = @($item.relatedProducts) | Where-Object { $_ -and $_.url }
  if ($products.Count -eq 0) { return "" }

  $links = New-Object System.Collections.ArrayList
  foreach ($p in $products) {
    [void]$links.Add("<a class=`"btn btn-purple`" href=`"../$($p.url)`">Conhecer $(Html-Attr $p.title) &rarr;</a>")
  }
  $linksHtml = $links -join "`n        "

  $label = if ($products.Count -gt 1) { "Materiais relacionados a este assunto" } else { "Material relacionado a este assunto" }

  return @"
    <div class="related-cta">
      <div class="related-cta-text"><strong>${label}:</strong></div>
        $linksHtml
    </div>
"@
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$waCta = "https://wa.me/5531996150785?text=Ol%C3%A1!%20Li%20um%20artigo%20no%20site%20e%20gostaria%20de%20saber%20mais."

foreach ($item in $items) {
  $slug = Get-Slug $item.link
  $bodyHtml = Get-BodyHtml $item
  $relatedHtml = Related-Cta-Html $item

  if ($item.image) {
    $imageHtml = "<div class=`"article-detail-image`"><img src=`"$(Html-Attr $item.image)`" alt=`"$(Html-Attr $item.title)`"></div>"
  } else {
    $coverClass = Get-CoverClass $slug
    $imageHtml = "<div class=`"article-detail-image no-image$coverClass`"><span class=`"cover-eyebrow`">$(Html-Attr $item.category)</span><span class=`"cover-title`">$(Html-Attr $item.title)</span></div>"
  }

  $html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$(Html-Attr $item.title) | Doutor Gestão</title>
<meta name="description" content="$(Html-Attr $item.excerpt)">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Open+Sans:wght@400;600&family=Fraunces:ital,wght@1,600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../assets/colecao.css">
</head>
<body>

<header class="site-header">
  <div class="wrap site-header-inner">
    <a href="../index.html" class="logo">
      <img src="../assets/doutor-gestao-banner.png" alt="Doutor Gestão">
    </a>
    <nav class="main-nav" id="main-nav">
      <ul>
        <li><a href="../index.html">Home</a></li>
        <li><a href="../cursos/">Cursos</a></li>
        <li><a href="../resultados/">Resultados</a></li>
        <li><a href="../artigos/" aria-current="page">Artigos</a></li>
        <li><a href="../quem-somos/">Quem Somos</a></li>
      </ul>
    </nav>
    <div class="header-actions">
      <a class="btn btn-primary" href="../cursos/">Conhecer cursos</a>
      <button class="nav-toggle" id="nav-toggle" aria-label="Abrir menu">&#9776;</button>
    </div>
  </div>
</header>

<section class="hero" style="padding:48px 0 36px">
  <div class="wrap">
    <p class="breadcrumb"><a href="../index.html">Home</a> / <a href="../artigos/">Artigos</a></p>
    <span class="eyebrow"><span class="dot"></span> $(Html-Attr $item.category)</span>
    <h1 style="max-width:800px;margin-top:14px;font-size:clamp(1.9rem,4vw,2.8rem)">$(Html-Attr $item.title)</h1>
    <p class="article-meta" style="color:#b9c2db">$($item.date)</p>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="wrap" style="max-width:760px">
    $imageHtml

    <div class="article-body">
      $bodyHtml
    </div>
$relatedHtml
    <div class="article-cta-box">
      <h3>Quer se aprofundar nesse assunto?</h3>
      <p>Fale com a gente no WhatsApp ou conheça nossa trilha de cursos em sistemas de gestão ISO.</p>
      <div class="cta-row">
        <a class="btn btn-primary" href="$waCta" target="_blank" rel="noopener">Falar no WhatsApp</a>
        <a class="btn btn-secondary" href="../cursos/">Ver cursos</a>
      </div>
    </div>
  </div>
</section>

<footer>
  <div class="wrap foot">
    <div>
      <div class="brand">
        <img src="../assets/doutor-gestao-banner.png" alt="Doutor Gestão">
      </div>
      <small>Formação e consultoria em sistemas de gestão, ESG e certificações internacionais. Belo Horizonte – MG.</small>
    </div>
    <small>
      <a href="../resultados/" style="color:#cfd6ea">Resultados</a> ·
      <a href="../quem-somos/" style="color:#cfd6ea">Quem Somos</a> ·
      <a href="../faq/" style="color:#cfd6ea">FAQ</a> ·
      <a href="../artigos/" style="color:#cfd6ea">Artigos</a><br>
      © Doutor Gestão. Todos os direitos reservados. · professor.ronaldo@doutorgestao.com.br · Site desenvolvido por <span style="display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;border-radius:50%;background:#4F3DE8;font-family:'Fraunces',serif;font-style:italic;font-weight:600;font-size:10px;color:#fff;vertical-align:middle;line-height:1;">V</span> Vanessa Sousa · (31) 99472-5779
    </small>
  </div>
</footer>

<a class="whatsapp-float" href="$waCta" target="_blank" rel="noopener" aria-label="Falar no WhatsApp">
  <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.29-1.39a9.9 9.9 0 0 0 4.75 1.21h.01c5.46 0 9.9-4.45 9.9-9.91C21.96 6.45 17.5 2 12.04 2zm5.83 14.16c-.24.68-1.39 1.3-1.93 1.38-.5.08-1.13.11-1.82-.12-.42-.13-.96-.31-1.65-.6-2.91-1.26-4.81-4.18-4.96-4.38-.15-.2-1.19-1.58-1.19-3.01s.75-2.13 1.02-2.42c.26-.29.58-.36.77-.36.2 0 .39 0 .56.01.18.01.42-.07.65.5.24.58.82 2.01.89 2.16.07.15.12.32.02.52-.09.2-.14.32-.28.5-.14.17-.29.38-.42.51-.14.14-.29.29-.12.57.16.29.72 1.19 1.55 1.93 1.07.95 1.97 1.25 2.26 1.39.29.14.46.12.63-.07.17-.2.71-.83.9-1.11.19-.29.38-.24.63-.14.26.09 1.63.77 1.91.91.29.14.48.21.55.33.07.12.07.68-.17 1.36z"/></svg>
</a>

<script>
  document.getElementById('nav-toggle').addEventListener('click', function () {
    document.getElementById('main-nav').classList.toggle('open');
  });
</script>

</body>
</html>
"@

  $dir = Join-Path $root $slug
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $outPath = Join-Path $dir "index.html"
  [System.IO.File]::WriteAllText($outPath, $html, $utf8NoBom)
}

Write-Output "OK: $($items.Count) paginas de artigo geradas."
