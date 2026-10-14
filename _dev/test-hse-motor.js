/**
 * Teste do MOTOR de cálculo HSE (ICAO-35) — sem rede, sem banco, sem .env.
 *
 *   node _dev/test-hse-motor.js                  # roda os casos fixos
 *   node _dev/test-hse-motor.js --linhas f.json  # também calcula sobre linhas reais exportadas do banco
 *
 * Extrai do psicomap-admin.html o bloco "HSE (S7)" (o motor que a tela e o laudo usam de fato) e confere contra um
 * oráculo INDEPENDENTE escrito aqui: o mapeamento item → dimensão do HSE original, a inversão por dimensão e o
 * exemplo do relatório F2 do outro player (todas as contas conferidas à mão em
 * .claude/notes/2026-10-08-referencia-hse-player-avalia-nr01.md §3 e §5.5).
 *
 * --linhas: JSON [{questionario_id, h:{item_id: valor}}] + meta [{id,codigo,dimensao,inversa,ordem,questionario_id}]
 * no formato {linhas:[…], meta:[…], esperado:{DIMENSAO: media}} — gerado por SQL independente no banco de DEV.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const html = fs.readFileSync(path.join(__dirname, '..', 'psicomap-admin.html'), 'utf8');
const ini = html.indexOf('// ==== HSE (S7) BEGIN');
const fim = html.indexOf('// ==== HSE (S7) END ====');
if (ini < 0 || fim < 0) { console.error('Bloco HSE (S7) não encontrado no admin.'); process.exit(2); }
const bloco = html.slice(ini, fim);

// Dependências do bloco que vivem fora dele (valores reais copiados do admin; conferidos abaixo contra o HTML).
const MATRIZ_RISCO = {
  '1_1':'IRRELEVANTE','1_2':'BAIXO','1_3':'BAIXO','1_4':'MÉDIO',
  '2_1':'BAIXO','2_2':'BAIXO','2_3':'MÉDIO','2_4':'ALTO',
  '3_1':'BAIXO','3_2':'MÉDIO','3_3':'ALTO','3_4':'ALTO',
  '4_1':'MÉDIO','4_2':'ALTO','4_3':'ALTO','4_4':'CRÍTICO',
};
const matrizNoHtml = html.match(/const MATRIZ_RISCO = \{([\s\S]*?)\};/);
const ctx = vm.createContext({ console, N_MIN_ANONIMATO: 5, MATRIZ_RISCO, LAUDO_NIVEL_BG: {}, LAUDO_NIVEL_TX: {}, Math, Object, Number, String, Set, Map, Array, JSON });
vm.runInContext(bloco + `
;globalThis.__m = { calcDimensoesHSE, calcRiscoHSE, _hseFaixa, _hseIndice, _hseZonaFixa, _hseMediaSimples,
  _hseLeituraTaxa, _hseMetaDasLinhas, _hseVersoesNasLinhas, HSE_DIMS, HSE_P_POR_FAIXA,
  ${/function _hsePrioridades/.test(bloco) ? '_hsePrioridades,' : ''} ${/const HSE_DIM_INFO/.test(bloco) ? 'HSE_DIM_INFO,' : ''} };`, ctx);
const M = ctx.__m;

let falhas = 0, ok = 0;
const quase = (a, b, eps = 1e-9) => a != null && b != null && Math.abs(a - b) <= eps;
function check(nome, cond, det = '') { if (cond) ok++; else { falhas++; console.log(`  ✗ ${nome}${det ? ' — ' + det : ''}`); } }

// ── Oráculo: HSE original ────────────────────────────────────────────────────────────────────────────────
const DIM_POR_ITEM = {
  ROLE: [1, 4, 11, 13, 17], CONTROL: [2, 10, 15, 19, 25, 30], DEMANDS: [3, 6, 9, 12, 16, 18, 20, 22],
  PEER_SUPPORT: [7, 24, 27, 31], MANAGER_SUPPORT: [8, 23, 29, 33, 35], RELATIONSHIPS: [5, 14, 21, 34], CHANGE: [26, 28, 32],
};
const INV = new Set(['DEMANDS', 'RELATIONSHIPS']);
const BENCH = { DEMANDS: 3.25, CONTROL: 3.72, MANAGER_SUPPORT: 3.80, PEER_SUPPORT: 4.01, RELATIONSHIPS: 4.11, ROLE: 4.16, CHANGE: 3.30 };
function metaVersao(qid) {
  const meta = {};
  Object.entries(DIM_POR_ITEM).forEach(([dim, ns]) => ns.forEach(n => {
    const cod = 'H' + String(n).padStart(2, '0');
    meta[`${qid}-${cod}`] = { id: `${qid}-${cod}`, questionario_id: qid, codigo: cod, ordem: n, dimensao: dim, inversa: INV.has(dim), texto: `${cod} (${qid})`, escala_labels: 'freq' };
  }));
  return meta;
}
// Respondente a partir dos ESCORES (pós-inversão) por código; grava o bruto como um respondente real marcaria.
function respondente(qid, escores) {
  const h = {};
  Object.entries(DIM_POR_ITEM).forEach(([dim, ns]) => ns.forEach(n => {
    const cod = 'H' + String(n).padStart(2, '0');
    const e = escores[cod];
    h[`${qid}-${cod}`] = INV.has(dim) ? 6 - e : e;
  }));
  return { questionario_id: qid, setor: 'Produção', funcao: 'Operador', h };
}

// Exemplo do relatório F2 (escores por item, já pós-inversão)
const F2 = { H03: 1, H06: 2, H09: 1, H12: 1, H16: 1, H18: 1, H20: 1, H22: 1,
  H02: 5, H10: 5, H15: 5, H19: 5, H25: 3, H30: 5, H08: 3, H23: 5, H29: 5, H33: 5, H35: 5,
  H07: 2, H24: 3, H27: 5, H31: 5, H21: 5, H14: 3, H05: 5, H34: 4,
  H01: 5, H04: 5, H11: 1, H13: 1, H17: 1, H26: 1, H28: 1, H32: 3 };
const F2_ESPERADO = {   // média, índice %, zona fixa  (relatório F2, conferido à mão)
  DEMANDS: [1.125, 3.13, 'VERMELHA'], CONTROL: [4.6667, 91.67, 'VERDE'], MANAGER_SUPPORT: [4.6, 90, 'VERDE'],
  PEER_SUPPORT: [3.75, 68.75, 'AMARELA'], RELATIONSHIPS: [4.25, 81.25, 'VERDE'], ROLE: [2.6, 40, 'AMARELA'], CHANGE: [1.6667, 16.67, 'VERMELHA'],
};

console.log('Motor HSE — casos fixos');

// 0. A cópia da matriz usada aqui é a do admin
check('MATRIZ_RISCO do teste = a do admin', !!matrizNoHtml && Object.entries(MATRIZ_RISCO).every(([k, v]) => matrizNoHtml[1].includes(`'${k}':'${v}'`)));

// 1. Exemplo F2 (5 respondentes idênticos: o n mínimo não oculta)
{
  const meta = metaVersao('v2');
  const linhas = Array.from({ length: 5 }, () => respondente('v2', F2));
  const r = M.calcDimensoesHSE(linhas, meta, BENCH);
  check('F2: n = 5', r.n === 5);
  for (const d of r.dims) {
    const [med, pct, zona] = F2_ESPERADO[d.id];
    check(`F2 ${d.id}: média ${med}`, quase(d.score, med, 1e-4), `obtido ${d.score}`);
    check(`F2 ${d.id}: índice ${pct}%`, quase(d.indice, pct, 0.01), `obtido ${d.indice}`);
    check(`F2 ${d.id}: zona ${zona}`, d.zona === zona, `obtido ${d.zona}`);
    check(`F2 ${d.id}: ${DIM_POR_ITEM[d.id].length} itens`, d.nItens === DIM_POR_ITEM[d.id].length && d.nItensEf === d.nItens);
    check(`F2 ${d.id}: invertida = ${INV.has(d.id)}`, d.invertida === INV.has(d.id));
  }
  const ms = M._hseMediaSimples(r);
  check('F2: média simples 3,237', quase(ms, 3.2369, 1e-3), `obtido ${ms}`);
  check('F2: índice da média simples 55,9%', Math.abs(M._hseIndice(ms) - 55.92) < 0.05, `obtido ${M._hseIndice(ms)}`);
  // item de prazo (H06 = "prazos impossíveis") escore 2 → 25% → vermelha
  const h06 = r.dims.find(d => d.id === 'DEMANDS').itens.find(i => i.codigo === 'H06');
  check('F2: H06 2,0 → 25% vermelha', h06.media === 2 && M._hseIndice(h06.media) === 25 && M._hseZonaFixa(25) === 'VERMELHA');
  // favoráveis/desfavoráveis (pós-normalização): Demandas 7 itens em 1 e 1 em 2 → 100% desfavorável
  const dem = r.dims.find(d => d.id === 'DEMANDS');
  check('F2: Demandas 100% desfavorável', quase(dem.desfavoravel, 1) && quase(dem.favoravel, 0));
  const pap = r.dims.find(d => d.id === 'ROLE');
  check('F2: Clareza de papel 40% fav / 60% desf (bimodal)', quase(pap.favoravel, 0.4) && quase(pap.desfavoravel, 0.6));
}

// 2. Inversão: bruto 1 ("Nunca") numa dimensão invertida = escore 5
{
  const meta = metaVersao('q');
  const h = {}; Object.values(meta).forEach(i => { h[i.id] = 1; });
  const r = M.calcDimensoesHSE(Array.from({ length: 5 }, () => ({ questionario_id: 'q', h })), meta, BENCH);
  r.dims.forEach(d => check(`inversão ${d.id}: tudo "Nunca" → ${INV.has(d.id) ? 5 : 1}`, d.score === (INV.has(d.id) ? 5 : 1), `obtido ${d.score}`));
}

// 3. Faixas relativas ao benchmark — limites, e ruído de ponto flutuante decidido pelo valor exibido
{
  const f = M._hseFaixa, ref = 3.25;
  check('faixa: 2,74 (−0,51) = VERMELHO', f(2.74, ref) === 'VERMELHO');
  check('faixa: 2,75 (−0,50) = AMBAR', f(2.75, ref) === 'AMBAR');
  check('faixa: 2,7499999999 (exibe 2,75) = AMBAR', f(2.7499999999, ref) === 'AMBAR');
  check('faixa: 3,24 = AMBAR', f(3.24, ref) === 'AMBAR');
  check('faixa: 3,25 (= ref) = AZUL', f(3.25, ref) === 'AZUL');
  check('faixa: 3,64 (+0,39) = AZUL', f(3.64, ref) === 'AZUL');
  check('faixa: 3,65 (+0,40) = VERDE', f(3.65, ref) === 'VERDE');
  check('faixa: 3,6499999999 (exibe 3,65) = VERDE', f(3.6499999999, ref) === 'VERDE');
}

// 4. Zonas fixas
{
  const z = p => M._hseZonaFixa(M._hseIndice(p));
  check('zona: 2,60 → 40,00% AMARELA (limite)', M._hseIndice(2.6) === 40 && z(2.6) === 'AMARELA');
  check('zona: 2,59 → VERMELHA', z(2.59) === 'VERMELHA');
  check('zona: 4,00 → 75% VERDE', z(4) === 'VERDE');
  check('zona: 3,99 → AMARELA', z(3.99) === 'AMARELA');
  check('índice: 1 → 0 e 5 → 100', M._hseIndice(1) === 0 && M._hseIndice(5) === 100);
  check('índice/zona: nulo → nulo', M._hseIndice(null) === null && M._hseZonaFixa(null) === null);
}

// 5. Risco para o PGR: P pela faixa, nível por lookup da matriz 4×4
{
  const cfg = Object.fromEntries(M.HSE_DIMS.map(d => [d.id, { severidade: 3 }]));
  const res = { dims: M.HSE_DIMS.map((d, i) => ({ id: d.id, nome: d.nome, score: 3, faixa: ['VERMELHO', 'AMBAR', 'AZUL', 'VERDE'][i % 4] })) };
  const rs = M.calcRiscoHSE(res, cfg);
  check('risco: VERMELHO → P4 × S3 = ALTO', rs[0].p === 4 && rs[0].s === 3 && rs[0].nivel === 'ALTO');
  check('risco: VERDE → P1 × S3 = BAIXO', rs[3].p === 1 && rs[3].nivel === 'BAIXO');
  const semCfg = M.calcRiscoHSE(res, {});
  check('risco: sem severidade não calcula nível', semCfg.every(r => r.nivel === null && r.s === null));
  check('P por faixa = 4/3/2/1', JSON.stringify(M.HSE_P_POR_FAIXA) === JSON.stringify({ VERMELHO: 4, AMBAR: 3, AZUL: 2, VERDE: 1 }));
}

// 6. Cache com DUAS versões e DUAS empresas: o motor só usa os itens do questionário das linhas
{
  const meta = { ...metaVersao('v1'), ...metaVersao('v2') };
  const linhas = Array.from({ length: 5 }, () => respondente('v2', F2));
  const r = M.calcDimensoesHSE(linhas, meta, BENCH);
  check('cache v1+v2, linhas v2: Clareza de papel tem 5 itens (não 10)', r.dims.find(d => d.id === 'ROLE').nItens === 5);
  check('cache v1+v2, linhas v2: total 35 itens', r.dims.reduce((a, d) => a + d.nItens, 0) === 35);
  check('cache v1+v2, linhas v2: média igual ao caso F2', quase(r.dims.find(d => d.id === 'DEMANDS').score, 1.125));
  check('_hseMetaDasLinhas: 35 itens', Object.keys(M._hseMetaDasLinhas(linhas, meta)).length === 35);
}

// 7. Ciclo com respostas de DUAS versões: itens fundidos por código, sem duplicar
{
  const meta = { ...metaVersao('v1'), ...metaVersao('v2') };
  const tudo5 = Object.fromEntries(Object.keys(F2).map(c => [c, 5]));
  const tudo1 = Object.fromEntries(Object.keys(F2).map(c => [c, 1]));
  const linhas = [respondente('v2', tudo5), respondente('v2', tudo5), respondente('v1', tudo1), respondente('v1', tudo1)];
  const r = M.calcDimensoesHSE(linhas, meta, BENCH);
  check('2 versões: 35 itens, não 70', r.dims.reduce((a, d) => a + d.nItens, 0) === 35);
  check('2 versões: cada item com n = 4', r.dims.every(d => d.itens.every(i => i.n === 4)));
  check('2 versões: média 3 (2×5 + 2×1)', r.dims.every(d => d.score === 3));
  check('2 versões: versoes = 2', r.versoes === 2);
  check('2 versões: texto exibido é da versão mais recente (linha[0])', r.dims[0].itens[0].texto.includes('(v2)'));
}

// 8. Taxa de resposta (faixas do HSE)
{
  const t = M._hseLeituraTaxa;
  check('taxa nula → indicativo', t(null).indicativo === true);
  check('taxa 0,49 → indicativo', t(0.49).indicativo === true);
  check('taxa 0,50 → adequada', t(0.5).indicativo === false && /adequada/.test(t(0.5).txt));
  check('taxa 0,80 → muito boa', /muito boa/.test(t(0.8).txt));
}

// 9. Prioridades (se o helper existir): pior faixa primeiro, depois menor score
if (M._hsePrioridades) {
  const res = { dims: [
    { id: 'A', faixa: 'AMBAR', score: 3.0 }, { id: 'B', faixa: 'VERMELHO', score: 2.9 }, { id: 'C', faixa: 'VERMELHO', score: 2.1 },
    { id: 'D', faixa: 'AZUL', score: 1.5 }, { id: 'E', faixa: 'VERDE', score: 4.5 } ] };
  const p = M._hsePrioridades(res).map(d => d.id).join('');
  check('prioridades: VERMELHO (menor score) > AMBAR; AZUL/VERDE fora', p === 'CBA', `obtido ${p}`);
}
if (M.HSE_DIM_INFO) {
  check('catálogo por dimensão cobre as 7', M.HSE_DIMS.every(d => M.HSE_DIM_INFO[d.id] && M.HSE_DIM_INFO[d.id].avalia && M.HSE_DIM_INFO[d.id].acoes.length >= 3));
}

// 10. Simulação de DEV (66 respostas, seed 2026) — esperado obtido por SQL INDEPENDENTE no banco de DEV em
//     2026-10-13 (média por respondente, que com os 35 itens obrigatórios é igual à média das médias dos itens).
//     A fixture vem de: node _dev/simular-hse.js --fixture _dev/fixture-hse-sim.json --seed 2026
//       --setores "Produção:36:critico-demandas,Administrativo:18:bom-gestor,Logística:12:conflito"
{
  const arq = path.join(__dirname, 'fixture-hse-sim.json');
  if (fs.existsSync(arq)) {
    const j = JSON.parse(fs.readFileSync(arq, 'utf8'));
    const meta = Object.fromEntries(j.meta.map(i => [i.id, i]));
    const SQL = { geral: { DEMANDS: 2.4678, CONTROL: 3.7702, MANAGER_SUPPORT: 3.9485, PEER_SUPPORT: 3.75, RELATIONSHIPS: 3.7045, ROLE: 4.2121, CHANGE: 2.6414 },
      'Produção': { DEMANDS: 1.826, CHANGE: 2.065, MANAGER_SUPPORT: 3.794 }, 'Administrativo': { MANAGER_SUPPORT: 4.389, ROLE: 4.4 },
      'Logística': { RELATIONSHIPS: 2.042, PEER_SUPPORT: 2.563 } };
    check('simulação: 66 respostas', j.linhas.length === 66);
    const r = M.calcDimensoesHSE(j.linhas, meta, BENCH);
    r.dims.forEach(d => check(`simulação geral ${d.id} = SQL ${SQL.geral[d.id]}`, quase(d.score, SQL.geral[d.id], 5e-5), `motor ${d.score}`));
    ['Produção', 'Administrativo', 'Logística'].forEach(s => {
      const rs = M.calcDimensoesHSE(j.linhas.filter(l => l.setor === s), meta, BENCH);
      Object.entries(SQL[s]).forEach(([dim, v]) => check(`simulação ${s} ${dim} = SQL ${v}`, quase(rs.dims.find(x => x.id === dim).score, v, 5.01e-4), `motor ${rs.dims.find(x => x.id === dim).score}`));
    });
    const fx = Object.fromEntries(r.dims.map(d => [d.id, d.faixa]));
    check('simulação: Demandas e Mudanças = Ação urgente', fx.DEMANDS === 'VERMELHO' && fx.CHANGE === 'VERMELHO', JSON.stringify(fx));
    check('simulação: prioridades começam por Demandas', M._hsePrioridades && M._hsePrioridades(r)[0].id === 'DEMANDS');
  } else console.log('  (fixture-hse-sim.json ausente — caso 10 pulado)');
}

// ── Linhas reais (opcional) ───────────────────────────────────────────────────────────────────────────────
const iArq = process.argv.indexOf('--linhas');
if (iArq > 0) {
  const j = JSON.parse(fs.readFileSync(process.argv[iArq + 1], 'utf8'));
  const meta = Object.fromEntries(j.meta.map(i => [i.id, i]));
  const r = M.calcDimensoesHSE(j.linhas, meta, BENCH);
  console.log(`Linhas reais: ${j.linhas.length} respondentes`);
  r.dims.forEach(d => {
    const esp = j.esperado?.[d.id];
    console.log(`  ${d.nome.padEnd(20)} motor ${d.score.toFixed(3)}  SQL ${esp != null ? Number(esp).toFixed(3) : '—'}  ${d.faixa}`);
    if (esp != null) check(`linhas reais ${d.id}: motor = SQL`, quase(d.score, Number(esp), 1e-6), `${d.score} × ${esp}`);
  });
}

console.log(`\n${ok} ok, ${falhas} falha(s)`);
process.exit(falhas ? 1 : 0);
