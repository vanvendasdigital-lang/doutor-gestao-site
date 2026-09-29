# Gera as 200 paginas individuais de artigo (ex: /auditoria-interna-iso-9001-2/index.html)
# a partir de data/artigos-data.json, e reescreve o campo "link" de cada item nesse
# mesmo arquivo para apontar pro caminho local (ex: "/auditoria-interna-iso-9001-2/")
# em vez da URL antiga do WordPress.
#
# Rode este script UMA VEZ para fazer a migracao. Depois disso, novos artigos podem
# ser adicionados direto com link local em data/artigos-data.json — nao precisa
# rodar este script de novo, so o build-artigos.ps1 (que regera as listagens e a
# busca a partir do artigos-data.json atualizado).
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
  # Aceita tanto o link antigo do WordPress quanto o link local (script e
  # idempotente: pode rodar de novo com seguranca depois da primeira migracao).
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

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$waCta = "https://wa.me/5531996150785?text=Ol%C3%A1!%20Li%20um%20artigo%20no%20site%20e%20gostaria%20de%20saber%20mais."

foreach ($item in $items) {
  $slug = Get-Slug $item.link
  $bodyHtml = Get-BodyHtml $item

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
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Open+Sans:wght@400;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../styles.css">
</head>
<body>

<header class="site-header">
  <div class="container">
    <a href="../index.html" class="logo">
      <img src="../assets/doutor-gestao-banner.png" alt="Doutor Gestão">
    </a>
    <nav class="main-nav" id="main-nav">
      <ul>
        <li><a href="../index.html">Home</a></li>
        <li><a href="../cursos/">Cursos</a></li>
        <li><a href="../artigos/" aria-current="page">Artigos</a></li>
        <li><a href="../quem-somos/">Quem Somos</a></li>
      </ul>
    </nav>
    <div class="header-actions">
      <a class="btn btn-primary" href="../curso-auditor-interno-iso-9001/">Quero me formar</a>
      <button class="nav-toggle" id="nav-toggle" aria-label="Abrir menu">☰</button>
    </div>
  </div>
</header>

<section class="hero" style="padding:48px 0 24px;">
  <div class="container" style="grid-template-columns:1fr;">
    <div class="hero-copy" style="max-width:760px;">
      <p class="breadcrumb"><a href="../index.html">Home</a> / <a href="../artigos/">Artigos</a></p>
      <span class="hero-eyebrow">$(Html-Attr $item.category)</span>
      <h1 style="font-size:32px;">$(Html-Attr $item.title)</h1>
      <p class="article-meta">$($item.date)</p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0;">
  <div class="container" style="max-width:760px;">
    $imageHtml

    <div class="article-body">
      $bodyHtml
    </div>

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

<footer class="site-footer">
  <div class="container">
    <div class="footer-logo-feature">
      <img src="../assets/doutor-gestao-banner.png" alt="Doutor Gestão">
    </div>
    <div class="footer-grid">
      <div>
        <p style="font-size:13px;">Formação e consultoria em sistemas de gestão, ESG e certificações internacionais. Belo Horizonte – MG.</p>
      </div>
      <div>
        <h4>Institucional</h4>
        <ul>
          <li><a href="../quem-somos/">Quem Somos</a></li>
          <li><a href="../faq/">FAQ</a></li>
          <li><a href="../artigos/">Artigos</a></li>
        </ul>
      </div>
      <div>
        <h4>Legal</h4>
        <ul>
          <li><a href="/politica-de-cookie/">Política de Cookies</a></li>
          <li><a href="/politica-de-privacidade/">Política de Privacidade</a></li>
          <li><a href="/termos-e-condicoes/">Termos e Condições</a></li>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© Doutor Gestão. Todos os direitos reservados.</span>
      <span>professor.ronaldo@doutorgestao.com.br</span>
    </div>
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

  $item.link = "/$slug/"
}

# Regrava o data/artigos-data.json com os links locais atualizados
$json = $items | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($dataPath, $json, $utf8NoBom)

Write-Output "OK: $($items.Count) paginas de artigo geradas, e data\artigos-data.json atualizado com links locais."
