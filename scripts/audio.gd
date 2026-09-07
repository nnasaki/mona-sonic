class_name CoastAudio
extends Node

var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index := 0
var last_ring := -1.0
var wind := AudioStreamPlayer.new()

func _ready() -> void:
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/coast.wav"):
		var track := load("res://assets/audio/coast.wav") as AudioStreamWAV
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_end = track.data.size()/2
		music.stream = track
		music.volume_db = -14
		if DisplayServer.get_name() != "headless":
			music.play()
	for i in 10:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for kind in ["ring","jump","dash","homing","chain","spring","hurt","land","drift","finish","charge","shortcut","hit"]:
		sounds[kind] = synth(kind)
	add_child(wind)
	wind.stream = synth("wind")
	wind.volume_db = -45
	if DisplayServer.get_name() != "headless":
		wind.play()

func synth(kind: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.23
	if kind in ["spring","dash","finish","wind"]:
		duration = 0.6 if kind != "wind" else 2.0
	var data := PackedByteArray()
	data.resize(int(duration*sample_rate)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 38
	var low_noise := 0.0
	var phase := 0.0
	for i in data.size()/2:
		var t := i/float(sample_rate)
		var u := t/duration
		var envelope := pow(1-u,2)*minf(t*180,1)
		var hz := 880.0
		var signal_value := 0.0
		match kind:
			"ring": hz = 1318.5 if t < 0.09 else 1760.0
			"jump": hz = 320+u*1100
			"homing": hz = 450+u*2000
			"chain": hz = 660+floorf(u*3)*220
			"spring": hz = 200+u*900+sin(u*60)*80
			"hurt": hz = 240-u*150
			"land": hz = 80-u*50
			"charge": hz = 140+u*760
			"finish": hz = [587.3,740.0,880.0,1174.7][mini(3,int(u*4))]
			"shortcut": hz = 880+floorf(u*3)*220
			"drift": hz = 480+u*700
			"hit": hz = 110+u*40
			_: hz = 140+u*400
		phase += TAU*hz/sample_rate
		low_noise = lerpf(low_noise,rng.randf_range(-1,1),0.17)
		signal_value = (sin(phase)+0.22*sin(phase*2))*envelope*0.34
		if kind in ["dash","hurt","hit","land"]:
			signal_value += low_noise*envelope*0.65
		if kind == "wind":
			signal_value = low_noise*0.7
		data.encode_s16(i*2,int(clampf(signal_value,-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if kind == "wind":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = data.size()/2
	return wav

func play(kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sounds.has(kind):
		return
	if kind == "ring":
		var now := Time.get_ticks_msec()/1000.0
		if now-last_ring < 0.047:
			return
		last_ring = now
	var voice := voices[voice_index%voices.size()]
	voice_index += 1
	voice.stream = sounds[kind]
	voice.volume_db = -13 if kind in ["ring","land"] else -10
	voice.pitch_scale = 1.0
	voice.play()

func update(speed: float, racing: bool) -> void:
	wind.volume_db = lerpf(-49,-20,clampf(speed/85,0,1))
	music.volume_db = -13 if racing else -17

func _exit_tree() -> void:
	for voice in voices+[music,wind]:
		voice.stop()
		voice.stream = null
