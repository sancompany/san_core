# Inventário de dados pessoais

Este é o registro de operações exigido pela LGPD (art. 37). Atualizar na
mesma tarefa que cria ou muda um dado. Estado: o schema existe só em
migration; ainda não está em produção.

| Dado | De quem | Para quê | Onde fica | Quem mais recebe | Retenção | Como sai | Base legal |
|---|---|---|---|---|---|---|---|
| E-mail, senha (hash do Supabase Auth) | Conta | Login | `auth.users`, Supabase `sa-east-1` | — | Enquanto a conta existir | Anonimização (Etapa 3) | Execução de contrato |
| Nome (opcional) | Conta | Exibição na comunidade | `profiles.nome` | — | Enquanto a conta existir | Apagado na anonimização | Execução de contrato |
| Pedidos (quantidade de passes, valor, status) | Comprador | Venda e conciliação | `pedidos` | San Checkout / Asaas | 5 anos (fiscal) | Desvinculado da pessoa na anonimização | Obrigação legal |
| Extrato de passes | Membro | Saldo e nível | `passes_ledger` | — | 5 anos (fiscal) | Mesmo que pedidos | Obrigação legal |
| Produtos da vitrine (título, descrição, link) | Membro | Divulgação | `produtos_comunidade` | Público, quando aprovado | Até o Membro remover | Apagado com a conta | Execução de contrato |
| IP e user-agent de login | Conta | Segurança e Marco Civil (6 meses) | Logs do Supabase Auth | — | **A definir:** o Marco Civil exige 6 meses e o log do Supabase não garante isso sozinho | — | Obrigação legal |
| CPF, telefone, endereço | Comprador | Cobrança | **Só no San Checkout / Asaas**; este projeto não guarda | Asaas | Conforme o Checkout | — | Execução de contrato |

## Subprocessadores

| Quem | Para quê | Região | Transferência internacional? |
|---|---|---|---|
| Supabase (AWS) | Banco, Auth, Storage, funções | São Paulo (`sa-east-1`) | Não |
| Cloudflare | Hospedagem do site, DNS, Access | Global | Sim: logs de acesso |
| San Checkout / Asaas | Pagamento | Brasil | Não |
| Anthropic (API da Claude) | Rotinas do Cláudio (Etapa 4) | EUA | **Sim**, quando o agente processa a mensagem ou a conta do membro. Precisa constar na Política |
