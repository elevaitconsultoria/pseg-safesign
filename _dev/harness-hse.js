/**
 * Harness do HSE no navegador, SEM login e SEM rede (o harness nunca pode criar sessão autenticada).
 *
 *   node _dev/simular-hse.js --fixture _dev/fixture-hse-sim.json --seed 2026 \
 *        --setores "Produção:36:critico-demandas,Administrativo:18:bom-gestor,Logística:12:conflito"      # ciclo atual
 *   node _dev/simular-hse.js --fixture _dev/fixture-hse-sim-c0.json --seed 7 \
 *        --setores "Produção:30:mediana,Administrativo:15:mediana,Logística:10:mediana"                    # ciclo anterior
 *   node _dev/harness-hse.js <saida.html>   # cópia do admin com as fixtures e um sbAdmin falso embutidos
 *
 * Sirva a pasta por HTTP (o Browser pane recusa file://) e, no console:
 *   await __hse.instalar()                 // troca sbAdmin/estado global pelo falso; empresa com 2 ciclos HSE + 1 BS
 *   await __hse.resultados('segregado')    // tela Resultados HSE (consolidado | segregado | ...)
 *   await __hse.laudo('segregado')         // preview do laudo HSE (iframe) com a checagem pré-geração
 *   await __hse.plano()                    // Plano de Ação HSE
 *   await __hse.distribuicao()             // Distribuição (tela Gráficos) HSE
 *   await __hse.comparativo()              // Comparativo entre os 2 ciclos HSE
 *   __hse.comQA(); await __hse.auditoria('real'|'teste')   // Auditoria: acrescenta uniformes/sem LGPD/sessão repetida e 4 respostas de teste
 *   await __hse.laudoHTML('segregado')     // { pf, html } — o MESMO HTML do PDF
 *   __hse.semLogistica(3)                  // deixa só 3 respostas de Logística (testa n mínimo e supressão complementar)
 *
 * Impressão real (PDF) sem interação: abra <saida.html>?auto=laudo&gran=segregado — a página se instala sozinha e
 * vira o próprio laudo; com Edge/Chrome headless:  msedge --headless --print-to-pdf=saida.pdf "<url>?auto=laudo"
 *
 * O sbAdmin falso responde só às tabelas que o HSE lê e honra os filtros eq() de ciclo. Severidade: valores de
 * TESTE, não validados (o laudo sai "CRITÉRIO NÃO VALIDADO", como em DEV). Nada aqui toca banco nenhum.
 */
'use strict';
const fs = require('fs'), path = require('path');
const saida = process.argv[2];
if (!saida) { console.error('uso: node _dev/harness-hse.js <saida.html>'); process.exit(1); }
const raiz = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(raiz, 'psicomap-admin.html'), 'utf8');
const ler = f => { const p = path.join(__dirname, f); return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : 'null'; };
const fx = ler('fixture-hse-sim.json'), fx0 = ler('fixture-hse-sim-c0.json');
if (fx === 'null') { console.error('Falta _dev/fixture-hse-sim.json (gere com simular-hse.js --fixture).'); process.exit(1); }

// Benchmark setorial: lido do seed versionado (o mesmo aplicado em DEV), para o seletor de referência ter dados reais.
const seedB = fs.readFileSync(path.join(raiz, 'seed_hse_benchmark_2023_setores.sql'), 'utf8');
const benchSetores = [...seedB.matchAll(/\('HSE_2023', 2023, '([A-Z_]+)', '([A-Z_]+)', ([0-9.]+), (\d+), true/g)]
  .map(m => ({ setor: m[1], dimensao: m[2], media: Number(m[3]), n_amostra: Number(m[4]) }));

const fake = function () {
  const FX = window.__HSE_FIXTURE, FX0 = window.__HSE_FIXTURE_C0;
  const EMP = 'aaaa0000-0000-4000-8000-0000000000a1', CIC = 'aaaa0000-0000-4000-8000-0000000000c1', CIC0 = 'aaaa0000-0000-4000-8000-0000000000c0';
  const Q = '00000000-0000-0000-0000-000000000003';
  const BENCH = { DEMANDS: 3.25, CONTROL: 3.72, MANAGER_SUPPORT: 3.80, PEER_SUPPORT: 4.01, RELATIONSHIPS: 4.11, ROLE: 4.16, CHANGE: 3.30 };
  const SEV = { DEMANDS: 3, CONTROL: 2, MANAGER_SUPPORT: 2, PEER_SUPPORT: 2, RELATIONSHIPS: 3, ROLE: 2, CHANGE: 2 };   // TESTE
  const HC = [{ setor: 'Produção', funcao: 'Operador', quantidade: 45 }, { setor: 'Produção', funcao: 'Supervisor', quantidade: 15 },
              { setor: 'Administrativo', funcao: 'Analista', quantidade: 30 }, { setor: 'Logística', funcao: 'Auxiliar', quantidade: 30 }];
  const respostasDe = (fxx, ciclo) => (fxx ? fxx.linhas : []).map((r, i) => ({ id: ciclo.slice(-2) + '-' + r.id, setor: r.setor, funcao: r.funcao, escolaridade: r.escolaridade,
    ciclo_id: ciclo, link_token: 'simhse000001', questionario_id: r.questionario_id, respondido_em: r.respondido_em, metodologia: 'HSE_ICAO35',
    session_id: (Math.imul(i + 1, 2654435761) >>> 0).toString(16).padStart(8, '0') + '-' + ciclo.slice(-2).padStart(4, '0') + '-4000-8000-000000000000', device_info: i % 2 ? 'Android 14 | Chrome 126' : 'iOS 17 | Safari 17',
    lgpd_aceito: i % 17 !== 0, lgpd_aceito_em: r.respondido_em,
    resposta_itens_hse: Object.entries(r.h).map(([item_id, valor]) => ({ item_id, valor })) }));
  // Linhas para a Auditoria (só entram com __hse.comQA()): uniformes, quase uniforme, sem LGPD, sessão repetida e 4 de TESTE.
  const linhaQA = (id, setor, valorDe, extra = {}) => ({ id, setor, funcao: setor === 'Logística' ? 'Auxiliar' : 'Operador', escolaridade: 'Ensino Médio', ciclo_id: CIC,
    link_token: 'simhse000001', questionario_id: Q, respondido_em: '2026-10-12T15:00:00Z', metodologia: 'HSE_ICAO35', session_id: (Math.imul(id.charCodeAt(0) * 31 + id.charCodeAt(1), 2246822519) >>> 0).toString(16).padStart(8, '0') + '-0000-4000-8000-' + id.padStart(12, '0'),
    device_info: 'Windows 11 | Edge 126', lgpd_aceito: true, lgpd_aceito_em: '2026-10-12T15:00:00Z',
    resposta_itens_hse: FX.meta.map((m, k) => ({ item_id: m.id, valor: valorDe(m, k) })), ...extra });
  const QA = () => [
    linhaQA('u1', 'Produção', () => 3), linhaQA('u2', 'Produção', () => 5),                                              // uniformes
    linhaQA('q1', 'Produção', (m, k) => (k < 32 ? 4 : 2)),                                                              // quase uniforme (32/35)
    linhaQA('n1', 'Produção', (m, k) => 1 + (k % 5), { lgpd_aceito: false, lgpd_aceito_em: null }),                      // sem LGPD
    linhaQA('d1', 'Administrativo', (m, k) => 1 + (k % 4), { session_id: 'd0d0d0d0-0000-4000-8000-000000000001' }),      // sessão repetida (par)
    linhaQA('d2', 'Administrativo', (m, k) => 2 + (k % 3), { session_id: 'd0d0d0d0-0000-4000-8000-000000000001' }),
    linhaQA('t1', 'Produção', (m, k) => 1 + (k % 5), { link_token: 'simteste0001' }), linhaQA('t2', 'Produção', () => 4, { link_token: 'simteste0001' }),
    linhaQA('t3', 'Logística', (m, k) => 1 + (k % 3), { link_token: 'simteste0001' }), linhaQA('t4', 'Logística', (m, k) => 2 + (k % 4), { link_token: 'simteste0001' }),
  ];
  let RESP = [...respostasDe(FX, CIC), ...respostasDe(FX0, CIC0)];
  const respostasQA = () => QA();
  const tabelas = {
    questionarios: () => [{ id: Q, versao: 2, config: { rascunho: true } }],
    hse_itens: () => FX.meta,
    hse_benchmark: () => [...Object.entries(BENCH).map(([dimensao, media]) => ({ dimensao, media, setor: 'GERAL', n_amostra: 39484, vigente: true })), ...window.__HSE_BENCH_SETORES],
    hse_riscos_config: () => Object.entries(SEV).map(([dimensao, severidade]) => ({ dimensao, severidade, danos: 'Transtorno mental (teste)', versao: 1, validado: false })),
    links_coleta: () => [{ token: 'simteste0001', is_teste: true }],
    respostas: f => RESP.filter(r => (!f.ciclo_id || r.ciclo_id === f.ciclo_id) && (!f.__in || f.__in.includes(r.link_token)) && (!f.__not || !f.__not.includes(r.link_token))),
    empresa_headcount: () => HC,
  };
  function q(t) {
    let rng = null; const f = {};
    const b = { _t: t };
    ['select', 'order', 'limit', 'is', 'gte', 'lte', 'neq', 'or', 'ilike', 'filter', 'match', 'upsert', 'insert', 'update', 'delete'].forEach(m => { b[m] = () => b; });
    b.eq = (col, val) => { f[col] = val; return b; };
    b.in = (col, arr) => { if (col === 'link_token') f.__in = arr; return b; };
    b.not = (col, op, v) => { if (col === 'link_token') f.__not = String(v).replace(/[()]/g, '').split(','); return b; };
    b.range = (a, z) => { rng = [a, z]; return b; };
    b.single = b.maybeSingle = () => b;
    b.then = (res, rej) => { let data = (tabelas[t] || (() => []))(f); if (rng) data = data.slice(rng[0], rng[1] + 1); return Promise.resolve({ data, error: null }).then(res, rej); };
    return b;
  }
  window.__hse = {
    async instalar() {
      sbAdmin = { from: q, rpc: async () => ({ data: null, error: null }), auth: { getSession: async () => ({ data: { session: null } }) } };
      currentUser = { id: 'harness', role: 'admin', tenant_id: 't' };
      _hseDisponivel = true;
      _estPerfil = { nome_empresa: 'Consultoria Harness', responsavel_padrao: 'Responsável de Teste' };
      _empresas = [{ id: EMP, nome: 'SIMULAÇÃO HSE (fictícia)', setores: ['Administrativo', 'Logística', 'Produção'], hierarquia: [] }];
      _ciclos = [{ id: CIC0, empresa_id: EMP, nome: 'Avaliação HSE — Março 2026', metodologia: 'HSE_ICAO35', ano_referencia: 2026, mes_referencia: 3 },
                 { id: CIC, empresa_id: EMP, nome: 'Avaliação HSE — Simulação', metodologia: 'HSE_ICAO35', ano_referencia: 2026, mes_referencia: 10 },
                 { id: 'bs-1', empresa_id: EMP, nome: 'Avaliação — Setembro 2026', metodologia: 'BS8800', ano_referencia: 2026, mes_referencia: 9 }];
      // Combos vazios = sem filtro. O boot sem banco cai no modo demo e deixa setores/funções FICTÍCIOS marcados.
      Object.keys(comboState).forEach(k => { if (/setor|funcao|escolaridade|ghe|nivel/.test(k)) comboState[k] = new Set(); });
      _links = []; gruposSetor = []; gruposFuncao = []; gruposGhe = []; _hcCache = {}; _hseMetaCache = {}; _hseBenchCache = null; _hseRefPorEmpresa = {};
      ['f-empresa', 'ld-empresa', 'plano-empresa', 'gf-empresa', 'cmp-empresa'].forEach(id => { const s = document.getElementById(id); if (s) s.innerHTML = `<option value="${EMP}">SIMULAÇÃO HSE (fictícia)</option>`; });
      ['f-ciclo', 'ld-ciclo', 'plano-ciclo', 'gf-ciclo', 'audit-ciclo'].forEach(id => preencherSelectCiclos(id, EMP));
      ['f-ciclo', 'ld-ciclo', 'plano-ciclo', 'gf-ciclo'].forEach(id => { const s = document.getElementById(id); if (s) s.value = CIC; });
      document.querySelectorAll('.screen').forEach(s => s.classList.remove('on'));
      // Sem sessão o app fica na tela de login: mostra o shell direto (só visual; nenhuma autenticação acontece).
      const lo = document.getElementById('login-overlay'); if (lo) lo.style.display = 'none';
      const sh = document.getElementById('app-shell'); if (sh) sh.style.display = '';
      return 'ok';
    },
    comQA() { RESP = [...RESP, ...respostasQA()]; _hseMetaCache = {}; return RESP.length; },
    reduzir(n = 3) { let i = 0; RESP = RESP.filter(r => r.ciclo_id !== CIC || r.link_token !== 'simhse000001' || (i++ < n)); _hseMetaCache = {}; return RESP.filter(r => r.ciclo_id === CIC).length; },
    semLogistica(k = 3) { let i = 0; RESP = RESP.filter(r => r.setor !== 'Logística' || r.ciclo_id !== CIC || (i++ < k)); _hseMetaCache = {}; return RESP.filter(r => r.ciclo_id === CIC).length; },
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
    async laudoHTML(gran = 'segregado') {
      this._gran(gran);
      const r = document.getElementById('ld-responsavel'); if (r && !r.value) r.value = 'Responsável de Teste';
      const reg = document.getElementById('ld-registro'); if (reg && !reg.value) reg.value = 'CRP 00/00000';
      const c = await _laudoHSEContexto(); return { pf: _laudoHSEPreflight(c), html: _buildLaudoHSEHTML(c, { preview: true }) };
    },
    async plano() { this.tela('sc-plano'); const s = document.getElementById('plano-ciclo'); if (s) s.value = CIC; await renderPlanoAcao(); return document.getElementById('plano-panel').innerText.slice(0, 400); },
    async auditoria(modo = 'real') {
      this.tela('sc-auditoria'); ['audit-empresa'].forEach(id => { const s = document.getElementById(id); if (s) s.innerHTML = `<option value="${EMP}">SIMULAÇÃO HSE (fictícia)</option>`; });
      preencherSelectCiclos('audit-ciclo', EMP); const c = document.getElementById('audit-ciclo'); if (c) c.value = CIC;
      const m = document.getElementById('audit-hse-modo'); if (m) m.value = modo;
      await renderTelaAuditoria(); return document.getElementById('audit-table-panel').innerText.slice(0, 700);
    },
    async distribuicao() { this.tela('sc-graficos'); const s = document.getElementById('gf-ciclo'); if (s) s.value = CIC; await renderGraficos(); return document.getElementById('graficos-panel').innerText.slice(0, 400); },
    async comparativo(setor = '') {
      this.tela('sc-comparativo'); _cmpMetEmp = null;
      await renderComparativo(); const s = document.getElementById('cmp-setor'); if (setor && s) { s.value = setor; await renderComparativo(); }
      return document.getElementById('comparativo-panel').innerText.slice(0, 600);
    },
  };
  // Modo automático (impressão headless): ?auto=laudo&gran=segregado[&semlog=3]
  const qs = new URLSearchParams(location.search);
  if (qs.get('auto') === 'laudo') {
    const go = async () => {
      await window.__hse.instalar();
      if (qs.get('semlog')) window.__hse.semLogistica(Number(qs.get('semlog')));
      const { html } = await window.__hse.laudoHTML(qs.get('gran') || 'segregado');
      document.open(); document.write(html); document.close();
    };
    window.addEventListener('load', () => setTimeout(() => go().catch(e => { document.body.innerHTML = '<pre>' + (e && e.stack || e) + '</pre>'; }), 300));
  }
};

const inj = `<script>window.__HSE_FIXTURE = ${fx};\nwindow.__HSE_FIXTURE_C0 = ${fx0};\nwindow.__HSE_BENCH_SETORES = ${JSON.stringify(benchSetores.map(b => ({ ...b, vigente: true })))};\n(${fake.toString()})();</script>`;
const i = html.lastIndexOf('</body>');
if (i < 0) { console.error('</body> não encontrado'); process.exit(1); }
fs.writeFileSync(saida, html.slice(0, i) + inj + html.slice(i));
console.log(`harness → ${saida} (${benchSetores.length / 7} setores de referência)`);
