class_name IconPainter
extends RefCounted
## IconPainter.gd — векторные иконки способностей и предметов. Рисуются кодом внутри _draw() любого Control.


static func _pts(cen: Vector2, k: float, arr: Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    for p in arr:
        out.append(cen + (p as Vector2) * k)
    return out


static func _star(cen: Vector2, k: float, n: int, inner: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in n * 2:
        var a := -PI / 2.0 + PI * float(i) / float(n)
        var r := k if i % 2 == 0 else k * inner
        out.append(cen + Vector2(cos(a), sin(a)) * r)
    return out


static func paint(c: CanvasItem, r: Rect2, icon: String, col: Color) -> void:
    c.draw_rect(r, col.darkened(0.72))
    c.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), col.darkened(0.55))
    c.draw_rect(Rect2(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0)), col.darkened(0.1), false, 1.0)
    var cen := r.get_center()
    var k := minf(r.size.x, r.size.y) * 0.36
    var light := col.lightened(0.6)
    var mid := col.lightened(0.2)
    match icon:
        "fire":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(0, -1), Vector2(0.35, -0.45), Vector2(0.6, 0.05), Vector2(0.45, 0.6), Vector2(0, 1), Vector2(-0.45, 0.6), Vector2(-0.6, 0.05), Vector2(-0.3, -0.4)]), Color(1.0, 0.5, 0.1))
            c.draw_colored_polygon(_pts(cen + Vector2(0, k * 0.25), k * 0.55, [Vector2(0, -1), Vector2(0.5, 0.0), Vector2(0.4, 0.7), Vector2(0, 1), Vector2(-0.4, 0.7), Vector2(-0.5, 0.0)]), Color(1.0, 0.9, 0.3))
        "bolt":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(0.15, -1), Vector2(-0.55, 0.15), Vector2(-0.1, 0.15), Vector2(-0.3, 1), Vector2(0.55, -0.2), Vector2(0.08, -0.2)]), Color(1.0, 0.95, 0.35))
        "ice":
            for i in 3:
                var d := Vector2.from_angle(PI / 3.0 * float(i))
                c.draw_line(cen + d * k, cen - d * k, Color(0.8, 0.95, 1.0), 2.5)
                var t := Vector2.from_angle(PI / 3.0 * float(i) + PI / 2.0) * k * 0.25
                c.draw_line(cen + d * k * 0.7 + t, cen + d * k * 0.7 - t, Color(0.8, 0.95, 1.0), 2.0)
                c.draw_line(cen - d * k * 0.7 + t, cen - d * k * 0.7 - t, Color(0.8, 0.95, 1.0), 2.0)
        "shield":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, 0.1), Vector2(0, 1), Vector2(-0.8, 0.1)]), light)
            c.draw_colored_polygon(_pts(cen, k * 0.7, [Vector2(-0.8, -0.85), Vector2(0.8, -0.85), Vector2(0.8, 0.1), Vector2(0, 1), Vector2(-0.8, 0.1)]), col.darkened(0.2))
        "skull":
            c.draw_circle(cen + Vector2(0, -k * 0.15), k * 0.75, light)
            c.draw_rect(Rect2(cen + Vector2(-k * 0.38, k * 0.3), Vector2(k * 0.76, k * 0.6)), light)
            c.draw_circle(cen + Vector2(-k * 0.28, -k * 0.15), k * 0.2, col.darkened(0.7))
            c.draw_circle(cen + Vector2(k * 0.28, -k * 0.15), k * 0.2, col.darkened(0.7))
        "arrow":
            c.draw_line(cen + Vector2(-0.9, 0.9) * k, cen + Vector2(0.6, -0.6) * k, light, 3.0)
            c.draw_colored_polygon(_pts(cen, k, [Vector2(1.0, -1.0), Vector2(0.15, -0.7), Vector2(0.7, -0.15)]), Color.WHITE)
            c.draw_line(cen + Vector2(-0.9, 0.9) * k, cen + Vector2(-0.9, 0.35) * k, mid, 2.0)
            c.draw_line(cen + Vector2(-0.9, 0.9) * k, cen + Vector2(-0.35, 0.9) * k, mid, 2.0)
        "wind":
            for j in 3:
                var pl := PackedVector2Array()
                for s in 12:
                    var x := -1.0 + 2.0 * float(s) / 11.0
                    pl.append(cen + Vector2(x, -0.55 + 0.55 * float(j) + sin(x * 3.2 + float(j)) * 0.18) * k)
                c.draw_polyline(pl, light, 2.5)
        "heart":
            c.draw_circle(cen + Vector2(-0.38, -0.25) * k, k * 0.5, Color(1.0, 0.4, 0.5))
            c.draw_circle(cen + Vector2(0.38, -0.25) * k, k * 0.5, Color(1.0, 0.4, 0.5))
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.86, -0.1), Vector2(0.86, -0.1), Vector2(0, 0.95)]), Color(1.0, 0.4, 0.5))
        "star":
            c.draw_colored_polygon(_star(cen, k, 5, 0.42), Color(1.0, 0.92, 0.45))
        "moon":
            c.draw_circle(cen, k * 0.9, Color(0.92, 0.95, 1.0))
            c.draw_circle(cen + Vector2(k * 0.45, -k * 0.2), k * 0.78, col.darkened(0.6))
        "boots":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.5, -0.9), Vector2(0.1, -0.9), Vector2(0.1, 0.1), Vector2(0.85, 0.4), Vector2(0.85, 0.9), Vector2(-0.5, 0.9)]), Color(0.85, 0.65, 0.4))
        "ring":
            c.draw_arc(cen + Vector2(0, k * 0.15), k * 0.6, 0.0, TAU, 24, Color(1.0, 0.85, 0.3), 4.0)
            c.draw_circle(cen + Vector2(0, -k * 0.5), k * 0.25, Color(0.4, 1.0, 0.7))
        "potion_hp", "potion_mp":
            var liq := Color(1.0, 0.3, 0.35) if icon == "potion_hp" else Color(0.3, 0.55, 1.0)
            c.draw_rect(Rect2(cen + Vector2(-0.2, -0.95) * k, Vector2(0.4, 0.6) * k), Color(0.85, 0.9, 0.95))
            c.draw_circle(cen + Vector2(0, 0.3) * k, k * 0.65, Color(0.85, 0.9, 0.95))
            c.draw_circle(cen + Vector2(0, 0.3) * k, k * 0.5, liq)
        "scroll":
            c.draw_rect(Rect2(cen + Vector2(-0.7, -0.5) * k, Vector2(1.4, 1.0) * k), Color(0.95, 0.9, 0.7))
            c.draw_circle(cen + Vector2(-0.7, 0.0) * k, k * 0.28, Color(0.8, 0.72, 0.5))
            c.draw_circle(cen + Vector2(0.7, 0.0) * k, k * 0.28, Color(0.8, 0.72, 0.5))
            c.draw_line(cen + Vector2(-0.4, -0.15) * k, cen + Vector2(0.4, -0.15) * k, Color(0.4, 0.3, 0.2), 1.5)
            c.draw_line(cen + Vector2(-0.4, 0.15) * k, cen + Vector2(0.3, 0.15) * k, Color(0.4, 0.3, 0.2), 1.5)
        "sword":
            c.draw_line(cen + Vector2(-0.55, 0.55) * k, cen + Vector2(0.85, -0.85) * k, Color(0.9, 0.93, 1.0), 4.0)
            c.draw_line(cen + Vector2(-0.7, 0.2) * k, cen + Vector2(-0.2, 0.7) * k, Color(1.0, 0.8, 0.3), 3.0)
            c.draw_circle(cen + Vector2(-0.8, 0.8) * k, k * 0.14, Color(1.0, 0.8, 0.3))
        "axe":
            c.draw_line(cen + Vector2(-0.7, 0.9) * k, cen + Vector2(0.3, -0.8) * k, Color(0.6, 0.4, 0.25), 3.5)
            c.draw_colored_polygon(_pts(cen, k, [Vector2(0.1, -0.95), Vector2(0.95, -0.35), Vector2(0.25, 0.1)]), Color(0.85, 0.88, 0.95))
        "hammer":
            c.draw_line(cen + Vector2(-0.5, 0.95) * k, cen + Vector2(0.3, -0.5) * k, Color(0.6, 0.4, 0.25), 3.5)
            c.draw_rect(Rect2(cen + Vector2(-0.2, -0.95) * k, Vector2(1.0, 0.6) * k), Color(0.8, 0.82, 0.9))
        "orb":
            c.draw_circle(cen, k * 0.8, mid)
            c.draw_circle(cen + Vector2(-0.25, -0.25) * k, k * 0.28, Color(1.0, 1.0, 1.0, 0.8))
        "nova":
            for rr in [0.35, 0.65, 0.95]:
                c.draw_arc(cen, k * rr, 0.0, TAU, 28, light, 2.5)
            c.draw_circle(cen, k * 0.12, Color.WHITE)
        "meteor":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.95, 0.95), Vector2(-0.1, -0.55), Vector2(0.55, 0.1)]), Color(1.0, 0.55, 0.15, 0.8))
            c.draw_circle(cen + Vector2(0.3, -0.3) * k, k * 0.5, Color(1.0, 0.85, 0.35))
        "fang":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.65, -0.85), Vector2(-0.1, -0.85), Vector2(-0.38, 0.95)]), Color(0.95, 0.95, 0.9))
            c.draw_colored_polygon(_pts(cen, k, [Vector2(0.1, -0.85), Vector2(0.65, -0.85), Vector2(0.38, 0.95)]), Color(0.95, 0.95, 0.9))
        "chain":
            c.draw_arc(cen + Vector2(-0.4, -0.4) * k, k * 0.42, 0.0, TAU, 16, light, 3.0)
            c.draw_arc(cen + Vector2(0.0, 0.0) * k, k * 0.42, 0.0, TAU, 16, light, 3.0)
            c.draw_arc(cen + Vector2(0.4, 0.4) * k, k * 0.42, 0.0, TAU, 16, light, 3.0)
        "eye":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-1.0, 0), Vector2(-0.45, -0.55), Vector2(0.45, -0.55), Vector2(1.0, 0), Vector2(0.45, 0.55), Vector2(-0.45, 0.55)]), light)
            c.draw_circle(cen, k * 0.32, col.darkened(0.5))
            c.draw_circle(cen, k * 0.14, Color.WHITE)
        "gem":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(0, -0.95), Vector2(0.75, -0.2), Vector2(0, 0.95), Vector2(-0.75, -0.2)]), Color(0.6, 0.95, 1.0))
            c.draw_line(cen + Vector2(-0.75, -0.2) * k, cen + Vector2(0.75, -0.2) * k, Color(1.0, 1.0, 1.0, 0.7), 1.5)
        "crown":
            c.draw_colored_polygon(_pts(cen, k, [Vector2(-0.85, 0.65), Vector2(-0.85, -0.55), Vector2(-0.4, 0.0), Vector2(0, -0.85), Vector2(0.4, 0.0), Vector2(0.85, -0.55), Vector2(0.85, 0.65)]), Color(1.0, 0.85, 0.3))
        "dash":
            for j in 3:
                var ox := -0.55 + 0.5 * float(j)
                c.draw_polyline(_pts(cen, k, [Vector2(ox - 0.25, -0.7), Vector2(ox + 0.25, 0.0), Vector2(ox - 0.25, 0.7)]), light, 3.0)
        _:
            c.draw_circle(cen, k * 0.6, mid)


static func color_for(icon: String) -> Color:
    match icon:
        "potion_hp", "heart":
            return Color(0.9, 0.3, 0.35)
        "potion_mp", "orb", "ice":
            return Color(0.3, 0.55, 0.95)
        "boots", "scroll", "axe", "hammer":
            return Color(0.75, 0.55, 0.3)
        "ring", "crown", "star", "bolt":
            return Color(0.95, 0.8, 0.3)
        "sword", "shield", "gem", "chain":
            return Color(0.6, 0.7, 0.85)
        "arrow", "wind", "dash":
            return Color(0.4, 0.8, 0.6)
        "fang", "skull", "fire", "meteor":
            return Color(0.9, 0.4, 0.2)
    return Color(0.6, 0.6, 0.8)
