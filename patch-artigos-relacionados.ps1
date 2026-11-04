# Adiciona o campo "relatedProducts" aos artigos de data/artigos-data.json,
# com base no mapeamento artigo -> produto(s) de vendas fornecido pelo cliente
# (tabela "Artigos e páginas de vendas relacionadas", pesquisa de 29/10/2026).
#
# So inclui vinculo quando a pagina de vendas existe de fato no site e a
# relacao era "direta" ou "complementar" (nunca "escopo a confirmar" nem
# "pagina nao identificada").
#
# Rode este script UMA VEZ (ou sempre que o mapeamento mudar) e depois rode
# build-artigo-paginas.ps1 para regerar as paginas com o CTA atualizado.
#
# Como rodar (a partir da pasta redesign-prototype):
#   powershell -ExecutionPolicy Bypass -File patch-artigos-relacionados.ps1

$ErrorActionPreference = "Stop"
$root = $PWD.Path
$dataPath = Join-Path $root "data\artigos-data.json"

$items = Get-Content -Raw -Encoding UTF8 $dataPath | ConvertFrom-Json

# Paginas de vendas reais confirmadas no site (checadas em 03/11/2026).
$PRODUCTS = @{
  curso9001          = @{ title = "Curso Auditor Interno ISO 9001:2015";        url = "curso-auditor-interno-iso-9001-2015/" }
  kit9001            = @{ title = "Kit Auditor ISO 9001:2026";                   url = "kit-auditoria-interna-iso-9001-2026/" }
  ebook9001transicao = @{ title = "E-book ISO 9001:2015 para 2026";              url = "colecao-iso-9001-2026/" }
  kit14001           = @{ title = "Kit Auditor ISO 14001:2026";                  url = "kit-auditoria-interna-iso-14001-2026/" }
  ebook14001         = @{ title = "E-book Atualização ISO 14001:2026";           url = "colecao-iso-14001-2026/" }
  kit45001           = @{ title = "Kit Auditor ISO 45001";                       url = "kit-auditor-iso-45001/" }
  curso45001         = @{ title = "Curso ISO 45001 — Interpretação e Aplicação"; url = "colecao-curso-iso-45001/" }
  ebook37001         = @{ title = "E-book ISO 37001:2025";                       url = "colecao-iso-37001-2025/" }
  ebook37301         = @{ title = "E-book ISO 37301:2021";                       url = "colecao-iso-37301-2021/" }
  sgi                = @{ title = "Curso SGI (amostra)";                         url = "amostra-sgi-9001-14001-45001/" }
}

# Indice (1-based, mesma ordem de data/artigos-data.json) -> lista de chaves de $PRODUCTS.
$MAP = @{
  1   = @("curso9001")
  3   = @("curso9001")
  4   = @("kit45001","curso45001")
  5   = @("ebook9001transicao","kit9001")
  6   = @("ebook14001","kit14001")
  7   = @("curso9001")
  8   = @("curso9001")
  9   = @("curso9001")
  10  = @("sgi")
  12  = @("curso9001")
  14  = @("curso9001")
  25  = @("kit14001","sgi")
  28  = @("sgi")
  32  = @("kit14001","sgi")
  33  = @("kit14001","sgi")
  34  = @("kit14001","sgi")
  35  = @("kit14001","sgi")
  36  = @("kit14001","sgi")
  37  = @("kit14001","sgi")
  38  = @("kit14001","sgi")
  39  = @("kit14001","sgi")
  40  = @("kit14001","sgi")
  41  = @("kit14001","sgi")
  42  = @("kit14001","sgi")
  43  = @("ebook37001","ebook37301")
  44  = @("ebook37001")
  45  = @("ebook37001")
  46  = @("ebook37001")
  47  = @("ebook37001")
  48  = @("ebook37001")
  49  = @("ebook37001")
  50  = @("ebook37001")
  51  = @("ebook37001")
  52  = @("ebook37001")
  53  = @("ebook37001")
  54  = @("ebook37301","ebook37001")
  55  = @("ebook37301","ebook37001")
  56  = @("sgi")
  58  = @("ebook37301","ebook37001")
  59  = @("ebook37301","ebook37001")
  60  = @("ebook37001")
  61  = @("ebook37301","ebook37001")
  62  = @("ebook37301","ebook37001")
  63  = @("ebook37301","ebook37001")
  65  = @("sgi")
  66  = @("kit14001","ebook37301")
  67  = @("kit14001","ebook37301")
  68  = @("kit14001","ebook37301")
  71  = @("kit14001")
  72  = @("kit45001")
  73  = @("sgi")
  74  = @("kit14001","ebook37301")
  75  = @("kit14001","ebook37301")
  76  = @("sgi")
  77  = @("sgi")
  78  = @("kit14001","ebook37301")
  79  = @("kit14001","ebook37301")
  81  = @("kit14001","ebook37301")
  83  = @("kit14001","ebook37301")
  84  = @("kit14001","ebook37301")
  85  = @("curso9001")
  86  = @("sgi")
  87  = @("sgi")
  88  = @("curso9001")
  89  = @("curso9001")
  90  = @("kit45001","curso45001")
  91  = @("kit45001","curso45001")
  92  = @("sgi")
  93  = @("sgi")
  94  = @("sgi")
  95  = @("curso9001")
  101 = @("curso9001")
  102 = @("curso9001")
  103 = @("curso9001")
  117 = @("kit45001","curso45001")
  118 = @("kit45001","curso45001")
  119 = @("kit45001","curso45001")
  120 = @("kit45001","curso45001")
  123 = @("kit45001","curso45001")
  124 = @("kit45001","curso45001")
  125 = @("kit45001","curso45001")
  127 = @("curso9001")
  128 = @("curso9001")
  129 = @("curso9001")
  130 = @("sgi")
  131 = @("curso9001")
  135 = @("curso9001")
  136 = @("kit45001","curso45001")
  137 = @("curso9001")
  143 = @("kit14001")
  144 = @("curso9001")
  145 = @("curso9001")
  146 = @("kit14001","ebook37301")
  148 = @("sgi")
  149 = @("sgi")
  150 = @("kit14001")
  151 = @("kit14001")
  152 = @("ebook37301")
  154 = @("kit45001","curso45001")
  156 = @("kit45001","curso45001")
  157 = @("kit14001","ebook37301")
  158 = @("kit14001")
  160 = @("kit14001","ebook37301")
  161 = @("ebook37001")
  162 = @("ebook37001")
  163 = @("ebook37001")
  164 = @("kit14001")
  165 = @("kit14001")
  167 = @("kit14001")
  172 = @("curso9001")
  179 = @("curso9001")
  180 = @("curso9001")
  181 = @("kit14001","sgi")
  184 = @("kit14001","ebook37301")
  185 = @("kit14001","sgi")
  186 = @("kit14001","sgi")
  187 = @("kit14001","sgi")
  188 = @("kit14001","sgi")
  189 = @("kit14001","sgi")
  196 = @("kit45001")
  198 = @("kit14001","ebook37301")
  199 = @("curso9001")
  200 = @("kit14001","ebook37301")
}

$applied = 0
foreach ($idx in $MAP.Keys) {
  $i = [int]$idx
  if ($i -lt 1 -or $i -gt $items.Count) {
    Write-Warning "Indice fora do intervalo: $i"
    continue
  }
  $keys = $MAP[$idx]
  $resolvedList = New-Object System.Collections.ArrayList
  foreach ($k in $keys) {
    [void]$resolvedList.Add([PSCustomObject]@{ title = $PRODUCTS[$k].title; url = $PRODUCTS[$k].url })
  }
  $items[$i - 1] | Add-Member -NotePropertyName "relatedProducts" -NotePropertyValue @($resolvedList) -Force
  $applied++
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$json = $items | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($dataPath, $json, $utf8NoBom)

Write-Output "OK: $applied artigos receberam relatedProducts. Rode build-artigo-paginas.ps1 para regerar as paginas."
