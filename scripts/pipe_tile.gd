extends Button

var mask: int = 0
var lit: bool = false
var badge: String = ""

func _draw() -> void:
	var center:=size*0.5
	var ink:=Color("d9bc72") if lit else Color("627970")
	for i in 4:
		if mask & (1<<i):
			var direction: Vector2=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][i]
			draw_line(center,center+direction*size*0.5,Color("0c1919"),14)
			draw_line(center,center+direction*size*0.5,ink,6)
	draw_rect(Rect2(center-Vector2(7,7),Vector2(14,14)),ink)
	if not badge.is_empty():
		draw_rect(Rect2(7,5,30,24),Color("182d29"))
		draw_string(get_theme_font("font"),Vector2(10,24),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("e8dbb6"))
