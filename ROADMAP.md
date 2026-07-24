# PsicoMap — Roadmap Interno

> Funcionalidades planejadas para versões futuras. Documento interno — não exibido no sistema.

---

## 🔬 Especificado (próxima versão)

### Ajuste de Probabilidade pelo Consultor
**Prioridade: Média**

Permitir que o consultor/admin sobrescreva a probabilidade calculada (P) de um fator de risco específico, registrando a justificativa técnica — sem perder rastreabilidade do valor original.

- Botão **✎** discreto ao lado do badge P, visível apenas para admin/consultor
- Painel inline (não modal): P calculado (readonly) + seletor P ajustado (1–4) + campo de justificativa obrigatório
- Badge muda para `P3*` com tooltip mostrando ajuste, autor e data
- Tabela `ajuste_probabilidade` (empresa_id, ciclo_id, cd_risco, p_calculado, p_ajustado, justificativa, ajustado_por, created_at)
- Laudo exibe ambos os valores (calculado e ajustado) com nota de rodapé
- Reset para P calculado com um clique

> Caso de uso principal: amostras pequenas (n < 5), ciclos atípicos (férias coletivas, greve) ou fatores contextuais que o algoritmo não captura.

---

## 📋 Planejado (versão futura)

### Portal do Cliente (Dashboard de Resultados)
**Prioridade: Baixa**

Área dedicada onde cada empresa cliente pode visualizar seus próprios resultados — sem precisar da intermediação da consultoria para cada análise.

- Login separado (role `cliente_viewer`) por empresa
- Dashboard resumido: score médio, top riscos, evolução temporal
- Gráficos de distribuição por setor e função (somente leitura)
- Download de relatório PDF sem marca da consultoria
- Comparativo entre ciclos (quando houver ≥ 2 ciclos de coleta)

> Exportação pelo consultor continua sendo a forma primária até implementação desta feature.

---

### Personalização do Questionário por Empresa
**Prioridade: Baixa**

Permitir que o consultor desative ou adicione questões específicas por empresa, mantendo o núcleo NR-17 obrigatório.

- Tabela `empresa_questoes_config` com overrides por empresa
- Questões NR-17 obrigatórias não podem ser desativadas
- Questões complementares podem ser acrescentadas pelo consultor
- Formulário de coleta carrega configuração via token do link

---

### Notificações & Alertas Automáticos
**Prioridade: Baixa**

- E-mail automático ao consultor quando nova resposta é recebida
- Alerta quando link está próximo de expirar (≤ 48 horas)
- Resumo semanal de novas respostas por empresa
- Webhook configurável para integração com sistemas externos

---

### Plano de Ação (5W2H)
**Prioridade: Baixa**

- Geração automática de plano 5W2H a partir dos riscos identificados
- Atribuição de responsável, prazo e status por ação
- Acompanhamento de progresso (% concluído por empresa)
- Inclusão no relatório PDF como seção de "Plano de Intervenção"

---

### Landing Page / Página de Vendas
**Prioridade: Média · Site separado**

Site separado voltado para conversão — apresenta o PsicoMap para potenciais clientes sem misturar com o app operacional.

- Domínio próprio (ex: `psicomap.com.br`) separado do app
- Seções: hero + proposta de valor, como funciona, planos, contato
- SEO-ready: meta tags, OG, Schema.org, carregamento sem Supabase
- CTA para trial/contato; onboarding leva ao app (app.psicomap.com.br)
- Sem autenticação — página pública, otimizada para conversão

> Modelo atual (B2B consultivo) pede landing separada — visitante frio não deve cair no app diretamente.

---

## ✅ Implementado

| Feature | Versão |
|---------|--------|
| Questionário NR-17 com coleta por link | v1.0 |
| Matriz P×S e análise de riscos | v1.0 |
| Laudo PDF com gráficos | v1.0 |
| Gestão de empresas e usuários | v1.0 |
| Multitenancy com RLS | v1.3 |
| Planos e billing (Stripe + Asaas) | v1.3 |
| Portal de upgrade com trial banner | v1.3 |
| Autenticação obrigatória (sem bypass) | v1.3 |
