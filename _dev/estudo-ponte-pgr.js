/**
 * Estudo da ponte HSE → inventário do PGR: matriz 4×4 (a nossa, a mesma do BS 8800) × matriz 5×5 do relatório do outro player.
 *
 *   node _dev/estudo-ponte-pgr.js            # imprime as tabelas (as do §3 de .claude/notes/2026-10-19-hse-ponte-pgr-4x4-estudo.md)
 *
 * Não depende de rede. Usa o motor do próprio admin (bloco "HSE (S7)", extraído como em test-hse-motor.js), então os números
 * são os do produto. O player 5×5 aqui é a engenharia reversa do relatório F2 (nota 2026-10-08 §5): P por faixas fixas de %
 * (90/75/60/40) e matriz lida célula a célula do PDF. NÃO é uma afirmação sobre o produto dele, só sobre aquele documento.
 */
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const html = fs.readFileSync(path.join(__dirname, '..', 'psicomap-admin.html'), 'utf8');
const bloco = html.slice(html.indexOf('// ==== HSE (S7) BEGIN'), html.indexOf('// ==== HSE (S7) END ===='));
const MATRIZ_RISCO = {};
[...html.match(/const MATRIZ_RISCO = \{([\s\S]*?)\};/)[1].matchAll(/'(\d_\d)':'([^']+)'/g)].forEach(m => { MATRIZ_RISCO[m[1]] = m[2]; });
const ctx = vm.createContext({ console, N_MIN_ANONIMATO: 5, MATRIZ_RISCO, Math, Object, Number, String, Set, Map, Array, JSON });
['S_LABELS', 'S_CRITERIA', 'CONDUTA_ADMINISTRATIVA', 'LAUDO_NIVEL_BG', 'LAUDO_NIVEL_TX'].forEach(n => vm.runInContext(html.match(new RegExp('const ' + n + ' = \\{[\\s\\S]*?\\};'))[0], ctx));
vm.runInContext(bloco + ';globalThis.__m = { _hseFaixa, _hseIndice, _hseZonaFixa, HSE_DIMS, HSE_P_POR_FAIXA, HSE_REF_SETORES };', ctx);
const M = ctx.__m;

// ── Player 5×5 (relatório F2) ───────────────────────────────────────────────────────────────────────────────
const P5 = { 5: ['Tolerável', 'Moderado', 'Substancial', 'Intolerável', 'Intolerável'], 4: ['Tolerável', 'Tolerável', 'Moderado', 'Substancial', 'Intolerável'],
  3: ['Trivial', 'Tolerável', 'Moderado', 'Substancial', 'Intolerável'], 2: ['Trivial', 'Tolerável', 'Moderado', 'Moderado', 'Substancial'], 1: ['Trivial', 'Trivial', 'Tolerável', 'Moderado', 'Moderado'] };
const PARA_NOSSO = { Trivial: 'IRRELEVANTE', 'Tolerável': 'BAIXO', Moderado: 'MÉDIO', Substancial: 'ALTO', 'Intolerável': 'CRÍTICO' };
const NIV = ['IRRELEVANTE', 'BAIXO', 'MÉDIO', 'ALTO', 'CRÍTICO'];
const pPlayer = pct => pct >= 90 ? 1 : pct >= 75 ? 2 : pct >= 60 ? 3 : pct >= 40 ? 4 : 5;       // intervalos semiabertos
const nivelPlayer = (p, s) => PARA_NOSSO[P5[p][s - 1]];
const nivelNosso = (p, s) => MATRIZ_RISCO[`${p}_${s}`];
const BENCH = { DEMANDS: 3.25, CONTROL: 3.72, MANAGER_SUPPORT: 3.80, PEER_SUPPORT: 4.01, RELATIONSHIPS: 4.11, ROLE: 4.16, CHANGE: 3.30 };   // GERAL 2023
const NOME = { DEMANDS: 'Demandas', CONTROL: 'Controle', MANAGER_SUPPORT: 'Apoio da gestão', PEER_SUPPORT: 'Suporte dos colegas', RELATIONSHIPS: 'Relacionamentos', ROLE: 'Clareza de papel', CHANGE: 'Mudanças' };
const pad = (t, n) => String(t).padEnd(n), padl = (t, n) => String(t).padStart(n);
const f2 = v => v.toFixed(2).replace('.', ',');

console.log('## 1. As duas matrizes lado a lado (nível pelo nome do BS 8800/PsicoMap)\n');
console.log('Nossa 4×4 (P linhas, S colunas):');
for (let p = 4; p >= 1; p--) console.log('  P' + p + '  ' + [1, 2, 3, 4].map(s => pad(nivelNosso(p, s), 12)).join(''));
console.log('\nPlayer 5×5 (mesmos nomes de nível; S5 = coluna extra):');
for (let p = 5; p >= 1; p--) console.log('  P' + p + '  ' + [1, 2, 3, 4, 5].map(s => pad(nivelPlayer(p, s), 12)).join(''));

// ── 2. Exemplo F2: níveis do player × os nossos ──────────────────────────────────────────────────────────────
console.log('\n## 2. Exemplo do relatório F2 (1 respondente): nível do player × nível pela nossa 4×4\n');
const F2 = { DEMANDS: [1.125, 4], CONTROL: [4.6667, 1], MANAGER_SUPPORT: [4.6, 1], PEER_SUPPORT: [3.75, 3], RELATIONSHIPS: [4.25, 4], ROLE: [2.6, 4], CHANGE: [1.6667, 4] };   // [média, S do player]
console.log(pad('Dimensão', 20) + pad('índice', 8) + pad('player P×S → nível', 28) + pad('nossa faixa→P', 22) + 'nossa 4×4 com o MESMO S → nível   Δ');
let igual = 0, acima = 0, abaixo = 0;
Object.entries(F2).forEach(([id, [media, s]]) => {
  const pct = M._hseIndice(media), pp = pPlayer(pct), np = nivelPlayer(pp, s);
  const fx = M._hseFaixa(media, BENCH[id]), po = M.HSE_P_POR_FAIXA[fx], no = nivelNosso(po, s);
  const d = NIV.indexOf(no) - NIV.indexOf(np); if (d === 0) igual++; else if (d > 0) acima++; else abaixo++;
  console.log(pad(NOME[id], 20) + pad(f2(pct) + '%', 8) + pad(`P${pp}×S${s} → ${np}`, 28) + pad(`${fx}→P${po}`, 22) + `P${po}×S${s} → ${no}`.padEnd(30) + (d === 0 ? '=' : d > 0 ? '+' + d : d));
});
console.log(`\nConcordância de nível: ${igual} iguais · ${acima} nossos 1+ acima · ${abaixo} nossos abaixo (de 7)`);

// ── 3. Organização mediana (todas as dimensões na média de referência) ────────────────────────────────────────
console.log('\n## 3. Organização "mediana" (cada dimensão exatamente na referência GERAL 2023)\n');
console.log(pad('Dimensão', 20) + pad('média', 8) + pad('índice', 9) + pad('player P', 10) + pad('nossa faixa', 16) + 'nosso P');
Object.entries(BENCH).forEach(([id, ref]) => { const pct = M._hseIndice(ref); console.log(pad(NOME[id], 20) + pad(f2(ref), 8) + pad(f2(pct) + '%', 9) + pad('P' + pPlayer(pct), 10) + pad(M._hseFaixa(ref, ref), 16) + 'P' + M.HSE_P_POR_FAIXA[M._hseFaixa(ref, ref)]); });
const medianos = Object.values(BENCH).map(r => pPlayer(M._hseIndice(r)));
console.log(`\nO player dá P≥3 a ${medianos.filter(p => p >= 3).length} das 7 dimensões de uma organização exatamente na média mundial (P4 em ${medianos.filter(p => p === 4).length}); a nossa dá P2 a todas — por construção, a média é "como a maioria".`);

// ── 4. Simulação: organizações com scores sorteados em torno da referência ───────────────────────────────────
function mulberry(seed) { let a = seed >>> 0; return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const rnd = mulberry(20261019), gauss = () => { let u = 0, v = 0; while (!u) u = rnd(); while (!v) v = rnd(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); };
const N = 20000, SD = 0.55;   // desvio entre organizações (as amplitudes mín–máx por setor do relatório HSE sugerem ~0,3–0,6)
const cruz = {}; let cmp = { igual: 0, acima: 0, abaixo: 0, n: 0 }; const difPorNivel = {};
const S_FIXO = { DEMANDS: 3, CONTROL: 2, MANAGER_SUPPORT: 2, PEER_SUPPORT: 2, RELATIONSHIPS: 3, ROLE: 2, CHANGE: 2 };   // proposta de partida (§5 da nota)
for (let k = 0; k < N; k++) for (const [id, ref] of Object.entries(BENCH)) {
  const sc = Math.round(Math.max(1, Math.min(5, ref + gauss() * SD)) * 100) / 100, pct = M._hseIndice(sc);
  const pp = pPlayer(pct), po = M.HSE_P_POR_FAIXA[M._hseFaixa(sc, ref)], s = S_FIXO[id];
  cruz[pp + '_' + po] = (cruz[pp + '_' + po] || 0) + 1;
  const d = NIV.indexOf(nivelNosso(po, s)) - NIV.indexOf(nivelPlayer(pp, s)); cmp.n++; if (d === 0) cmp.igual++; else if (d > 0) cmp.acima++; else cmp.abaixo++;
  const dn = Math.max(-2, Math.min(2, d)); difPorNivel[dn] = (difPorNivel[dn] || 0) + 1;
}
console.log(`\n## 4. Simulação — ${N} organizações × 7 dimensões, score ~ N(referência; ${SD}), S fixo da proposta (S3 em Demandas/Relacionamentos, S2 nas demais)\n`);
console.log('P do player (linhas, fixo por %) × P nosso (colunas, por faixa do benchmark) — % do total:');
console.log('        ' + [1, 2, 3, 4].map(p => padl('P' + p, 8)).join(''));
for (let pp = 1; pp <= 5; pp++) console.log('  player P' + pp + [1, 2, 3, 4].map(po => padl((100 * (cruz[pp + '_' + po] || 0) / cmp.n).toFixed(1) + '%', 8)).join(''));
console.log(`\nNível final (mesmo S): ${(100 * cmp.igual / cmp.n).toFixed(1)}% iguais · ${(100 * cmp.acima / cmp.n).toFixed(1)}% o nosso MAIS ALTO · ${(100 * cmp.abaixo / cmp.n).toFixed(1)}% o nosso MAIS BAIXO`);
console.log('Distribuição da diferença (nosso − player, em níveis): ' + [-2, -1, 0, 1, 2].map(k => `${k > 0 ? '+' : ''}${k}${Math.abs(k) === 2 ? '(ou mais)' : ''}: ${(100 * (difPorNivel[k] || 0) / cmp.n).toFixed(1)}%`).join(' · '));

// ── 5. Sensibilidade a S: quantos níveis mudam se a SST subir/baixar a severidade de uma dimensão ─────────────
console.log('\n## 5. Sensibilidade à severidade (organizações simuladas, 4×4): quanto S muda o nível\n');
const sens = { '-1': 0, '+1': 0, tot: 0 };
const rnd2 = mulberry(7);
for (let k = 0; k < 5000; k++) for (const [id, ref] of Object.entries(BENCH)) {
  const sc = Math.max(1, Math.min(5, ref + (rnd2() + rnd2() + rnd2() - 1.5) * 1.3)), po = M.HSE_P_POR_FAIXA[M._hseFaixa(Math.round(sc * 100) / 100, ref)], s = S_FIXO[id];
  const base = NIV.indexOf(nivelNosso(po, s)); sens.tot++;
  if (s > 1) sens['-1'] += Math.abs(NIV.indexOf(nivelNosso(po, s - 1)) - base);
  if (s < 4) sens['+1'] += Math.abs(NIV.indexOf(nivelNosso(po, s + 1)) - base);
}
console.log(`Mudar S em ±1 desloca o nível em média ${(sens['-1'] / sens.tot).toFixed(2)} (baixando) e ${(sens['+1'] / sens.tot).toFixed(2)} (subindo) níveis por dimensão — a severidade pesa tanto quanto a faixa; por isso é decisão de SST, versionada e assinada.`);

// ── 6. Inventário de três perfis com a severidade proposta ───────────────────────────────────────────────────
console.log('\n## 6. Inventário resultante (severidade da proposta de partida) em três perfis\n');
const perfis = { 'Mediana (na referência)': Object.fromEntries(Object.entries(BENCH)), 'Exemplo F2': Object.fromEntries(Object.entries(F2).map(([k, v]) => [k, v[0]])),
  'Crítica em Demandas/Mudanças': { ...BENCH, DEMANDS: 1.8, CHANGE: 2.0 } };
Object.entries(perfis).forEach(([nome, sc]) => {
  console.log(nome);
  Object.entries(sc).forEach(([id, v]) => { const fx = M._hseFaixa(v, BENCH[id]), po = M.HSE_P_POR_FAIXA[fx]; console.log('  ' + pad(NOME[id], 20) + pad(f2(v), 6) + pad(fx, 9) + `P${po}×S${S_FIXO[id]} → ${nivelNosso(po, S_FIXO[id])}`); });
});

// ── 7. Piso absoluto: onde o alerta de zona fixa vermelha dispararia ─────────────────────────────────────────
console.log('\n## 7. Alerta de piso absoluto (índice < 40% mas faixa relativa ≠ Ação urgente) por referência\n');
console.log(pad('Referência', 40) + 'dimensões onde o alerta é possível (limiar relativo ref−0,50 abaixo de 2,60)');
const refsSetoriais = {};
[...fs.readFileSync(path.join(__dirname, '..', 'seed_hse_benchmark_2023_setores.sql'), 'utf8').matchAll(/\('HSE_2023', 2023, '([A-Z_]+)', '([A-Z_]+)', ([0-9.]+)/g)].forEach(m => { (refsSetoriais[m[1]] = refsSetoriais[m[1]] || {})[m[2]] = Number(m[3]); });
refsSetoriais.GERAL = BENCH;
Object.entries(refsSetoriais).forEach(([setor, refs]) => {
  const ds = Object.entries(refs).filter(([, r]) => r - 0.5 < 2.6).map(([id, r]) => `${NOME[id]} (ref ${f2(r)}: faixa vermelha só abaixo de ${f2(r - 0.5)})`);
  console.log(pad((M.HSE_REF_SETORES[setor] || setor), 40) + (ds.length ? ds.join('; ') : '—'));
});
