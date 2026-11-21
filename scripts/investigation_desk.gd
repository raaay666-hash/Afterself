extends Node

const Pipe = preload("res://scripts/pipe_tile.gd")
static var catalog: Dictionary = {}
var g
var selected: int = -1
var feedback: Label
var active_number: int = 1
var hint_step: int = 0
var controls: Array = []

static func book() -> Dictionary:
	if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/investigation-v6.json"))
	return catalog

static func integers(value: Variant) -> Array:
	var result: Array=[]
	if value is Array:
		for item in value:
			if item is int or item is float: result.append(int(item))
	return result

static func rotate(mask: int) -> int:
	return ((mask<<1)&15)|((mask>>3)&1)

static func route(values: Array) -> Array:
	if values.size()!=9 or not (int(values[0])&8): return []
	var visited: Array=[]
	var current: int=0
	var incoming: int=3
	while current not in visited:
		visited.append(current)
		var mask: int=int(values[current])
		if not mask&(1<<incoming): break
		var outgoing: int=-1
		for i in 4:
			if i!=incoming and mask&(1<<i): outgoing=i
		if outgoing<0: break
		if current==8 and outgoing==1: visited.append(9);break
		var x: int=current%3;var y: int=current/3
		var dx: int=[0,1,0,-1][outgoing];var dy: int=[-1,0,1,0][outgoing]
		x+=dx;y+=dy
		if x<0 or x>2 or y<0 or y>2: break
		var next: int=y*3+x
		incoming=(outgoing+2)%4
		if not int(values[next])&(1<<incoming): break
		current=next
	return visited

static func valid_solution(n: int, values: Array) -> bool:
	var c: Dictionary=book()[str(n)]
	if c.kind=="order":
		return values==range(c.pieces.size())
	if c.kind=="compare":
		var sorted: Array=values.duplicate();sorted.sort()
		return sorted==integers(c.correct)
	var path: Array=route(values)
	if path.is_empty() or path[-1]!=9: return false
	var previous: int=-1
	for key in c.checkpoints:
		var pos: int=path.find(int(key))
		if pos<=previous: return false
		previous=pos
	return true

static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary={"tasks":{},"stories":{}}
	if not raw is Dictionary: return result
	for n in range(1,7):
		var key: String=str(n);var c: Dictionary=book()[key]
		var tasks: Variant=raw.get("tasks",{})
		if tasks is Dictionary and tasks.get(key) is Dictionary:
			var s: Dictionary=tasks[key];var v: Array=integers(s.get("values",[]))
			var legal: bool=false
			if c.kind=="order":
				var sorted: Array=v.duplicate();sorted.sort();legal=sorted==range(c.pieces.size())
			elif c.kind=="compare":
				legal=true;var seen: Array=[]
				for x in v:
					if x<0 or x>=c.left.size() or x in seen: legal=false
					seen.append(x)
			else:
				legal=v.size()==9
				if legal:
					for i in 9:
						var allowed: Array=[];var mask: int=int(c.initial[i])
						for t in 4: allowed.append(mask);mask=rotate(mask)
						if v[i] not in allowed: legal=false
			if legal: result.tasks[key]={"values":v,"done":s.get("done")==true and valid_solution(n,v)}
		var stories: Variant=raw.get("stories",{})
		if stories is Dictionary and stories.get(key) is Dictionary:
			var v: Array=integers(stories[key].get("values",[]));var sorted: Array=v.duplicate();sorted.sort()
			if sorted==[0,1,2,3]: result.stories[key]={"values":v,"done":stories[key].get("done")==true and v==[0,1,2,3]}
	return result

func data() -> Dictionary:
	if not g.journey.has("desk"): g.journey.desk={"tasks":{},"stories":{}}
	return g.journey.desk

func available(n: int) -> bool:
	if n==1: return true
	return n<=int(g.journey.unlocked)

func closed(n: int) -> bool:
	if n==1: return g.completed
	var s: Dictionary=g.journey.chapters.get(str(n),{})
	return s.get("ended",false) if n==6 else s.get("bridge_done",false)

func acquired(n: int) -> Array:
	return g.evidence if n==1 else g.journey.chapters.get(str(n),{}).get("evidence",[])

func ready(n: int) -> bool:
	if not available(n): return false
	for key in book()[str(n)].requires:
		if key not in acquired(n): return false
	return true

func task_state(n: int) -> Dictionary:
	var tasks: Dictionary=data().tasks;var key: String=str(n)
	if not tasks.has(key): tasks[key]={"values":integers(book()[key].get("initial",[])),"done":false}
	return tasks[key]

func done(n: int) -> bool:
	return ready(n) and task_state(n).done and valid_solution(n,task_state(n).values)

func verify(n: int) -> bool:
	if not ready(n) or not valid_solution(n,task_state(n).values): return false
	task_state(n).done=true;g.save_journey();g.sound.play("found");return true

func title_for(n: int, key: String) -> String:
	return g.Data.EVIDENCE[key][0] if n==1 else g.Flow.book()[str(n)].evidence[key].title

func show_task(n: int = 0) -> void:
	g.field.show_chapter(n)

func show_legacy_task(n: int = 0) -> void:
	if n==0: n=int(g.journey.chapter)
	if not available(n): return
	active_number=n;selected=-1;controls=[]
	var c: Dictionary=book()[str(n)]
	g.new_modal("现场核验 / "+c.task,true)
	g.label_at(g.modal,c.instruction,Rect2(32,79,1096,64),20,"c8d4bc")
	if not ready(n):
		var missing: String="先带回原件，再操作核验台：\n"
		for key in c.requires:
			if key not in acquired(n): missing+="\n[  ]  "+title_for(n,key)
		g.label_at(g.modal,missing,Rect2(44,163,1020,260),24)
		g.button_at(g.modal,"返回调查",Rect2(782,523,340,44),g.close_modal);return
	var s: Dictionary=task_state(n)
	feedback=g.label_at(g.modal,c.result if done(n) else "操作保存在当前案卷中。先试着判断，再提交核验。",Rect2(34,451,1090,66),20,"d9c28a")
	if c.kind=="order":
		for i in c.pieces.size():
			g.label_at(g.modal,"%02d" % [i+1],Rect2(43,164+i*65,60,42),24,"c6b67f")
			var b=g.button_at(g.modal,c.pieces[int(s.values[i])],Rect2(114,158+i*65,980,53),func(): operate(i))
			controls.append(b);b.disabled=done(n)
	elif c.kind=="compare":
		g.label_at(g.modal,"原件 / 保留版本",Rect2(44,146,476,30),20,"b6c6b2")
		g.label_at(g.modal,"待核版本 / 点击标记差异",Rect2(604,146,485,30),20,"dfc18e")
		for i in c.left.size():
			var y: int=185+i*61
			var paper=g.panel_at(g.modal,Rect2(40,y,496,51),"cbbfa1")
			g.label_at(paper,c.left[i],Rect2(15,12,466,28),20,"293b35")
			g.label_at(g.modal,"→",Rect2(551,y+10,40,36),24,"a2b5a1")
			var b=g.button_at(g.modal,("[X] " if i in s.values else "[ ] ")+c.right[i],Rect2(602,y,496,51),func(): operate(i))
			controls.append(b);b.disabled=done(n)
	else:
		var path: Array=route(s.values)
		g.label_at(g.modal,"入口 →",Rect2(18,187,112,35),20,"d5bf83")
		for i in 9:
			var b:=Pipe.new();b.mask=int(s.values[i]);b.lit=i in path;b.badge=str(i+1) if c.checkpoints.has(str(i)) else ""
			b.add_theme_stylebox_override("normal",g.box_style("172c28","52695c",2))
			b.add_theme_stylebox_override("hover",g.box_style("2b4237","d6be83",2))
			b.add_theme_stylebox_override("disabled",g.box_style("172c28","52695c",2))
			b.add_theme_stylebox_override("focus",g.box_style("00000000","e9d39a",2))
			g.modal.add_child(b);b.position=Vector2(130+(i%3)*142,155+int(i/3)*94);b.size=Vector2(142,94)
			b.pressed.connect(func(): operate(i));b.disabled=done(n);controls.append(b)
		g.label_at(g.modal,"→ 出口",Rect2(563,375,130,35),20,"d5bf83")
		g.label_at(g.modal,"线路检查",Rect2(724,163,354,38),24,"e3cf9b")
		var labels: String=""
		for key in c.checkpoints: labels+="%02d  %s\n\n" % [int(key)+1,c.checkpoints[key]]
		g.label_at(g.modal,labels,Rect2(724,219,355,180),20)
		g.label_at(g.modal,"已连通出口" if 9 in path else "信号停在 %02d 号接头" % [int(path[-1])+1 if not path.is_empty() else 1],Rect2(716,402,382,30),20,"d6bd80")
	g.button_at(g.modal,"核验操作结果" if not done(n) else "已核验 / 返回调查",Rect2(780,523,342,44),func():
		if done(n): g.close_modal();return
		if verify(n): show_task(n);g.toast("第 %d 章 / 现场核验已封存" % n)
		else:
			if c.kind=="order":
				for i in s.values.size():
					if int(s.values[i])!=i: feedback.text="第 %d 个时点还不匹配。对照卡片年代，再交换位置。" % [i+1];break
			elif c.kind=="compare": feedback.text="标记里还有遗漏或误判。逐行核对内容，未改动的字段不要选。"
			else: feedback.text="线路未按要求通过全部核验点。观察亮线停在哪里，再转动相邻接头。")
	g.button_at(g.modal,"逐步提示",Rect2(34,523,224,44),func():
		hint_step+=1
		feedback.text=c.hint if hint_step==1 else (("从东城表下行，再向左折返，经西城表接向出口；右上支线不用接。" if n==4 else "从入口走上排，再向下折返经过中排，最后沿下排到出口。") if c.kind=="circuit" else c.hint),true)
	g.button_at(g.modal,"重置操作",Rect2(275,523,224,44),func():
		if done(n): feedback.text="核验已经封存。可在故事脉络中回顾。";return
		s.values=integers(c.get("initial",[]));g.save_journey();show_task(n),true)
	g.button_at(g.modal,"回查原件",Rect2(516,523,245,44),func(): show_sources(n,false),true)

func operate(index: int) -> void:
	var n: int=active_number;var c: Dictionary=book()[str(n)];var s: Dictionary=task_state(n)
	if not ready(n) or done(n): return
	if c.kind=="order":
		if selected<0: selected=index;controls[index].modulate=Color("e6c679");feedback.text="已拿起一张卡。再选另一张交换；再次点击原卡可取消。";return
		var old: int=selected;var value: int=int(s.values[index]);s.values[index]=s.values[old];s.values[old]=value
	elif c.kind=="compare":
		if index in s.values: s.values.erase(index)
		else: s.values.append(index)
	else: s.values[index]=rotate(int(s.values[index]))
	g.sound.play("click");g.save_journey();show_task(n)

func show_sources(n: int, archive: bool) -> void:
	if archive and not closed(n): return
	g.new_modal("原件索引 / "+book()[str(n)].title)
	var keys: Array=g.REQUIRED if n==1 else g.Flow.book()[str(n)].evidence.keys()
	for i in keys.size():
		var key: String=keys[i]
		var b=g.button_at(g.modal,title_for(n,key) if key in acquired(n) else "",Rect2(34,82+i*49,800,42),func():
			g.collection.inspect("c%d.%s" % [n,key],func(): show_sources(n,archive)))
		b.disabled=key not in acquired(n)
	g.button_at(g.modal,"返回故事脉络" if archive else "返回现场核验",Rect2(485,461,350,45),func():
		if archive: show_archive(n,1)
		else: show_task(n),true)

func choice_text(n: int) -> String:
	if n==1:
		return ("身份：单列现行实例。" if g.identity_choice=="independent" else "身份：沿用原档并记载中断。")+"\n生活："+g.future_summary()+"\n报告："+("请求制度复核。" if g.decisions.get("report")=="system" else "本案独立封存。")
	var c: Dictionary=g.Flow.book()[str(n)];var s: Dictionary=g.journey.chapters.get(str(n),{})
	var result: String=""
	for choice in c.choices:
		if choice.id==s.get("resolution"): result=choice.label
	if n==6: result+="\n私人选择："+("提交最终备份指令。" if s.get("private")=="upload" else "不上传，在此告别。")
	return result

func show_archive(n: int = 0, page: int = 0, sorting: bool = false) -> void:
	if n==0:
		for i in range(1,7):
			if closed(i): n=i
		if n==0: n=1
	selected=-1;controls=[]
	g.new_modal("全篇卷宗 / 故事脉络",true)
	g.button_at(g.modal,"全篇线索索引",Rect2(30,85,196,42),show_overview,true)
	for i in range(1,7):
		var b=g.button_at(g.modal,"%02d / %s" % [i,"可回顾" if closed(i) else "待结案"],Rect2(30,141+(i-1)*54,196,43),func(): show_archive(i),i!=n)
		b.disabled=not closed(i)
	g.label_at(g.modal,"只收录已通关案件\n不提前揭示后续真相",Rect2(32,484,200,64),20,"92aa98")
	if not closed(n):
		g.label_at(g.modal,"这一页尚未结案。\n完成案件和章末事件后，\n故事卡、来源与选择会自动归档。",Rect2(286,163,780,210),24)
		g.button_at(g.modal,"返回当前案卷",Rect2(778,523,340,44),g.show_journal,true);return
	var c: Dictionary=book()[str(n)]
	g.button_at(g.modal,"故事经过",Rect2(275,86,220,40),func(): show_archive(n),page!=0)
	g.button_at(g.modal,"证据与选择",Rect2(507,86,220,40),func(): show_archive(n,1),page!=1)
	g.label_at(g.modal,"%02d / %s" % [n,c.title],Rect2(748,88,375,33),20,"d7c393")
	if page==0:
		g.label_at(g.modal,c.recap,Rect2(279,143,842,72),20,"d2d5bd")
		var stories: Dictionary=data().stories;var key: String=str(n)
		if not stories.has(key): stories[key]={"values":[2,0,3,1],"done":false}
		var s: Dictionary=stories[key]
		var values: Array=s.values if sorting else [0,1,2,3]
		for i in 4:
			var b=g.button_at(g.modal,"%02d  %s" % [i+1,c.cards[int(values[i])]],Rect2(275,224+i*60,846,50),func():
				if not sorting: return
				if selected<0: selected=i;controls[i].modulate=Color("e7c980");return
				var value: int=int(s.values[i]);s.values[i]=s.values[selected];s.values[selected]=value;s.done=false;g.save_journey();show_archive(n,0,true),true)
			controls.append(b)
		feedback=g.label_at(g.modal,"交换两张卡，复原故事的因果先后。" if sorting else ("已梳理 / 你已亲手复原这段故事。" if s.done else "已按故事顺序整理；也可以自行复原，加深理解。"),Rect2(279,473,840,38),20,"d6bb82")
		g.button_at(g.modal,"核验故事顺序" if sorting else "亲手整理故事卡",Rect2(275,523,400,44),func():
			if not sorting: show_archive(n,0,true)
			elif s.values==[0,1,2,3]: s.done=true;g.save_journey();g.sound.play("found");show_archive(n)
			else:
				for i in 4:
					if int(s.values[i])!=i: feedback.text="第 %d 张的前因尚未发生。可返回故事经过，对照原件重排。" % [i+1];break)
	else:
		var claims: Dictionary=g.Story.CLAIMS if n==1 else g.Flow.book()[str(n)].claims
		var row: int=0
		for claim in claims.values():
			g.button_at(g.modal,"[已证实] "+claim.title+"  >",Rect2(275,136+row*87,846,38),func():
				g.new_modal(claim.title)
				g.label_at(g.modal,claim.body,Rect2(34,107,800,214),24)
				g.label_at(g.modal,"来源："+title_for(n,claim.pair[0])+" + "+title_for(n,claim.pair[1]),Rect2(34,348,800,72),20,"b8c8b2")
				g.button_at(g.modal,"返回证据与选择",Rect2(480,461,350,45),func(): show_archive(n,1)),true)
			g.label_at(g.modal,"来源："+title_for(n,claim.pair[0])+" + "+title_for(n,claim.pair[1]),Rect2(279,178+row*87,838,28),20,"a5bea9")
			row+=1
		g.label_at(g.modal,"[你的选择]  "+choice_text(n),Rect2(279,408,836,104),20,"d4d7c3")
		g.button_at(g.modal,"回查本章原件",Rect2(275,523,400,44),func(): show_sources(n,true))
	g.button_at(g.modal,"返回当前案卷",Rect2(703,523,418,44),g.show_journal,true)

func show_overview() -> void:
	g.new_modal("全篇卷宗 / 目前已经知道的故事",true)
	g.label_at(g.modal,"从个人案件到公共规则。点开已结案条目，可查看经过、依据和你的选择。",Rect2(34,76,1094,51),20,"bccab4")
	var links: Array=[
		"宋屿案：恢复不能抵消死亡。Q-17 把个人遭遇带到清理名单。",
		"旧街案：伪造地契应单独追责，不能借此注销真实居民。",
		"签名案：同名不等于同一意愿。旧错误、模板套用与反对要分开。",
		"水闸案：删去条件的旧文不能授予永久控制，居民要求共同复核。",
		"来信案：冻结与删日志是不同责任。可审计通信让两边获得联系。",
		"表决案：历史副本不能添票，当期异议不能被摘要替换。"]
	for i in 6:
		var n: int=i+1
		var b=g.button_at(g.modal,"%02d  %s" % [n,links[i] if closed(n) else "未结案 / 这一段尚未收录"],Rect2(34,140+i*57,1094,47),func(): show_archive(n),true)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.disabled=not closed(n)
	g.label_at(g.modal,"串联的是证据与问题；没有证据的关联不会自动写成事实。",Rect2(34,486,1092,30),20,"bfa977")
	g.button_at(g.modal,"返回当前案卷",Rect2(745,534,383,42),g.show_journal,true)
