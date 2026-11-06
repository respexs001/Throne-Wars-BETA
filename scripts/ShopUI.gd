class_name ShopUI
extends PanelContainer
## ShopUI.gd — магазин: категории слева, карточки предметов по центру, справа описание, покупка, сумка курьера.
## Рядом с базой покупки идут в инвентарь, вдали - в сумку курьера (его нужно позвать). Продажа - только на базе.

const CATS: Array = [
    ["Рекомендуемые", []],
    ["Расходники", ["health_potion", "mana_potion", "tp_scroll"]],
    ["Атрибуты", ["iron_branch", "ogre_axe", "blade_alacrity", "staff_wizardry", "vitality", "energy", "ring_health", "boots", "arcane_orb", "battle_boots"]],
    ["Оружие", ["blade_attack", "gloves", "crystalys", "butterfly", "warlord_blade"]],
    ["Защита", ["chainmail", "cloak", "vanguard", "mekansm", "heart", "bulwark", "mage_cloak", "titan_plate"]],
    ["Активные", ["tp_scroll", "blink_dagger", "dagon", "bkb", "mekansm"]],
    ["Рецепты", ["battle_boots", "bulwark", "arcane_orb", "warlord_blade", "mage_cloak", "titan_plate"]],
    ["Все предметы", []],
]
const STAT_LABELS: Dictionary = {
    "str": ["Сила", 1.0], "agi": ["Ловкость", 1.0], "int": ["Интеллект", 1.0], "hp": ["Здоровье", 1.0], "mp": ["Мана", 1.0],
    "dmg": ["Урон", 1.0], "armor": ["Броня", 1.0], "mr": ["Сопротивление магии, %", 100.0], "block": ["Блок урона", 1.0],
    "aspd": ["Скорость атаки", 1.0], "ms": ["Скорость бега", 1.0], "hp_regen": ["Реген HP", 1.0], "mp_regen": ["Реген MP", 1.0],
    "evasion": ["Уклонение, %", 100.0], "crit": ["Шанс крита, %", 100.0], "lifesteal": ["Вампиризм, %", 100.0],
}

var hero: BaseHero
var _cat: int = 0
var _grid: GridContainer
var _info: RichTextLabel
var _buy_btn: Button
var _status: Label
var _gold_lbl: Label
var _courier_lbl: Label
var _cards: Array = []
var _sell_slots: Array = []
var _stash_slots: Array = []
var _selected: String = ""
var _last_click: int = 0
var _acc: float = 0.0
var embedded: bool = false
var _search: LineEdit
var _sort: int = 0
var _sort_btn: Button


func setup(h: BaseHero) -> void:
    hero = h
    var tabs_w: float = 120.0 if embedded else 150.0
    var scroll_w: float = 400.0 if embedded else 560.0
    var cols: int = 3 if embedded else 4
    var right_w: float = 260.0 if embedded else 300.0
    var root := HBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    add_child(root)

    # --- категории ---
    var tabs := VBoxContainer.new()
    tabs.custom_minimum_size = Vector2(tabs_w, 0.0)
    tabs.add_theme_constant_override("separation", 5)
    root.add_child(tabs)
    var build_picker := OptionButton.new()
    for guide in BuildGuide.choices(hero.hero_id): build_picker.add_item(guide["name"])
    build_picker.selected = hero.build_choice
    build_picker.item_selected.connect(func(index: int) -> void:
        hero.build_choice = index
        _set_cat(_cat)
    )
    tabs.add_child(build_picker)
    var title := Label.new()
    title.text = "МАГАЗИН"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    tabs.add_child(title)
    var group := ButtonGroup.new()
    for i in CATS.size():
        var b := Button.new()
        b.text = CATS[i][0]
        b.toggle_mode = true
        b.button_group = group
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(tabs_w, 38.0)
        b.pressed.connect(_set_cat.bind(i))
        tabs.add_child(b)
        if i == 0:
            b.button_pressed = true
    var sp := Control.new()
    sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.add_child(sp)
    var close := Button.new()
    close.text = "Закрыть (F4)"
    close.focus_mode = Control.FOCUS_NONE
    close.custom_minimum_size = Vector2(tabs_w, 38.0)
    close.pressed.connect(toggle)
    tabs.add_child(close)
    close.visible = not embedded

    # --- карточки и продажа ---
    var center := VBoxContainer.new()
    center.add_theme_constant_override("separation", 8)
    root.add_child(center)
    _gold_lbl = Label.new()
    _gold_lbl.add_theme_font_size_override("font_size", 17)
    _gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    center.add_child(_gold_lbl)
    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 6)
    center.add_child(srow)
    _search = LineEdit.new()
    _search.placeholder_text = "Поиск предмета..."
    _search.custom_minimum_size = Vector2(220.0, 32.0)
    _search.text_changed.connect(func(_t: String) -> void: _set_cat(_cat))
    srow.add_child(_search)
    _sort_btn = Button.new()
    _sort_btn.text = "Сортировка: стандарт"
    _sort_btn.focus_mode = Control.FOCUS_NONE
    _sort_btn.pressed.connect(_cycle_sort)
    srow.add_child(_sort_btn)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(scroll_w, 300.0)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    center.add_child(scroll)
    _grid = GridContainer.new()
    _grid.columns = cols
    _grid.add_theme_constant_override("h_separation", 6)
    _grid.add_theme_constant_override("v_separation", 6)
    scroll.add_child(_grid)
    var sl := Label.new()
    sl.text = "Твои предметы (клик - продать за 50%, только на базе):"
    sl.add_theme_font_size_override("font_size", 12)
    center.add_child(sl)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    center.add_child(row)
    for i in 6:
        var s := ItemSlot.new()
        s.index = i
        s.custom_minimum_size = Vector2(54.0, 46.0)
        s.pressed.connect(_on_sell)
        row.add_child(s)
        _sell_slots.append(s)

    # --- описание, покупка, курьер ---
    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(right_w, 0.0)
    right.add_theme_constant_override("separation", 8)
    root.add_child(right)
    _info = RichTextLabel.new()
    _info.bbcode_enabled = true
    _info.custom_minimum_size = Vector2(right_w, 170.0)
    _info.add_theme_font_size_override("normal_font_size", 14)
    right.add_child(_info)
    _buy_btn = Button.new()
    _buy_btn.focus_mode = Control.FOCUS_NONE
    _buy_btn.custom_minimum_size = Vector2(right_w, 44.0)
    _buy_btn.pressed.connect(func() -> void: _buy(_selected))
    right.add_child(_buy_btn)
    var qrow := HBoxContainer.new()
    qrow.add_theme_constant_override("separation", 6)
    right.add_child(qrow)
    var auto_btn := Button.new()
    auto_btn.text = "Купить по сборке"
    auto_btn.focus_mode = Control.FOCUS_NONE
    auto_btn.tooltip_text = "Покупает следующий предмет рекомендованной сборки героя"
    auto_btn.pressed.connect(_auto_buy)
    qrow.add_child(auto_btn)
    var undo_btn := Button.new()
    undo_btn.text = "Вернуть покупку"
    undo_btn.focus_mode = Control.FOCUS_NONE
    undo_btn.tooltip_text = "Полный возврат за 10 секунд после покупки"
    undo_btn.pressed.connect(_undo)
    qrow.add_child(undo_btn)
    _status = Label.new()
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.custom_minimum_size = Vector2(right_w, 36.0)
    _status.add_theme_font_size_override("font_size", 12)
    right.add_child(_status)
    var cl := Label.new()
    cl.text = "Курьер"
    cl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    right.add_child(cl)
    _courier_lbl = Label.new()
    _courier_lbl.add_theme_font_size_override("font_size", 12)
    right.add_child(_courier_lbl)
    var stash_row := HBoxContainer.new()
    stash_row.add_theme_constant_override("separation", 3)
    right.add_child(stash_row)
    for i in 6:
        var s2 := ItemSlot.new()
        s2.index = i
        s2.custom_minimum_size = Vector2(44.0, 38.0)
        stash_row.add_child(s2)
        _stash_slots.append(s2)
    var cb := HBoxContainer.new()
    cb.add_theme_constant_override("separation", 6)
    right.add_child(cb)
    var call := Button.new()
    call.text = "Позвать курьера"
    call.focus_mode = Control.FOCUS_NONE
    call.pressed.connect(_call_courier)
    cb.add_child(call)
    var home := Button.new()
    home.text = "Домой"
    home.focus_mode = Control.FOCUS_NONE
    home.pressed.connect(func() -> void:
        if hero.courier != null:
            hero.courier.call_home())
    cb.add_child(home)
    _set_cat(0)


func toggle() -> void:
    visible = not visible
    _status.text = ""
    if not visible:
        _search.release_focus()
    if visible:
        modulate.a = 0.0
        create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func near_shop() -> bool:
    return Global.flat_dist(hero.global_position, Global.throne_pos(hero.team)) <= Global.SHOP_RADIUS


func _ids_for(i: int) -> Array:
    if i == 0:
        return BuildGuide.items(hero.hero_id, hero.build_choice)
    if i == CATS.size() - 1:
        return Global.ITEM_ORDER
    return CATS[i][1]


func _set_cat(i: int) -> void:
    _cat = i
    for c in _grid.get_children():
        c.queue_free()
    _cards.clear()
    var rec: Array = BuildGuide.items(hero.hero_id, hero.build_choice)
    for id in _filtered_ids(i):
        var card := ShopCard.new()
        card.item_id = id
        card.recommended = rec.has(id)
        card.pressed.connect(_on_card)
        card.hovered.connect(_on_hover)
        _grid.add_child(card)
        _cards.append(card)
    var ids := _filtered_ids(i)
    _select(String(ids[0]) if ids.size() > 0 else "")


func _on_card(id: String) -> void:
    var now := Time.get_ticks_msec()
    if _selected == id and now - _last_click < 700:
        _buy(id)
    _select(id)
    _last_click = now


func _on_hover(id: String) -> void:
    _show_info(_selected if id == "" else id)


func _select(id: String) -> void:
    _selected = id
    _show_info(id)
    if id == "":
        _buy_btn.text = "Выберите предмет"
    else:
        var item: Dictionary = Global.ITEMS[id]
        _buy_btn.text = "Купить: %d зол." % Global.item_price(hero.inventory, id)


func _show_info(id: String) -> void:
    if id == "" or not Global.ITEMS.has(id):
        _info.text = ""
        return
    var item: Dictionary = Global.ITEMS[id]
    var lines: Array = []
    lines.append("[font_size=19][b][color=#ffe08a]%s[/color][/b][/font_size]" % item["name"])
    lines.append("[color=#ffd54a]Цена: %d (с учётом ваших компонентов: %d)[/color]" % [int(item["cost"]), Global.item_price(hero.inventory, id)])
    if item.has("recipe"):
        var names: Array = []
        for comp in item["recipe"]:
            names.append(String((Global.ITEMS[comp] as Dictionary)["name"]))
        lines.append("[color=#9fe0a0]Сборка: %s[/color]" % " + ".join(names))
    lines.append("[color=#ddd]%s[/color]" % item["desc"])
    lines.append("\n" + str(BuildGuide.choices(hero.hero_id)[hero.build_choice]["tip"]))
    var st: Dictionary = item["stats"]
    for k in st:
        if STAT_LABELS.has(k):
            var info: Array = STAT_LABELS[k]
            lines.append("+%s  %s" % [("%.1f" % (float(st[k]) * float(info[1]))).trim_suffix(".0"), info[0]])
    if item.has("active"):
        var act: Dictionary = item["active"]
        lines.append("[color=#9fb4ff]Активный предмет, перезарядка %d с[/color]" % int(act["cd"]))
    _info.text = "\n".join(lines)


func _process(delta: float) -> void:
    if not visible or hero == null:
        return
    _acc += delta
    if _acc < 0.1:
        return
    _acc = 0.0
    _gold_lbl.text = "Золото: %d    %s" % [hero.gold, "Вы у базы: покупка в инвентарь" if near_shop() else "Вдали от базы: покупки уйдут курьеру"]
    for c in _cards:
        var card: ShopCard = c
        var item: Dictionary = Global.ITEMS[card.item_id]
        var eff := Global.item_price(hero.inventory, card.item_id)
        card.price = eff
        card.affordable = hero.gold >= eff
        var itm: Dictionary = Global.ITEMS[card.item_id]
        if itm.has("recipe"):
            var pool: Array = hero.inventory.duplicate()
            var have := 0
            for comp in itm["recipe"]:
                var k := pool.find(comp)
                if k != -1:
                    pool.remove_at(k)
                    have += 1
            card.parts_have = have
            card.parts_total = (itm["recipe"] as Array).size()
        card.queue_redraw()
    for i in 6:
        var sl: ItemSlot = _sell_slots[i]
        sl.item_id = hero.inventory[i]
        sl.queue_redraw()
        var st: ItemSlot = _stash_slots[i]
        var cr := hero.courier
        st.item_id = String(cr.stash[i]) if cr != null and i < cr.stash.size() else ""
        st.queue_redraw()
    var cr2 := hero.courier
    if cr2 == null:
        _courier_lbl.text = "нет курьера"
    elif not cr2.alive:
        _courier_lbl.text = "уничтожен, возродится через %d с" % int(ceilf(cr2._respawn_t))
    else:
        _courier_lbl.text = ["ждёт на базе", "летит к вам", "возвращается"][cr2.state] + ", в сумке: %d" % cr2.stash.size()


func _buy(id: String) -> void:
    if id == "":
        return
    var item: Dictionary = Global.ITEMS[id]
    var cost: int = item["cost"]
    var eff: int = Global.item_price(hero.inventory, id) if near_shop() else cost
    if hero.gold < eff:
        _status.text = "Не хватает золота."
        return
    if near_shop():
        if hero.buy_item(id):
            _status.text = "Куплено: %s" % item["name"]
            Global.sfx("gold", -10.0)
        else:
            _status.text = "Нет места в инвентаре."
        return
    var c := hero.courier
    if c == null or not c.alive:
        _status.text = "Курьер недоступен. Вернись на базу."
    elif c.stash.size() >= 6:
        _status.text = "Сумка курьера полна."
    else:
        hero.gold -= cost
        c.stash.append(id)
        _status.text = "Куплено: курьер привезёт. Нажми «Позвать курьера»."
        Global.sfx("gold", -10.0)


func _on_sell(slot: int) -> void:
    if not near_shop():
        _status.text = "Продавать можно только на базе."
    elif hero.sell_item(slot):
        _status.text = "Продано."


func _call_courier() -> void:
    var c := hero.courier
    if c != null and c.deliver_to(hero):
        _status.text = "Курьер летит к вам."
    else:
        _status.text = "У курьера нет предметов."


func _filtered_ids(i: int) -> Array:
    var ids: Array = _ids_for(i).duplicate()
    var q := _search.text.strip_edges().to_lower() if _search != null else ""
    if q != "":
        var out: Array = []
        for id in ids:
            var item: Dictionary = Global.ITEMS[id]
            if String(item["name"]).to_lower().contains(q) or String(item["desc"]).to_lower().contains(q):
                out.append(id)
        ids = out
    match _sort:
        1:
            ids.sort_custom(func(a, b) -> bool: return int(Global.ITEMS[a]["cost"]) < int(Global.ITEMS[b]["cost"]))
        2:
            ids.sort_custom(func(a, b) -> bool: return int(Global.ITEMS[a]["cost"]) > int(Global.ITEMS[b]["cost"]))
        3:
            ids.sort_custom(func(a, b) -> bool: return String(Global.ITEMS[a]["name"]) < String(Global.ITEMS[b]["name"]))
    return ids


func _cycle_sort() -> void:
    _sort = (_sort + 1) % 4
    _sort_btn.text = "Сортировка: " + ["стандарт", "цена вверх", "цена вниз", "по имени"][_sort]
    _set_cat(_cat)


func _auto_buy() -> void:
    for id in BuildGuide.items(hero.hero_id, hero.build_choice):
        if id == "boots" and hero.inventory.has("battle_boots"):
            continue
        if not hero.inventory.has(id):
            var price := Global.item_price(hero.inventory, id)
            _select(id)
            if hero.gold >= price:
                _buy(id)
            else:
                _status.text = "Следующий по сборке: %s. Нужно золота: %d" % [(Global.ITEMS[id] as Dictionary)["name"], price]
            return
    _status.text = "Рекомендованная сборка уже куплена."


func _undo() -> void:
    if hero.undo_purchase():
        _status.text = "Покупка возвращена."
    else:
        _status.text = "Нечего возвращать (10 секунд после покупки, без сборных)."
