# COPSOQ — rascunhos de contato (licença) e briefing para o jurídico/DPO

> Criado em 2026-10-19 após a decisão do usuário: (1) o texto de "interpretação das perguntas" do player vira **glossário do laudo** (não é mostrado ao respondente); (2) **iniciar o contato com a rede COPSOQ**.
> **Nada foi enviado.** São rascunhos para o usuário revisar e enviar pelo canal oficial (formulário/contato em copsoq-network.org; o endereço da equipe nacional do Brasil deve ser confirmado lá — não foi inventado aqui).

## 1. Mensagem à rede COPSOQ (PT; versão EN abaixo)
**Assunto:** Solicitação de licença de uso comercial — COPSOQ II versão brasileira curta (Gonçalves et al., 2021)

Prezados,

Somos uma empresa de tecnologia (PsicoMap) que oferece a consultorias de segurança do trabalho uma plataforma para aplicar e analisar avaliações de riscos psicossociais exigidas pela NR-01/NR-17. Gostaríamos de incluir o COPSOQ II – versão brasileira curta (Gonçalves, Moriguchi, Chaves & Sato, 2021, Rev Saúde Pública 55:69) como instrumento opcional, aplicado de forma anônima e on-line.

Entendemos que a licença é CC BY-NC-ND 4.0 com exceção para uso comercial em que não se cobra pelo questionário em si, mas por aplicação, análise e assessoria. Pedimos, por escrito:
1. Confirmação de que esse uso (plataforma SaaS cobrada pelo serviço, sem cobrar pelo questionário) está permitido.
2. O **texto oficial em português** da versão curta (itens, escalas de resposta, itens invertidos e agrupamento em dimensões/domínios) e a forma correta de atribuição.
3. Orientação sobre **pontuação** (transformação 0–100, regra de itens ausentes) e se existem **valores de referência** brasileiros publicáveis.
4. Se podemos exibir o nome "COPSOQ II-Br" mantendo o texto **sem alterações**, e como identificar qualquer adaptação (a cláusula ND).
5. Contato da equipe nacional responsável e se há exigência de registro/comunicação de uso.

Atenciosamente,
[nome, cargo, empresa, contato]

**EN (short):** We operate a SaaS platform for occupational-safety consultancies (NR-01, Brazil). We would like to offer the Brazilian short COPSOQ II (Gonçalves et al., 2021) anonymously online, charging for the service and not for the questionnaire. Please confirm in writing that this use is permitted under the CC BY-NC-ND 4.0 commercial exception; provide the official Portuguese text, scoring rules, any Brazilian reference values and attribution wording; clarify use of the name "COPSOQ II-Br" with unmodified text; and indicate the national team contact.

## 2. Briefing para o jurídico/DPO (decisões a tomar)
- **Dados sensíveis (LGPD art. 5º, II):** saúde percebida, estresse, esgotamento e comportamentos ofensivos. Definir base legal (obrigação legal NR-01 × consentimento específico) e texto de consentimento.
- **RIPD** (relatório de impacto) antes de qualquer piloto.
- **Anonimato reforçado:** n mínimo maior para dimensões de saúde (hoje 5, provisório, para HSE/BS), sem cruzamento setor × função × escolaridade nessas dimensões, sem exportação por respondente, comportamentos ofensivos nunca em recorte pequeno.
- **Retenção e descarte** dos dados de saúde; papéis (consultoria = operador? empresa cliente = controladora?).
- **Nome do produto**: "COPSOQ II-Br" só com texto idêntico ao validado e atribuição; qualquer adaptação → nome neutro.

## 3. Glossário (decisão 1)
- O texto "Essa pergunta quer entender…" do player **não** vai ao formulário nem é copiado (redação de terceiro). O PsicoMap escreverá **glossário próprio por dimensão** ("o que mede / como ler") para o laudo, revisado por SST/psicólogo, depois que o mapa item → dimensão vier da fonte validada.
- O campo `instrumento_itens.ajuda` continua existindo, mas **vazio** para o COPSOQ por padrão.
