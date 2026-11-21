extends RefCounted

const Rig=preload("res://scripts/character_rig.gd")

static func run(g: Node) -> void:
	for fps in [30,60,120]:
		var a=Rig.new();g.add_child(a);a.set_process(false);a.speed=28
		a.position=Vector2.ZERO;a.scale=Vector2.ONE;a.walk_to(70)
		var contacts: Array=[0];a.footstep.connect(func(): contacts[0]+=1)
		var max_slip: float=0
		var max_pose_step: float=0
		var max_step_at: String=""
		var previous_weight: float=0
		var previous: Dictionary={}
		var previous_phase: Dictionary={}
		var previous_feet: Dictionary={}
		for frame in fps*4:
			a._process(1.0/fps)
			for key in a.bones:
				var local: Vector2=a.skeleton.to_local(a.bones[key].global_position)
				if (a.walk_weight<.999 or previous_weight<.999) and previous.has(key) and local.distance_to(previous[key])>max_pose_step:
					max_pose_step=local.distance_to(previous[key]);max_step_at=str(frame)+"/"+str(key)
				previous[key]=local
			for side in ["front","back"]:
				var phase: float=fposmod(a.travelled/a.STRIDE+(0 if side=="front" else .5),1)
				var foot: Vector2=a.bone_world_position(side+"_foot")
				if a.walk_weight>.999 and previous_weight>.999 and a.move_enabled and previous_phase.has(side) and phase>previous_phase[side] and phase<.59:
					max_slip=maxf(max_slip,foot.distance_to(previous_feet[side]))
				previous_phase[side]=phase;previous_feet[side]=foot
			previous_weight=a.walk_weight
		g.check(a.reached and is_equal_approx(a.position.x,70),"accelerated walk arrives at "+str(fps)+" fps")
		g.check(contacts[0]==5,"footstep events follow foot contacts at "+str(fps)+" fps")
		g.check(max_slip<.05,"planted foot world slip "+str(max_slip)+" at "+str(fps)+" fps")
		g.check(max_pose_step<3.0,"continuous start and stop pose at "+str(fps)+" fps, max step="+str(max_pose_step)+" at "+max_step_at)
		g.check(a.walk_weight==0,"walk settles into neutral stance at "+str(fps)+" fps")
		# Reverse while moving; remain finite and reach the replacement destination.
		a.walk_to(120)
		for frame in fps/3: a._process(1.0/fps)
		a.walk_to(30)
		for frame in fps*4: a._process(1.0/fps)
		g.check(a.reached and is_equal_approx(a.position.x,30) and a.facing==-1,"mid-walk destination reversal at "+str(fps)+" fps")
		a.free()
