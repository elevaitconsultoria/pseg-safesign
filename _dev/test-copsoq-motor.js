/**
 * Teste do MOTOR do COPSOQ (rascunho) — sem rede, sem banco.   node _dev/test-copsoq-motor.js
 * Extrai o bloco "COPSOQ (S10)" do admin e confere contra contas feitas aqui, à mão:
 * inversão por item, índice 0–100, zonas fixas nos limites, favoráveis/desfavoráveis, itens casados por código entre
 * versões, dimensão sem itens e a regra de visibilidade das dimensões sensíveis.
 */
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const html = fs.readFileSync(path.join(__dirname, '..', 'psicomap-admin.html'), 'utf8');
const ini = html.indexOf('// ==== COPSOQ (S10) BEGIN'), fim = html.indexOf('// ==== COPSOQ (S10) END ====');
if (ini < 0 || fim < 0) { console.error('Bloco COPSOQ (S10) não encontrado.'); process.exit(2); }
const funcDe = n => { const m = html.match(new RegExp('function ' + n + '\\([\\s\\S]*?\\n\\}\\n')); if (!m) { console.error('função não encontrada: ' + n); process.exit(2); } return m[0]; };
const ctx = vm.createContext({ console, N_MIN_ANONIMATO: 5, Math, Object, Number, String, Set, Map, Array, JSON, HSE_ESCALA_MAX: 5,
  HSE_ZONA_FIXA: { VERMELHA: { txt: 'Vermelha', cor: '#d32f2f' }, AMARELA: { txt: 'Amarela', cor: '#f9a825' }, VERDE: { txt: 'Verde', cor: '#2e7d32' } } });
vm.runInContext(funcDe('_hseMetaDasLinhas') + funcDe('_hseZonaFixa').replace(/^function/, 'function') + `
function _hseIndice(media) { return media == null ? null : Math.round((media - 1) / (HSE_ESCALA_MAX - 1) * 10000) / 100; }`, ctx);
vm.runInContext(html.match(/const HSE_CSV_GENERICO = \{[^}]*\};/)[0] + funcDe('_hseGeneralizarCSV'), ctx);
vm.runInContext(html.slice(ini, fim) + '\n;globalThis.__m = { calcDimensoesCOPSOQ, _cqPorDominio, _cqSensivelVisivel, N_MIN_SENSIVEL, COPSOQ_GLOSSARIO, _cqMontarCSV };', ctx);
const M = ctx.__m;

let ok = 0, falhas = 0;
const t = (nome, got, esperado) => { const a = JSON.stringify(got), b = JSON.stringify(esperado); if (a === b) ok++; else { falhas++; console.log(`FALHA ${nome}\n   obtido:   ${a}\n   esperado: ${b}`); } };
const perto = (nome, got, esperado, tol = 1e-9) => { if (Math.abs(got - esperado) <= tol) ok++; else { falhas++; console.log(`FALHA ${nome}: ${got} ≠ ${esperado}`); } };

const dims = [
  { id: 'A', nome: 'A (alto_pior)', dominio: 'D1', altoPior: true, sensivel: false },
  { id: 'B', nome: 'B (alto_melhor)', dominio: 'D1', altoPior: false, sensivel: false },
  { id: 'S', nome: 'S (sensível)', dominio: 'D2', altoPior: true, sensivel: true },
  { id: 'Z', nome: 'Z (sem itens)', dominio: 'D2', altoPior: false, sensivel: false },
];
const meta = {
  a1: { id: 'a1', questionario_id: 'q1', codigo: 'C01', ordem: 1, dimensao: 'A', texto: 'a1', inversa: true },
  a2: { id: 'a2', questionario_id: 'q1', codigo: 'C02', ordem: 2, dimensao: 'A', texto: 'a2', inversa: true },
  b1: { id: 'b1', questionario_id: 'q1', codigo: 'C03', ordem: 3, dimensao: 'B', texto: 'b1', inversa: false },
  s1: { id: 's1', questionario_id: 'q1', codigo: 'C04', ordem: 4, dimensao: 'S', texto: 's1', inversa: true },
};
const linha = (h, q = 'q1') => ({ questionario_id: q, h });
const calc = (linhas, m = meta) => M.calcDimensoesCOPSOQ(linhas, m, dims);
const dim = (r, id) => r.dims.find(d => d.id === id);

// 1) inversão: A com bruto 5 e 1 → normalizados 1 e 5 → média 3 → índice 50 (amarela)
let r = calc([linha({ a1: 5, a2: 1, b1: 4, s1: 3 })]);
perto('A score', dim(r, 'A').score, 3); perto('A indice', dim(r, 'A').indice, 50); t('A zona', dim(r, 'A').zona, 'AMARELA');
// 2) sem inversão: B bruto 4 → 4 → índice 75 → verde (limite)
perto('B indice', dim(r, 'B').indice, 75); t('B zona (limite 75)', dim(r, 'B').zona, 'VERDE');
// 3) extremos
r = calc([linha({ a1: 1, a2: 1, b1: 5, s1: 1 })]);   // tudo melhor possível
perto('A tudo favorável', dim(r, 'A').indice, 100); t('A zona', dim(r, 'A').zona, 'VERDE'); perto('B 100', dim(r, 'B').indice, 100);
r = calc([linha({ a1: 5, a2: 5, b1: 1, s1: 5 })]);   // pior possível
perto('A tudo desfavorável', dim(r, 'A').indice, 0); t('A zona', dim(r, 'A').zona, 'VERMELHA');
// 4) limites das zonas (decididos em centésimos: 2,6 → 40,00 amarela; 2,59 → 39,75 vermelha)
r = calc([linha({ a1: 5, a2: 5, b1: 2.6, s1: 3 })]); t('2,60 → amarela', dim(r, 'B').zona, 'AMARELA'); perto('2,60 → 40', dim(r, 'B').indice, 40);
r = calc([linha({ a1: 5, a2: 5, b1: 2.59, s1: 3 })]); t('2,59 → vermelha', dim(r, 'B').zona, 'VERMELHA');
r = calc([linha({ a1: 5, a2: 5, b1: 3.99, s1: 3 })]); t('3,99 → amarela', dim(r, 'B').zona, 'AMARELA');
// 5) favoráveis/desfavoráveis já normalizados: A com brutos 1 e 2 → 5 e 4 → ambos favoráveis; com 5 e 4 → 1 e 2 → ambos desfavoráveis
r = calc([linha({ a1: 1, a2: 2, b1: 3, s1: 3 })]); perto('A fav', dim(r, 'A').favoravel, 1); perto('A desf', dim(r, 'A').desfavoravel, 0);
r = calc([linha({ a1: 5, a2: 4, b1: 3, s1: 3 })]); perto('A fav', dim(r, 'A').favoravel, 0); perto('A desf', dim(r, 'A').desfavoravel, 1);
// 6) média das médias dos itens com várias pessoas: a1 = (5+1)/2 → normalizado (1+5)/2 = 3 ; a2 = (1+1)/2 → (5+5)/2 = 5 ; score A = 4
r = calc([linha({ a1: 5, a2: 1, b1: 3, s1: 3 }), linha({ a1: 1, a2: 1, b1: 3, s1: 3 })]);
perto('A média das médias', dim(r, 'A').score, 4); perto('A índice', dim(r, 'A').indice, 75); t('n', r.n, 2);
// 7) dimensão sem itens não aparece
t('Z ausente', !!dim(r, 'Z'), false);
// 8) itens casados por CÓDIGO entre versões do questionário (id diferente, mesmo C01)
const meta2 = { ...meta, a1v2: { id: 'a1v2', questionario_id: 'q2', codigo: 'C01', ordem: 1, dimensao: 'A', texto: 'a1 (v2)', inversa: true } };
r = M.calcDimensoesCOPSOQ([linha({ a1: 5, a2: 1 }, 'q1'), linha({ a1v2: 1, a2: 1 }, 'q2')], meta2, dims);
const itemA1 = dim(r, 'A').itens.find(i => i.codigo === 'C01'); t('C01 conta as duas versões', itemA1.n, 2); t('itens de A (sem duplicar)', dim(r, 'A').itens.length, 2);
// 9) resposta que falta num item não entra na média (n do item)
r = calc([linha({ a1: 1, b1: 3 }), linha({ a1: 5, a2: 5, b1: 3 })]); t('a2 só com 1 resposta', dim(r, 'A').itens.find(i => i.codigo === 'C02').n, 1);
// 10) domínios
t('domínios', M._cqPorDominio(calc([linha({ a1: 3, a2: 3, b1: 3, s1: 3 })])).map(g => [g.nome, g.dims.map(d => d.id), g.saude]), [['D1', ['A', 'B'], false], ['D2', ['S'], true]]);
// 11) visibilidade de dimensão sensível: n mínimo reforçado
t('N_MIN_SENSIVEL', M.N_MIN_SENSIVEL, 10); t('9 → oculto', M._cqSensivelVisivel(9), false); t('10 → visível', M._cqSensivelVisivel(10), true);
// 12) glossário cobre todas as dimensões do seed
const seed = fs.readFileSync(path.join(__dirname, '..', 'seed_copsoq_dev_rascunho.sql'), 'utf8');
const codigos = [...seed.matchAll(/\('COPSOQ_II', '([A-Z_]+)',\s+'/g)].map(m => m[1]);
t('17 dimensões no seed', codigos.length, 17); t('glossário completo', codigos.filter(c => !M.COPSOQ_GLOSSARIO[c]), []);
// 13) seed: dimensões alto_pior ⇔ itens inversos (a lista de inversas do INSERT)
const altoPior = [...seed.matchAll(/\('COPSOQ_II', '([A-Z_]+)',[^\n]*'alto_pior'/g)].map(m => m[1]).sort();
const inv = (seed.match(/dim IN \(([^)]*)\)/) || [])[1]; const invList = [...(inv || '').matchAll(/'([A-Z_]+)'/g)].map(m => m[1]).sort();
t('inversa ⇔ alto_pior', invList, altoPior);

// 14) CSV: sem colunas de itens sensíveis, valor bruto, sem identificação fora do tripé, grupos pequenos generalizados
{
  const mk = (h, setor, funcao, esc = 'Médio') => ({ questionario_id: 'q1', setor, funcao, escolaridade: esc, sessao: 'x', data: '2026-01-01', h });
  const ls = [];
  for (let i = 0; i < 6; i++) ls.push(mk({ a1: 5, a2: 1, b1: 4, s1: 3 }, 'Produção', 'Operador'));
  ls.push(mk({ a1: 2, a2: 2, b1: 2, s1: 5 }, 'RH', 'Analista'));   // grupo de 1 → generalizado
  const csv = M._cqMontarCSV(ls, meta, new Set(['S']), 'Emp', 'Ciclo');
  t('colunas', csv.cab, ['empresa', 'ciclo', 'setor', 'funcao', 'escolaridade', 'C01', 'C02', 'C03']);   // C04 (dimensão S, sensível) fora
  t('omitidas', csv.omitidas, ['C04']);
  t('valor bruto (sem inverter)', csv.linhas[0].slice(5), [5, 1, 4]);
  t('sem sessão/data/dispositivo', csv.cab.filter(c => /sess|data|disp/i.test(c)), []);
  t('grupo pequeno generalizado', csv.linhas.filter(l => l[2] === 'RH').length, 0);
  t('nGen conta a linha generalizada', csv.nGen >= 1, true);
  t('mesma quantidade de linhas', csv.linhas.length, 7);
}

console.log(`\nMotor COPSOQ — ${ok} ok, ${falhas} falha(s)`);
process.exit(falhas ? 1 : 0);
