/**
 * Diagrama vivo do ecossistema San & Co.
 *
 * Hoje os dados abaixo são estáticos. Quando cada subdomínio publicar seu
 * próprio arquivo `sanco-info.json`, basta trocar PROJETOS por um fetch
 * por projeto, mantendo a mesma forma de objeto usada aqui.
 *
 * status aceita três valores, que definem automaticamente o tamanho do nó
 * e a distância até o núcleo (quanto mais maduro, maior e mais distante):
 *   'ideia'     -> nó pequeno, órbita próxima, gira mais rápido
 *   'em breve'  -> nó médio, órbita intermediária
 *   'operação'  -> nó grande, órbita distante, gira mais devagar
 *
 * As posições NÃO são fixas: cada projeto orbita o núcleo continuamente e
 * um projeto novo já entra na órbita certa sozinho, sem coordenada manual.
 */

const PROJETOS = [
  {
    id: 'core',
    core: true,
    nome: 'Núcleo Operacional',
    area: 'Infraestrutura, engenharia e governança',
    descricao: 'O centro que concentra domínio, dados e inteligência para todo o ecossistema San & Co.',
    status: 'operação',
    url: 'https://sancocore.com.br',
  },
  {
    id: 'checkout',
    nome: 'San Checkout',
    area: 'Motor de pagamentos universal',
    descricao: 'Motor de pagamento whitelabel (Pix e cartão) do ecossistema.',
    status: 'operação',
    url: 'https://checkout.sancocore.com.br',
  },
  {
    id: 'humano',
    nome: 'Humano',
    area: 'Gestão financeira executiva e rotineira',
    descricao: 'Dashboard pessoal de finanças, patrimônio e rotina.',
    status: 'em breve',
    url: 'https://humano.sancocore.com.br',
  },
  {
    id: 'trimundi',
    nome: 'Trimundi',
    area: 'Produtora de eventos',
    descricao: 'Produção e organização de eventos.',
    status: 'em breve',
    url: 'https://trimundi.sancocore.com.br',
  },
  {
    id: 'anakor',
    nome: 'Anakor',
    area: 'E-commerce local',
    descricao: 'Loja online voltada ao comércio local — ainda em fase de ideia.',
    status: 'ideia',
    url: 'https://anakor.sancocore.com.br',
  },
];

const ORBITA = {
  'ideia':     { raioX: 15, raioY: 17, velocidade: 10,  anguloInicial: 140 },
  'em breve':  { raioX: 25, raioY: 28, velocidade: 5.5, anguloInicial: -20 },
  'operação':  { raioX: 37, raioY: 41, velocidade: 3,   anguloInicial: -90 },
};

const frame = document.querySelector('[data-diagrama-frame]');

if (frame) {
  const svgNS = 'http://www.w3.org/2000/svg';
  const linesSvg = document.createElementNS(svgNS, 'svg');
  linesSvg.setAttribute('class', 'diagrama__lines');
  linesSvg.setAttribute('viewBox', '0 0 100 100');
  linesSvg.setAttribute('preserveAspectRatio', 'none');
  frame.appendChild(linesSvg);

  const core = PROJETOS.find((p) => p.core);
  const perifericos = PROJETOS.filter((p) => !p.core);

  // Distribui o ângulo inicial de cada nó dentro do seu próprio anel
  // (mesmo status), para não nascerem empilhados.
  const porStatus = {};
  perifericos.forEach((p) => {
    porStatus[p.status] = porStatus[p.status] || [];
    porStatus[p.status].push(p);
  });
  Object.entries(porStatus).forEach(([status, lista]) => {
    const cfg = ORBITA[status];
    const passo = 360 / lista.length;
    lista.forEach((p, i) => {
      p.anguloBase = cfg.anguloInicial + i * passo;
      p.raioX = cfg.raioX;
      p.raioY = cfg.raioY;
      p.velocidade = cfg.velocidade;
    });
  });

  const itens = [];

  perifericos.forEach((p) => {
    const line = document.createElementNS(svgNS, 'line');
    line.setAttribute('vector-effect', 'non-scaling-stroke');
    linesSvg.appendChild(line);

    const node = document.createElement('button');
    node.type = 'button';
    const classeStatus = p.status === 'operação' ? 'node--live' : p.status === 'em breve' ? 'node--soon' : 'node--idea';
    node.className = `node ${classeStatus}`;
    node.setAttribute('aria-haspopup', 'dialog');
    node.innerHTML = `
      <span class="node__dot">${p.nome}</span>
      <span class="node__label">${p.status}</span>
    `;
    node.addEventListener('click', () => openProjetoCard(p));
    frame.appendChild(node);

    itens.push({ p, node, line });
  });

  // Núcleo: fixo no centro
  const coreNode = document.createElement('button');
  coreNode.type = 'button';
  coreNode.className = 'node node--core';
  coreNode.style.left = '50%';
  coreNode.style.top = '50%';
  coreNode.setAttribute('aria-haspopup', 'dialog');
  coreNode.innerHTML = `<span class="node__dot">sancocore<br>.com.br</span><span class="node__label"></span>`;
  coreNode.addEventListener('click', () => openProjetoCard(core));
  frame.appendChild(coreNode);

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function posicionar(timestampSeg) {
    itens.forEach(({ p, node, line }) => {
      const anguloDeg = p.anguloBase + (prefersReducedMotion ? 0 : p.velocidade * timestampSeg);
      const anguloRad = (anguloDeg * Math.PI) / 180;
      const x = 50 + p.raioX * Math.cos(anguloRad);
      const y = 50 + p.raioY * Math.sin(anguloRad);
      node.style.left = `${x}%`;
      node.style.top = `${y}%`;
      line.setAttribute('x1', 50);
      line.setAttribute('y1', 50);
      line.setAttribute('x2', x);
      line.setAttribute('y2', y);
    });
  }

  posicionar(0);

  if (!prefersReducedMotion) {
    let start = null;
    function loop(ts) {
      if (start === null) start = ts;
      posicionar((ts - start) / 1000);
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
  }
}

// ===== Card sobreposto =====
const card = document.querySelector('[data-projeto-card]');
const cardPanel = card ? card.querySelector('.projeto-card__panel') : null;

function openProjetoCard(p) {
  if (!card || !cardPanel) return;
  cardPanel.innerHTML = `
    <button type="button" class="projeto-card__close" aria-label="Fechar">&times;</button>
    <span class="projeto-card__status" data-status="${p.status}">${p.status}</span>
    <h3>${p.nome}</h3>
    <p class="projeto-card__area">${p.area}</p>
    <p class="projeto-card__desc">${p.descricao}</p>
    <a class="btn btn-primary" href="${p.url}" target="_blank" rel="noopener">Abrir site</a>
  `;
  card.classList.add('is-open');
  cardPanel.querySelector('.projeto-card__close').addEventListener('click', closeProjetoCard);
  document.addEventListener('keydown', onEscClose);
}

function closeProjetoCard() {
  if (!card) return;
  card.classList.remove('is-open');
  document.removeEventListener('keydown', onEscClose);
}

function onEscClose(e) {
  if (e.key === 'Escape') closeProjetoCard();
}

if (card) {
  card.addEventListener('click', (e) => {
    if (e.target === card) closeProjetoCard();
  });
}
