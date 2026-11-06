# Воспроизводимая Windows-сборка

Используйте Godot 4.7.2 standard и экспортные шаблоны **той же версии**. Шаблоны 4.6.2 не подходят.

Официальный источник: https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable . Из `Godot_v4.7.2-stable_export_templates.tpz` нужны `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`, `version.txt`.

```powershell
python tools/test.py --godot "C:/path/to/Godot.exe" --suite core
python tools/build_windows.py --godot "C:/path/to/Godot.exe" --templates "C:/path/to/4.7.2.stable"
python tools/test_windows.py "build/windows/ThroneWars-1.0.3-alpha.1-candidate.zip"
python tools/test_windows.py "build/windows/ThroneWars-1.0.3-alpha.1-candidate.zip" --benchmark --report-dir artifacts/windows-benchmark
```

Сборщик создаёт временную экспортную копию исходников и изолированный APPDATA. Настоящие accounts.cfg/settings.cfg не читаются и не входят в пакет. ZIP, контрольная сумма и manifest находятся в build/windows. Файлы build не коммитятся.

Официальные шаблоны 4.7.2 не разрешают подменять пути и запускать внешние сценарии через `--script`. Проверка EXE использует встроенный фиксированный сценарий `-- --verify-runtime`, только при THRONE_WARS_TEST=1 и пользовательском каталоге внутри временного `thronewars-runtime-*`. Он проверяет гостевые матчи и пишет отчёт в тестовые данные; произвольный код и административный доступ не открываются. Инструмент распаковывает ZIP во временный каталог и читает JSON с явными условиями: GDScript assert в release отключён.

Замер запускает именно экспортированный release EXE: среднее качество, 1280×720, скорость ×1, фиксированное начальное состояние 1093, 120 с прогрева и 60 с измерения. На время замера не управляйте игрой; пауза делает результат недействительным. Проводите замер после завершения параллельных прогонов. Тест автоматически закрывает своё окно и сохраняет JSON. Графика и ИИ работают штатно; основной пользовательский профиль не читается.

Сборщик сохраняет SHA-256 исходных игровых файлов, EXE и шаблона в manifest. Проверка ZIP сверяет хэш EXE и версию manifest с запущенной игрой. Файловые метаданные EXE пока остаются от шаблона: rcedit и цифровая подпись в эту сборку не входят. Версия игры указана в меню, README и manifest.

Для релиза: выполните acceptance, графическую проверку и внешний тест по docs/VALIDATION.md. До закрытия всех критериев пакет является кандидатом для тестирования, а не одобренным релизом. Публиковать ZIP через GitHub Releases с тегом v1.0.3-alpha.1; секреты и учётные данные не добавлять в экспортный пресет.
