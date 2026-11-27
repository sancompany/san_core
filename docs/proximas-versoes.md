# Próximas versões

Ideias guardadas. Nenhuma entrada aqui autoriza construir.

## Escada de quatro níveis
- **O que:** Iniciado, Construtor, Estrategista e Conselho, por faixa de
  passes, cada uma liberando mais.
- **Por que:** dar progressão a quem acumula passes. Na v1, 2 e 100
  passes liberam a mesma coisa.
- **De onde veio:** diretriz de arquitetura de 27/11/2026, cortada da v1 no
  mesmo dia para simplificar.
- **O que toca:** linhas novas em `niveis_config`, o
  `nivel_minimo_exigido` dos conteúdos e as telas de progresso. O schema já
  comporta essa mudança.
- **Quando vale a pena:** quando houver Membros comprando mais passes
  sem ter o que desbloquear, ou conteúdo suficiente para justificar mais de
  uma faixa. Antes disso, rever os nomes "Conselho" e "Estrategista" com o
  jurídico (`CONSTRAINTS.md` §1).

## Videoaulas
- **O que:** módulos em vídeo no acervo.
- **Por que:** o formato que a diretriz prevê para depois dos e-books.
- **De onde veio:** diretriz de 27/11/2026 ("em fases futuras").
- **O que toca:** `conteudos.tipo = 'video'` (já existe), o Storage ou um
  provedor de vídeo, e o custo de banda.
- **Quando vale a pena:** quando o acervo em texto estiver publicado e
  houver pedido dos Membros.
