extends Node
## State is separate from evidence truth. Hidden entries never reach the visible UI.
static var catalog: Dictionary = {}
var g
var active_id: String = ""
var active_view: String = "front"
var active_kind: String = ""
var return_to: Callable
var controls: Dictionary = {}
var details: Label
var progress: Label
var popup_count: int = 0

static func book() -> Dictionary:
	if catalog.is_empty():
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/evidence-runtime-v9.json"))
		for item in source.entries: catalog[item.id]=item
	return catalog

static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary={"stories":[],"pending":[],"announced":[],"inspected":{}}
	if not raw is Dictionary: return result
	for field in ["stories","pending","announced"]:
		if not raw.get(field) is Array: continue
		for id in raw[field]:
			if not id is String or not book().has(id) or id in result[field]: continue
			if field=="stories" and book()[id].category!="collection": continue
			result[field].append(id)
	if raw.get("inspected") is Dictionary:
		for id in raw.inspected:
			if not book().has(id) or not raw.inspected[id] is Array: continue
			var points: Array=[]
			for h in book()[id].hotspots:
				if h.id in raw.inspected[id]: points.append(h.id)
			result.inspected[id]=points
	return result

func state() -> Dictionary:
	if not g.journey.has("collection"): g.journey.collection=clean({})
	return g.journey.collection

func acquired(id: String) -> bool:
	if not book().has(id): return false
	var e: Dictionary=book()[id]
	if e.category=="collection": return id in state().stories
	var key: String=id.get_slice(".",1)
	return key in (g.evidence if int(e.chapter)==1 else g.journey.chapters.get(str(int(e.chapter)),{}).get("evidence",[]))

func current_chapter() -> int:
	return int(g.journey.chapter)

func ready(id: String) -> bool:
	if not book().has(id): return false
	var e: Dictionary=book()[id];var n: int=int(e.chapter)
	if e.category!="collection" or n>int(g.journey.unlocked): return false
	if id=="c1.lease" and "lease" in g.observations: return true
	for key in e.requires:
		if not acquired("c%d.%s" % [n,key]): return false
	var event: String=e.event
	if n==1:
		if event=="truth" and not g.flags.get("truth",false): return false
	else:
		var s: Dictionary=g.journey.chapters.get(str(n),{})
		if event=="puzzle" and not s.get("puzzle",false): return false
		if event=="ended" and not s.get("ended",false): return false
		if "/" in event and event not in s.get("seen",[]): return false
	return true

func reconcile() -> void:
	# Loading a prior save does not synthesize collection stories or first-time notices.
	g.journey.collection=clean(g.journey.get("collection",{}))
	var data: Dictionary=state()
	for id in data.stories.duplicate():
		if not ready(id): data.stories.erase(id)
	for field in ["pending","announced"]:
		for id in data[field].duplicate():
			if not acquired(id): data[field].erase(id)
	for id in data.inspected.keys():
		if not acquired(id): data.inspected.erase(id)

func enqueue(id: String) -> void:
	if not acquired(id) or id in state().announced or id in state().pending: return
	state().pending.append(id);g.save_journey()

func _process(_delta: float) -> void:
	if g==null or g.title_mode or g.dialog_mode or g.choice_locked or is_instance_valid(g.opening_layer) or is_instance_valid(g.modal): return
	if not state().pending.is_empty(): popup(str(state().pending[0]))

func pending(id: String) -> bool:
	return id in state().pending

func acknowledge(id: String) -> void:
	if id.is_empty(): return
	state().pending.erase(id)
	if id not in state().announced: state().announced.append(id)
	g.save_journey()

func modal_closed() -> void:
	if active_kind=="popup": acknowledge(active_id)
	active_kind="";active_id="";controls.clear()

func dismiss() -> void:
	var after: Callable=return_to
	g.close_modal()
	return_to=Callable()
	if after.is_valid(): after.call()

func configure_close() -> void:
	for node in g.modal.get_children():
		if node is Button and node.text=="×":
			for connection in node.pressed.get_connections(): node.pressed.disconnect(connection.callable)
			node.pressed.connect(dismiss)

func picture(parent: Node, id: String, view: String, rect: Rect2) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=load("res://assets/evidence-models-v2/"+book()[id].assets[view])
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image);image.position=rect.position;image.size=rect.size
	return image

func popup(id: String, after: Callable = Callable()) -> void:
	if not acquired(id) or g.dialog_mode or g.choice_locked: return
	g.new_modal("新证物已收集")
	active_kind="popup";active_id=id;return_to=after;popup_count+=1;configure_close()
	var e: Dictionary=book()[id]
	picture(g.modal,id,"front",Rect2(36,112,192,192))
	g.label_at(g.modal,e.title,Rect2(264,92,567,64),28,"e9dbb2")
	g.label_at(g.modal,source(id),Rect2(264,177,561,93),21,"b5c3ae")
	g.label_at(g.modal,"已存入证物柜。可以翻页、检查细节，\n原始记录不会被消耗。",Rect2(264,294,561,82),21)
	controls.view=g.button_at(g.modal,"立即检查",Rect2(34,447,389,54),func():
		var resume: Callable=return_to
		acknowledge(id);inspect(id,resume))
	controls.later=g.button_at(g.modal,"稍后查看",Rect2(447,447,389,54),dismiss,true)

func source(id: String) -> String:
	var e: Dictionary=book()[id];var n: int=int(e.chapter);var key: String=id.get_slice(".",1)
	if e.category=="collection": return "由 "+e.owner+" 获准记录 · 原物按原约定保管"
	if n==1: return g.Data.EVIDENCE[key][1]
	return "第 %d 章 · %s · 原始记录留存" % [n,g.Flow.book()[str(n)].title]

func body(id: String) -> String:
	var e: Dictionary=book()[id]
	if e.category=="collection": return e.body
	var key: String=id.get_slice(".",1)
	if int(e.chapter)==1: return g.Data.EVIDENCE[key][2]
	return g.Flow.book()[str(int(e.chapter))].evidence[key].body

func inspect(id: String, after: Callable = Callable(), view: String = "front") -> void:
	if not acquired(id): show_album(current_chapter(),after);return
	g.new_modal(book()[id].title,true)
	active_kind="inspect";active_id=id;active_view=view;return_to=after;configure_close()
	var e: Dictionary=book()[id]
	g.panel_at(g.modal,Rect2(30,91,380,367),"101a1d")
	picture(g.modal,id,view,Rect2(44,107,352,352))
	var checked: Array=state().inspected.get(id,[])
	for h in e.hotspots:
		if h.view!=view: continue
		var r: Array=h.rect
		# Geometry fits the same displayed square as the nearest-neighbor sprite.
		var rect:=Rect2(44+float(r[0])*352/192,107+float(r[1])*352/192,float(r[2])*352/192,float(r[3])*352/192)
		var button=g.button_at(g.modal,"",rect,func(): check_point(id,h.id))
		button.tooltip_text=h.label
		button.add_theme_stylebox_override("normal",point_style("ab843e" if h.id in checked else "69817b88"))
		for mode in ["hover","pressed","focus"]: button.add_theme_stylebox_override(mode,point_style("e9dbb2"))
		controls[h.id]=button
	g.label_at(g.modal,source(id),Rect2(442,92,673,65),20,"b8c7b0")
	var scroll:=ScrollContainer.new();g.modal.add_child(scroll);scroll.position=Vector2(442,164);scroll.size=Vector2(672,215)
	var text:=Label.new();text.text=body(id);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size=Vector2(637,0);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size",24);text.add_theme_color_override("font_color",Color("e9dbb2"));scroll.add_child(text)
	details=g.label_at(g.modal,"点击模型上的框，查看该处原文或叙事边界。",Rect2(442,395,670,91),20,"dac397")
	g.button_at(g.modal,"正面",Rect2(30,484,178,43),func(): inspect(id,return_to,"front"),true)
	g.button_at(g.modal,e.secondary_label,Rect2(222,484,188,43),func(): inspect(id,return_to,"secondary"),true)
	progress=g.label_at(g.modal,"已检查 %d / %d 处 · 可反复查阅" % [checked.size(),e.hotspots.size()],Rect2(442,490,668,32),19,"a8b99e")
	g.button_at(g.modal,"返回证物柜",Rect2(442,540,319,36),func(): show_album(int(e.chapter),return_to),true)
	g.button_at(g.modal,"收起",Rect2(785,540,326,36),dismiss,true)

func check_point(id: String, point: String) -> void:
	if not acquired(id) or active_id!=id: return
	for h in book()[id].hotspots:
		if h.id!=point or h.view!=active_view: continue
		if not state().inspected.has(id): state().inspected[id]=[]
		if point not in state().inspected[id]: state().inspected[id].append(point);g.save_journey()
		details.text=h.label+" / "+point_text(id,h)
		progress.text="已检查 %d / %d 处 · 可反复查阅" % [state().inspected[id].size(),book()[id].hotspots.size()]
		if controls.has(point): controls[point].add_theme_stylebox_override("normal",point_style("ab843e"))
		return

func point_style(border: String) -> StyleBoxFlat:
	var style: StyleBoxFlat=g.box_style("00000000",border,2)
	style.shadow_size=0
	return style

func point_text(id: String, h: Dictionary) -> String:
	# Only the actual acquired document supplies facts; model scribbles are never evidence.
	return str(h.get("text",body(id)))

func show_album(n: int = -1, after: Callable = Callable()) -> void:
	if n<0: n=current_chapter()
	n=clampi(n,1,int(g.journey.unlocked))
	g.new_modal("证物柜 / 第 %d 章" % n,true)
	active_kind="album";active_id="";return_to=after;configure_close()
	for ch in range(1,int(g.journey.unlocked)+1):
		g.button_at(g.modal,"第 %d 章" % ch,Rect2(30+(ch-1)*156,77,144,36),func(): show_album(ch,return_to),true)
	var i: int=0
	for id in book():
		var e: Dictionary=book()[id]
		if int(e.chapter)!=n: continue
		var rect:=Rect2(30+(i%3)*359,132+int(i/3)*115,339,102)
		if acquired(id):
			var b=g.button_at(g.modal,"",rect,func(): inspect(id,after))
			picture(b,id,"icon",Rect2(8,15,64,64))
			g.label_at(b,e.title,Rect2(82,12,248,56),20,"e9dbb2")
			g.label_at(b,"人物物件" if e.category=="collection" else "原始记录",Rect2(82,72,239,23),16,"a0b39c")
			controls[id]=b
		else:
			# Blank paper slot: no title, silhouette, tooltip, hotspot or leaked future ID.
			g.panel_at(g.modal,rect,"29332f")
		i+=1
	g.button_at(g.modal,"可调查的物件委托",Rect2(30,510,430,48),func(): show_tasks(n,"",after),true)
	g.button_at(g.modal,"返回调查",Rect2(710,510,399,48),dismiss,true)

func available_tasks(n: int, owner: String = "") -> Array:
	var result: Array=[]
	for id in book():
		if int(book()[id].chapter)==n and ready(id) and not acquired(id) and (owner.is_empty() or book()[id].owner==owner): result.append(id)
	return result

func show_tasks(n: int, owner: String = "", after: Callable = Callable()) -> void:
	g.new_modal("物件委托 / 当事人愿意留下的记录")
	active_kind="tasks";active_id="";return_to=after;configure_close()
	var tasks: Array=available_tasks(n,owner)
	if tasks.is_empty(): g.label_at(g.modal,"目前没有可接受的物件委托。\n先调查现场，听当事人自己的说法。",Rect2(34,130,798,162),24)
	for i in tasks.size():
		var id: String=tasks[i];var e: Dictionary=book()[id]
		g.label_at(g.modal,e.owner+" / 获准记录，不带走原物",Rect2(34,105+i*132,800,32),20,"bdc5ac")
		g.button_at(g.modal,"询问："+e.title,Rect2(34,148+i*132,800,56),func(): accept_task(id,after))
	g.button_at(g.modal,"返回证物柜",Rect2(34,458,384,45),func(): show_album(n,after),true)
	g.button_at(g.modal,"回到调查",Rect2(448,458,385,45),dismiss,true)

func accept_task(id: String, after: Callable = Callable()) -> void:
	if not ready(id) or acquired(id): return
	var lines: Array=book()[id].dialogue
	g.start_dialog(lines,func():
		if not ready(id): return
		state().stories.append(id);enqueue(id);g.sound.play("found");g.save_journey();popup(id,after))

func handle_key(event: InputEvent) -> bool:
	if active_kind.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode==KEY_ESCAPE: dismiss();g.get_viewport().set_input_as_handled();return true
	return false
