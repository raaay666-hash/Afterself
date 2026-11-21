extends Control
# Editable native pixel art. Four screen pixels per logical pixel, no raster AI assets.
var kind: String = "lock"
var values: Array = []
var sealed: bool = false
const INK = "172c28"
const PAPER = "d0c3a0"
const SHADE = "96866c"
const BRASS = "b89860"
const COPPER = "82624a"
const LIGHT = "8ba987"

func r(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x,y,w,h),Color(color))

func wire(points: Array, color: String = "597c75", width: float = 1) -> void:
	for i in range(1,points.size()): draw_line(points[i-1],points[i],Color(color),width)

func paper(x: float, y: float, w: float, h: float) -> void:
	r(x+2,y+2,w,h,"070f11");r(x,y,w,h,PAPER);r(x+w-2,y,2,h,SHADE)
	for hole in range(4,int(h)-3,7): r(x+2,y+hole,1,2,SHADE)
	for line in range(8,int(h)-5,7): r(x+6,y+line,w-13,1,"b5a789")

func screw(x: float, y: float) -> void:
	r(x,y,3,3,"596b62");r(x+1,y,1,3,"1a2825")

func lamp(x: float, y: float, lit: bool) -> void:
	r(x-1,y-1,6,6,"0b1719");r(x,y,4,4,LIGHT if lit else "3b4d45");r(x+1,y,2,1,"c9d6ac" if lit else "536256")

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(4,4))
	if kind=="scene_door":
		# The frame follows the existing corridor doorway; restrained teal stays in its ambient shadow.
		r(0,0,56,96,"101e20");r(2,2,52,92,"263939");r(4,4,48,88,"0b161a")
		r(2,2,52,1,"394843");r(2,3,1,90,"45514a");r(53,3,1,90,"0c181a")
		if sealed:
			r(5,5,15,86,"263d3c");r(18,6,2,84,"465853");r(12,48,3,2,"8c8059")
			r(22,9,26,80,"0e2023");r(23,27,24,2,"27383a");r(23,61,24,2,"27383a")
			paper(30,33,11,16);r(29,77,15,5,"182b2b")
		else:
			r(5,5,46,86,"203637");r(7,7,42,82,"283e3d")
			r(8,8,1,78,"344b45");r(48,8,1,78,"172b2d")
			r(11,11,31,23,"1b3134");r(11,35,31,1,"344843")
			r(13,17,26,11,"13272b");r(16,21,19,2,"747763")
			r(11,41,31,42,"223838");r(12,42,1,39,"2e4441")
			r(42,47,3,7,"142a2d");r(41,48,3,2,"8c8059")
			for chip in [Vector2(9,38),Vector2(26,81),Vector2(39,57),Vector2(17,72)]:
				r(chip.x,chip.y,3,1,"475149");r(chip.x+1,chip.y+1,2,1,"514a3d")
		for hinge in [18,70]: r(4,hinge,3,7,"42514a");r(5,hinge+1,1,5,"6a6754")
		lamp(50,28,sealed);r(2,93,52,2,"4c4a3e");r(6,95,43,1,"162628")
		draw_set_transform(Vector2.ZERO);return
	r(0,0,180,76,"0d191b");r(0,71,180,5,"22332e")
	for x in range(0,180,16): r(x,73,1,3,"34463b")
	match kind:
		"lock":
			r(7,7,166,60,COPPER);r(11,10,158,52,"594936");r(12,50,156,10,"705942")
			r(17,13,146,36,BRASS);r(17,47,146,3,"755934")
			for i in 3:
				var x: int=24+i*49
				r(x,17,34,31,"392f25");r(x+2,18,30,28,"b4a57e");r(x+3,19,28,2,"e0cc96")
				r(x+3,30,28,1,"66573c");r(x+3,43,28,2,"877852")
			for p in [Vector2(19,14),Vector2(158,14),Vector2(19,44),Vector2(158,44)]: screw(p.x,p.y)
			r(157 if not sealed else 143,54,12,4,BRASS)
			if sealed: r(13,61,151,4,"0a1618");paper(58,57,60,12)
		"door":
			r(8,4,164,64,"33433a");r(10,6,160,59,"22342f");r(14,9,152,12,"101d1d")
			for i in 3:
				var x: int=22+i*50
				paper(x-8,24,40,40)
				r(x,27,24,13,COPPER if i!=2 else "80908a");r(x+3,28,18,2,"bfa775" if i!=2 else "b1c1b8")
				r(x+6,40,3 if i!=1 else 7,7,BRASS);r(x+17,40,3 if i!=1 else 7,7,BRASS)
				if i==int(values[0]): draw_rect(Rect2(x-9,23,42,42),Color(BRASS),false,1)
			lamp(157,13,sealed);r(155,51,6,11,"3f5347")
			if sealed: r(166,25,2,35,"0c191b")
		"timeline":
			paper(5,6,169,62);wire([Vector2(12,45),Vector2(163,45)],COPPER,2)
			for i in 4:
				var x: int=16+i*46
				r(x,37,2,17,"8a795d");r(x-3,42,8,6,BRASS)
			r(15,52,94,7,"849478");r(62,38,2,21,"a76c57")
		"map":
			paper(2,3,83,64);paper(94,3,83,64)
			for origin in [Vector2(2,3),Vector2(94,3)]:
				for x in range(8,80,9): r(origin.x+x,origin.y+3,1,57,"b7ab8d")
				for y in range(8,61,9): r(origin.x+3,origin.y+y,76,1,"b7ab8d")
			var anchors: Array=[Vector2(15,18),Vector2(59,34),Vector2(34,53)]
			for offset in [Vector2.ZERO,Vector2(92,0)]:
				for i in 3: anchor(anchors[i]+offset,i,"706d59")
			var angle: float=float(values[2])*PI/2
			var delta: Vector2=Vector2(int(values[0])-2,int(values[1])-2)*4
			var transformed: Array=[]
			for i in 3:
				var p: Vector2=(anchors[i]-Vector2(42,35)).rotated(angle)+Vector2(134,35)+delta
				transformed.append(p);anchor(p,i,"537d76")
			wire(transformed,"537d76",2)
			if values==[2,2,0]: lamp(145,57,true)
		"map_route":
			paper(4,3,171,63)
			wire([Vector2(18,28),Vector2(86,30),Vector2(158,32)],"527d73",3)
			wire([Vector2(18,28),Vector2(45,61)],"92856c",2)
			wire([Vector2(86,30),Vector2(148,61)],"92856c",2)
			for p in [Vector2(18,28),Vector2(86,30),Vector2(158,32)]:
				r(p.x-4,p.y-4,8,8,BRASS);r(p.x-1,p.y-1,2,2,"34554b")
			r(143,58,10,2,"a76c57");r(146,55,2,8,"a76c57")
		"deeds":
			paper(9,5,75,62);paper(96,5,75,62)
			for x in [17,104]:
				draw_rect(Rect2(x,18,57,34),Color("7e8e78"),false,1)
				draw_rect(Rect2(x+5,22,45,10),Color("7e8e78"),false,1)
				r(x+40,42,13,10,"aa7a65");r(x+43,44,7,6,"c6a082")
		"parcels", "addresses":
			paper(5,5,169,62)
			for i in 3:
				var x: int=14+i*55
				for house in 3:
					r(x+house*12,27,9,18,"70816a" if i==1 else "8d8670")
					r(x+house*12+3,36,3,9,"d6c296" if i==1 else "42564b")
				wire([Vector2(x,49),Vector2(x+39,49)],"628479",2)
		"archive":
			r(7,5,166,63,"334b40")
			for i in 3:
				var x: int=10+i*55
				r(x,9,49,52,"26382f");r(x+2,11,45,45,"6d765e");r(x+3,48,43,9,"485a49")
				paper(x+7,17,35,26);r(x+18,46,13,2,BRASS)
				if sealed: paper(x+6,53,36,12)
		"tape", "rubbing", "sources", "footer":
			for i in 3:
				var x: int=8+i*57
				paper(x,9,49,53)
				if kind=="tape":
					for y in range(10,62,5): r(x+46,y,2,2,COPPER)
					r(x+23,2,2,5,BRASS);wire([Vector2(x+21,5),Vector2(x+24,8),Vector2(x+27,5)],BRASS)
				elif kind=="rubbing":
					r(x+40,54,9,8,"786e5c");r(x+40,54,9,2,PAPER)
				elif kind=="sources": wire([Vector2(x+24,39),Vector2(x+24,67)],"648477",2)
		"meters":
			r(5,4,170,65,"34483d")
			for i in 2:
				var center: Vector2=Vector2(47+i*88,31)
				draw_circle(center,22,Color("162a27"));draw_circle(center,19,Color(PAPER))
				for tick in 9:
					var angle: float=PI+tick*PI/8
					draw_line(center+Vector2.from_angle(angle)*15,center+Vector2.from_angle(angle)*18,Color(COPPER))
				var reading: int=(18 if i==0 else 23)+int(values[i])-3
				var needle: float=PI+(reading-12)*PI/16
				draw_line(center,center+Vector2.from_angle(needle)*15,Color("a76c57"),2)
				r(center.x-2,center.y-2,4,4,BRASS);screw(center.x-28,58)
		"conditions":
			for i in 3:
				var x: int=8+i*56
				r(x,6,47,58,"3b5141");r(x+4,26,39,22,"6b816c");r(x+4,36,39,4,"527d75")
				lamp(x+8,53,sealed)
		"logs", "compare":
			paper(4,5,172,62)
			for y in [22,39,56]: r(8,y,161,2,"96886c")
			for x in [42,80,121,159]: r(x,20,2,42,"b19864")
		"debug":
			r(8,6,65,49,"2e4a40");r(108,6,64,49,"2e4a40")
			wire([Vector2(73,15),Vector2(89,15),Vector2(89,24),Vector2(108,24)],BRASS,2)
			wire([Vector2(108,44),Vector2(92,44),Vector2(92,35),Vector2(73,35)],"8ba987",2)
			r(104,22,4,4,BRASS);r(73,33,4,4,LIGHT)
			if sealed: r(83,22,15,19,"0d191b");lamp(88,29,true)
		"port":
			r(4,5,172,62,"33473d");r(7,8,166,56,"182c29")
			for i in 4:
				var x: int=12+i*42
				r(x,19,33,32,"78846b");r(x+3,22,27,25,"415a4b");lamp(x+13,11,sealed or int(values[i])==i)
				if i<3: wire([Vector2(x+33,34),Vector2(x+42,34)],LIGHT if sealed else "526a5b",2)
				for pin in 4: r(x+5+pin*6,51,2,5,BRASS)
			r(14,61,150,1,"4c5a50")
		"mask", "mask_read":
			paper(10,3,160,63)
			for row in 4:
				for col in 4:
					draw_rect(Rect2(13+col*39,6+row*14,36,12),Color("97896d"),false,1)
			var holes: Array=[Vector2i(0,1),Vector2i(1,2),Vector2i(2,1)]
			var turns: int=int(values[0]) if kind=="mask" else 0
			for h in holes:
				var p: Vector2i=h
				for _i in turns: p=Vector2i(p.y,3-p.x)
				draw_rect(Rect2(13+p.y*39,6+p.x*14,36,12),Color(BRASS),false,2)
			var triangle: Vector2=Vector2(0,-1).rotated(turns*PI/2)
			var tip: Vector2=Vector2(90,36)+triangle*34
			draw_colored_polygon(PackedVector2Array([tip,tip-triangle*4+triangle.orthogonal()*3,tip-triangle*4-triangle.orthogonal()*3]),Color(BRASS))
		"ballots", "ballot_reasons":
			for i in 6:
				var x: int=7+(i%3)*58;var y: int=5+int(i/3)*33
				paper(x,y,50,28);r(x+34,y+20,10,4,"78937a" if i in values and kind=="ballots" else "aa8064")
		"packet", "letters", "receipt", "names", "clock":
			paper(14,7,67,55);paper(100,7,65,55)
			if kind=="clock":
				draw_circle(Vector2(90,30),20,Color(BRASS));draw_circle(Vector2(90,30),17,Color(PAPER))
				wire([Vector2(90,30),Vector2(90,17)],COPPER,2);wire([Vector2(90,30),Vector2(101,30)],COPPER,2)
			elif kind=="packet":
				wire([Vector2(80,32),Vector2(100,32)],LIGHT,2);r(85,28,9,9,"a47c5e")
			elif kind=="names": r(86,9,9,52,"0d191b")
	for p in [Vector2(1,1),Vector2(176,1),Vector2(1,67),Vector2(176,67)]: screw(p.x,p.y)
	draw_set_transform(Vector2.ZERO)

func anchor(p: Vector2, shape: int, color: String) -> void:
	if shape==0: draw_circle(p,3,Color(color))
	elif shape==1: r(p.x-3,p.y-3,2,6,color);r(p.x+1,p.y-3,2,6,color)
	else: draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),Color(color),false,1)
