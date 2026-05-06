# claude-auto-reset

Автопинг **Claude Code** по расписанию, чтобы не ждать «пока сам откроешь чат».

- [Claude](https://claude.ai/) - сам чат/модель  
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) - CLI `claude` в терминале  
- [Anthropic](https://www.anthropic.com/) - кто это всё делает и какие лимиты

## Зачем

У многих лимит ведёт себя так: **отсчёт завязан на первое сообщение в сессии**. Долго не писал - картина с «когда обновится» другая. Скрипт раз в несколько часов дергает `claude -p` с крошечным текстом - как будто ты написал первое сообщение, только по таймеру.

Сработает ли это именно на твоём тарифе - только у них в правилах. Тут только автозапуск.

## РФ

Нужен нормальный **VPN** до сервисов.  
**ПК включён** в момент срабатывания задачи (спящий ПК задачу не выполнит; ночью - настраивай сон сам).

## Что сделать (коротко)

1. Поставь [Claude Code](https://docs.anthropic.com/en/docs/claude-code), в терминале команда `claude` должна находиться (PATH). Один раз залогинься вручную.
2. Склонируй репозиторий или скачай zip.
3. Автоматом повесь расписание (см. ниже) или настрой руками. Интервал **короче пяти часов** имеет смысл, часто ставят каждые **4**.

## Какой файл куда

| ОС | Файл |
|----|------|
| Windows (пинг один раз) | `windows/ping-claude.bat` |
| Windows (задача в планировщике двойным кликом) | `windows/schedule-install.bat` / снять: `windows/schedule-remove.bat` |
| Linux | `linux/ping-claude.sh` |
| macOS | `macos/ping-claude.sh` |

Пауза при исчерпании лимита: логика во вложенной папке **`windows/internal/`**, трогать вручную не нужно — вызывает только `ping-claude.bat`.

Краткие шпаргалки по файлам: **`README.ru.txt`** (русский) и **`README.en.txt`** (English). Содержание одно и то же. В корне **`README.txt`** — только указатель на эти два файла.

**Linux / macOS:** после `git clone` скрипты уже исполняемые. Если скачал zip и `permission denied` - из корня репо один раз: `bash install.sh`.

## Автопостановка расписания

**Windows:** проще **`windows/schedule-install.bat`** двойным кликом (он вызывает `ping-claude.bat schedule-install`). Либо из **cmd**:

```bat
"C:\полный\путь\к\repo\windows\ping-claude.bat" schedule-install
```

Снимает задачу планировщика:

```bat
"C:\полный\путь\...\ping-claude.bat" schedule-remove
```

Создаётся задача **`claude-auto-reset`**, раз в **4 часа**, под тем юзером, от которого ты запустил установку (`schtasks`). Если ошибка доступа - тот же `schedule-install` из cmd **от администратора** или задачу вручную в `taskschd.msc`.

Обычный «пинг» без аргумента - как раньше (одноразово).

**Linux и macOS** (одно и то же по командам, разные только путь к своему `ping-claude.sh`):

```bash
/path/to/repo/linux/ping-claude.sh cron-install
```

Лог по умолчанию: **`/tmp/claude-auto-reset.log`**. Убрать из crontab блок:

```bash
/path/to/repo/linux/ping-claude.sh cron-remove
```

Cron вызывает скрипт с аргументом **`run`** (сам добавляется в строку) - не трогай руками, если ставил `cron-install`.

**macOS:** на свежих системах доступ к cron урезан, если не срабатывает - смотри настройки **Full Disk Access** для `cron`/`Terminal` или повесь то же через **launchd** вручную.

## Ручная настройка (если авто не зашло)

### Windows

Планировщик заданий: каждые 4 часа запуск **`cmd.exe /c "полный путь к ping-claude.bat"`**.

### Linux

Пример строки без автоскрипта:

```
0 */4 * * * /home/ты/claude-auto-reset/linux/ping-claude.sh run >> /tmp/claude-ping.log 2>&1
```

### macOS

Тот же принцип в `crontab -e` или **launchd**.

## Если в логе «не является командой» или код 9009 (Windows)

В PowerShell выполни `Get-Command claude` и посмотри **Source**. Впиши путь в `ping-claude.bat` строкой `set "CLAUDE_EXE=..."` после `rem`. Батник подмешивает в PATH типичные каталоги, но планировщик может стартовать с пустым PATH.

## Если `claude` не находится

- **Windows:** см. абзац выше.
- **Linux / macOS:** перед запуском `export CLAUDE_EXE=/полный/путь/к/claude`

## Подкрутка внутри скриптов

Вверху файла (до логики пинга): `msg` в `-p`, `tries`, пауза между попытками.
