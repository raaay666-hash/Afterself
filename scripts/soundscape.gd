extends Node

var rain: AudioStreamPlayer
var drone: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var enabled: bool = true
var level: float = 0.55
var clips: Dictionary = {}
var next_voice: int = 0

func _ready() -> void:
	for key in ["rain","drone","step","paper","click","found","lock"]:
		var path: String="res://assets/audio/"+key+".wav"
		if ResourceLoader.exists(path): clips[key]=load(path)
	rain=AudioStreamPlayer.new()
	drone=AudioStreamPlayer.new()
	add_child(rain);add_child(drone)
	for pair in [[rain,"rain"],[drone,"drone"]]:
		if clips.has(pair[1]):
			var stream: AudioStreamWAV=clips[pair[1]].duplicate()
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin=0
			# Imported WAVs may be compressed; byte length is not the sample count.
			stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
			pair[0].stream=stream
			if enabled: pair[0].play()
	for i in 5:
		var voice:=AudioStreamPlayer.new()
		add_child(voice)
		effects.append(voice)
	refresh()

func refresh() -> void:
	var db: float=linear_to_db(maxf(level,0.0001))
	rain.volume_db=db-12 if enabled else -80
	drone.volume_db=db-12 if enabled else -80
	for voice in effects: voice.volume_db=db-4 if enabled else -80
	for player in [rain,drone]:
		if enabled and not player.playing: player.play()
		elif not enabled and player.playing: player.stop()

func scene_mix(scene_id: String) -> void:
	refresh()
	if enabled:
		rain.volume_db-=10 if scene_id in ["archive","clinic","server","boardroom"] else (5 if scene_id=="waterworks" else 0)

func play(key: String) -> void:
	if not enabled or not clips.has(key): return
	var voice: AudioStreamPlayer=effects[next_voice%effects.size()]
	next_voice+=1
	voice.stream=clips[key]
	voice.play()

func stop_all() -> void:
	for player in [rain,drone]:
		if is_instance_valid(player): player.stop();player.stream=null
	for voice in effects:
		if is_instance_valid(voice): voice.stop();voice.stream=null

func _exit_tree() -> void:
	stop_all()
