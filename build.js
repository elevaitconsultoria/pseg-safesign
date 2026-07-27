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
 */

const fs   = require('fs');
const path = require('path');

// ── Ler variáveis de ambiente ──────────────────────────────────
const env = {
  SUPA_URL:        process.env.SUPA_URL        || '',
  SUPA_ANON:       process.env.SUPA_ANON       || '',
  STRIPE_MODE:     process.env.STRIPE_MODE     || 'test',
  STRIPE_STARTER:  process.env.STRIPE_STARTER  || '',
  STRIPE_PRO:      process.env.STRIPE_PRO      || '',
  STRIPE_ENT:      process.env.STRIPE_ENT      || '',
  APP_ENV:         process.env.APP_ENV         || 'production',
};

// Validação obrigatória
const missing = ['SUPA_URL', 'SUPA_ANON'].filter(k => !env[k]);
if (missing.length) {
  console.error(`[build] ERRO: variáveis obrigatórias não definidas: ${missing.join(', ')}`);
  process.exit(1);
}

// ── Ler HTML fonte ─────────────────────────────────────────────
const dist = path.join(__dirname, 'dist');
if (!fs.existsSync(dist)) fs.mkdirSync(dist, { recursive: true });

// Arquivos HTML que recebem injeção de credenciais
const htmlTargets = [
  'psicomap-admin.html',
  'psicomap-forms.html',
];

htmlTargets.forEach(filename => {
  const srcPath = path.join(__dirname, filename);
  if (!fs.existsSync(srcPath)) return;
  let html = fs.readFileSync(srcPath, 'utf8');

  // Substituir credenciais hardcoded (forms usa strings literais, admin usa __placeholders__)
  html = html
    .replace(/__SUPA_URL__/g,  JSON.stringify(env.SUPA_URL))
    .replace(/__SUPA_ANON__/g, JSON.stringify(env.SUPA_ANON))
    // Credenciais hardcoded no psicomap-forms.html
    .replace(
      /const SUPABASE_URL\s*=\s*'https:\/\/[^']+'/g,
      `const SUPABASE_URL  = ${JSON.stringify(env.SUPA_URL)}`
    )
    .replace(
      /const SUPABASE_ANON\s*=\s*'[^']+'/g,
      `const SUPABASE_ANON = ${JSON.stringify(env.SUPA_ANON)}`
    );

  fs.writeFileSync(path.join(dist, filename), html, 'utf8');
  console.log(`[build] processado: ${filename}`);
});

// Manter referência para o arquivo principal (usado abaixo para Stripe e banner)
const src = path.join(__dirname, 'psicomap-admin.html');
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
html = html.replace(
  /const STRIPE_PAYMENT_LINKS\s*=\s*\{[\s\S]*?\};/,
  stripeLinks
);

// 3. Injetar banner de ambiente em dev (visível apenas no develop)
if (env.APP_ENV?.trim().toLowerCase() === 'development') {
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
  if (lastBody !== -1) {
    html = html.slice(0, lastBody) + devBanner + '\n</body>' + html.slice(lastBody + 7);
  }
}

// ── Escrever output ────────────────────────────────────────────
fs.writeFileSync(out, html, 'utf8');

// ── Copiar arquivos estáticos ──────────────────────────────────
const staticFiles = ['404.html', 'index.html', 'login-bg.jpg', 'favicon.ico'];
staticFiles.forEach(file => {
  const srcPath = path.join(__dirname, file);
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, path.join(dist, file));
    console.log(`[build] copiado: ${file}`);
  }
});

// Copiar pasta supabase/functions se existir (para referência, não deploy)
console.log(`[build] ✅ HTML gerado → dist/psicomap-admin.html`);
console.log(`[build] Ambiente: ${env.APP_ENV} | Supabase: ${env.SUPA_URL.replace(/https:\/\/(.{8}).*/, 'https://$1...')} | Stripe: ${env.STRIPE_MODE}`);
