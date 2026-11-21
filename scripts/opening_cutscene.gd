extends Control

signal completed

const SHOTS = [
	{"scene":"street","kicker":"第七码头 / 06:37","title":"雨下了一夜。","body":"林砚，异常案件调查员。\n清晨的巡查被一通报案打断。","note":"地点：07 号公寓。报案人：苏筠。"},
	{"scene":"apartment","kicker":"07 号公寓 / 报案录音","title":"他醒了。","body":"苏筠：昨夜他照常睡下，今早也照常起床。\n可他不记得我们刚和好的那三天。","note":"当事人的记忆与家人的经历对不上。"},
	{"scene":"corridor","kicker":"维修走廊 / 两种说法","title":"昨夜有人离开。","body":"值班邻居说，凌晨见过一辆盖布担架。\n管理处的答复却是：昨夜没有死亡记录。","note":"证词与记录冲突，哪一边都还不是结论。"},
	{"scene":"apartment","kicker":"第一章 / 睡过头的人","title":"从眼前的人查起。","body":"先去 07 号公寓，分别听苏筠和宋屿说话。\n再核对现场、夜班工单与档案记录。","note":"鼠标调查  ·  H 显示热点  ·  J 打开案卷"}
]

var game: Control
var shot_index: int = 0
var elapsed: float = 0.0
var moving_view: TextureRect
var veil: ColorRect
var active_tween: Tween

func begin(owner: Control) -> void:
	game=owner
	z_index=70
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	show_shot(0)

func _process(delta: float) -> void:
	elapsed+=delta
	if not game.testing and shot_index<SHOTS.size()-1 and elapsed>=9.0: next_shot()

func show_shot(index: int) -> void:
	shot_index=index
	elapsed=0.0
	if is_instance_valid(active_tween): active_tween.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var shot: Dictionary=SHOTS[index]
	game.set_background(shot.scene)
	moving_view=TextureRect.new()
	moving_view.texture=game.backgrounds[shot.scene]
	moving_view.position=Vector2(-22,-12)
	moving_view.size=Vector2(1324,744)
	moving_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	moving_view.stretch_mode=TextureRect.STRETCH_SCALE
	moving_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	moving_view.material=game.background.material
	moving_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(moving_view)
	game.shade(self,Rect2(0,0,1280,720),Color("07111577"))
	game.shade(self,Rect2(0,0,773,720),Color("071115e5"))
	game.shade(self,Rect2(48,58,6,587),Color("d3b982"))
	game.label_at(self,"启动阶段  /  开场",Rect2(79,57,620,36),22,"bdcfc5")
	game.label_at(self,shot.kicker,Rect2(80,162,650,42),24,"d6bc86")
	game.label_at(self,shot.title,Rect2(74,229,680,86),54,"f4e7c8")
	var body: Label=game.label_at(self,shot.body,Rect2(82,346,670,155),28,"e5e4d6")
	body.add_theme_constant_override("line_spacing",12)
	game.label_at(self,shot.note,Rect2(82,544,675,64),20,"b4c5bc")
	game.label_at(self,"%02d / %02d" % [index+1,SHOTS.size()],Rect2(1113,48,120,36),20,"e5d3ac")
	game.button_at(self,"跳过开场",Rect2(1017,626,207,48),finish,true)
	game.button_at(self,"进入调查  →" if index==SHOTS.size()-1 else "下一幕  →",Rect2(802,626,200,48),next_shot)
	game.label_at(self,"空格 / 回车继续     Esc 跳过",Rect2(80,650,670,34),18,"91aaa5")
	veil=game.shade(self,Rect2(0,0,1280,720),Color("071115"))
	active_tween=create_tween().set_parallel(true)
	active_tween.tween_property(veil,"modulate:a",0.0,.55)
	active_tween.tween_property(moving_view,"position",Vector2(0,0),9.0)

func next_shot() -> void:
	if shot_index+1>=SHOTS.size(): finish()
	else: show_shot(shot_index+1)

func finish() -> void:
	set_process(false)
	completed.emit()

func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo: return false
	if event.keycode==KEY_ESCAPE: finish();return true
	if event.keycode in [KEY_SPACE,KEY_ENTER]: next_shot();return true
	return false
