# Reconstroi as 20 paginas de artigos (artigos/index.html + artigos/page/2../20/)
# a partir de data/artigos-data.json.
#
# Quando editar uma imagem (ou qualquer campo) em data/artigos-data.json,
# rode este script de novo pra atualizar as paginas. Nao depende mais do
# WordPress em nada.
#
# Como rodar (a partir da pasta redesign-prototype):
#   powershell -ExecutionPolicy Bypass -File build-artigos.ps1

$ErrorActionPreference = "Stop"
$root = $PWD.Path

$dataPath = Join-Path $root "data\artigos-data.json"
if (-not (Test-Path $dataPath)) {
  Write-Error "Nao encontrei data\artigos-data.json. Rode a partir da pasta redesign-prototype."
  exit 1
}

$items = Get-Content -Raw -Encoding UTF8 $dataPath | ConvertFrom-Json

# Gera data/artigos-search.js: versao enxuta (titulo, link, categoria, data) dos
# 200 artigos, usada pela busca client-side no topo da pagina de Artigos.
# E um <script src="..."> (nao fetch de JSON) pra funcionar tambem abrindo o
# arquivo local direto no navegador (file://), sem bloqueio de CORS.
$searchItems = $items | ForEach-Object {
  [PSCustomObject]@{
    title    = $_.title
    link     = $_.link
    category = $_.category
    date     = $_.date
  }
}
$searchJson = $searchItems | ConvertTo-Json -Compress
$searchJs = "// Gerado automaticamente por build-artigos.ps1 a partir de artigos-data.json. Nao editar a mao.`nconst ARTICLES_SEARCH_DATA = $searchJson;`n"
$searchJsPath = Join-Path $root "data\artigos-search.js"
$utf8NoBomEarly = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($searchJsPath, $searchJs, $utf8NoBomEarly)

function Html-Attr([string]$s) {
  if ($null -eq $s) { return "" }
  return $s -replace '&','&amp;' -replace '"','&quot;' -replace '<','&lt;' -replace '>','&gt;'
}

$pageSize = 10
$totalItems = $items.Count
$totalPages = [Math]::Ceiling($totalItems / $pageSize)

function Get-CoverClass([string]$slug) {
  $sum = 0
  foreach ($c in $slug.ToCharArray()) { $sum += [int]$c }
  $variant = ($sum % 5) + 1
  if ($variant -eq 1) { return "" }
  return " cover-v$variant"
}

function Card-Html($item) {
  if ($item.image) {
    $thumbHtml = "<div class=`"thumb`"><img src=`"$(Html-Attr $item.image)`" alt=`"`"></div>"
  } else {
    $slug = ($item.link -replace '^/','' -replace '/$','')
    $coverClass = Get-CoverClass $slug
    $thumbHtml = "<div class=`"thumb no-image$coverClass`"><span class=`"cover-eyebrow`">$(Html-Attr $item.category)</span><span class=`"cover-title`">$(Html-Attr $item.title)</span></div>"
  }
  return @"
      <a class="article-card" href="$(Html-Attr $item.link)">
        $thumbHtml
        <div class="body">
          <span class="tag">$(Html-Attr $item.category)</span>
          <h4>$(Html-Attr $item.title)</h4>
          <p class="excerpt">$(Html-Attr $item.excerpt)</p>
          <span class="date">$($item.date)</span>
        </div>
      </a>
"@
}

function Get-PageHref($currentPage, $targetPage) {
  if ($targetPage -eq 1) {
    if ($currentPage -eq 1) { return "index.html" } else { return "../../" }
  } else {
    if ($currentPage -eq 1) { return "page/$targetPage/" } else { return "../$targetPage/" }
  }
}

function Pagination-Html($currentPage, $totalPages) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("<nav class=`"pagination`" aria-label=`"Paginação de artigos`">`n")

  if ($currentPage -gt 1) {
    $prevHref = Get-PageHref $currentPage ($currentPage - 1)
    [void]$sb.Append("  <a href=`"$prevHref`" class=`"page-prev`">&larr; Anterior</a>`n")
  } else {
    [void]$sb.Append("  <span class=`"page-prev disabled`">&larr; Anterior</span>`n")
  }

  for ($i = 1; $i -le $totalPages; $i++) {
    if ($i -eq $currentPage) {
      [void]$sb.Append("  <span class=`"page-num current`">$i</span>`n")
    } else {
      $href = Get-PageHref $currentPage $i
      [void]$sb.Append("  <a href=`"$href`" class=`"page-num`">$i</a>`n")
    }
  }

  if ($currentPage -lt $totalPages) {
    $nextHref = Get-PageHref $currentPage ($currentPage + 1)
    [void]$sb.Append("  <a href=`"$nextHref`" class=`"page-next`">Próxima &rarr;</a>`n")
  } else {
    [void]$sb.Append("  <span class=`"page-next disabled`">Próxima &rarr;</span>`n")
  }

  [void]$sb.Append("</nav>")
  return $sb.ToString()
}

function Page-Template($cardsHtml, $paginationHtml, $currentPage, $totalPages, $totalItems) {
  $isFirst = ($currentPage -eq 1)
  $rootPrefix = if ($isFirst) { "../" } else { "../../../" }
  $cssHref = if ($isFirst) { "../styles.css" } else { "../../../styles.css" }
  $artigosHref = if ($isFirst) { "./" } else { "../../" }
  $titleSuffix = if ($isFirst) { "" } else { " — Página $currentPage" }

  return @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Artigos sobre Gestão, Qualidade e Normas ISO$titleSuffix | Doutor Gestão</title>
<meta name="description" content="Artigos práticos sobre ISO 9001, 14001, 45001, gestão da qualidade, ESG e segurança do trabalho, escritos pelo Prof. Ronaldo Veloso. Página $currentPage de $totalPages.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Open+Sans:wght@400;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="$cssHref">
</head>
<body>

<header class="site-header">
  <div class="container">
    <a href="${rootPrefix}index.html" class="logo">
      <img src="${rootPrefix}assets/doutor-gestao-banner.png" alt="Doutor Gestão">
    </a>
    <nav class="main-nav" id="main-nav">
      <ul>
        <li><a href="${rootPrefix}index.html">Home</a></li>
        <li><a href="${rootPrefix}cursos/">Cursos</a></li>
        <li><a href="$artigosHref">Artigos</a></li>
        <li><a href="${rootPrefix}quem-somos/">Quem Somos</a></li>
      </ul>
    </nav>
    <div class="header-actions">
      <a class="btn btn-primary" href="${rootPrefix}como-se-tornar-auditor-iso/">Saiba mais</a>
      <button class="nav-toggle" id="nav-toggle" aria-label="Abrir menu">☰</button>
    </div>
  </div>
</header>

<section class="hero" style="padding:56px 0 40px;">
  <div class="container" style="grid-template-columns:1fr;">
    <div class="hero-copy" style="max-width:680px;">
      <p class="breadcrumb"><a href="${rootPrefix}index.html">Home</a> / Artigos</p>
      <span class="hero-eyebrow">Conteúdo gratuito</span>
      <h1>Artigos sobre gestão, qualidade e normas ISO</h1>
      <p class="hero-sub" style="max-width:600px;">Conteúdo prático, direto de quem audita. $totalItems artigos publicados — página $currentPage de $totalPages.</p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0;">
  <div class="container">
    <div class="catalog-search">
      <div class="search-results-wrap">
        <input type="search" id="article-search" class="course-search-input" placeholder="Buscar entre os $totalItems artigos..." aria-label="Buscar artigo" autocomplete="off">
        <div class="search-results-dropdown" id="article-search-results"></div>
      </div>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0;">
  <div class="container">
    <div class="article-grid article-grid-3">
$cardsHtml
    </div>

    $paginationHtml
  </div>
</section>

<section class="final-cta">
  <div class="container">
    <h2>Quer aprender na prática?</h2>
    <p>Do artigo à formação completa — conheça o curso de Auditor Interno ISO 9001.</p>
    <a class="btn btn-primary" href="${rootPrefix}curso-auditor-interno-iso-9001/">Ver curso</a>
  </div>
</section>

<footer class="site-footer">
  <div class="container">
    <div class="footer-logo-feature">
      <img src="${rootPrefix}assets/doutor-gestao-banner.png" alt="Doutor Gestão">
    </div>
    <div class="footer-grid">
      <div>
        <p style="font-size:13px;">Formação e consultoria em sistemas de gestão, ESG e certificações internacionais. Belo Horizonte – MG.</p>
      </div>
      <div>
        <h4>Institucional</h4>
        <ul>
          <li><a href="${rootPrefix}quem-somos/">Quem Somos</a></li>
          <li><a href="${rootPrefix}faq/">FAQ</a></li>
          <li><a href="$artigosHref">Artigos</a></li>
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

<a class="whatsapp-float" href="https://wa.me/5531996150785?text=Ol%C3%A1!%20Vi%20um%20artigo%20no%20site%20e%20gostaria%20de%20saber%20mais." target="_blank" rel="noopener" aria-label="Falar no WhatsApp">
  <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.29-1.39a9.9 9.9 0 0 0 4.75 1.21h.01c5.46 0 9.9-4.45 9.9-9.91C21.96 6.45 17.5 2 12.04 2zm5.83 14.16c-.24.68-1.39 1.3-1.93 1.38-.5.08-1.13.11-1.82-.12-.42-.13-.96-.31-1.65-.6-2.91-1.26-4.81-4.18-4.96-4.38-.15-.2-1.19-1.58-1.19-3.01s.75-2.13 1.02-2.42c.26-.29.58-.36.77-.36.2 0 .39 0 .56.01.18.01.42-.07.65.5.24.58.82 2.01.89 2.16.07.15.12.32.02.52-.09.2-.14.32-.28.5-.14.17-.29.38-.42.51-.14.14-.29.29-.12.57.16.29.72 1.19 1.55 1.93 1.07.95 1.97 1.25 2.26 1.39.29.14.46.12.63-.07.17-.2.71-.83.9-1.11.19-.29.38-.24.63-.14.26.09 1.63.77 1.91.91.29.14.48.21.55.33.07.12.07.68-.17 1.36z"/></svg>
</a>

<script src="${rootPrefix}data/artigos-search.js"></script>
<script>
  document.getElementById('nav-toggle').addEventListener('click', function () {
    document.getElementById('main-nav').classList.toggle('open');
  });

  (function () {
    var input = document.getElementById('article-search');
    var dropdown = document.getElementById('article-search-results');

    function escapeHtml(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function render(term) {
      if (term === '') {
        dropdown.classList.remove('is-open');
        dropdown.innerHTML = '';
        return;
      }
      var matches = ARTICLES_SEARCH_DATA.filter(function (a) {
        return a.title.toLowerCase().indexOf(term) !== -1;
      }).slice(0, 8);

      if (matches.length === 0) {
        dropdown.innerHTML = '<div class="search-empty">Nenhum artigo encontrado.</div>';
      } else {
        dropdown.innerHTML = matches.map(function (a) {
          return '<a class="search-result-item" href="' + a.link + '">' +
            '<div class="search-result-title">' + escapeHtml(a.title) + '</div>' +
            '<div class="search-result-meta">' + escapeHtml(a.category) + ' · ' + escapeHtml(a.date) + '</div>' +
          '</a>';
        }).join('');
      }
      dropdown.classList.add('is-open');
    }

    input.addEventListener('input', function () {
      render(input.value.trim().toLowerCase());
    });

    document.addEventListener('click', function (e) {
      if (!e.target.closest('.search-results-wrap')) {
        dropdown.classList.remove('is-open');
      }
    });
  })();
</script>

</body>
</html>
"@
}

for ($page = 1; $page -le $totalPages; $page++) {
  $startIdx = ($page - 1) * $pageSize
  $pageItems = $items | Select-Object -Skip $startIdx -First $pageSize
  $cardsHtml = ($pageItems | ForEach-Object { Card-Html $_ }) -join "`n"
  $paginationHtml = Pagination-Html $page $totalPages
  $html = Page-Template $cardsHtml $paginationHtml $page $totalPages $totalItems

  if ($page -eq 1) {
    $outPath = Join-Path $root "artigos\index.html"
  } else {
    $dir = Join-Path $root "artigos\page\$page"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $outPath = Join-Path $dir "index.html"
  }

  # Grava sem BOM, sem quebra de linha extra no final
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($outPath, $html, $utf8NoBom)
}

Write-Output "OK: $totalPages paginas geradas a partir de data\artigos-data.json"
