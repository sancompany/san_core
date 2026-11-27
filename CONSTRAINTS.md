# CONSTRAINTS — San & Co. Core

O que este projeto **não** faz e os limites que ele assume. Um item daqui só
sai por decisão explícita do dono, nunca porque alguém (pessoa ou IA) achou
que seria boa ideia.

## 1. Comunicação das cotas — REGRA OBRIGATÓRIA

Na interface e em toda comunicação, inclusive no texto que o agente gera, o
nome é **"Cotas de Acesso"** ou **"Cotas de Participação"**.

**Nunca prometer, sugerir ou insinuar:**
- rendimento, retorno, lucro, dividendo ou ganho financeiro passivo;
- participação no lucro, no capital, no CNPJ ou em decisões da empresa;
- valorização da cota, revenda ou "investimento";
- ganho por indicar novos compradores.

A cota vale **apenas** desbloqueio de conteúdo, ferramentas comerciais,
status e benefícios dentro da comunidade.

**Por quê:** a CVM trata como valor mobiliário (contrato de investimento
coletivo, Lei 6.385/76, art. 2º, IX) a oferta pública de um título que dá
expectativa de ganho pelo esforço de outra pessoa. E renda vinda da entrada
de novos participantes caracteriza pirâmide (Lei 1.521/51, art. 2º, IX). O
nome do produto não protege: vale o que é oferecido e como.

**Riscos que continuam abertos até a revisão jurídica:**
- a palavra "participação";
- o nível chamado "Conselho", que sugere poder de decisão;
- o operador ser MEI, que não tem quotas e tem atividades e teto de
  faturamento limitados.

Veja a spec, §7.

## 2. Escopo negativo

- **Cobrança própria — VETADO.** Todo pagamento passa pelo San Checkout.
- **Transferência ou revenda de cotas entre membros — FORA**, até a decisão
  2 da spec ser tomada.
- **Comissão ou cota por indicação — VETADO.** É o gatilho de pirâmide da
  §1.
- **O agente executar estorno, reembolso ou ajuste de cotas — VETADO.**
  Essas ações vão para a fila `escalonamentos`.
- **Alterar ou apagar uma linha do `cotas_ledger` — VETADO.** Correção é
  um lançamento novo, com motivo.

## 3. Limites assumidos

Ainda não medidos. Entram aqui na Etapa 1, quando o banco existir.
