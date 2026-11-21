extends RefCounted
const UI=preload("res://scripts/playthrough_test.gd")

static func checkpoint(g: Node) -> void:
	var file: String=g.artifact_path("test-campaign.json")
	g.check(g.save_journey(file,true),"campaign checkpoint written")
	g.journey=g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(file)))
	g.start_campaign(int(g.journey.chapter))

static func run(g: Node) -> void:
	g.typewriter=false
	g.journey={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[0]}
	g.check(g.Dossier.known(g,0) and not g.Dossier.known(g,1),"only encountered characters are lit")
	g.check(g.Dossier.notes(g,0).size()==1 and not "清理名单" in str(g.Dossier.notes(g,0)),"first dossier entry keeps later truth hidden")
	g.record_cast_meeting(6,false)
	g.check(g.Dossier.known(g,6) and g.Dossier.notes(g,6).size()==1,"meeting unlocks one initial note")
	g.flags.truth=true
	g.check(g.Dossier.notes(g,6).size()==2,"case truth adds a note after it is known")
	g.flags={}
	g.record_cast_meeting(1,false)
	g.check(g.Dossier.display_name(g,1)=="银发董事","real-world identity stays hidden before chapter three bridge")
	g.journey.chapters["3"]={"bridge_done":true}
	g.check(g.Dossier.display_name(g,1)=="现实林砚" and g.Dossier.notes(g,1).size()==2,"identity and history unlock at the reveal")
	g.record_cast_meeting(2,false)
	g.check(g.Dossier.notes(g,2).size()==1,"Wen's private history stays hidden without her account")
	g.journey.chapters["3"].seen=["闻遥/你为什么如此在意重新编号？"]
	g.check(g.Dossier.notes(g,2).size()==2,"Wen's private history appears after her dialogue")
	var sanitized: Dictionary=g.Flow.sanitize({"version":5,"cast_met":[0,0,6,99,"5",1.5]})
	g.check(sanitized.cast_met==[0,6],"encounter list rejects duplicates and invalid ids")
	g.journey={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[]}
	g.v2_started=true;g.intro_done=true;g.scene_id="archive"
	g.recover_legacy_cast()
	g.check(g.journey.cast_met.has(0) and g.journey.cast_met.has(6) and g.journey.cast_met.has(7) and g.journey.cast_met.has(2) and not g.journey.cast_met.has(5),"older first-chapter save recovers only supported encounters")
	g.v2_started=false;g.intro_done=false;g.scene_id="apartment"
	g.journey={"version":5,"chapter":2,"unlocked":2,"chapters":{},"choices":{"first_identity":"independent","first_future":"breakfast"}}
	for n in range(2,7):
		g.start_campaign(n);g.drain_dialog()
		var f=g.campaign_flow
		g.check(f.number==n and f.state.intro,"chapter intro reachable "+str(n))
		g.check(not f.solve_puzzle(f.chapter.puzzle.correct),"puzzle needs source documents "+str(n))
		g.check(not f.submit(f.chapter.rounds[0].claim),"accusation needs completed investigation "+str(n))
		var keys: Array=f.chapter.evidence.keys();keys.reverse()
		for k in keys: f.read_evidence(k);g.close_modal()
		g.check(f.state.evidence.size()==6,"six documents reachable in arbitrary order "+str(n))
		g.check(f.combine([keys[0],keys[0]]).is_empty(),"duplicate evidence rejected "+str(n))
		for c in f.chapter.claims: g.check(f.combine(f.chapter.claims[c].pair)==c,"chapter claim "+str(n)+"/"+c)
		g.check(not f.solve_puzzle([]),"invalid puzzle rejected "+str(n))
		g.check(f.solve_puzzle(f.chapter.puzzle.correct),"unique puzzle resolved "+str(n))
		for suffix in ["a","b"]:
			g.check(preload("res://scripts/field_test.gd").solve_logic(g,"c%d%s" % [n,suffix]),"new manipulation derives narrative state "+str(n)+suffix)
		preload("res://scripts/investigation_test.gd").solve_logic(g,n)
		checkpoint(g);g.drain_dialog();f=g.campaign_flow
		g.check(f.state.puzzle and f.state.claims.size()==3,"solved investigation survives checkpoint "+str(n))
		for i in 3:
			g.check(not f.submit("invalid"),"unrelated confrontation response rejected")
			g.check(f.submit(f.chapter.rounds[i].claim),"round submitted "+str(n)+"/"+str(i))
			checkpoint(g);g.drain_dialog();f=g.campaign_flow
			g.check(f.state.reply==-1 and f.state.court==i+1,"interrupted confrontation reply replayed")
		g.check(g.choice_locked,"chapter disposition cannot be dismissed")
		if n<6:
			var alternative: Dictionary=g.journey.duplicate(true)
			g.check(f.choose_resolution(f.chapter.choices[1].id),"alternative case disposition "+str(n))
			g.drain_dialog();checkpoint(g);g.drain_dialog();f=g.campaign_flow
			g.check(f.state.resolution==f.chapter.choices[1].id and f.state.resolution_seen,"alternative disposition survives save "+str(n))
			g.journey=alternative;g.start_campaign(n);f=g.campaign_flow
			g.check(f.choose_resolution(f.chapter.choices[0].id),"case disposition accepted "+str(n))
			checkpoint(g);g.drain_dialog();f=g.campaign_flow
			g.check(f.state.resolution_seen,"interrupted disposition response replayed")
			g.check(not f.answer_bridge(0),"interlude requires both documents")
			f.state.bridge_docs=[0,1]
			g.check(f.answer_bridge(1),"interlude accepts informed response")
			checkpoint(g);g.drain_dialog();f=g.campaign_flow
			g.check(not f.state.bridge_done,"unfinished interlude not silently completed")
			f.answer_bridge(1);g.drain_dialog()
			g.check(f.state.bridge_done and g.journey.unlocked==n+1,"next chapter unlocks after interlude "+str(n))
		else:
			var baseline: Dictionary=g.journey.duplicate(true)
			for public_choice in ["isolate","open","joint"]:
				for private_choice in ["upload","decline"]:
					g.journey=baseline.duplicate(true);g.start_campaign(6);f=g.campaign_flow
					g.check(f.choose_resolution(public_choice),"public proposal "+public_choice)
					g.drain_dialog()
					g.check(g.choice_locked and not f.state.ended,"private decision remains independent")
					f.private_epilogue(private_choice);checkpoint(g);g.drain_dialog();f=g.campaign_flow
					g.check(f.state.ended and f.state.private==private_choice,"complete ending "+public_choice+"/"+private_choice)
					g.check(g.background.texture==g.backgrounds.clinic and g.hero.character_id==1,"private ending restores correct setting and viewpoint")
	var malformed: Dictionary=g.Flow.sanitize({"version":5,"chapter":6,"unlocked":6,"chapters":{"6":{"court":3,"resolution":"open","private":"upload","ended":true}},"choices":{}})
	g.check(malformed.unlocked==1 and malformed.chapter==1 and malformed.chapters.is_empty(),"malformed save cannot invent completed campaign")
	g.check(g.backgrounds.size()==9,"all nine environment assets loaded")
	var f=g.campaign_flow
	f.public_epilogue()
	g.check("各有自己的位置" in str(g.current_lines) and "第一批家庭核验" in str(g.current_lines),"separate identities and full ledger affect public epilogue")
	g.journey.choices.first_identity="continued";g.journey.choices.first_future="space"
	g.journey.chapters["3"].resolution="chain";g.journey.chapters["5"].resolution="summary"
	g.journey.chapters["2"].resolution="protected";g.journey.chapters["4"].resolution="trial"
	f.public_epilogue()
	g.check("仍要求" in str(g.current_lines) and "部分家庭的查找要等" in str(g.current_lines),"qualified support and delayed family tracing are explicit consequences")
	g.check("延期" in str(g.current_lines) and "身份还由独立" in str(g.current_lines) and "试测到期" in str(g.current_lines),"life witness and water choices reach final epilogue")
	for id in [1,3,4,5,9,10,11]:
		var t=preload("res://scripts/cast_pixels.gd").get_body(id)
		g.check(t.get_width()==20 and t.get_height()==40,"continuous coarse upper body "+str(id))
		g.check(connected(t.get_image()),"new upper body has no detached head or neck "+str(id))
	print("CAMPAIGN TESTS PASSED" if g.test_failures==0 else "CAMPAIGN FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)

static func connected(im: Image) -> bool:
	var pixels: Dictionary={}
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a>.5: pixels[Vector2i(x,y)]=true
	if pixels.is_empty(): return false
	var queue: Array=[pixels.keys()[0]];pixels.erase(queue[0])
	while not queue.is_empty():
		var p: Vector2i=queue.pop_back()
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if pixels.has(p+step): pixels.erase(p+step);queue.append(p+step)
	return pixels.is_empty()

static func hotspot(g: Node, key: String) -> void:
	var b: Button=g.campaign_flow.controls[key]
	await g.mouse_click(b.get_global_rect().get_center())
	var ticks: int=0
	while g.hero.move_enabled and ticks<300:
		await g.get_tree().create_timer(.02).timeout;ticks+=1
	g.check(not g.hero.move_enabled,"campaign walk reaches "+key)
	await g.get_tree().process_frame

static func window_run(g: Node, from_first: bool = false) -> void:
	g.typewriter=false
	await g.get_tree().process_frame
	if not from_first:
		await UI.click(g,"从第二章开始")
		await UI.click(g,"以此记录进入第二章")
	await UI.dialog(g)
	for n in range(2,7):
		var f=g.campaign_flow
		g.check(f.number==n,"window entered chapter "+str(n))
		for i in 3:
			if n==3 and i==2 and not g.field.chapter_done(3): continue
			await UI.click(g,f.chapter.scenes[i].name)
			await UI.capture(g,"chapter-%d-scene-%d" % [n,i])
			var room: Dictionary=f.chapter.scenes[i]
			var person: Dictionary=room.people[0]
			await hotspot(g,"npc/"+person.name)
			await UI.click(g,"· "+person.topics[0].title);await UI.dialog(g)
			await UI.click(g,"暂时问到这里")
			for item in room.items:
				if not g.field.evidence_gate(n,item.key).is_empty(): continue
				await hotspot(g,"item/"+item.key)
				await UI.click(g,"稍后查看")
		for suffix in ["a","b"]:
			await preload("res://scripts/field_test.gd").solve_window(g,"c%d%s" % [n,suffix],true)
		await preload("res://scripts/field_test.gd").dismiss_notices(g)
		for i in 3:
			var room: Dictionary=f.chapter.scenes[i]
			var missing: bool=false
			for item in room.items:
				if item.key not in f.state.evidence: missing=true
			if not missing: continue
			await UI.click(g,room.name)
			for item in room.items:
				if item.key in f.state.evidence: continue
				await hotspot(g,"item/"+item.key);await UI.click(g,"稍后查看")
		g.check(f.state.puzzle,"window puzzle solved "+str(n))
		await UI.click(g,"案卷 [J]")
		for key in f.chapter.claims:
			for e in f.chapter.claims[key].pair: await UI.click(g,f.chapter.evidence[e].title)
			await UI.click(g,"组合选中的记录");await UI.click(g,"记入推论")
		await UI.click(g,"返回现场")
		g.check(g.field.chapter_done(n),"scene manipulation complete before court "+str(n))
		await UI.click(g,"提交结案推论")
		for r in f.chapter.rounds:
			await UI.click(g,f.chapter.claims[r.claim].title);await UI.dialog(g)
		await UI.capture(g,"chapter-%d-choice" % n)
		await UI.click(g,f.chapter.choices[2 if n==6 else 0].label);await UI.dialog(g)
		if n<6:
			for i in 2:
				await UI.click(g,"· "+f.chapter.bridge.docs[i].title)
				await UI.click(g,"读完，回到现场")
			await UI.capture(g,"chapter-%d-interlude" % n)
			await UI.click(g,f.chapter.bridge.options[0]);await UI.dialog(g)
			await UI.click(g,"继续第 %d 章  →" % [n+1]);await UI.dialog(g)
		else:
			await UI.capture(g,"private-choice")
			await UI.click(g,"上传 / 提交最终备份指令");await UI.dialog(g)
			g.check(f.state.ended,"window complete five chapters and private ending")
			await UI.capture(g,"campaign-ending")
			await UI.click(g,"章节目录")
			await UI.key(g,KEY_ESCAPE)
			g.check(g.choice_locked,"chapter selector cannot leave an empty ending stage")
			await UI.click(g,"返回当前进度")
			g.check(f.state.ended and UI.find_button(g,"回看公共尾声")!=null,"chapter selector resumes final card")
	print("CAMPAIGN WINDOW PLAYTHROUGH PASSED" if g.test_failures==0 else "CAMPAIGN WINDOW FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)
