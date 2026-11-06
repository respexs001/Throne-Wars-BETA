# Воспроизводимая Windows-сборка

Используйте Godot 4.7.2 standard и экспортные шаблоны **той же версии**. Шаблоны 4.6.2 не подходят.

Официальный источник: https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable . Из `Godot_v4.7.2-stable_export_templates.tpz` нужны `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`, `version.txt`.

```powershell
python tools/test.py --godot "C:/path/to/Godot.exe" --suite core
python tools/build_windows.py --godot "C:/path/to/Godot.exe" --templates "C:/path/to/4.7.2.stable"
```

Сборщик создаёт временную экспортную копию исходников и изолированный APPDATA. Настоящие accounts.cfg/settings.cfg не читаются и не входят в пакет. ZIP, контрольная сумма и manifest находятся в build/windows. Файлы build не коммитятся.

Для релиза: выполните acceptance, графическую проверку и внешний тест по docs/VALIDATION.md. До закрытия всех критериев пакет является кандидатом для тестирования, а не одобренным релизом. Публиковать ZIP через GitHub Releases с тегом v1.0.3-alpha.1; секреты и учётные данные не добавлять в экспортный пресет.
