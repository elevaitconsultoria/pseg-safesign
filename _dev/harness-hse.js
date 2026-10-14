/**
 * Harness do HSE no navegador, SEM login e SEM rede (o harness nunca pode criar sessão autenticada).
 *
 *   node _dev/simular-hse.js --fixture _dev/fixture-hse-sim.json --seed 2026 \
 *        --setores "Produção:36:critico-demandas,Administrativo:18:bom-gestor,Logística:12:conflito"
 *   node _dev/harness-hse.js <saida.html>          # cópia do admin com a fixture e um sbAdmin falso embutidos
 *
 * Abra <saida.html> no navegador (file://) e, no console:
 *   await __hse.instalar()                 // troca sbAdmin/estado global pelo falso e cria a empresa/ciclo da simulação
 *   await __hse.resultados('segregado')    // tela Resultados HSE (consolidado | segregado | ...)
 *   await __hse.laudo('segregado')         // preview do laudo HSE (iframe) com a checagem pré-geração
 *   await __hse.plano()                    // Plano de Ação HSE
 *   __hse.laudoHTML('segregado')           // HTML do laudo (o MESMO do PDF), para inspecionar
 *
 * O sbAdmin falso responde só às tabelas que o HSE lê. Severidade: valores de TESTE, não validados (o laudo sai
 * marcado "CRITÉRIO NÃO VALIDADO", como em DEV). Nada aqui toca banco nenhum.
 */
'use strict';
const fs = require('fs'), path = require('path');
const saida = process.argv[2];
if (!saida) { console.error('uso: node _dev/harness-hse.js <saida.html>'); process.exit(1); }
const raiz = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(raiz, 'psicomap-admin.html'), 'utf8');
const fx = fs.readFileSync(path.join(__dirname, 'fixture-hse-sim.json'), 'utf8');

const fake = function () {
  const FX = window.__HSE_FIXTURE;
  const EMP = 'aaaa0000-0000-4000-8000-0000000000a1', CIC = 'aaaa0000-0000-4000-8000-0000000000c1', Q = '00000000-0000-0000-0000-000000000003';
  const BENCH = { DEMANDS: 3.25, CONTROL: 3.72, MANAGER_SUPPORT: 3.80, PEER_SUPPORT: 4.01, RELATIONSHIPS: 4.11, ROLE: 4.16, CHANGE: 3.30 };
  const SEV = { DEMANDS: 3, CONTROL: 2, MANAGER_SUPPORT: 2, PEER_SUPPORT: 2, RELATIONSHIPS: 3, ROLE: 2, CHANGE: 2 };   // TESTE
  const HC = [{ setor: 'Produção', funcao: 'Operador', quantidade: 45 }, { setor: 'Produção', funcao: 'Supervisor', quantidade: 15 },
              { setor: 'Administrativo', funcao: 'Analista', quantidade: 30 }, { setor: 'Logística', funcao: 'Auxiliar', quantidade: 30 }];
  const tabelas = {
    questionarios: () => [{ id: Q, config: { rascunho: true } }],
    hse_itens: () => FX.meta,
    hse_benchmark: () => Object.entries(BENCH).map(([dimensao, media]) => ({ dimensao, media, setor: 'GERAL', vigente: true })),
    hse_riscos_config: () => Object.entries(SEV).map(([dimensao, severidade]) => ({ dimensao, severidade, danos: 'Transtorno mental (teste)', versao: 1, validado: false })),
    links_coleta: () => [],
    respostas: () => FX.linhas.map(r => ({ id: r.id, setor: r.setor, funcao: r.funcao, escolaridade: r.escolaridade, ciclo_id: CIC, link_token: 'simhse000001',
      questionario_id: r.questionario_id, respondido_em: r.respondido_em, metodologia: 'HSE_ICAO35',
      resposta_itens_hse: Object.entries(r.h).map(([item_id, valor]) => ({ item_id, valor })) })),
    empresa_headcount: () => HC,
  };
  function q(t) {
    let rng = null;
    const b = { _t: t };
    ['select', 'eq', 'in', 'not', 'order', 'limit', 'is', 'gte', 'lte', 'neq', 'or', 'ilike', 'filter', 'match', 'upsert', 'insert', 'update', 'delete'].forEach(m => { b[m] = () => b; });
    b.range = (a, z) => { rng = [a, z]; return b; };
    b.single = b.maybeSingle = () => b;
    b.then = (res, rej) => { let data = (tabelas[t] || (() => []))(); if (rng) data = data.slice(rng[0], rng[1] + 1); return Promise.resolve({ data, error: null }).then(res, rej); };
    return b;
  }
  window.__hse = {
    async instalar() {
      sbAdmin = { from: q, rpc: async () => ({ data: null, error: null }), auth: { getSession: async () => ({ data: { session: null } }) } };
      currentUser = { id: 'harness', role: 'admin', tenant_id: 't' };
      try { perfilAtual = { role: 'admin' }; } catch (e) {}
      _hseDisponivel = true;
      _estPerfil = { nome_empresa: 'Consultoria Harness', responsavel_padrao: 'Responsável de Teste' };
      _empresas = [{ id: EMP, nome: 'SIMULAÇÃO HSE (fictícia)', setores: ['Administrativo', 'Logística', 'Produção'], hierarquia: [] }];
      _ciclos = [{ id: CIC, empresa_id: EMP, nome: 'Avaliação HSE — Simulação', metodologia: 'HSE_ICAO35', ano_referencia: 2026, mes_referencia: 10 },
                 { id: 'bs-1', empresa_id: EMP, nome: 'Avaliação — Setembro 2026', metodologia: 'BS8800', ano_referencia: 2026, mes_referencia: 9 }];
      // Combos vazios = sem filtro. O boot sem banco cai no modo demo e deixa setores/funções FICTÍCIOS marcados.
      Object.keys(comboState).forEach(k => { if (/setor|funcao|escolaridade|ghe|nivel/.test(k)) comboState[k] = new Set(); });
      _links = []; gruposSetor = []; gruposFuncao = []; gruposGhe = []; _hcCache = {}; _hseMetaCache = {}; _hseBenchCache = null;
      ['f-empresa', 'ld-empresa', 'plano-empresa'].forEach(id => { const s = document.getElementById(id); if (s) s.innerHTML = `<option value="${EMP}">SIMULAÇÃO HSE (fictícia)</option>`; });
      ['f-ciclo', 'ld-ciclo', 'plano-ciclo', 'gf-ciclo', 'audit-ciclo'].forEach(id => preencherSelectCiclos(id, EMP));
      ['f-ciclo', 'ld-ciclo', 'plano-ciclo'].forEach(id => { const s = document.getElementById(id); if (s) s.value = CIC; });
      document.querySelectorAll('.screen').forEach(s => s.classList.remove('on'));
      // Sem sessão o app fica na tela de login: mostra o shell direto (só visual; nenhuma autenticação acontece).
      const lo = document.getElementById('login-overlay'); if (lo) lo.style.display = 'none';
      const sh = document.getElementById('app-shell'); if (sh) sh.style.display = '';
      return 'ok';
    },
    tela(id) { document.querySelectorAll('.screen').forEach(s => s.classList.remove('on')); document.getElementById(id).classList.add('on'); },
    async resultados(seg = 'consolidado') {
      this.tela('sc-analise'); window._segMode = seg; const s = document.getElementById('f-segmentacao'); if (s) s.value = seg;
      await rodarAnalise(); return document.getElementById('resultado-panel').innerText.slice(0, 400);
    },
    _gran(g) { const el = document.getElementById('laudo-granularidade'); if (el) { [...el.options].forEach(o => { o.hidden = false; }); el.value = g; } },
    async laudo(gran = 'segregado') {
      this.tela('sc-laudo'); this._gran(gran);
      const r = document.getElementById('ld-responsavel'); if (r) r.value = 'Responsável de Teste';
      const reg = document.getElementById('ld-registro'); if (reg) reg.value = 'CRP 00/00000';
      await renderLaudo(); return document.getElementById('laudo-preview-panel').innerText.slice(0, 600);
    },
    async laudoHTML(gran = 'segregado') { this._gran(gran); const c = await _laudoHSEContexto(); return { pf: _laudoHSEPreflight(c), html: _buildLaudoHSEHTML(c, { preview: true }) }; },
    async plano() { this.tela('sc-plano'); const s = document.getElementById('plano-ciclo'); if (s) s.value = CIC; await renderPlanoAcao(); return document.getElementById('plano-panel').innerText.slice(0, 400); },
  };
};

const inj = `<script>window.__HSE_FIXTURE = ${fx};\n(${fake.toString()})();</script>`;
const i = html.lastIndexOf('</body>');
if (i < 0) { console.error('</body> não encontrado'); process.exit(1); }
fs.writeFileSync(saida, html.slice(0, i) + inj + html.slice(i));
console.log('harness →', saida);
