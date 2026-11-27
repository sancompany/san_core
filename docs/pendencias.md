# Pendências

## Achados da auditoria de 27/11/2026

- `www.sancocore.com.br` responde **522**. A origem do subdomínio `www` não
  está configurada no Cloudflare.
- `/admin/` está público e sem Cloudflare Access. O login ainda não faz
  nada, mas precisa do Access antes de virar login real.
- `js/contato.js` descarta a mensagem e mostra "enviado". Corrigir: enviar
  de verdade ou não fingir que enviou.
- Não há CI nem `.env.example` (nascem na Etapa 1, com as primeiras variáveis).
- Não há Termos de Uso nem Política de Privacidade.

## Só o dono faz

- Validar a spec (`docs/specs/2026-11-27-plataforma-cotas.md` §7): faixas,
  pacotes, transferência, vitrine e revisão jurídica.
- Autorizar a criação do projeto Supabase `san_core` (custo).
- Fornecer a chave da API da Claude para o agente rodar sozinho.
- Cadastrar este projeto como contratante no painel do San Checkout
  (manual, API.md §2) quando a Etapa 2 abrir.
- Configurar a origem do `www` e o Access do `/admin` no Cloudflare.
