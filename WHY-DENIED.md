# WHY-DENIED — what each rule blocks and why

> Installed by [`agent-workflow-training`](https://github.com/Bestme-admin/agent-workflow-training) at `~/.claude/WHY-DENIED.md`. Each session prints a one-line banner pointing here, so the first time you see a deny error in Claude Code you know where to look.

📖 [English](#english) · 🇷🇺 [Русский](#русский)

---

## English

### How deny errors get surfaced

When Claude Code refuses a tool call, you see one of two message shapes in your terminal:

1. **`Tool use X denied by permissions.deny pattern: <pattern>`** — a `permissions.deny` glob in `settings.json` matched. Fast, cheap, fires before any hook. The pattern itself is the only context — look it up below.
2. **A custom message from a hook** (e.g. `"Blocked: shell command touches a .env file. Secrets stay out of agent context..."`) — a PreToolUse hook ran and returned a structured deny. These already explain themselves inline; you usually don't need this doc for them.

This doc covers the `permissions.deny` patterns because their on-screen text is terse.

---

### `.env` file access

| Pattern (example) | Why blocked | What to do instead |
|---|---|---|
| `Read(**/.env)`, `Read(**/.env.*)` | Secrets in `.env` shouldn't enter agent chat context. Once in context, they're cached, transcripted, and travel with every prompt. | Read `.env.example` (committed template) for variable *names*. If the agent needs a specific value, you share only that value in chat. |
| `Edit(**/.env)`, `Write(**/.env)` | Same reason as reads, plus: agent-written `.env` files are a common source of accidental commits. | You edit `.env` yourself in your editor. Update `.env.example` if you're adding a new var. |
| `Bash(cat .env*)`, `Bash(less .env*)`, `Bash(head .env*)`, `Bash(tail .env*)`, `Bash(bat .env*)`, `Bash(xxd .env*)`, `Bash(strings .env*)`, etc. | Shell-level read of `.env` — same secrets exposure as Tool-level Read. | Same as above. |
| `Bash(source .env*)`, `Bash(. .env*)` | Dot-sourcing executes the file in the shell, leaking secrets into env vars the agent's subsequent commands can see. | You source it in *your* shell before launching Claude, then pass needed values via prompt. |
| `Bash(cp .env* **)`, `Bash(mv .env* **)`, `Bash(Copy-Item .env* **)`, `Bash(Move-Item .env* **)` | Copying / moving `.env` is often the prelude to staging it for commit, or making a "backup" that ends up shared. | Don't move `.env` files via the agent. |
| `PowerShell(Get-Content .env*)`, `PowerShell(gc .env*)`, `PowerShell(type .env*)`, `PowerShell(cat .env*)` | PowerShell equivalents of the Bash reads — all surface the same secret content. | Same as above. |

---

### Private-key file access

| Pattern (example) | Why blocked | What to do instead |
|---|---|---|
| `Read(**/*.pem)`, `Read(**/*.key)`, `Read(**/id_rsa)`, `Read(**/id_ed25519)` | Private cryptographic material must not enter agent context — same logic as `.env` plus the keys are typically irrevocable in the moment. | If the agent needs to know *that* a key exists, run `ls -la ~/.ssh/` yourself. If the agent needs key content, that's almost never the right answer — push back. |
| `Bash(cat *.pem)`, `Bash(cat **/id_rsa)`, etc. | Shell reads of the same files. | Same as above. |

---

### Destructive Bash / PowerShell

| Pattern (example) | Why blocked | What to do instead |
|---|---|---|
| `Bash(rm -rf /*)`, `Bash(rm -rf ~*)`, `Bash(rm -rf $HOME*)`, `Bash(sudo rm*)` | Unrecoverable, blast radius is the whole machine. Almost never the right way to clean up. | Be specific: `rm <file>` or `rm -rf <subfolder-name>`. If you genuinely need to wipe a directory, do it yourself. |
| `Bash(git push --force origin main*)`, `Bash(git push -f origin main*)`, `Bash(git push --force origin master*)` | Force-push to a shared branch destroys teammates' work. | Use a feature branch and a normal `git push`. Open a PR. |
| `Bash(git reset --hard origin/main*)`, `Bash(git reset --hard origin/master*)` | Discards local work without a way to recover it. | If you really need to reset, you do it after stashing or branching off your current state. |
| `Bash(git branch -D main*)`, `Bash(git branch -D master*)` | Deletes the main branch locally — almost always a mistake. | Switch branches with `git switch`, don't delete the protected one. |
| `Bash(git clean -fdx*)` | Removes ignored files including possibly-uncommitted local config. | `git clean -fd` (without `-x`) leaves `.gitignore`d files alone; or just clean specific paths. |
| `Bash(npm publish*)`, `Bash(pnpm publish*)` | Publishes a package version to a public registry — irreversible. | You run publishes after reviewing the package contents and version bump. |
| `Bash(gh repo delete*)` | Self-evident. | Don't. |
| `Bash(gh auth logout*)` | Wipes auth credentials from the gh keyring — affects future sessions you may not be tracking, and unrelated projects on the same machine. | If you need to switch active account, use `gh auth switch -u <user>` (reversible). |
| `PowerShell(Remove-Item -Recurse -Force /*)`, `PowerShell(Remove-Item -Recurse -Force ~*)` | PowerShell equivalent of `rm -rf /` and `rm -rf ~`. | Same as above. |

---

### Where the rules come from

All the patterns above are installed from one of:

- `~/.claude/settings.json` — user scope, installed by `agent-workflow-training/install.sh` (or `.ps1`)
- `<project>/.claude/settings.json` — project scope, installed when you run the installer with `--project`

You can inspect them yourself: `cat ~/.claude/settings.json` (you'll see it because `.json` isn't `.env`).

### Disabling or relaxing a rule

Don't disable patterns ad-hoc. If a rule is wrong:

- **Genuine false positive** — file an issue (or PR) against [`agent-workflow-training`](https://github.com/Bestme-admin/agent-workflow-training). Include the tool call that was blocked and why it's safe.
- **You need a one-shot bypass** — close Claude Code, do the operation yourself in your shell, restart Claude Code. Don't edit the deny list to make the deny go away.
- **Project-specific exemption** — extend the deny list in `<project>/.claude/settings.json`, don't weaken the user-scope rules.

The framework's principle: rules that exist exist because someone learned them the hard way. Treat the deny list as a record of incidents, not a list of nuisances.

---

## Русский

### Как видны deny-ошибки

Когда Claude Code отказывает в tool call'е, в терминале вы увидите одну из двух форм сообщения:

1. **`Tool use X denied by permissions.deny pattern: <pattern>`** — сработал glob из `permissions.deny` в `settings.json`. Быстро, дёшево, выполняется до любого хука. Сам шаблон — единственный контекст; ищите его ниже.
2. **Кастомное сообщение от хука** (например, `"Blocked: shell command touches a .env file. Secrets stay out of agent context..."`) — отработал PreToolUse-хук и вернул структурированный отказ. Эти сообщения объясняют себя inline; этот документ для них обычно не нужен.

Этот документ описывает шаблоны `permissions.deny`, потому что их экранный текст краток.

---

### Доступ к файлам `.env`

| Шаблон (пример) | Почему запрещено | Что делать вместо |
|---|---|---|
| `Read(**/.env)`, `Read(**/.env.*)` | Секреты из `.env` не должны попадать в контекст агента. Попав туда, они кешируются, сохраняются в транскрипте и путешествуют с каждым промптом. | Читайте `.env.example` (закоммиченный шаблон) для *имён* переменных. Если агенту нужно конкретное значение — сообщите только его в чате. |
| `Edit(**/.env)`, `Write(**/.env)` | Та же причина, что и для чтения, плюс: написанные агентом `.env`-файлы часто случайно коммитятся. | Редактируйте `.env` сами в своём редакторе. Обновляйте `.env.example`, если добавляете новую переменную. |
| `Bash(cat .env*)`, `Bash(less .env*)`, `Bash(head .env*)`, `Bash(tail .env*)`, `Bash(bat .env*)`, `Bash(xxd .env*)`, `Bash(strings .env*)` и т. п. | Чтение `.env` через shell — та же утечка секретов, что и через Tool-level Read. | Аналогично выше. |
| `Bash(source .env*)`, `Bash(. .env*)` | Source/dot-sourcing исполняет файл в shell, секреты попадают в env vars, которые видят последующие команды агента. | Source-те его в *своём* shell перед запуском Claude, потом передавайте нужные значения через промпт. |
| `Bash(cp .env* **)`, `Bash(mv .env* **)`, `Bash(Copy-Item .env* **)`, `Bash(Move-Item .env* **)` | Копирование/перемещение `.env` часто прелюдия к подготовке к коммиту или «бэкапу», который потом расшарят. | Не двигайте `.env`-файлы через агента. |
| `PowerShell(Get-Content .env*)`, `PowerShell(gc .env*)`, `PowerShell(type .env*)`, `PowerShell(cat .env*)` | PowerShell-эквиваленты Bash-чтений — тот же контент секрета. | Аналогично выше. |

---

### Доступ к приватным ключам

| Шаблон (пример) | Почему запрещено | Что делать вместо |
|---|---|---|
| `Read(**/*.pem)`, `Read(**/*.key)`, `Read(**/id_rsa)`, `Read(**/id_ed25519)` | Приватный криптоматериал не должен попадать в контекст агента — та же логика, что и для `.env`, плюс ключи обычно нельзя «отозвать» оперативно. | Если агенту нужно знать, *что* ключ существует — запустите `ls -la ~/.ssh/` сами. Если агенту нужен контент ключа — почти всегда это неправильный путь, отказывайте. |
| `Bash(cat *.pem)`, `Bash(cat **/id_rsa)` и т. п. | Shell-чтения тех же файлов. | Аналогично выше. |

---

### Разрушительные Bash / PowerShell

| Шаблон (пример) | Почему запрещено | Что делать вместо |
|---|---|---|
| `Bash(rm -rf /*)`, `Bash(rm -rf ~*)`, `Bash(rm -rf $HOME*)`, `Bash(sudo rm*)` | Невосстановимо, blast radius — вся машина. Почти никогда не правильный способ очистки. | Будьте конкретны: `rm <файл>` или `rm -rf <имя-подпапки>`. Если действительно нужно затереть директорию — делайте сами. |
| `Bash(git push --force origin main*)`, `Bash(git push -f origin main*)`, `Bash(git push --force origin master*)` | Force-push в общую ветку уничтожает работу коллег. | Используйте feature-ветку и обычный `git push`. Открывайте PR. |
| `Bash(git reset --hard origin/main*)`, `Bash(git reset --hard origin/master*)` | Сбрасывает локальную работу без возможности восстановить. | Если действительно нужен reset, делайте после `git stash` или ветвления от текущего состояния. |
| `Bash(git branch -D main*)`, `Bash(git branch -D master*)` | Удаляет main-ветку локально — почти всегда ошибка. | Переключайте ветки через `git switch`, не удаляйте защищённую. |
| `Bash(git clean -fdx*)` | Удаляет игнорируемые файлы, в т.ч. возможно незакоммиченную локальную конфигурацию. | `git clean -fd` (без `-x`) не трогает `.gitignore`d файлы; или чистите конкретные пути. |
| `Bash(npm publish*)`, `Bash(pnpm publish*)` | Публикует версию пакета в публичный registry — необратимо. | Запускайте publish сами, после ревью содержимого пакета и version bump. |
| `Bash(gh repo delete*)` | Самоочевидно. | Не надо. |
| `Bash(gh auth logout*)` | Стирает auth-учётки из gh keyring — затрагивает будущие сессии, которые вы можете не отслеживать, и несвязанные проекты на той же машине. | Если нужно переключить активный аккаунт — используйте `gh auth switch -u <user>` (обратимо). |
| `PowerShell(Remove-Item -Recurse -Force /*)`, `PowerShell(Remove-Item -Recurse -Force ~*)` | PowerShell-эквивалент `rm -rf /` и `rm -rf ~`. | Аналогично выше. |

---

### Откуда берутся правила

Все шаблоны выше устанавливаются из одного из:

- `~/.claude/settings.json` — user-scope, ставится через `agent-workflow-training/install.sh` (или `.ps1`)
- `<project>/.claude/settings.json` — project-scope, ставится при запуске установщика с `--project`

Можете посмотреть сами: `cat ~/.claude/settings.json` (вам можно — это `.json`, а не `.env`).

### Отключение или ослабление правила

Не отключайте шаблоны ad-hoc. Если правило неверно:

- **Настоящий false positive** — заводите issue (или PR) в [`agent-workflow-training`](https://github.com/Bestme-admin/agent-workflow-training). Приложите tool call, который был заблокирован, и почему он безопасен.
- **Нужен one-shot bypass** — закройте Claude Code, сделайте операцию сами в своём shell, перезапустите Claude Code. Не редактируйте deny-list, чтобы убрать deny.
- **Project-specific исключение** — расширяйте deny-list в `<project>/.claude/settings.json`, не ослабляйте user-scope правила.

Принцип фреймворка: правила существуют, потому что кто-то узнал их трудным путём. Воспринимайте deny-list как запись инцидентов, а не как список раздражителей.
