extends RefCounted

static func find_button(root: Node, text: String) -> Button:
	text=text.replace("✓","+").replace("☑","[X]").replace("□","[ ]").replace("↻",">")
	for child in root.get_children():
		if child is Button and child.text==text: return child
		if child is Button and child.text.is_empty():
			for label in child.get_children():
				if label is Label and label.text==text: return child
		var found: Button=find_button(child,text)
		if found: return found
	return null

static func click(g: Node, text: String) -> void:
	# Let deferred acquisition notices settle before locating the next visible action.
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	var button: Button=find_button(g,text)
	g.check(button!=null,"button exists: "+text)
	if button==null:
		g.get_tree().quit(1)
		await g.get_tree().process_frame
		return
	await g.mouse_click(button.get_global_rect().get_center())

static func hotspot(g: Node, key: String) -> void:
	await g.mouse_click(g.test_ui_nodes[key].get_global_rect().get_center())
	var loops: int=0
	while is_instance_valid(g.hero) and g.hero.move_enabled and loops<100:
		await g.get_tree().create_timer(.08).timeout
		loops+=1
	await g.get_tree().process_frame
	g.check(not g.hero.move_enabled,"walk reaches interaction: "+key)

static func dialog(g: Node) -> void:
	var loops: int=0
	while g.dialog_mode and loops<80:
		await click(g,"继续  →")
		loops+=1
	g.check(loops<80,"dialogue exits or returns to topics")

static func key(g: Node, code: int, unicode_value: int = 0) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.unicode=unicode_value;e.pressed=down
		Input.parse_input_event(e)
		await g.get_tree().process_frame

static func capture(g: Node, filename: String) -> void:
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(g.artifact_path(filename+".png"))

static func run(g: Node) -> void:
	g.typewriter=false;g.simulate_walk=true
	await g.get_tree().process_frame
	await click(g,"开始调查   →")
	g.check(is_instance_valid(g.opening_layer),"opening scene appears before first investigation")
	await click(g,"跳过开场")
	await dialog(g)
	await click(g,"暂 停")
	await click(g,"人物档案")
	g.check(g.Dossier.known(g,6) and g.Dossier.known(g,7) and not g.Dossier.known(g,1),"first case dossier lights met people without future identity")
	await click(g,"×")
	await g.mouse_click(g.test_ui_nodes["su"].get_global_rect().get_center())
	await click(g,"暂 停")
	var paused_position: Vector2=g.hero.position
	await g.get_tree().create_timer(.5).timeout
	g.check(g.hero.position.is_equal_approx(paused_position) and is_instance_valid(g.modal),"pause freezes walk and keeps modal open")
	await click(g,"继续调查")
	var resume_loops: int=0
	while g.hero.move_enabled and resume_loops<100:
		await g.get_tree().create_timer(.08).timeout
		resume_loops+=1
	g.check(not g.hero.move_enabled and find_button(g,"暂时问到这里")!=null,"resume reaches original investigation target")
	await click(g,"暂时问到这里")
	await hotspot(g,"su")
	await click(g,"·  你们是怎么和好的？")
	await dialog(g)
	await click(g,"·  抽屉里的东西，可以看看吗？")
	await dialog(g)
	await click(g,"暂时问到这里")
	await hotspot(g,"calendar");await click(g,"稍后查看")
	await hotspot(g,"drawer")
	for digit in "714": await key(g,digit.unicode_at(0),digit.unicode_at(0))
	await click(g,"转动锁盘")
	g.check("note" in g.evidence,"keyboard enters lock solution")
	await click(g,"稍后查看")
	await hotspot(g,"song")
	await click(g,"·  最后一件记得的事是什么？")
	await dialog(g)
	await click(g,"稍后查看")
	await click(g,"·  你想怎么继续生活？")
	await dialog(g);await click(g,"暂时问到这里")
	await hotspot(g,"lease");await dialog(g);await capture(g,"lease-note");await click(g,"稍后查看")
	await hotspot(g,"bread");await dialog(g);await click(g,"收起侧记")
	await click(g,"维修走廊")
	await hotspot(g,"pressure");await dialog(g);await click(g,"收起侧记")
	await hotspot(g,"order");await click(g,"稍后查看")
	await hotspot(g,"access");await click(g,"收起")
	await hotspot(g,"shao")
	await click(g,"·  维护凭据借给过别人吗？")
	await dialog(g);await click(g,"暂时问到这里")
	await hotspot(g,"neighbor");await dialog(g);await click(g,"收起侧记")
	await click(g,"稍后查看")
	g.check("access" in g.evidence,"custody reconstructed by real scene interactions")
	await click(g,"居民档案室")
	await hotspot(g,"consent");await dialog(g);await click(g,"收起侧记")
	await hotspot(g,"wen")
	await click(g,"·  恢复和复活，区别在哪里？")
	await dialog(g);await click(g,"暂时问到这里")
	await hotspot(g,"terminal")
	# Click the inline record controls; avoid OS-dependent native popups.
	for i in 3:
		var option: Button=g.test_ui_nodes["timeline_"+str(i)]
		for n in [2,3,1][i]: await g.mouse_click(option.get_global_rect().get_center())
		g.check(option.get_meta("record")==[2,3,1][i],"timeline record selection "+str(i))
	await click(g,"核对时间线")
	g.check("restore" in g.evidence,"timeline UI completes")
	await click(g,"稍后查看")
	await hotspot(g,"receipt");await click(g,"稍后查看")
	await click(g,"07号公寓")
	await hotspot(g,"su");await capture(g,"truth-choice")
	await key(g,KEY_ESCAPE);await key(g,KEY_J)
	g.check(g.choice_locked and find_button(g,"先让宋屿知情，由他邀请苏筠")!=null,"critical choice cannot be bypassed by keyboard")
	await click(g,"先让宋屿知情，由他邀请苏筠");await capture(g,"truth-dialogue");await dialog(g)
	await hotspot(g,"su");await click(g,"谈谈明天的安排");await dialog(g)
	await click(g,"提议试一次早餐，不等于答应开店");await dialog(g)
	await click(g,"案 卷  [ J ]")
	await click(g,"现场侧记 / 人物与待办");await capture(g,"fieldnotes");await click(g,"返回证据页")
	for pair in [["宋屿的陈述","恢复登记"],["凭据签收与见证","独立执行回执"],["未寄出的举报便条","夜间维修单"]]:
		await click(g,pair[0]);await click(g,pair[1]);await click(g,"组合这两份记录");await click(g,"写入案卷")
	g.check(g.claims.size()==3,"three claims built with journal UI")
	await click(g,"返回现场")
	await click(g,"维修走廊")
	await preload("res://scripts/investigation_test.gd").solve_window(g,1)
	await hotspot(g,"shao")
	for title in ["不是失忆，是实例替换","M-204 的实际执行人","被删除的举报动机"]:
		await click(g,title);await dialog(g)
	g.check(g.court_step==3,"three confrontation rounds completed through UI")
	await capture(g,"custody-choice")
	await click(g,"附上材料，请求调查清理程序与资格续期");await dialog(g)
	await hotspot(g,"song");await dialog(g)
	await click(g,"单列现行实例，保留历史联系");await dialog(g)
	await capture(g,"horizon-window")
	await click(g,"查看维护窗口与清理附页");await capture(g,"horizon-reveal");await dialog(g)
	g.check(g.completed and g.identity_choice=="independent","full playable chapter reaches ending")
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(g.artifact_path("ending-playthrough.png"))
	await click(g,"回访现场")
	await click(g,"暂 停")
	await click(g,"开发附录 · 骨骼检视")
	g.check(g.lab_actor.bones.size()==25,"pixel character laboratory uses 25 bones")
	await click(g,"骨架开关")
	await click(g,"转身")
	var screen_target: Vector2=g.lab_actor.to_global(Vector2(-10,-32))
	await g.mouse_click(screen_target)
	await g.get_tree().create_timer(.6).timeout
	g.check(g.lab_actor.bone_world_position("front_hand").distance_to(screen_target)<.5,"mirrored pixel canvas maps mouse target correctly")
	print("FULL WINDOW PLAYTHROUGH PASSED" if g.test_failures==0 else "PLAYTHROUGH FAILURES: "+str(g.test_failures))
	if "--full-story-test" in OS.get_cmdline_user_args():
		g.show_ending()
		await click(g,"继续第二章  →")
		await preload("res://scripts/campaign_test.gd").window_run(g,true)
		return
	g.get_tree().quit(0 if g.test_failures==0 else 1)
