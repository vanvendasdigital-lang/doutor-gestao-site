// Lista de cursos exibidos no catálogo (cursos/index.html).
//
// Para adicionar um curso novo, copie um bloco { ... } inteiro, cole antes do
// "];" no final, e ajuste os campos. Não precisa mexer em nenhum HTML.
// Depois é só salvar e recarregar a página do catálogo no navegador.
//
// Campos:
//   status      "disponivel" ou "em-breve"
//   category    categoria do curso, usada nos filtros do topo do catálogo.
//               Use uma das já existentes ("Qualidade", "Meio Ambiente",
//               "Segurança do Trabalho") ou crie uma nova — o filtro se
//               atualiza sozinho com base no que estiver aqui.
//   mediaLabel  texto curto sobre a imagem do card (ex: "ISO 14001")
//   image       URL da imagem (link do WordPress, ou de qualquer imagem hospedada)
//   title       título do curso
//   rating      texto de avaliação (ex: "4,7/5 · 2.600+ avaliações"), ou null se não tiver ainda
//   description texto curto (1-2 linhas) sobre o curso
//   link        para onde o botão leva. Use "#" se ainda não tiver página do curso.
//   ctaLabel    texto do botão (ex: "Ver curso", "Avise-me")

const COURSES_DATA = [
  {
    status: "disponivel",
    category: "Qualidade",
    mediaLabel: "ISO 9001:2015",
    image: "https://doutorgestao.com.br/wp-content/uploads/2026/03/imagem-curso-formacao-auditores-ISO-9001-1-850x600.png",
    title: "Interpretação e Formação de Auditor Interno ISO 9001:2015",
    rating: "4,7/5 · 2.600+ avaliações · 5.700+ alunos",
    description: "Metodologia A1: planejamento, condução de entrevistas, relatório e apresentação de resultados.",
    link: "../curso-auditor-interno-iso-9001/",
    ctaLabel: "Ver curso"
  },
  {
    status: "em-breve",
    category: "Meio Ambiente",
    mediaLabel: "ISO 14001",
    image: "https://doutorgestao.com.br/wp-content/uploads/2025/10/categoria-ISO-14001-curso.webp",
    title: "Formação em Sistema de Gestão Ambiental ISO 14001",
    rating: null,
    description: "Auditoria interna e implantação de sistemas de gestão ambiental. Estrutura de curso em preparação.",
    link: "#",
    ctaLabel: "Avise-me"
  },
  {
    status: "em-breve",
    category: "Segurança do Trabalho",
    mediaLabel: "ISO 45001",
    image: "https://doutorgestao.com.br/wp-content/uploads/2025/11/Auditoria-Interna-ISO-450012018-em-SST.png",
    title: "Formação em Segurança e Saúde Ocupacional ISO 45001",
    rating: null,
    description: "Auditoria e requisitos de SST aplicados. Estrutura de curso em preparação.",
    link: "#",
    ctaLabel: "Avise-me"
  },
  {
    status: "disponivel",
    category: "Compliance",
    mediaLabel: "ISO 37301:2021",
    image: "",
    title: "E-book ISO 37301:2021 — Sistema de Gestão de Compliance na Prática",
    rating: null,
    description: "153 páginas, 20 capítulos, 100 exercícios comentados e kit com 14 ferramentas preenchíveis.",
    link: "../ebook-iso-37301-compliance/",
    ctaLabel: "Ver e-book"
  },
  {
    status: "disponivel",
    category: "Compliance",
    mediaLabel: "ISO 37001:2025",
    image: "",
    title: "E-book ISO 37001:2025 — Guia Prático de Implementação e Certificação",
    rating: null,
    description: "Sistema de Gestão Antissuborno alinhado à Lei Anticorrupção (12.846/2013) e ao Decreto 11.129/2022.",
    link: "../ebook-iso-37001-antissuborno/",
    ctaLabel: "Ver e-book"
  }
];
