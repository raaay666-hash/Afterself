extends RefCounted
const UI=preload("res://scripts/playthrough_test.gd")

static func solution(g: Node, n: int) -> Array:
	var c: Dictionary=g.Desk.book()[str(n)]
	if c.kind=="order": return range(c.pieces.size())
	return g.Desk.integers(c.correct if c.kind=="compare" else c.solution)

static func solve_logic(g: Node, n: int) -> void:
	g.desk.task_state(n).values=solution(g,n)
	g.check(g.desk.verify(n),"fieldwork solution accepted "+str(n))

static func completed_fixture(g: Node) -> void:
	g.completed=true;g.identity_choice="independent";g.evidence=g.REQUIRED.duplicate()
	g.journey={"version":5,"chapter":6,"unlocked":6,"choices":{"first_identity":"independent"},"chapters":{}}
	for n in range(2,7):
		var c: Dictionary=g.Flow.book()[str(n)];var s: Dictionary=g.Flow.blank()
		s.evidence=c.evidence.keys();s.claims=c.claims.keys();s.intro=true;s.answers=c.puzzle.correct.duplicate();s.puzzle=true
		s.court=3;s.resolution=c.choices[0].id;s.resolution_seen=true;s.bridge_docs=[0,1];s.bridge_answer=0;s.bridge_done=true
		if n==6: s.private="decline";s.ended=true
		g.journey.chapters[str(n)]=s

static func run(g: Node) -> void:
	g.typewriter=false
	var text: String=""
	for directory in ["res://scripts", "res://assets"]:
		for filename in DirAccess.get_files_at(directory):
			if filename.ends_with(".gd") or filename.ends_with(".json"): text+=FileAccess.get_file_as_string(directory.path_join(filename))
	for filename in ["pixel-small", "pixel-text"]:
		var face: Font=load("res://assets/fonts/"+filename+".otf")
		print("FONT METRICS ",filename," 20=",face.get_height(20)," 24=",face.get_height(24))
		var missing: String=""
		for character in text:
			var code: int=character.unicode_at(0)
			if code>=0x4e00 and code<=0x9fff and not face.has_char(code) and character not in missing: missing+=character
		g.check(missing.is_empty(),"Chinese glyph coverage "+filename+" missing="+missing)
	g.journey={"version":5,"chapter":1,"unlocked":1,"choices":{},"chapters":{}}
	g.completed=false;g.evidence=[]
	g.check(not g.desk.closed(1) and not g.desk.closed(6),"archive conceals unfinished cases")
	g.desk.show_archive(6)
	g.check(not "所谓全体同意" in visible_text(g.modal),"requested locked recap has no spoiler")
	g.desk.task_state(1).values=solution(g,1)
	g.check(not g.desk.verify(1),"fieldwork cannot pass without originals")
	g.journey.unlocked=2;g.journey.choices.first_identity="independent"
	g.check(not g.desk.closed(1),"direct chapter two entry does not invent chapter one completion")
	completed_fixture(g)
	for n in range(1,7):
		g.check(g.desk.closed(n),"completed recap unlocks "+str(n))
		g.check(g.desk.ready(n),"completed source records present "+str(n))
		var c: Dictionary=g.Desk.book()[str(n)]
		var partial: Array=g.Desk.integers(c.get("initial",[]))
		if c.kind=="compare": partial=[0]
		g.desk.task_state(n).values=partial
		var partial_save: Dictionary=g.Flow.sanitize(JSON.parse_string(JSON.stringify(g.journey)))
		g.check(partial_save.desk.tasks[str(n)].values==partial and not partial_save.desk.tasks[str(n)].done,"unfinished manipulation survives save "+str(n))
		g.desk.task_state(n).values=[]
		g.check(not g.desk.verify(n),"empty board rejected "+str(n))
		solve_logic(g,n)
		g.check(g.desk.done(n),"verified board seals "+str(n))
		var restored: Dictionary=g.Flow.sanitize(JSON.parse_string(JSON.stringify(g.journey)))
		g.check(restored.desk.tasks[str(n)].done,"board survives JSON roundtrip "+str(n))
		g.desk.show_archive(n,1)
		g.check("来源：" in visible_text(g.modal),"recap exposes evidence provenance "+str(n))
		g.desk.show_archive(n,0,true)
		g.journey.desk.stories[str(n)]={"values":[0,1,2,3],"done":true}
	var bad: Dictionary=g.Desk.clean({"tasks":{"1":{"values":[0,0,1,2],"done":true},"4":{"values":[15,15,15,15,15,15,15,15,15],"done":true}},"stories":{"2":{"values":[2,0,3,1],"done":true}}})
	g.check(bad.tasks.is_empty(),"duplicate cards and illegal circuit shapes rejected")
	g.check(not bad.stories["2"].done,"incorrect story cannot remain certified")
	for n in [2,6]:
		var all_rows: Array=range(g.Desk.book()[str(n)].left.size())
		g.check(not g.Desk.valid_solution(n,all_rows),"marking every field rejected "+str(n))
	for n in [4,5]:
		var v: Array=solution(g,n);v[4]=g.Desk.rotate(v[4])
		g.check(not g.Desk.valid_solution(n,v),"broken middle connection rejected "+str(n))
		v=solution(g,n);v[0]=g.Desk.rotate(v[0])
		g.check(not g.Desk.valid_solution(n,v),"disconnected inlet rejected "+str(n))
	var cleaned: Dictionary=g.Flow.sanitize(JSON.parse_string(JSON.stringify(g.journey)))
	g.check(cleaned.desk.stories.size()==6,"six story reconstructions persist")
	var old: Dictionary=g.journey.duplicate(true);old.erase("desk")
	g.check(g.Flow.sanitize(old).unlocked==6,"v5 campaign migrates without losing unlocks")
	g.journey=g.Flow.sanitize(old)
	g.journey.chapters["2"].resolution="";g.journey.chapters["2"].bridge_done=false;g.journey.chapters["2"].court=0
	g.start_campaign(2);g.close_modal();g.campaign_flow.show_court()
	g.check(UI.find_button(g,"核验操作结果")!=null,"new confrontation requires field manipulation")
	g.journey.chapters["2"].court=1;g.campaign_flow.show_court()
	g.check(UI.find_button(g,"核验操作结果")==null,"v5 confrontation in progress is not blocked again")
	completed_fixture(g)
	for n in range(1,7): g.desk.data().stories[str(n)]={"values":[0,1,2,3],"done":true}
	var save: String=g.artifact_path("test-desk-save.json")
	g.check(g.save_journey(save,true),"isolated v6 checkpoint writes")
	g.check(g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(save))).desk.stories.size()==6,"disk checkpoint preserves archive")
	print("INVESTIGATION TESTS PASSED" if g.test_failures==0 else "INVESTIGATION FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)

static func visible_text(node: Node) -> String:
	var value: String=node.text if node is Label or node is Button else ""
	for child in node.get_children(): value+=visible_text(child)
	return value

static func solve_window(g: Node, n: int) -> void:
	g.desk.show_legacy_task(n)
	var c: Dictionary=g.Desk.book()[str(n)]
	if g.desk.done(n): g.close_modal();return
	if c.kind=="order":
		for i in c.pieces.size():
			var j: int=g.desk.task_state(n).values.find(i)
			if j!=i:
				await g.mouse_click(g.desk.controls[i].get_global_rect().get_center())
				await g.mouse_click(g.desk.controls[j].get_global_rect().get_center())
	elif c.kind=="compare":
		for i in c.left.size():
			if (i in g.desk.task_state(n).values)!=(i in solution(g,n)):
				await g.mouse_click(g.desk.controls[i].get_global_rect().get_center())
	else:
		for i in 9:
			for turns in 4:
				if int(g.desk.task_state(n).values[i])==int(c.solution[i]): break
				await g.mouse_click(g.desk.controls[i].get_global_rect().get_center())
	await UI.capture(g,"fieldwork-%d" % n)
	await UI.click(g,"核验操作结果")
	g.check(g.desk.done(n),"mouse operation solves board "+str(n))
	await UI.click(g,"已核验 / 返回调查")

static func window_run(g: Node) -> void:
	g.typewriter=false
	completed_fixture(g)
	g.start_campaign(2);g.drain_dialog();g.close_modal()
	await UI.capture(g,"pixel-scene")
	g.start_dialog([["闻遥","记录可以保留，意思却可能被改写。把两份原件放在一起，看看谁删掉了条件，又替谁写下了同意。"]])
	await UI.capture(g,"pixel-dialogue");g.close_modal()
	for n in range(1,7):
		await solve_window(g,n)
	g.desk.show_archive(5)
	await UI.capture(g,"story-archive")
	await UI.click(g,"亲手整理故事卡")
	for i in 4:
		var j: int=g.journey.desk.stories["5"].values.find(i)
		if i!=j:
			await g.mouse_click(g.desk.controls[i].get_global_rect().get_center())
			await g.mouse_click(g.desk.controls[j].get_global_rect().get_center())
	await UI.click(g,"核验故事顺序")
	g.check(g.journey.desk.stories["5"].done,"mouse operation reconstructs story")
	await UI.click(g,"证据与选择");await UI.capture(g,"story-evidence")
	await UI.click(g,"回查本章原件");await UI.click(g,"旧端口接线说明")
	await UI.capture(g,"pixel-document")
	await UI.click(g,"收起");await UI.click(g,"返回故事脉络")
	await UI.click(g,"返回当前案卷")
	g.check(UI.find_button(g,"现场核验")!=null,"archive returns to current chapter journal")
	await UI.capture(g,"pixel-journal")
	await UI.click(g,"故事脉络");await UI.capture(g,"story-overview")
	g.check("Q-17" in visible_text(g.modal),"overview connects known cases")
	g.close_modal();g.show_title();await UI.click(g,"故事脉络");await UI.key(g,KEY_ESCAPE)
	g.check(UI.find_button(g,"章节目录")!=null,"Escape from title archive restores title controls")
	print("INVESTIGATION WINDOW PASSED" if g.test_failures==0 else "INVESTIGATION WINDOW FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)
