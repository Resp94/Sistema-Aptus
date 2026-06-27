# Compatibilidade de Scripts PowerShell no Windows

## Contexto e Objetivo
Durante a execução de automações locais do SpecKit no ambiente Windows com PowerShell 5.1, identificamos falhas na atualização de contexto de agentes (`AGENTS.md`) por conta de particularidades do interpretador e da versão do .NET Framework subjacente. Este documento registra as correções realizadas para garantir a portabilidade e robustez dos scripts do projeto.

---

## 1. Problemas Identificados e Soluções

### A. Falha no Script Inline de Python no Windows PowerShell
* **Problema:** A execução de scripts Python multilinha inline usando o parâmetro `-c` com *here-strings* (`@' ... '@`) no PowerShell falha porque o PowerShell do Windows altera o formato das quebras de linha ou passa argumentos separados de forma que o Python acusa erro de sintaxe (`SyntaxError: '(' was never closed`).
* **Solução:** O script foi alterado para gravar temporariamente o código Python em um arquivo de script temporário (`.py`) no diretório temporário do sistema, executá-lo a partir do arquivo e, em seguida, remover o arquivo temporário na cláusula `finally`.

### B. Incompatibilidade com `[System.IO.Path]::GetRelativePath`
* **Problema:** O método estático `GetRelativePath` na classe `System.IO.Path` é uma adição recente do .NET Core 2.1 / .NET Standard 2.1. O Windows PowerShell 5.1 executa sob o .NET Framework (até a versão 4.8), onde esse método não existe, gerando uma exceção fatal `MethodNotFound` que abortava silenciosamente a detecção automática de planos.
* **Solução:** Substituímos o método por uma manipulação simples de string nativa do PowerShell: extraímos a porção do caminho utilizando o comprimento da pasta raiz do projeto (`$ProjectRoot.Length`), removemos barras iniciais excedentes e normalizamos as barras invertidas (`\`) para barras normais (`/`).

### C. Exceção com `$ErrorActionPreference = 'Stop'` em Loops
* **Problema:** Com `$ErrorActionPreference = 'Stop'`, se o comando `Get-Item -LiteralPath` fosse executado em uma pasta que não contivesse o arquivo `plan.md`, ele disparava um erro terminante de item não encontrado, o que interrompia todo o loop e abortava a busca no bloco `catch`.
* **Solução:** Adicionamos uma validação explícita com `Test-Path -LiteralPath` antes de chamar `Get-Item`. Dessa forma, evitamos a geração de erros do PowerShell que causavam falsos negativos.

---

## 2. Arquivos Modificados
* [.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1](file:///C:/Users/respl/OneDrive/Aptus%20Flow/sistema-aptus/.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1)

---

## 3. Histórico de Mudanças
* **Data:** 2026-06-26
* **Autor:** Antigravity (IA) via Jonathas
* **Descrição:** Correção do script de atualização de contexto dos agentes para execução com sucesso no Windows PowerShell 5.1.
