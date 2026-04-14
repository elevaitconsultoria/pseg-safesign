# PSEG SafeSign

Sistema de avaliação de riscos psicossociais ocupacionais (NR-17 / NR-01).

## Arquivos

| Arquivo | Rota no Vercel | Descrição |
|---------|---------------|-----------|
| `pseg-admin-questionario.html` | `/admin` | Painel administrativo (requer login) |
| `pseg-forms.html` | `/form` | Formulário público via token |

## Deploy no Vercel

1. Faça push deste repositório para o GitHub
2. Acesse [vercel.com](https://vercel.com) → **Add New Project**
3. Importe o repositório do GitHub
4. Clique **Deploy** (sem alterar nada — detecta HTML estático automaticamente)
5. Após deploy, configure **Allowed Origins** no Supabase:
   - Supabase → Project Settings → API → **Allowed Origins**
   - Adicione a URL do Vercel: `https://seu-projeto.vercel.app`

## Configuração Supabase

1. Execute `pseg-schema-v3.sql` no SQL Editor do Supabase
2. Execute `pseg-admin-rls-policies.sql` no SQL Editor do Supabase
3. Vá em **Authentication → Settings**:
   - Desative **Enable email confirmations**
   - Adicione a URL do Vercel em **Site URL** e **Redirect URLs**
4. Crie usuários admin em **Authentication → Users**
