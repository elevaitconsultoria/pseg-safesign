#!/usr/bin/env node
/**
 * Simulador de respostas do HSE — SOMENTE DEV.
 *
 * Envia respostas sintéticas pela RPC REAL `salvar_resposta` (a mesma que o formulário público usa, com a
 * mesma validação: 35 itens, 1..5, sem duplicar), então o caminho completo é exercitado — inclusive a
 * análise, o laudo, o n mínimo e a taxa de resposta, que leem o que a RPC gravou.
 *
 *   node --env-file=.env _dev/simular-hse.js --perfil mediana --n 40
 *   node --env-file=.env _dev/simular-hse.js --setores "Produção:30:critico-demandas,Administrativo:12:otimo,Logistica:8"
 *   node --env-file=.env _dev/simular-hse.js --perfil player-f2 --n 5          # reproduz o relatório F2 do outro player
 *   node --env-file=.env _dev/simular-hse.js --perfis                          # lista os perfis
 *
 * Pré-requisito (DEV): seed_hse_simulacao_dev.sql (empresa fictícia + ciclo HSE + link `simhse000001`).
 * Limpeza (SQL, DEV): DELETE FROM respostas WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1';
 *                     DELETE FROM respostas_fila WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1';
 *                     DELETE FROM respostas_raw_backup WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1';
 *
 * Opções
 *   --token T        link de coleta (padrão simhse000001)
 *   --perfil P       perfil aplicado a todos os setores (padrão mediana)
 *   --n N            nº de respondentes (padrão 40) — ignorado se --setores for dado
 *   --setores LISTA  "Setor:n[:perfil],Setor:n[:perfil]" — um perfil por setor
 *   --ruido X        desvio-padrão do sorteio por item, em pontos de escala (padrão 0.8)
 *   --seed S         semente do sorteio (padrão 1) — mesma semente, mesmas respostas
 *   --dry            não envia nada; só mostra o que enviaria e os escores esperados
 *   --fixture ARQ    OFFLINE: não acessa a rede; grava em ARQ as respostas que ENVIARIA (mesmo sorteio do envio real,
 *                    inclusive função e escolaridade) + os 35 itens da v2, para o harness do navegador e o teste do motor.
 *                    Com --seed 2026 e os mesmos --setores do estado de DEV, reproduz as 66 respostas gravadas lá.
 *
 * CONVENÇÃO (a mesma do motor do sistema): "escore" do item = alto é melhor, DEPOIS da inversão.
 * Em Demandas e Relacionamentos a resposta BRUTA é o espelho (raw = 6 − escore); o simulador sorteia o escore
 * e grava o bruto, que é o que um respondente de verdade marcaria.
 */
'use strict';

const REF_PROD = 'vftyiildukrpgmnbcnao';

// ── Mapeamento código → dimensão (numeração do HSE ORIGINAL; igual ao seed das versões do instrumento) ───
const DIM_POR_ITEM = {
  ROLE: [1, 4, 11, 13, 17], CONTROL: [2, 10, 15, 19, 25, 30], DEMANDS: [3, 6, 9, 12, 16, 18, 20, 22],
  PEER_SUPPORT: [7, 24, 27, 31], MANAGER_SUPPORT: [8, 23, 29, 33, 35], RELATIONSHIPS: [5, 14, 21, 34], CHANGE: [26, 28, 32],
};
const INVERTIDAS = new Set(['DEMANDS', 'RELATIONSHIPS']);
const ITEM = {};   // 'H01' → { n, dim, inv }
Object.entries(DIM_POR_ITEM).forEach(([dim, ns]) => ns.forEach(n => { ITEM['H' + String(n).padStart(2, '0')] = { n, dim, inv: INVERTIDAS.has(dim) }; }));
const DIMS = Object.keys(DIM_POR_ITEM);

// ── Perfis: escore médio-alvo (1..5, alto = melhor) por dimensão ──────────────────────────────────────────
const BENCH_2023 = { DEMANDS: 3.25, CONTROL: 3.72, MANAGER_SUPPORT: 3.80, PEER_SUPPORT: 4.01, RELATIONSHIPS: 4.11, ROLE: 4.16, CHANGE: 3.30 };
const mediana = BENCH_2023;
const PERFIS = {
  'mediana':          { desc: 'Organização mediana do benchmark HSE 2023 (médias gerais).', alvo: mediana },
  'otimo':            { desc: 'Tudo muito bom (≈4,7).', alvo: Object.fromEntries(DIMS.map(d => [d, 4.7])) },
  'pessimo':          { desc: 'Tudo muito ruim (≈1,5).', alvo: Object.fromEntries(DIMS.map(d => [d, 1.5])) },
  'critico-demandas': { desc: 'Mediana, mas Demandas e Mudanças críticas (≈1,8 e ≈2,0).', alvo: { ...mediana, DEMANDS: 1.8, CHANGE: 2.0 } },
  'bom-gestor':       { desc: 'Mediana, com Apoio da gestão e Papel muito bons (≈4,6).', alvo: { ...mediana, MANAGER_SUPPORT: 4.6, ROLE: 4.6 } },
  'conflito':         { desc: 'Mediana, mas Relacionamentos e Suporte dos colegas ruins (≈2,2 e ≈2,6).', alvo: { ...mediana, RELATIONSHIPS: 2.2, PEER_SUPPORT: 2.6 } },
  // Exatamente o exemplo do relatório F2 do outro player (escores por item, já depois da inversão). Sem ruído.
  'player-f2': {
    desc: 'Reproduz o respondente do relatório F2 (AVALIA NR01). Use com --n 5 ou mais (o n mínimo oculta menos que isso).',
    itens: { H03: 1, H06: 2, H09: 1, H12: 1, H16: 1, H18: 1, H20: 1, H22: 1,            // Demandas
             H02: 5, H10: 5, H15: 5, H19: 5, H25: 3, H30: 5,                              // Controle
             H08: 3, H23: 5, H29: 5, H33: 5, H35: 5,                                      // Apoio da gestão
             H07: 2, H24: 3, H27: 5, H31: 5,                                              // Suporte dos colegas
             H21: 5, H14: 3, H05: 5, H34: 4,                                              // Relacionamentos
             H01: 5, H04: 5, H11: 1, H13: 1, H17: 1,                                      // Clareza de papel
             H26: 1, H28: 1, H32: 3 },                                                    // Mudanças
  },
};

// ── Utilitários ────────────────────────────────────────────────────────────────────────────────────────────
function prng(seed) {   // mulberry32
  let a = seed >>> 0;
  return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function normal(rnd) { let u = 0, v = 0; while (!u) u = rnd(); while (!v) v = rnd(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
const clamp = x => Math.max(1, Math.min(5, x));

function arg(nome, padrao) { const i = process.argv.indexOf('--' + nome); if (i < 0) return padrao; const v = process.argv[i + 1]; return (v === undefined || v.startsWith('--')) ? true : v; }

// Gera as respostas BRUTAS de UM respondente e devolve também o escore (pós-inversão) por item.
function gerarRespondente(perfil, rnd, ruido) {
  const escores = {}, brutos = {};
  Object.entries(ITEM).forEach(([cod, it]) => {
    let e;
    if (perfil.itens) e = perfil.itens[cod];
    else e = Math.round(clamp(perfil.alvo[it.dim] + normal(rnd) * ruido));
    escores[cod] = e;
    brutos[cod] = it.inv ? 6 - e : e;
  });
  return { escores, brutos };
}

const ESCOLARIDADES = ['Ensino Fundamental', 'Ensino Médio', 'Ensino Superior'];
// setor → funções do quadro (seed_hse_simulacao_dev.sql); setor desconhecido usa 'Operador'
const FUNCOES = { 'Produção': ['Operador', 'Operador', 'Operador', 'Supervisor'], 'Administrativo': ['Analista'], 'Logística': ['Auxiliar'] };

async function rpc(url, anon, nome, corpo) {
  const r = await fetch(`${url}/rest/v1/rpc/${nome}`, { method: 'POST', headers: { apikey: anon, Authorization: `Bearer ${anon}`, 'Content-Type': 'application/json' }, body: JSON.stringify(corpo) });
  const txt = await r.text(); let j; try { j = JSON.parse(txt); } catch { j = txt; }
  return { ok: r.ok, status: r.status, corpo: j };
}

// Modo --fixture: mesmo sorteio do envio real (gerarRespondente → função → escolaridade, nesta ordem), sem rede.
// Os itens vêm do seed da v2 (texto real), com ids sintéticos "v2-Hnn" e questionario_id da v2 de DEV.
function gerarFixture(arquivo) {
  const fs = require('fs'), path = require('path');
  const seedSql = fs.readFileSync(path.join(__dirname, '..', 'seed_hse_icao35_ptbr_v2_dev.sql'), 'utf8');
  const Q = '00000000-0000-0000-0000-000000000003';
  const meta = [...seedSql.matchAll(/\(\s*(\d+),'([A-Z_]+)',\s*'((?:[^']|'')*)'\)/g)].map(m => {
    const n = +m[1], cod = 'H' + String(n).padStart(2, '0');
    return { id: 'v2-' + cod, questionario_id: Q, codigo: cod, ordem: n, parte: 1, dimensao: m[2], texto: m[3].replace(/''/g, "'"), inversa: INVERTIDAS.has(m[2]), escala_labels: 'freq' };
  });
  if (meta.length !== 35) { console.error('Esperava 35 itens no seed v2, achei ' + meta.length); process.exit(1); }
  const ruido = parseFloat(arg('ruido', '0.8')), seed = parseInt(arg('seed', '1'), 10), perfilPadrao = arg('perfil', 'mediana');
  const sArg = arg('setores', null);
  const grupos = (sArg && sArg !== true)
    ? String(sArg).split(',').map(p => { const [setor, n, perfil] = p.split(':'); return { setor: setor.trim(), n: parseInt(n, 10), perfil: (perfil || perfilPadrao).trim() }; })
    : (() => { const N = parseInt(arg('n', '40'), 10), nP = Math.round(N * 0.5), nA = Math.round(N * 0.3); return [{ setor: 'Produção', n: nP, perfil: perfilPadrao }, { setor: 'Administrativo', n: nA, perfil: perfilPadrao }, { setor: 'Logística', n: N - nP - nA, perfil: perfilPadrao }].filter(g => g.n > 0); })();
  const rnd = prng(seed), linhas = [];
  const t0 = Date.parse('2026-10-10T12:00:00Z');
  for (const g of grupos) {
    const perfil = PERFIS[g.perfil]; if (!perfil) { console.error('Perfil desconhecido: ' + g.perfil); process.exit(1); }
    const funcoes = FUNCOES[g.setor] || ['Operador'];
    for (let k = 0; k < g.n; k++) {
      const { brutos } = gerarRespondente(perfil, rnd, perfil.itens ? 0 : ruido);
      const funcao = funcoes[Math.floor(rnd() * funcoes.length)], escolaridade = ESCOLARIDADES[Math.floor(rnd() * ESCOLARIDADES.length)];
      linhas.push({ id: 'sim-' + (linhas.length + 1), setor: g.setor, funcao, escolaridade, questionario_id: Q,
        respondido_em: new Date(t0 + linhas.length * 3600e3).toISOString(),
        h: Object.fromEntries(Object.entries(brutos).map(([cod, v]) => ['v2-' + cod, v])) });
    }
  }
  fs.writeFileSync(arquivo, JSON.stringify({ gerado: new Date().toISOString(), seed, grupos, meta, linhas }));
  console.log(`Fixture: ${linhas.length} respostas, ${meta.length} itens → ${arquivo}`);
}

async function main() {
  if (arg('perfis', false)) { Object.entries(PERFIS).forEach(([k, p]) => console.log(`${k.padEnd(18)} ${p.desc}`)); return; }

  const fixture = arg('fixture', null);
  if (fixture && fixture !== true) return gerarFixture(fixture);
  const url = (process.env.SUPA_URL || '').trim(), anon = (process.env.SUPA_ANON || '').trim();
  if (!url || !anon) { console.error('Defina SUPA_URL e SUPA_ANON (use: node --env-file=.env _dev/simular-hse.js ...).'); process.exit(1); }
  if (url.includes(REF_PROD)) { console.error('RECUSADO: SUPA_URL aponta para PROD. O simulador é só para DEV.'); process.exit(1); }

  const token = arg('token', 'simhse000001');
  const ruido = parseFloat(arg('ruido', '0.8'));
  const seed = parseInt(arg('seed', '1'), 10);
  const dry = !!arg('dry', false);
  const perfilPadrao = arg('perfil', 'mediana');

  // grupos: [{ setor, n, perfil }]
  let grupos;
  const sArg = arg('setores', null);
  if (sArg && sArg !== true) {
    grupos = String(sArg).split(',').map(p => { const [setor, n, perfil] = p.split(':'); return { setor: setor.trim(), n: parseInt(n, 10), perfil: (perfil || perfilPadrao).trim() }; });
  } else {
    const N = parseInt(arg('n', '40'), 10), nP = Math.round(N * 0.5), nA = Math.round(N * 0.3);
    grupos = [{ setor: 'Produção', n: nP, perfil: perfilPadrao }, { setor: 'Administrativo', n: nA, perfil: perfilPadrao },
              { setor: 'Logística', n: N - nP - nA, perfil: perfilPadrao }].filter(g => g.n > 0);
  }
  for (const g of grupos) { if (!PERFIS[g.perfil]) { console.error(`Perfil desconhecido: ${g.perfil}. Use --perfis.`); process.exit(1); } if (!(g.n > 0)) { console.error(`n inválido para ${g.setor}.`); process.exit(1); } }

  // Instrumento servido pelo link (mesma RPC anônima do formulário): id do item por código.
  const inst = await rpc(url, anon, 'obter_instrumento_link', { p_token: token });
  if (!inst.ok || !inst.corpo || inst.corpo.metodologia !== 'HSE_ICAO35') { console.error('Link sem instrumento HSE (' + JSON.stringify(inst.corpo).slice(0, 160) + '). Aplicou seed_hse_simulacao_dev.sql?'); process.exit(1); }
  const idPorCodigo = Object.fromEntries(inst.corpo.itens.map(i => [i.codigo, i.id]));
  const faltam = Object.keys(ITEM).filter(c => !idPorCodigo[c]);
  if (faltam.length) { console.error('O instrumento servido não tem os códigos: ' + faltam.join(', ')); process.exit(1); }
  const lnk = await fetch(`${url}/rest/v1/links_coleta?select=empresa_id,ciclo_id&token=eq.${encodeURIComponent(token)}`, { headers: { apikey: anon, Authorization: `Bearer ${anon}` } }).then(r => r.json());
  if (!Array.isArray(lnk) || !lnk[0]) { console.error('Link não encontrado/ativo: ' + token); process.exit(1); }
  const { empresa_id, ciclo_id } = lnk[0];

  console.log(`Instrumento v${inst.corpo.versao} · empresa ${empresa_id.slice(0, 8)}… · ciclo ${ciclo_id.slice(0, 8)}… · semente ${seed} · ruído ${ruido}${dry ? ' · DRY-RUN' : ''}`);
  const rnd = prng(seed);
  const soma = {}, cont = {}; DIMS.forEach(d => { soma[d] = 0; cont[d] = 0; });
  let ok = 0, falhas = 0, total = 0;
  const porSetor = {};

  for (const g of grupos) {
    const perfil = PERFIS[g.perfil];
    const funcoes = FUNCOES[g.setor] || ['Operador'];
    for (let k = 0; k < g.n; k++) {
      const { escores, brutos } = gerarRespondente(perfil, rnd, perfil.itens ? 0 : ruido);
      Object.entries(escores).forEach(([cod, e]) => { const d = ITEM[cod].dim; soma[d] += e; cont[d]++; });
      total++;
      porSetor[g.setor] = porSetor[g.setor] || { n: 0, ok: 0 };
      porSetor[g.setor].n++;
      if (dry) continue;
      const itens = Object.entries(brutos).map(([cod, v]) => ({ questao_id: idPorCodigo[cod], valor: v }));
      const r = await rpc(url, anon, 'salvar_resposta', {
        p_empresa_id: empresa_id, p_ciclo_id: ciclo_id, p_link_token: token, p_setor: g.setor,
        p_funcao: funcoes[Math.floor(rnd() * funcoes.length)], p_escolaridade: ESCOLARIDADES[Math.floor(rnd() * ESCOLARIDADES.length)],
        p_itens: itens, p_session_id: crypto.randomUUID(), p_lgpd_aceito: true, p_device_info: 'simulacao-dev',
      });
      if (r.ok) { ok++; porSetor[g.setor].ok++; } else { falhas++; if (falhas <= 3) console.error('  falha:', r.status, JSON.stringify(r.corpo).slice(0, 200)); }
    }
  }

  console.log('\nRespondentes por setor (perfil):');
  grupos.forEach(g => console.log(`  ${g.setor.padEnd(16)} n=${String(g.n).padStart(3)}  ${g.perfil}${dry ? '' : `  enviados ${porSetor[g.setor].ok}/${g.n}`}`));
  console.log('\nEscore médio ESPERADO por dimensão (alto = melhor, depois da inversão) — compare com a tela de análise:');
  const NOME = { DEMANDS: 'Demandas', CONTROL: 'Controle', MANAGER_SUPPORT: 'Apoio da gestão', PEER_SUPPORT: 'Suporte dos colegas', RELATIONSHIPS: 'Relacionamentos', ROLE: 'Clareza de papel', CHANGE: 'Mudanças' };
  DIMS.forEach(d => { const m = soma[d] / cont[d]; console.log(`  ${NOME[d].padEnd(20)} ${m.toFixed(3)}   índice ${((m - 1) / 4 * 100).toFixed(1)}%`); });
  if (!dry) console.log(`\n${ok} de ${total} respostas gravadas${falhas ? `, ${falhas} FALHAS` : ''}.`);
  process.exit(falhas ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
