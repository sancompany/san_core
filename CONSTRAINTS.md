# CONSTRAINTS — San & Co. Core

O que este projeto **não** faz e os limites que ele assume. Um item daqui só
sai por decisão explícita do dono, nunca porque alguém (pessoa ou IA) achou
que seria boa ideia.

## 1. Comunicação dos passes — REGRA OBRIGATÓRIA

O nome nos termos, na estrutura jurídica e no código é **"Passes de
Acesso"**. A interface pode dizer só "passes".

**Nunca prometer, sugerir ou insinuar,** nem na interface nem no texto que
o agente gera:
- rendimento, retorno, lucro, dividendo ou ganho financeiro passivo;
- participação no lucro, no capital, no CNPJ ou em decisões da empresa,
  incluindo as palavras "cota", "participação", "sócio" e "investimento";
- valorização do passe ou revenda;
- ganho por indicar novos compradores.

O passe vale **apenas** acesso: conteúdo, ferramentas, status e benefícios
dentro da comunidade.

**Por quê:** a CVM trata como valor mobiliário (contrato de investimento
coletivo, Lei 6.385/76, art. 2º, IX) a oferta pública de um título que dá
expectativa de ganho pelo esforço de outra pessoa. E renda vinda da entrada
de novos participantes caracteriza pirâmide (Lei 1.521/51, art. 2º, IX). O
que conta é o que é oferecido, não o nome. A revisão jurídica antes da
divulgação continua recomendada: o operador é MEI, com atividades e teto
de faturamento limitados.

## 2. Escopo negativo

- **Cobrança própria — VETADO.** Todo pagamento passa pelo San Checkout.
- **Transferir ou revender passes entre contas — VETADO.** Cria mercado
  secundário com preço (§1). Decisão do dono, 27/11/2026.
- **Expirar passes — FORA da v1.** Decisão do dono, 27/11/2026.
- **Comissão ou passe por indicação — VETADO.** É o gatilho de pirâmide da
  §1.
- **A plataforma intermediar a venda dos produtos dos Membros — VETADO na
  v1.** A vitrine só divulga, com link externo `https://`. Intermediar faria
  a San & Co. receber dinheiro de terceiros e responder como marketplace.
- **O agente executar estorno, reembolso ou ajuste de passes — VETADO.**
  Esses casos vão para `escalonamentos`.
- **Alterar ou apagar uma linha do `passes_ledger` — VETADO**, garantido
  por trigger. Correção é um lançamento novo, com motivo e autor.
- **Apagar a conta direto em `auth.users` — BLOQUEADO** pela FK
  `on delete restrict`. A exclusão LGPD será um fluxo de anonimização
  (Etapa 3), porque pedido e extrato têm guarda fiscal.

## 3. Limites assumidos

Ainda não medidos. Entram aqui quando o banco estiver no ar.

## 4. Dispensas e exceções

- **Testes de banco locais em Postgres 16; o Supabase roda 17.** O CI usa
  `postgres:17`. A migration não usa nada que mude entre as duas versões.
