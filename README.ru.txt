claude-auto-reset — какой файл запускать
=========================================

Windows
-------

1) Разовый прогон (проверка, что в PATH есть claude):

   windows\ping-claude.bat

   Двойной щелчок или запуск из cmd.

2) Поставить задачу в Планировщик (по умолчанию каждые 4 ч 50 мин, задача claude-auto-reset):

   windows\schedule-install.bat

   Убрать задачу:

   windows\schedule-remove.bat

   Из cmd можно так: ping-claude.bat schedule-install  и  ping-claude.bat schedule-remove

3) пауза при лимите и при необходимости сдвиг задачи в Планировщике — в папке
   windows\internal (не трогай руками). После успешного пинга снова ставится интервал
   **4 ч 50 мин** (через `schedule-install`), если задача до этого была переведена
   в режим «один раз к моменту сброса».

Подсказка: текст в окне после запуска .bat может быть по-английски —
так надёжнее для консоли Windows (кодовая страница). Смысл — в этом файле.

Linux и macOS
-------------

Разово: linux/ping-claude.sh или macos/ping-claude.sh.

Cron установка и снятие: те же скрипты с аргументами cron-install и cron-remove.

Подробно — см. README.md

English cheatsheet — README.en.txt
