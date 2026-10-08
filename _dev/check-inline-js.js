#!/usr/bin/env node
// Verifica a sintaxe de todos os <script> inline dos HTML do projeto.
//
// Por que existe: psicomap-admin.html (~21 mil linhas) e psicomap-forms.html têm TODO o JS inline,
// sem bundler e sem CI. Um erro de sintaxe (ex.: crase dentro do template literal do laudo)
// derruba o painel inteiro e só aparece em runtime. Esta é a única checagem automática barata.
//
// Uso:  node _dev/check-inline-js.js [arquivo.html ...]
//       (sem argumentos, checa psicomap-admin.html e psicomap-forms.html)
// Saída: código 0 se tudo ok; código 1 se algum <script> inline tiver erro de sintaxe.
//
// Limites: só confere sintaxe. Não executa o código, não detecta erro de runtime nem variável
// indefinida. Scripts com `src=` e blocos que não são JS (type="application/json" etc.) são pulados.

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const raiz = path.resolve(__dirname, '..');
const alvos = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ['psicomap-admin.html', 'psicomap-forms.html'];

const reScript = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
let falhas = 0;

for (const nome of alvos) {
  const arquivo = path.resolve(raiz, nome);
  if (!fs.existsSync(arquivo)) {
    console.error(`[ERRO] não encontrado: ${nome}`);
    falhas++;
    continue;
  }
  const html = fs.readFileSync(arquivo, 'utf8');
  let ok = 0;
  let pulados = 0;
  let m;
  while ((m = reScript.exec(html)) !== null) {
    const attrs = m[1] || '';
    const codigo = m[2];
    if (/\bsrc\s*=/.test(attrs)) { pulados++; continue; }
    const tipo = (attrs.match(/\btype\s*=\s*["']([^"']+)["']/i) || [])[1];
    if (tipo && !/^(text\/javascript|application\/javascript|module)$/i.test(tipo)) { pulados++; continue; }
    if (!codigo.trim()) { pulados++; continue; }

    // linha do HTML em que o <script> começa (para localizar o erro)
    const inicio = html.slice(0, m.index).split('\n').length;
    try {
      // vm.Script só compila (não executa). `module` não aceita `import` em Script; aqui não há.
      new vm.Script(codigo, { filename: `${nome}#script@linha${inicio}` });
      ok++;
    } catch (e) {
      falhas++;
      // e.stack traz "arquivo:linha" relativo ao bloco; somamos o deslocamento do bloco no HTML.
      const rel = (e.stack || '').match(/#script@linha\d+:(\d+)/);
      const linhaHtml = rel ? inicio + Number(rel[1]) - 1 : inicio;
      console.error(`[ERRO] ${nome}: ${e.name}: ${e.message}`);
      console.error(`       bloco <script> iniciado na linha ${inicio}; erro aproximadamente na linha ${linhaHtml} do HTML`);
    }
  }
  console.log(`[ok]   ${nome}: ${ok} bloco(s) inline compilam${pulados ? `, ${pulados} pulado(s)` : ''}`);
}

if (falhas) {
  console.error(`\n${falhas} problema(s) encontrado(s).`);
  process.exit(1);
}
