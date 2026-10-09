#!/usr/bin/env node
/**
 * Verifica o HARDENING do build.js: cada defeito abaixo, que antes passava calado, tem de derrubar o build
 * (código de saída ≠ 0) e o caso saudável tem de passar. Roda numa cópia temporária — não toca em dist/.
 *
 *   node _dev/check-build.js
 *
 * Não precisa de .env nem de rede. Sai com 1 se algum cenário não se comportar como esperado.
 */
const fs   = require('fs');
const os   = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const RAIZ = process.env.CHECK_BUILD_ROOT || path.join(__dirname, '..');   // CHECK_BUILD_ROOT: provar o teste contra outro build.js
const ARQUIVOS = ['build.js', 'psicomap-admin.html', 'psicomap-forms.html', '404.html', 'index.html', '_redirects', '_headers'];
const PROD = 'vftyiildukrpgmnbcnao', DEV = 'szqatgvgghxvyyncsjxl', OUTRO = 'abcdefghijklmnopqrst';

const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (ref, role = 'anon') => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ iss: 'supabase', ref, role })}.assinatura`;
const url = ref => `https://${ref}.supabase.co`;
const TESTE = 'https://buy.stripe.com/test_abc', REAL = 'https://buy.stripe.com/abc123';

const baseEnv = () => ({ SUPA_URL: url(DEV), SUPA_ANON: jwt(DEV), APP_ENV: 'development', STRIPE_MODE: 'test',
                         STRIPE_STARTER: TESTE, STRIPE_PRO: TESTE, STRIPE_ENT: TESTE });

function rodar(nome, { env = {}, mutar = () => {} } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'psicomap-build-'));
  try {
    ARQUIVOS.forEach(f => { if (fs.existsSync(path.join(RAIZ, f))) fs.copyFileSync(path.join(RAIZ, f), path.join(dir, f)); });
    const ler = f => fs.readFileSync(path.join(dir, f), 'utf8');
    const gravar = (f, t) => fs.writeFileSync(path.join(dir, f), t, 'utf8');
    mutar({ ler, gravar, apagar: f => fs.unlinkSync(path.join(dir, f)) });
    // Ambiente limpo: nada herdado do shell (um .env carregado mascararia o cenário).
    const e = { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, ...env };
    const r = spawnSync(process.execPath, ['build.js'], { cwd: dir, env: e, encoding: 'utf8' });
    return { nome, status: r.status, saida: (r.stdout || '') + (r.stderr || ''), dir, ler };
  } finally { /* o chamador remove depois de inspecionar o dist */ }
}

const falhas = [];
function esperar(nome, opts, { passa, msg }) {
  const r = rodar(nome, opts);
  const ok = passa ? r.status === 0 : (r.status === 1 && (!msg || r.saida.includes(msg)));
  console.log(`${ok ? '[ok]  ' : '[FALHOU]'} ${nome}${ok ? '' : `\n         status=${r.status}\n         ${r.saida.trim().split('\n').slice(-3).join('\n         ')}`}`);
  if (!ok) falhas.push(nome);
  return r;
}

// ── caso saudável ──────────────────────────────────────────────────────────────────────────────
const ok = esperar('saudável (DEV)', { env: baseEnv() }, { passa: true });
try {
  const forms = fs.readFileSync(path.join(ok.dir, 'dist', 'psicomap-forms.html'), 'utf8');
  const admin = fs.readFileSync(path.join(ok.dir, 'dist', 'psicomap-admin.html'), 'utf8');
  const prova = [
    ['forms usa a URL do ambiente', forms.includes(JSON.stringify(url(DEV)))],
    ['forms não tem o projeto de PROD', !forms.includes(PROD)],
    ['admin sem placeholder', !/__SUPA_(URL|ANON)__/.test(admin)],
    ['admin com banner de DEV', admin.includes('dev-env-banner')],
    ['links do Stripe injetados', admin.includes(TESTE)],
  ];
  prova.forEach(([t, v]) => { console.log(`${v ? '[ok]  ' : '[FALHOU]'}   ↳ ${t}`); if (!v) falhas.push(t); });
} finally { fs.rmSync(ok.dir, { recursive: true, force: true }); }

const limpa = r => { fs.rmSync(r.dir, { recursive: true, force: true }); return r; };
const caso = (nome, opts, exp) => limpa(esperar(nome, opts, exp));
const forms = (de, para) => ({ ler, gravar }) => { const t = ler('psicomap-forms.html'); if (!t.includes(de)) throw new Error('fixture mudou: ' + de); gravar('psicomap-forms.html', t.replace(de, para)); };
const admin = (de, para) => ({ ler, gravar }) => { const t = ler('psicomap-admin.html'); if (!t.includes(de)) throw new Error('fixture mudou: ' + de); gravar('psicomap-admin.html', t.split(de).join(para)); };

// ── o fonte mudou de formato (a troca deixaria de acontecer em silêncio) ───────────────────────
caso('forms: linha SUPABASE_URL em aspas duplas (regex não casa)', { env: baseEnv(),
  mutar: forms("const SUPABASE_URL  = 'https://" + PROD + ".supabase.co';", 'const SUPABASE_URL  = "https://' + PROD + '.supabase.co";') }, { msg: 'SUPABASE_URL' });
caso('forms: duas linhas SUPABASE_ANON', { env: baseEnv(),
  mutar: ({ ler, gravar }) => gravar('psicomap-forms.html', ler('psicomap-forms.html') + "\n<script>const SUPABASE_ANON = 'x';</script>") }, { msg: 'SUPABASE_ANON' });
caso('forms: URL de outro projeto fora da linha de credencial', { env: baseEnv(),
  mutar: ({ ler, gravar }) => gravar('psicomap-forms.html', ler('psicomap-forms.html') + '\n<!-- ' + url(PROD) + ' -->') }, { msg: 'outro projeto' });
caso('admin: placeholders removidos', { env: baseEnv(), mutar: admin('__SUPA_URL__', 'SUPA_URL_X') }, { msg: '__SUPA_URL__' });
caso('admin: objeto STRIPE_PAYMENT_LINKS removido', { env: baseEnv(), mutar: admin('const STRIPE_PAYMENT_LINKS', 'const STRIPE_LINKS_X') }, { msg: 'STRIPE_PAYMENT_LINKS' });
caso('admin: </body> ausente com APP_ENV=development', { env: baseEnv(),
  mutar: ({ ler, gravar }) => gravar('psicomap-admin.html', ler('psicomap-admin.html').split('</body>').join('')) }, { msg: '</body>' });
caso('estático obrigatório ausente (_redirects)', { env: baseEnv(), mutar: ({ apagar }) => apagar('_redirects') }, { msg: '_redirects' });
caso('estático obrigatório ausente (_headers)', { env: baseEnv(), mutar: ({ apagar }) => apagar('_headers') }, { msg: '_headers' });

// ── credenciais erradas ────────────────────────────────────────────────────────────────────────
caso('SUPA_URL ausente', { env: { ...baseEnv(), SUPA_URL: '' } }, { msg: 'obrigatórias' });
caso('SUPA_URL com formato inválido', { env: { ...baseEnv(), SUPA_URL: 'https://exemplo.com' } }, { msg: 'SUPA_URL' });
caso('SUPA_ANON não é JWT', { env: { ...baseEnv(), SUPA_ANON: 'sb_publishable_xyz' } }, { msg: 'JWT' });
caso('SUPA_ANON com role service_role', { env: { ...baseEnv(), SUPA_ANON: jwt(DEV, 'service_role') } }, { msg: 'service_role' });
caso('chave de um projeto, URL de outro', { env: { ...baseEnv(), SUPA_ANON: jwt(OUTRO) } }, { msg: 'pertence ao projeto' });

// ── cruzamento DEV↔PROD ────────────────────────────────────────────────────────────────────────
caso('APP_ENV=development apontando para PROD', { env: { ...baseEnv(), SUPA_URL: url(PROD), SUPA_ANON: jwt(PROD) } }, { msg: 'APP_ENV=development' });
caso('APP_ENV=production apontando para DEV', { env: { ...baseEnv(), APP_ENV: 'production' } }, { msg: 'APP_ENV=production' });
caso('sem APP_ENV (preview) com DEV: permitido', { env: (() => { const e = baseEnv(); delete e.APP_ENV; return e; })() }, { passa: true });
caso('APP_ENV=production com PROD: permitido', { env: { ...baseEnv(), APP_ENV: 'production', SUPA_URL: url(PROD), SUPA_ANON: jwt(PROD) } }, { passa: true });

// ── Stripe ─────────────────────────────────────────────────────────────────────────────────────
caso('STRIPE_MODE=live com link de teste', { env: { ...baseEnv(), STRIPE_MODE: 'live' } }, { msg: 'TESTE' });
caso('STRIPE_MODE=test com link real', { env: { ...baseEnv(), STRIPE_STARTER: REAL } }, { msg: 'cobraria' });
caso('Stripe vazio: só avisa', { env: { ...baseEnv(), STRIPE_STARTER: '', STRIPE_PRO: '', STRIPE_ENT: '' } }, { passa: true });

console.log(falhas.length ? `\n${falhas.length} verificação(ões) falharam: ${falhas.join('; ')}` : '\nTodos os cenários do build se comportaram como esperado.');
process.exit(falhas.length ? 1 : 0);
