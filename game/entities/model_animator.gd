extends Node
## Maps clips to logical states by keyword, because models bring their own names
## ("Duck_walk" vs. "walk"). Movement clips loop; one-shots do not. The dive clip is
## a seamless full cycle where the duck spends most of the time upside down, so it is
## looped natively instead of frozen with seek() — freezing killed the leg paddling (8.C.2).

const KEYWORDS := {
	"idle": ["idle", "stand", "rest"],
	"walk": ["walk", "run", "waddle", "move"],
	"swim": ["swim", "float", "paddle"],
	"dive": ["dive", "dabble", "eat", "bob", "feed"],
	"fly": ["fly", "flap", "jump"],
}
const LOOPING := ["idle", "walk", "swim", "dive"]

var player: AnimationPlayer
var clips: Dictionary = {}   # state -> clip name
var current_state := ""

func setup(p: AnimationPlayer) -> void:
	player = p
	for clip in p.get_animation_list():
		var lower := clip.to_lower()
		for state in KEYWORDS:
			if clips.has(state):
				continue
			for kw in KEYWORDS[state]:
				if kw in lower:
					clips[state] = clip
					break
	for state in clips:
		var anim := p.get_animation(clips[state])
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR if state in LOOPING else Animation.LOOP_NONE
	if not clips.has("idle") and clips.size() > 0:
		clips["idle"] = clips.values()[0]
	set_state("idle")

func set_state(state: String) -> void:
	if state == current_state or player == null:
		return
	var clip: String = clips.get(state, clips.get("idle", ""))
	if clip == "":
		return
	current_state = state
	if player.current_animation != clip:
		player.play(clip, 0.15)

func has_state(state: String) -> bool:
	return clips.has(state)
