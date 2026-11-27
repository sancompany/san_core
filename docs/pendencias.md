# Pendências

## Etapa 1 — Banco (aberta)

- [x] Migration `supabase/migrations/20261127000100_base.sql`
- [x] Testes de saldo, nível e RLS passando (`tests/db/run.sh`, Postgres 16)
- [ ] Projeto Supabase `san_core` criado. **Bloqueado: só o dono resolve** (abaixo)
- [ ] Migration aplicada no projeto, e advisors de segurança e performance limpos
- [ ] CI verde em Postgres 17 (precisa do workflow colado pelo dono)
- [ ] `docs/funcional.md`, antes de construir as telas (Etapas 2 e 3)

## Achados da auditoria de 27/11/2026

- `www.sancocore.com.br` responde **522**: a origem do `www` não está
  configurada no Cloudflare.
- `/admin/` está público, sem Cloudflare Access. É obrigatório antes de o
  login virar real.
- `js/contato.js` descarta a mensagem e mostra "enviado".
- Endereço inexistente responde 200 com a home: falta uma página 404.
- Não há Termos de Uso nem Política de Privacidade.
- O log de IP de login por 6 meses (Marco Civil) não está garantido
  (`docs/inventario-de-dados.md`).

## Só o dono faz

1. **Projeto Supabase.** A organização "San & Co" está no plano Free, que
   permite 2 projetos ativos, e os 2 já existem (MostrAi e San_Checkout).
   Escolha uma saída:
   - assinar o Pro em supabase.com/dashboard/org/fphbzkrzgijqzpqzvshh/billing;
   - ou pausar um dos dois projetos.

   Depois, crie o `san_core` em `sa-east-1` ou me autorize a criar. Nesta
   sessão, a criação foi bloqueada pela política de permissões.
2. **CI.** Copie `infra/ci/ci.yml` para `.github/workflows/ci.yml` (pelo
   site do GitHub: Add file → Create new file).
3. **Cloudflare.** Configure a origem do `www` e coloque `/admin/*` atrás
   do Access.
4. **Etapa 2.** Cadastre este projeto como contratante no painel do San
   Checkout (API.md §2).
5. **Etapa 4.** Forneça a chave da API da Claude.
