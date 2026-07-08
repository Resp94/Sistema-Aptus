# Research: Padrao Enterprise Relatorios

## Decision 1: Forcar download de PDF sem preview via bytes/blob no frontend

**Rationale**:
- O comportamento atual baseado em URL assinada permite que o navegador abra o PDF em preview.
- Para garantir o requisito de "sem preview", o frontend precisa tratar o PDF como download controlado, obtendo os bytes e salvando localmente com nome e MIME corretos.
- Isso preserva bucket privado, signed URL curta e UX consistente entre exportacao imediata e historico.

**Alternatives considered**:
- Navegar diretamente para a signed URL: rejeitado porque o browser pode abrir preview de PDF.
- Tornar o objeto publico com `Content-Disposition: attachment`: rejeitado por reduzir seguranca e contrariar a arquitetura da feature 008.
- Introduzir um proxy de download adicional no backend: rejeitado por adicionar complexidade sem necessidade, ja que o navegador pode baixar bytes autenticados a partir da URL temporaria.

## Decision 2: PDF continua sendo o unico artefato com layout enterprise completo

**Rationale**:
- A necessidade de padrao enterprise esta ligada a leitura executiva e apresentacao institucional.
- CSV/ZIP e um artefato operacional de dados e nao deve competir semanticamente com o documento executivo.
- Separar claramente os papeis reduz ambiguidade para o usuario e evita inflar o escopo com uma pseudo-planilha executiva.

**Alternatives considered**:
- Tornar CSV equivalente ao PDF na comunicacao do produto: rejeitado porque contradiz a natureza tabular do formato.
- Remover CSV do produto: rejeitado porque a spec atual preserva o formato operacional como util para manipulacao de dados.

## Decision 3: Corrigir o PDF por template document-oriented por categoria

**Rationale**:
- O renderer atual se comporta como serializacao bruta de payload, o que causa vazamento de `label`, `valor` e outros nomes internos.
- O padrao enterprise exige secoes explicitas, hierarquia visual, copy em PT-BR e empty states legiveis.
- Cada categoria possui indicadores e detalhes proprios; portanto, o template precisa ser category-aware.

**Alternatives considered**:
- Continuar iterando `Object.entries(...)` com cosmetica: rejeitado porque so mascara o problema estrutural.
- Criar um unico template generico sem diferencas por categoria: rejeitado porque empobrece a legibilidade do resumo e dos detalhes.

## Decision 4: Embed de fonte TrueType no PDF para PT-BR e consistencia visual

**Rationale**:
- A spec atual da feature ja assumiu uma fonte com suporte explicito a PT-BR.
- O padrao enterprise exige acentuacao confiavel e melhor controle visual do documento.
- Embutir a fonte no bundle da Edge Function evita dependencia externa em runtime.

**Alternatives considered**:
- Permanecer com `StandardFonts` do `pdf-lib`: rejeitado porque nao atende com seguranca a estrategia aprovada na spec corrente.
- Usar fonte remota em tempo de execucao: rejeitado por adicionar dependencia de rede e instabilidade operacional.

## Decision 5: Exportacao tabular recebe correcoes de encoding e nomenclatura, nao redesign executivo

**Rationale**:
- O problema de abertura em Excel e de headers tecnicos e real e afeta usabilidade.
- Adicionar BOM UTF-8, headers de negocio e nomes coerentes resolve o principal risco sem descaracterizar o papel do formato.
- O produto deve evitar qualquer rotulo que sugira entrega `XLSX` quando o artefato real for `ZIP + CSV`.

**Alternatives considered**:
- Gerar XLSX real agora: rejeitado por abrir um segundo projeto tecnico sem necessidade para esta rodada.
- Deixar CSV como esta e corrigir apenas PDF: rejeitado porque parte da deliberacao atual inclui encoding, acentuacao e nomenclatura tambem no formato tabular.

## Decision 6: Historico expirado permanece visivel e sem download

**Rationale**:
- O historico continua sendo trilha auditavel da exportacao.
- Itens expirados precisam comunicar indisponibilidade de forma clara sem parecer erro de UI.
- O comportamento ja e compativel com a feature 008 e deve ser reforcado, nao reinventado.

**Alternatives considered**:
- Remover itens expirados do historico: rejeitado porque reduz rastreabilidade.
- Permitir novo signed URL mesmo apos expiracao logica: rejeitado porque conflita com a politica de validade do artefato.
