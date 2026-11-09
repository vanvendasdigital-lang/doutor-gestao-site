# Reconstroi as paginas de artigos:
#   - artigos/index.html + artigos/page/2../20/      (listagem geral)
#   - artigos/categoria/<slug>/ + .../page/2../N/    (uma por categoria)
# a partir de data/artigos-data.json.
#
# Estas sao paginas de LISTAGEM: usam o mesmo visual claro da Home (styles.css),
# igual ao resto do site. So as paginas INDIVIDUAIS de cada artigo (geradas
# por build-artigo-paginas.ps1) usam a identidade nova (colecao.css).
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

# Converte um nome de categoria em slug de URL (sem acento, minusculo, com hifens).
function Get-CategorySlug([string]$name) {
  # Hashtables do PowerShell sao case-insensitive por padrao: 'a' e 'A' seriam
  # a mesma chave. Por isso o texto e minusculizado ANTES do mapa de acentos,
  # que assim so precisa de uma entrada por letra.
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

$pageSize = 10
$totalItems = $items.Count
$totalPages = [Math]::Ceiling($totalItems / $pageSize)

# Categorias (contagem global) e 5 artigos mais recentes, para a sidebar.
# Independem da pagina atual, entao sao calculados uma unica vez.
$categoryGroups = $items | Group-Object category | Sort-Object Count -Descending

# Cada categoria na sidebar linka pra sua propria pagina de listagem filtrada
# (artigos/categoria/<slug>/), onde da pra ver so os artigos daquele assunto.
function CatList-Html($categoryGroups, $rootPrefix) {
  $rows = $categoryGroups | ForEach-Object {
    $name = $_.Name
    $count = $_.Count
    $slug = Get-CategorySlug $name
    $href = "${rootPrefix}artigos/categoria/$slug/"
    "      <li><a class=`"cat-row`" href=`"$href`"><span>$(Html-Attr $name)</span><span class=`"count`">$count</span></a></li>"
  }
  return ($rows -join "`n")
}

$recentItems = $items | Select-Object -First 5
$recentListHtml = ($recentItems | ForEach-Object {
  "      <li><span class=`"recent-dot`"></span><div><a href=`"$(Html-Attr $_.link)`">$(Html-Attr $_.title)</a><small>$($_.date)</small></div></li>"
}) -join "`n"

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

# $rootPrefix leva da pagina atual ate a raiz do site; $baseHref e o caminho
# (relativo a raiz) da listagem sendo paginada, ex: "artigos/" ou
# "artigos/categoria/conformidade/". Funciona pra qualquer profundidade.
function Get-PageHref($rootPrefix, $baseHref, $targetPage) {
  if ($targetPage -eq 1) { return "$rootPrefix$baseHref" }
  return "$rootPrefix${baseHref}page/$targetPage/"
}

function Pagination-Html($currentPage, $totalPages, $rootPrefix, $baseHref) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("<nav class=`"pagination`" aria-label=`"Paginação de artigos`">`n")

  if ($currentPage -gt 1) {
    $prevHref = Get-PageHref $rootPrefix $baseHref ($currentPage - 1)
    [void]$sb.Append("  <a href=`"$prevHref`" class=`"page-prev`">&larr; Anterior</a>`n")
  } else {
    [void]$sb.Append("  <span class=`"page-prev disabled`">&larr; Anterior</span>`n")
  }

  for ($i = 1; $i -le $totalPages; $i++) {
    if ($i -eq $currentPage) {
      [void]$sb.Append("  <span class=`"page-num current`">$i</span>`n")
    } else {
      $href = Get-PageHref $rootPrefix $baseHref $i
      [void]$sb.Append("  <a href=`"$href`" class=`"page-num`">$i</a>`n")
    }
  }

  if ($currentPage -lt $totalPages) {
    $nextHref = Get-PageHref $rootPrefix $baseHref ($currentPage + 1)
    [void]$sb.Append("  <a href=`"$nextHref`" class=`"page-next`">Próxima &rarr;</a>`n")
  } else {
    [void]$sb.Append("  <span class=`"page-next disabled`">Próxima &rarr;</span>`n")
  }

  [void]$sb.Append("</nav>")
  return $sb.ToString()
}

function Page-Template($cardsHtml, $paginationHtml, $currentPage, $totalPages, $totalItems, $recentListHtml, $rootPrefix) {
  $cssHref = "${rootPrefix}styles.css"
  $artigosHref = "${rootPrefix}artigos/"
  $titleSuffix = if ($currentPage -eq 1) { "" } else { " — Página $currentPage" }
  $catListHtml = CatList-Html $categoryGroups $rootPrefix

  return @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Artigos sobre Gestão, Qualidade e Normas ISO$titleSuffix | Doutor Gestão</title>
<meta name="description" content="Artigos práticos sobre ISO 9001, 14001, 45001, gestão da qualidade, ESG e segurança do trabalho, escritos pelo Prof. Ronaldo Veloso. Página $currentPage de $totalPages.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Open+Sans:wght@400;600&family=Fraunces:ital,wght@1,600&display=swap" rel="stylesheet">
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
        <li><a href="${rootPrefix}resultados/">Resultados</a></li>
        <li><a href="$artigosHref" aria-current="page">Artigos</a></li>
        <li><a href="${rootPrefix}quem-somos/">Quem Somos</a></li>
      </ul>
    </nav>
    <div class="header-actions">
      <a class="btn btn-primary" href="${rootPrefix}cursos/">Conhecer cursos</a>
      <button class="nav-toggle" id="nav-toggle" aria-label="Abrir menu">☰</button>
    </div>
  </div>
</header>

<section class="hero" style="padding:40px 0;text-align:center;">
  <div class="container" style="grid-template-columns:1fr;">
    <div class="hero-copy" style="max-width:680px;margin:0 auto;">
      <p class="breadcrumb"><a href="${rootPrefix}index.html">Home</a> / Artigos</p>
      <span class="hero-eyebrow">Conteúdo gratuito</span>
      <h1 style="font-size:clamp(34px,5.5vw,54px);">Artigos Doutorgestão</h1>
      <p class="hero-sub" style="max-width:600px;margin:0 auto;">Conteúdo prático, direto de quem audita. $totalItems artigos publicados — página $currentPage de $totalPages.</p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0;">
  <div class="container">
    <div class="articles-layout">
      <main>
        <div class="article-grid article-grid-2">
$cardsHtml
        </div>

        $paginationHtml
      </main>

      <aside class="sidebar">
        <div class="side-banner">
          <span class="eyebrow-b">Curso em destaque</span>
          <h4>Kit de Auditoria Interna ISO 9001:2026</h4>
          <p>Prepare sua empresa para a nova versão da norma com auditoria interna guiada.</p>
          <a class="btn" href="${rootPrefix}kit-auditoria-interna-iso-9001-2026/">Conhecer o kit</a>
        </div>

        <div class="side-card side-card-search">
          <h3>Buscar artigos</h3>
          <div class="search-results-wrap">
            <input type="search" id="article-search" class="course-search-input" placeholder="Buscar entre os $totalItems artigos..." aria-label="Buscar artigo" autocomplete="off">
            <div class="search-results-dropdown" id="article-search-results"></div>
          </div>
        </div>

        <div class="side-card">
          <h3>Categorias</h3>
          <ul class="cat-list">
$catListHtml
          </ul>
        </div>

        <div class="side-card">
          <h3>Recentes</h3>
          <ul class="recent-list">
$recentListHtml
          </ul>
        </div>
      </aside>
    </div>
  </div>
</section>

<section class="final-cta">
  <div class="container">
    <h2>Quer aprender na prática?</h2>
    <p>Do artigo à formação completa — conheça o curso de Auditor Interno ISO 9001.</p>
    <a class="btn btn-primary" href="${rootPrefix}curso-auditor-interno-iso-9001-2015/">Ver curso</a>
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
          <li><a href="${rootPrefix}resultados/">Resultados</a></li>
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
      <span>Site desenvolvido por <span style="display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;border-radius:50%;background:#4F3DE8;font-family:'Fraunces',serif;font-style:italic;font-weight:600;font-size:10px;color:#fff;vertical-align:middle;line-height:1;">V</span> Vanessa Sousa · (31) 99472-5779</span>
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

function Category-Page-Template($cardsHtml, $paginationHtml, $currentPage, $totalPages, $categoryName, $categoryTotal, $recentListHtml, $rootPrefix) {
  $cssHref = "${rootPrefix}styles.css"
  $artigosHref = "${rootPrefix}artigos/"
  $titleSuffix = if ($currentPage -eq 1) { "" } else { " — Página $currentPage" }
  $catListHtml = CatList-Html $categoryGroups $rootPrefix

  return @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$(Html-Attr $categoryName) — Artigos$titleSuffix | Doutor Gestão</title>
<meta name="description" content="Artigos sobre $(Html-Attr $categoryName). $categoryTotal artigos publicados — página $currentPage de $totalPages.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Open+Sans:wght@400;600&family=Fraunces:ital,wght@1,600&display=swap" rel="stylesheet">
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
        <li><a href="${rootPrefix}resultados/">Resultados</a></li>
        <li><a href="$artigosHref" aria-current="page">Artigos</a></li>
        <li><a href="${rootPrefix}quem-somos/">Quem Somos</a></li>
      </ul>
    </nav>
    <div class="header-actions">
      <a class="btn btn-primary" href="${rootPrefix}cursos/">Conhecer cursos</a>
      <button class="nav-toggle" id="nav-toggle" aria-label="Abrir menu">☰</button>
    </div>
  </div>
</header>

<section class="hero" style="padding:40px 0;text-align:center;">
  <div class="container" style="grid-template-columns:1fr;">
    <div class="hero-copy" style="max-width:680px;margin:0 auto;">
      <p class="breadcrumb"><a href="${rootPrefix}index.html">Home</a> / <a href="$artigosHref">Artigos</a> / $(Html-Attr $categoryName)</p>
      <span class="hero-eyebrow">Categoria</span>
      <h1 style="font-size:clamp(30px,5vw,46px);">$(Html-Attr $categoryName)</h1>
      <p class="hero-sub" style="max-width:600px;margin:0 auto;">$categoryTotal artigos nessa categoria — página $currentPage de $totalPages. <a href="$artigosHref">Ver todos os artigos &rarr;</a></p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:0;">
  <div class="container">
    <div class="articles-layout">
      <main>
        <div class="article-grid article-grid-2">
$cardsHtml
        </div>

        $paginationHtml
      </main>

      <aside class="sidebar">
        <div class="side-banner">
          <span class="eyebrow-b">Curso em destaque</span>
          <h4>Kit de Auditoria Interna ISO 9001:2026</h4>
          <p>Prepare sua empresa para a nova versão da norma com auditoria interna guiada.</p>
          <a class="btn" href="${rootPrefix}kit-auditoria-interna-iso-9001-2026/">Conhecer o kit</a>
        </div>

        <div class="side-card side-card-search">
          <h3>Buscar artigos</h3>
          <div class="search-results-wrap">
            <input type="search" id="article-search" class="course-search-input" placeholder="Buscar entre os artigos..." aria-label="Buscar artigo" autocomplete="off">
            <div class="search-results-dropdown" id="article-search-results"></div>
          </div>
        </div>

        <div class="side-card">
          <h3>Categorias</h3>
          <ul class="cat-list">
$catListHtml
          </ul>
        </div>

        <div class="side-card">
          <h3>Recentes</h3>
          <ul class="recent-list">
$recentListHtml
          </ul>
        </div>
      </aside>
    </div>
  </div>
</section>

<section class="final-cta">
  <div class="container">
    <h2>Quer aprender na prática?</h2>
    <p>Do artigo à formação completa — conheça o curso de Auditor Interno ISO 9001.</p>
    <a class="btn btn-primary" href="${rootPrefix}curso-auditor-interno-iso-9001-2015/">Ver curso</a>
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
          <li><a href="${rootPrefix}resultados/">Resultados</a></li>
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
      <span>Site desenvolvido por <span style="display:inline-flex;align-items:center;justify-content:center;width:16px;height:16px;border-radius:50%;background:#4F3DE8;font-family:'Fraunces',serif;font-style:italic;font-weight:600;font-size:10px;color:#fff;vertical-align:middle;line-height:1;">V</span> Vanessa Sousa · (31) 99472-5779</span>
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

  $isFirst = ($page -eq 1)
  $rootPrefix = if ($isFirst) { "../" } else { "../../../" }
  $paginationHtml = Pagination-Html $page $totalPages $rootPrefix "artigos/"
  $html = Page-Template $cardsHtml $paginationHtml $page $totalPages $totalItems $recentListHtml $rootPrefix

  if ($isFirst) {
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

# Uma listagem paginada por categoria (artigos/categoria/<slug>/...), pra quem
# clica numa categoria na sidebar ver so os artigos daquele assunto.
$categoryPagesTotal = 0
foreach ($group in $categoryGroups) {
  $categoryName = $group.Name
  $categorySlug = Get-CategorySlug $categoryName
  # @(...) forca contexto de array: sem isso, uma categoria com 1 so artigo
  # (ex: Segurança do Trabalho) vira um objeto solto e .Count retorna $null,
  # fazendo o loop de paginas abaixo nao rodar nenhuma vez.
  $categoryItems = @($items | Where-Object { $_.category -eq $categoryName })
  $catTotalItems = $categoryItems.Count
  $catTotalPages = [Math]::Ceiling($catTotalItems / $pageSize)

  for ($page = 1; $page -le $catTotalPages; $page++) {
    $startIdx = ($page - 1) * $pageSize
    $pageItems = $categoryItems | Select-Object -Skip $startIdx -First $pageSize
    $cardsHtml = ($pageItems | ForEach-Object { Card-Html $_ }) -join "`n"

    $isFirst = ($page -eq 1)
    $rootPrefix = if ($isFirst) { "../../../" } else { "../../../../../" }
    $baseHref = "artigos/categoria/$categorySlug/"
    $paginationHtml = Pagination-Html $page $catTotalPages $rootPrefix $baseHref
    $html = Category-Page-Template $cardsHtml $paginationHtml $page $catTotalPages $categoryName $catTotalItems $recentListHtml $rootPrefix

    if ($isFirst) {
      $dir = Join-Path $root "artigos\categoria\$categorySlug"
    } else {
      $dir = Join-Path $root "artigos\categoria\$categorySlug\page\$page"
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $outPath = Join-Path $dir "index.html"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outPath, $html, $utf8NoBom)
    $categoryPagesTotal++
  }
}

Write-Output "OK: $categoryPagesTotal paginas de categoria geradas ($($categoryGroups.Count) categorias)"
