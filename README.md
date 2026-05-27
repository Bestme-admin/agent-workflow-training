# agent-workflow-training

> **Guardrails + iteration loop for Claude Code, installed once and shared across projects.**
> **Защитные правила и итерационный цикл для Claude Code — устанавливаются один раз, общие для всех проектов.**

📖 [English](#english) · 🇷🇺 [Русский](#русский)

---

## English

This repo is an installable framework that does two things:

1. **Drops policy** — deny rules + PreToolUse hooks — into `~/.claude/` and optionally into a project's `.claude/`, so the agent can't accidentally read your `.env`, force-push to `main`, or run a destructive SQL query without a human in the loop.
2. **Ships an `ai-workflow` skill** — the canonical *investigate → plan → approve → implement → debrief* loop — that every project's `CLAUDE.md` references as required reading.

It's the seatbelt + the driving school, not the car. The car is whatever Claude Code project you bring.

### Why this exists

Working with Claude Code is fast. "Fast" is exactly when you cause expensive accidents: an agent that reads your secrets into chat context, runs `git push --force origin main`, or executes an `UPDATE users SET ...` query because it was helpfully trying to "fix the data."

You can't fix this with prompts. Prompts drift, get forgotten, and aren't enforceable. You fix it with **two layers**:

| Layer | Where it lives | What it catches |
|---|---|---|
| `permissions.deny` | `settings.json` | Clear-cut destructive patterns: `Read(.env)`, `Bash(git push --force origin main*)`, etc. |
| `PreToolUse` hooks | `settings.json` → small Node scripts | Cases that need *logic*: parsing SQL for write keywords, detecting `.env` paths inside arbitrary shell commands, etc. |

Anything not auto-denied still surfaces to you as an approval prompt — you stay in the loop on anything that isn't pre-vetted as safe.

The `ai-workflow` skill is the human-readable counterpart: when the agent reads it (one-line `CLAUDE.md` reference triggers it), it knows the team's iteration discipline — investigate before acting, plan before implementing, ask before doing anything irreversible.

### What's in the box

```
agent-workflow-training/
├── README.md                   you are here
├── LICENSE                     MIT
├── install.sh                  macOS + Linux installer
├── install.ps1                 Windows installer (PowerShell 7+)
│
├── settings/
│   ├── user.json               ~/.claude/settings.json template
│   └── project.json            <project>/.claude/settings.json template
│
├── hooks/                      cross-platform Node hooks
│   ├── deny-env-access.js      block reads/writes/shell access to .env*
│   └── deny-supabase-writes.js block ad-hoc mutating SQL via Supabase MCP execute_sql
│
├── skills/
│   ├── user/                   installed to ~/.claude/skills/ (cross-project)
│   │   └── ai-workflow/
│   │       └── SKILL.md        the dev iteration loop
│   └── project/                installed to <project>/.claude/skills/ (per-repo)
│       └── supabase-migration-merge/
│           └── SKILL.md        coordinate multi-branch migration merges via gh
│
└── mcp-templates/              per-MCP setup recipes
    ├── README.md
    ├── supabase.md
    ├── freedcamp.md
    ├── google.md
    └── clickup.md
```

### Install

**Requirements:**

- **Node.js 18+** — the hooks run on Node. Same Node you already have for the rest of your stack.
- **git** — to clone this repo.
- **Claude Code** — obviously.

**macOS / Linux:**

```bash
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
chmod +x install.sh
./install.sh                 # user-scope only
# or, to also install into the project you're standing in:
./install.sh --project
```

**Windows (PowerShell 7+):**

```powershell
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
.\install.ps1                # user-scope only
# or, to also install into the project you're standing in:
.\install.ps1 -Project
```

**Install flags:**

| Flag (sh / ps1) | What it does |
|---|---|
| `--user-only` / `-UserOnly` | Default. Installs only `~/.claude/`. |
| `--project` / `-Project` | Also install into the current directory's `.claude/`. |
| `--project-only` / `-ProjectOnly` | Skip user scope entirely. |
| `--force` / `-Force` | Overwrite existing `settings.json` instead of writing a sidecar. |
| `--dry-run` / `-DryRun` | Print what would happen, change nothing. |

**What gets written:**

User scope (`~/.claude/`):
- `hooks/deny-env-access.js`
- `hooks/deny-supabase-writes.js`
- Everything under `skills/user/` → `~/.claude/skills/<skill-name>/SKILL.md` (currently: `ai-workflow`)
- `settings.json` *(if missing — otherwise `settings.json.agent-workflow-training` sidecar)*

Project scope (`<project>/.claude/`):
- Same hooks (duplicated into the project so the protections travel with the repo)
- Everything under `skills/project/` → `<project>/.claude/skills/<skill-name>/SKILL.md` (currently: `supabase-migration-merge`)
- `settings.json` *(or sidecar if existing)*

### After install: wire skills into your project

Add this block near the top of your project's `CLAUDE.md`:

```markdown
> **Required reading:** the `ai-workflow` skill (installed at `~/.claude/skills/ai-workflow/SKILL.md`).
> Read it before any non-trivial task.
>
> **Project-scope skills:** see `.claude/skills/` for repo-specific skills installed by `agent-workflow-training` — currently `supabase-migration-merge` (invoke when 2+ branches touch `supabase/migrations/`).
```

### What the agent can and can't do after install

| Action | Status | Caught by |
|---|---|---|
| Read `.env`, `.env.local`, `.env.prod` | **Denied** | `permissions.deny` + `deny-env-access.js` |
| `cat .env` / `Get-Content .env` in Bash | **Denied** | `deny-env-access.js` |
| Read `.env.example` | Allowed | — |
| Supabase MCP `SELECT * FROM ...` | Allowed | — |
| Supabase MCP `execute_sql` with `INSERT/UPDATE/DELETE/DROP/...` | **Denied** | `deny-supabase-writes.js` |
| Supabase MCP `apply_migration` | **Allowed** — this is the *intended* path for schema changes (versioned, replayable). The `supabase-migration-merge` skill (installed at `<project>/.claude/skills/`) helps when concurrent migrations from multiple branches need to be reconciled. | — |
| `git push --force origin main` | **Denied** | `permissions.deny` |
| `git push` (normal) | Allowed | — |
| `rm -rf /` or `rm -rf ~` | **Denied** | `permissions.deny` |
| Reading the codebase, editing files, running tests | Allowed | — |
| Anything else risky | Approval prompt | (default Claude Code behavior — not pre-allowed) |

### Verification after install

Start a Claude Code session in any project and try each of these. They should match the column above:

```
1. Read on a fake .env file        → expected: denied
2. Read on .env.example            → expected: allowed
3. Supabase execute_sql 'SELECT 1' → expected: allowed
4. Supabase execute_sql 'INSERT …' → expected: denied
5. Bash 'cat ./.env'               → expected: denied
6. Bash 'cat package.json'         → expected: allowed
```

If any of these don't match, see [`docs/troubleshooting.md`](docs/troubleshooting.md).

### MCP setup

The framework doesn't auto-configure your MCPs — that's project-specific and credential-bearing. See [`mcp-templates/`](mcp-templates/) for copy-paste setup recipes:

- [Supabase](mcp-templates/supabase.md) — DB queries, schema inspection
- [Freedcamp](mcp-templates/freedcamp.md) — one MCP per Freedcamp project
- [ClickUp](mcp-templates/clickup.md) — alternative PM tool

### Updating the framework

Same as install:

```bash
cd agent-workflow-training
git pull
./install.sh --force        # or .\install.ps1 -Force
```

`--force` overwrites the installed hooks and settings with the latest from this repo. Your `settings.json` customizations live in `settings.json` (user) and `<project>/.claude/settings.json` (project) — re-merge from the new sidecar if upgrade emits one.

### Contributing

This is an internal-but-public framework. PRs welcome from BestMe team members. The minimal bar for a new rule:

1. **Why it exists** — describe the incident, near-miss, or class of accident the rule prevents.
2. **Test case** — what tool call should be denied, what tool call should still pass.
3. **Scope** — user, project, or both. Document the choice.

For a new MCP template, follow the structure in [`mcp-templates/README.md`](mcp-templates/README.md).

### License

MIT — see [LICENSE](LICENSE).

---

## Русский

Этот репозиторий — устанавливаемый фреймворк, который делает две вещи:

1. **Раскладывает политику** — `deny`-правила и `PreToolUse`-хуки — в `~/.claude/` и (по желанию) в `.claude/` проекта. Это не даёт агенту случайно прочитать ваш `.env`, сделать `git push --force origin main` или выполнить разрушительный SQL-запрос без человека в цикле.
2. **Поставляет навык `ai-workflow`** — канонический цикл *исследовать → планировать → согласовать → реализовать → подвести итог*, на который ссылается `CLAUDE.md` каждого проекта как на обязательное чтение.

Это ремень безопасности и автошкола, а не сама машина. Машиной служит любой ваш проект, где работает Claude Code.

### Зачем это нужно

Работа с Claude Code — быстрая. «Быстро» — это ровно тот момент, когда случаются дорогие аварии: агент затягивает секреты в контекст чата, делает `git push --force origin main` или выполняет `UPDATE users SET ...`, потому что услужливо пытается «починить данные».

Промптом это не исправляется. Промпты дрейфуют, забываются и не могут принудительно применяться. Исправление — в **двух слоях**:

| Слой | Где живёт | Что ловит |
|---|---|---|
| `permissions.deny` | `settings.json` | Однозначно разрушительные шаблоны: `Read(.env)`, `Bash(git push --force origin main*)` и т. п. |
| Хуки `PreToolUse` | `settings.json` → небольшие Node-скрипты | Случаи, где нужна *логика*: парсинг SQL на write-ключевые слова, выявление путей `.env` внутри произвольных shell-команд и т. п. |

Всё, что не запрещено автоматически, всё равно показывается вам как запрос на подтверждение — вы остаётесь в цикле для любого действия, которое заранее не разрешено как безопасное.

Навык `ai-workflow` — это человеко-читаемая половина системы: когда агент его читает (одна строчка в `CLAUDE.md` запускает это), он знает командную дисциплину итераций — исследовать перед действием, планировать перед реализацией, спрашивать перед любым необратимым шагом.

### Что внутри

```
agent-workflow-training/
├── README.md                   вы здесь
├── LICENSE                     MIT
├── install.sh                  установщик для macOS + Linux
├── install.ps1                 установщик для Windows (PowerShell 7+)
│
├── settings/
│   ├── user.json               шаблон ~/.claude/settings.json
│   └── project.json            шаблон <project>/.claude/settings.json
│
├── hooks/                      кроссплатформенные Node-хуки
│   ├── deny-env-access.js      блокирует read/write/shell-доступ к .env*
│   └── deny-supabase-writes.js блокирует ad-hoc мутирующий SQL через Supabase MCP execute_sql
│
├── skills/
│   ├── user/                   ставится в ~/.claude/skills/ (общее для всех проектов)
│   │   └── ai-workflow/
│   │       └── SKILL.md        цикл итераций разработки
│   └── project/                ставится в <project>/.claude/skills/ (на конкретный репо)
│       └── supabase-migration-merge/
│           └── SKILL.md        координация межветочных мерджей миграций через gh
│
└── mcp-templates/              рецепты настройки для каждого MCP
    ├── README.md
    ├── supabase.md
    ├── freedcamp.md
    ├── google.md
    └── clickup.md
```

### Установка

**Требования:**

- **Node.js 18+** — хуки исполняются в Node. Тот же самый Node, что и для всего остального вашего стека.
- **git** — чтобы склонировать этот репо.
- **Claude Code** — очевидно.

**macOS / Linux:**

```bash
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
chmod +x install.sh
./install.sh                 # только user-scope
# или, чтобы установить также в текущий проект:
./install.sh --project
```

**Windows (PowerShell 7+):**

```powershell
gh repo clone Bestme-admin/agent-workflow-training
cd agent-workflow-training
.\install.ps1                # только user-scope
# или, чтобы установить также в текущий проект:
.\install.ps1 -Project
```

**Флаги установщика:**

| Флаг (sh / ps1) | Что делает |
|---|---|
| `--user-only` / `-UserOnly` | По умолчанию. Ставит только в `~/.claude/`. |
| `--project` / `-Project` | Также ставит в `.claude/` текущей директории. |
| `--project-only` / `-ProjectOnly` | Пропускает user-scope полностью. |
| `--force` / `-Force` | Перезаписывает существующий `settings.json` вместо записи в sidecar. |
| `--dry-run` / `-DryRun` | Показывает, что произойдёт, но ничего не меняет. |

**Что записывается:**

User-scope (`~/.claude/`):
- `hooks/deny-env-access.js`
- `hooks/deny-supabase-writes.js`
- Всё из `skills/user/` → `~/.claude/skills/<имя-навыка>/SKILL.md` (сейчас: `ai-workflow`)
- `settings.json` *(если его нет — иначе sidecar `settings.json.agent-workflow-training`)*

Project-scope (`<project>/.claude/`):
- Те же хуки (дублируются в проект, чтобы защиты путешествовали вместе с репо)
- Всё из `skills/project/` → `<project>/.claude/skills/<имя-навыка>/SKILL.md` (сейчас: `supabase-migration-merge`)
- `settings.json` *(или sidecar, если уже существует)*

### После установки: подключите навыки к проекту

Добавьте этот блок в начало `CLAUDE.md` вашего проекта:

```markdown
> **Обязательное чтение:** навык `ai-workflow` (установлен в `~/.claude/skills/ai-workflow/SKILL.md`).
> Прочитайте перед любой нетривиальной задачей.
>
> **Project-scope навыки:** см. `.claude/skills/` — навыки, установленные `agent-workflow-training`, специфичные для этого репо. Сейчас: `supabase-migration-merge` (вызывается, когда 2+ ветки трогают `supabase/migrations/`).
```

### Что агент может и не может после установки

| Действие | Статус | Что ловит |
|---|---|---|
| Read `.env`, `.env.local`, `.env.prod` | **Запрещено** | `permissions.deny` + `deny-env-access.js` |
| `cat .env` / `Get-Content .env` в Bash | **Запрещено** | `deny-env-access.js` |
| Read `.env.example` | Разрешено | — |
| Supabase MCP `SELECT * FROM ...` | Разрешено | — |
| Supabase MCP `execute_sql` с `INSERT/UPDATE/DELETE/DROP/...` | **Запрещено** | `deny-supabase-writes.js` |
| Supabase MCP `apply_migration` | **Разрешено** — это *задуманный* путь для изменений схемы (версионируется, воспроизводимо). Навык `supabase-migration-merge` (установлен в `<project>/.claude/skills/`) помогает, когда параллельные миграции с нескольких веток нужно согласовать. | — |
| `git push --force origin main` | **Запрещено** | `permissions.deny` |
| `git push` (обычный) | Разрешено | — |
| `rm -rf /` или `rm -rf ~` | **Запрещено** | `permissions.deny` |
| Чтение кодовой базы, редактирование файлов, прогон тестов | Разрешено | — |
| Что-либо ещё рискованное | Запрос на подтверждение | (стандартное поведение Claude Code — не одобрено заранее) |

### Проверка после установки

Запустите Claude Code в любом проекте и попробуйте каждое из этих действий. Результаты должны совпадать с колонкой выше:

```
1. Read на фейковый .env файл       → ожидается: запрет
2. Read на .env.example             → ожидается: разрешено
3. Supabase execute_sql 'SELECT 1'  → ожидается: разрешено
4. Supabase execute_sql 'INSERT …'  → ожидается: запрет
5. Bash 'cat ./.env'                → ожидается: запрет
6. Bash 'cat package.json'          → ожидается: разрешено
```

Если что-то не совпадает — см. [`docs/troubleshooting.md`](docs/troubleshooting.md).

### Настройка MCP

Фреймворк не настраивает ваши MCP автоматически — это специфично для проекта и связано с секретами. См. [`mcp-templates/`](mcp-templates/) с готовыми рецептами для копирования:

- [Supabase](mcp-templates/supabase.md) — запросы к БД, инспекция схемы
- [Freedcamp](mcp-templates/freedcamp.md) — один MCP на каждый Freedcamp-проект
- [ClickUp](mcp-templates/clickup.md) — альтернативный PM-инструмент

### Обновление фреймворка

То же, что и установка:

```bash
cd agent-workflow-training
git pull
./install.sh --force        # или .\install.ps1 -Force
```

`--force` перезаписывает установленные хуки и настройки последней версией из репо. Ваши кастомизации `settings.json` живут в `settings.json` (user) и `<project>/.claude/settings.json` (project) — при обновлении при необходимости снова смерджите из нового sidecar.

### Вклад в развитие

Это внутренний, но публичный фреймворк. PR-ы приветствуются от команды BestMe. Минимальный порог для нового правила:

1. **Зачем оно существует** — опишите инцидент, потенциальную аварию или класс ошибок, который правило предотвращает.
2. **Тест-кейс** — какой tool call должен быть запрещён, какой — пройти.
3. **Область** — user, project или обе. Зафиксируйте выбор.

Для нового MCP-шаблона следуйте структуре в [`mcp-templates/README.md`](mcp-templates/README.md).

### Лицензия

MIT — см. [LICENSE](LICENSE).
