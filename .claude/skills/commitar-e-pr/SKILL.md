---
name: commitar-e-pr
description: >
  Commita as alterações do branch develop e abre PR documentada para main no repositório
  pseg-safesign. Use sempre que houver mudanças prontas para subir: o skill cuida de
  git add, commit com mensagem convencional, push, e gh pr create com título e body
  estruturado em português. O usuário só precisa aprovar e fazer o merge.
---

# Commitar e abrir PR — PSEG SafeSign

Execute cada etapa em sequência. Não pule etapas.

## 1. Verificar estado do repositório

```bash
git status
git diff --stat
```

Analisar:
- Quais arquivos foram modificados
- Se há arquivos não rastreados que devem entrar no commit (ex: novos skills, migrations)
- Se há arquivos que NÃO devem entrar (ex: `.env`, arquivos de debug temporários)

> **Atenção:** Nunca adicionar `supabase/.temp/`, arquivos `.env` ou credenciais.
> Verificar o conteúdo de qualquer arquivo suspeito antes de adicionar.

## 2. Montar a mensagem de commit

Usar **Conventional Commits** em português:

| Prefixo | Quando usar |
|---------|-------------|
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de bug |
| `docs:` | Apenas documentação |
| `chore:` | Manutenção, configurações, sem impacto funcional |
| `refactor:` | Refatoração sem mudança de comportamento |

Formato:
```
<prefixo>: <resumo em português, imperativo, máx 72 chars>

<corpo opcional — explica O QUÊ e POR QUÊ, não o como>
```

## 3. Adicionar arquivos e commitar

Adicionar apenas os arquivos relevantes (nunca `git add .` sem revisar):

```bash
git add <arquivo1> <arquivo2> ...
git commit -m "$(cat <<'EOF'
<mensagem completa aqui>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

## 4. Push para develop

```bash
git push origin develop
```

## 5. Abrir PR para main

```bash
gh pr create --base main --head develop \
  --title "<mesmo título do commit>" \
  --body "$(cat <<'EOF'
## Problema / Motivação

<O que estava errado ou qual necessidade motivou a mudança. 2–4 linhas.>

## O que foi feito

<Lista das mudanças aplicadas. Seja específico: arquivo, função, comportamento antes/depois.>

- `arquivo.html` — descrição da mudança
- `outro-arquivo.js` — descrição da mudança

## O que NÃO muda

<Listar explicitamente o que ficou de fora do escopo, especialmente se pode gerar dúvida.>

- Dados já no banco não são reprocessados
- Nenhuma mudança de schema
- etc.

## Plano de teste

- [ ] Passo de teste 1
- [ ] Passo de teste 2
- [ ] Rodar `/validar-importacao-ghe` se envolver GHE
- [ ] Rodar `/validar-formulario` se envolver pipeline de respostas

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Regras do projeto

- Branch base sempre é `main` (protegida — PRs obrigatórias, nunca push direto)
- Branch de trabalho é sempre `develop`
- `gh` CLI autenticado com conta `elevaitconsultoria` via token no keyring
- Se `gh pr create` retornar "No commits between main and develop", a PR já foi mergeada — verificar com `gh pr list --base main --state all`
- Se retornar "Resource not accessible", o token expirou — pedir ao usuário para renovar em github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens → `claude-git-token`

## Resultado esperado

Ao final o usuário recebe:
1. Link da PR criada no GitHub
2. Título e descrição prontos
3. Checklist de testes para executar antes do merge
