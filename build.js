#!/usr/bin/env node
/**
 * PsicoMap — Build script
 *
 * Injeta variáveis de ambiente no HTML estático antes do deploy.
 * Usado pelo Cloudflare Pages (branch main = prod, branch develop = dev).
 *
 * Variáveis esperadas (definir no painel do Cloudflare Pages):
 *   SUPA_URL         URL do projeto Supabase
 *   SUPA_ANON        Chave anon pública do Supabase
 *   STRIPE_MODE      'test' | 'live'
 *   STRIPE_STARTER   Payment link do plano Starter
 *   STRIPE_PRO       Payment link do plano Professional
 *   STRIPE_ENT       Payment link do plano Enterprise
 *   APP_ENV          'development' | 'production'
 *
 * HARDENING: toda substituição por regex é CONTADA. Um `.replace` que não casa devolve o texto
 * intacto sem erro — foi assim que o formulário público podia ir ao ar com as credenciais de PROD
 * hardcoded dentro de um deploy de DEV (ou o inverso). Aqui, qualquer troca que case um número de
 * vezes diferente do esperado derruba o build com código 1 e uma mensagem que diz qual foi.
 * Os cenários estão em _dev/check-build.js (`node _dev/check-build.js`).
 */

const fs   = require('fs');
const path = require('path');

// Projetos Supabase conhecidos (identificadores públicos, não segredos). Usados só para barrar o
// cruzamento DEV↔PROD quando o APP_ENV foi declarado de forma explícita.
const SUPABASE_REF = {
  production:  'vftyiildukrpgmnbcnao',
  development: 'szqatgvgghxvyyncsjxl',
};

function fail(msg) {
  console.error(`[build] ERRO: ${msg}`);
  process.exit(1);
}

// ── Ler variáveis de ambiente ──────────────────────────────────
const env = {
  SUPA_URL:        (process.env.SUPA_URL        || '').trim(),
  SUPA_ANON:       (process.env.SUPA_ANON       || '').trim(),
  STRIPE_MODE:     process.env.STRIPE_MODE     || 'test',
  STRIPE_STARTER:  process.env.STRIPE_STARTER  || '',
  STRIPE_PRO:      process.env.STRIPE_PRO      || '',
  STRIPE_ENT:      process.env.STRIPE_ENT      || '',
  APP_ENV:         process.env.APP_ENV         || 'production',
};
const appEnvExplicito = !!(process.env.APP_ENV || '').trim();

// Validação obrigatória
const missing = ['SUPA_URL', 'SUPA_ANON'].filter(k => !env[k]);
if (missing.length) fail(`variáveis obrigatórias não definidas: ${missing.join(', ')}`);

// ── Validar o conteúdo das credenciais ─────────────────────────
const mUrl = /^https:\/\/([a-z0-9]{20})\.supabase\.co$/.exec(env.SUPA_URL);
if (!mUrl) fail(`SUPA_URL não parece uma URL de projeto Supabase (https://<ref>.supabase.co): "${env.SUPA_URL.slice(0, 40)}"`);
const refUrl = mUrl[1];

let claims;
try {
  const parts = env.SUPA_ANON.split('.');
  if (parts.length !== 3) throw new Error('não é um JWT');
  claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
} catch (e) {
  fail(`SUPA_ANON não é um JWT legível (${e.message}). Confira se foi colada a chave anon inteira.`);
}
// Chave service_role no bundle do navegador = acesso total ao banco para qualquer visitante.
if (claims.role !== 'anon') fail(`SUPA_ANON tem role "${claims.role}" — só a chave "anon" pode ir para o navegador.`);
if (claims.ref !== refUrl) fail(`SUPA_ANON pertence ao projeto "${claims.ref}", mas SUPA_URL aponta para "${refUrl}".`);

// Cruzamento DEV↔PROD: só vale quando o APP_ENV foi declarado (um build sem APP_ENV assume 'production').
const appEnv = env.APP_ENV.trim().toLowerCase();
if (appEnvExplicito && SUPABASE_REF[appEnv]) {
  const outro = appEnv === 'production' ? 'development' : 'production';
  if (refUrl === SUPABASE_REF[outro]) {
    fail(`APP_ENV=${appEnv}, mas SUPA_URL aponta para o banco de ${outro.toUpperCase()} (${refUrl}).`);
  }
}

// Stripe: um link de teste em produção não cobra ninguém; um link real fora de produção cobra de verdade.
const stripeModo = String(env.STRIPE_MODE).trim().toLowerCase();
[['STRIPE_STARTER', env.STRIPE_STARTER], ['STRIPE_PRO', env.STRIPE_PRO], ['STRIPE_ENT', env.STRIPE_ENT]].forEach(([k, v]) => {
  if (!v) return;
  const ehTeste = /\/test_/.test(v);
  if (stripeModo === 'live' && ehTeste) fail(`${k} é um link de TESTE, mas STRIPE_MODE=live.`);
  if (stripeModo === 'test' && !ehTeste) fail(`${k} parece um link REAL (sem "/test_"), mas STRIPE_MODE=test — cobraria clientes de verdade.`);
});
const stripeVazios = ['STRIPE_STARTER', 'STRIPE_PRO', 'STRIPE_ENT'].filter(k => !env[k]);
if (stripeVazios.length) {
  // Não derruba (pode ser intencional), mas é o único caso em que o build APAGA links que estão no código.
  console.warn(`[build] AVISO: ${stripeVazios.join(', ')} vazio(s) — os links de pagamento correspondentes serão gravados como "" (os de teste do código são descartados).`);
}

// ── Substituição contada ───────────────────────────────────────
// Falha se o padrão casar um número de vezes diferente de `esperado` (número exato) ou, se `esperado`
// for um objeto {min}, menos que o mínimo.
function substituir(html, filename, padrao, novo, esperado, rotulo) {
  const total = (html.match(padrao) || []).length;
  const ok = typeof esperado === 'number' ? total === esperado : total >= esperado.min;
  if (!ok) {
    const quer = typeof esperado === 'number' ? `exatamente ${esperado}` : `pelo menos ${esperado.min}`;
    fail(`${filename}: "${rotulo}" casou ${total} vez(es), esperado ${quer}. O arquivo-fonte mudou de formato — ajuste o regex do build antes de publicar.`);
  }
  return html.replace(padrao, novo);
}

// ── Ler HTML fonte ─────────────────────────────────────────────
const dist = path.join(__dirname, 'dist');
if (!fs.existsSync(dist)) fs.mkdirSync(dist, { recursive: true });

// Arquivos HTML que recebem injeção de credenciais
const htmlTargets = [
  'psicomap-admin.html',
  'psicomap-forms.html',
];

const urlsPermitidas = new Set([env.SUPA_URL]);

htmlTargets.forEach(filename => {
  const srcPath = path.join(__dirname, filename);
  if (!fs.existsSync(srcPath)) fail(`arquivo-fonte ausente: ${filename}`);
  let html = fs.readFileSync(srcPath, 'utf8');

  if (filename === 'psicomap-admin.html') {
    // O admin usa placeholders (typeof + uso = 2 ocorrências de cada hoje; exige ao menos 1).
    html = substituir(html, filename, /__SUPA_URL__/g,  JSON.stringify(env.SUPA_URL),  { min: 1 }, '__SUPA_URL__');
    html = substituir(html, filename, /__SUPA_ANON__/g, JSON.stringify(env.SUPA_ANON), { min: 1 }, '__SUPA_ANON__');
  } else {
    // O formulário público tem credenciais literais: UMA linha de URL e UMA de chave, nem mais nem menos.
    html = substituir(html, filename, /const SUPABASE_URL\s*=\s*'https:\/\/[^']+'/g,
      `const SUPABASE_URL  = ${JSON.stringify(env.SUPA_URL)}`, 1, "const SUPABASE_URL = '…'");
    html = substituir(html, filename, /const SUPABASE_ANON\s*=\s*'[^']+'/g,
      `const SUPABASE_ANON = ${JSON.stringify(env.SUPA_ANON)}`, 1, "const SUPABASE_ANON = '…'");
  }

  // Pós-condição: nada de placeholder sobrando e nenhuma URL Supabase que não seja a do ambiente.
  const sobra = html.match(/__SUPA_(URL|ANON)__/g);
  if (sobra) fail(`${filename}: placeholder(s) ${[...new Set(sobra)].join(', ')} ainda presente(s) no resultado.`);
  const estranhas = [...new Set(html.match(/https:\/\/[a-z0-9]+\.supabase\.co/g) || [])].filter(u => !urlsPermitidas.has(u));
  if (estranhas.length) fail(`${filename}: URL(s) Supabase de outro projeto no resultado: ${estranhas.join(', ')} (o deploy falaria com o banco errado).`);
  if (!html.includes(JSON.stringify(env.SUPA_URL))) fail(`${filename}: a SUPA_URL do ambiente não aparece no resultado.`);

  fs.writeFileSync(path.join(dist, filename), html, 'utf8');
  console.log(`[build] processado: ${filename}`);
});

// Manter referência para o arquivo principal (usado abaixo para Stripe e banner)
const out = path.join(dist, 'psicomap-admin.html');
let html  = fs.readFileSync(out, 'utf8'); // já foi escrito acima

// ── Substituições adicionais (só admin) ───────────────────────
// Credenciais já foram substituídas no loop acima; continua com Stripe e banner

// 2. Stripe payment links — substitui o objeto hardcoded
const stripeLinks = `const STRIPE_PAYMENT_LINKS = {
  starter:      ${JSON.stringify(env.STRIPE_STARTER)},
  professional: ${JSON.stringify(env.STRIPE_PRO)},
  enterprise:   ${JSON.stringify(env.STRIPE_ENT)},
};`;
html = substituir(html, 'psicomap-admin.html', /const STRIPE_PAYMENT_LINKS\s*=\s*\{[\s\S]*?\};/g,
  () => stripeLinks, 1, 'const STRIPE_PAYMENT_LINKS = {…}');

// 3. Injetar banner de ambiente em dev (visível apenas no develop)
if (appEnv === 'development') {
  const devBanner = `
<div id="dev-env-banner" style="
  position:fixed;bottom:0;left:0;right:0;z-index:9999;
  background:#1d4ed8;color:white;text-align:center;
  font-family:monospace;font-size:11px;font-weight:600;
  padding:4px 8px;letter-spacing:.3px;pointer-events:none
">
  ⚙ AMBIENTE DE DESENVOLVIMENTO — ${new Date().toISOString().split('T')[0]}
</div>`;
  const lastBody = html.lastIndexOf('</body>');
  if (lastBody === -1) fail('psicomap-admin.html: </body> não encontrado — o banner de DEV não pôde ser injetado.');
  html = html.slice(0, lastBody) + devBanner + '\n</body>' + html.slice(lastBody + 7);
}

// ── Escrever output ────────────────────────────────────────────
fs.writeFileSync(out, html, 'utf8');

// ── Copiar arquivos estáticos ──────────────────────────────────
// _redirects e _headers são obrigatórios: sem eles os links antigos distribuídos (WhatsApp/QR) e os
// headers de segurança somem do deploy sem erro nenhum (ver "Checklist de rebrand" no CLAUDE.md).
const staticFiles = ['404.html', 'index.html', 'login-bg.jpg', 'favicon.ico', '_redirects', '_headers'];
const obrigatorios = new Set(['_redirects', '_headers']);
staticFiles.forEach(file => {
  const srcPath = path.join(__dirname, file);
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, path.join(dist, file));
    console.log(`[build] copiado: ${file}`);
  } else if (obrigatorios.has(file)) {
    fail(`arquivo estático obrigatório ausente: ${file}`);
  }
});

// Copiar pasta supabase/functions se existir (para referência, não deploy)
console.log(`[build] ✅ HTML gerado → dist/psicomap-admin.html`);
console.log(`[build] Ambiente: ${env.APP_ENV} | Supabase: ${env.SUPA_URL.replace(/https:\/\/(.{8}).*/, 'https://$1...')} | Stripe: ${env.STRIPE_MODE}`);
