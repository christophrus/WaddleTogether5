extends Node
## Maps clips to logical states by keyword, because models bring their own names
## ("Duck_walk" vs. "walk", "Duck_hunt" for the dabble). Keywords are tried in priority
## order and, among clips matching the same keyword, the shortest name wins so
## "Duck_idle" beats "Duck_idle_swim". Movement clips loop; one-shots do not. The dive
## clip is a seamless full cycle where the duck spends most of the time upside down, so
## it is looped natively instead of frozen with seek() — freezing killed the leg
## paddling (8.C.2).

const KEYWORDS := {
	"idle": ["stand_idle", "duck_idle", "idle", "stand", "rest"],
	"walk": ["walk", "waddle", "run", "move"],
	"swim": ["duck_swim", "swim"],
	"dive": ["hunt", "dabble", "dive", "sit_wash", "wash", "eat", "feed"],
	"sleep": ["sleep", "sit_idle", "rest"],
	"fly": ["flapping", "fly", "flap", "jump"],
}
const LOOPING := ["idle", "walk", "swim", "dive", "sleep"]

var player: AnimationPlayer
var clips: Dictionary = {}   # state -> clip name
var current_state := ""

func setup(p: AnimationPlayer) -> void:
	player = p
	var names: Array = Array(p.get_animation_list())
	for state in KEYWORDS:
		for kw in KEYWORDS[state]:
			var best := ""
			for clip in names:
				var lower: String = clip.to_lower()
				# Match against the part after the last "|" so rig prefixes do not count.
				var short := lower.get_slice("|", lower.get_slice_count("|") - 1)
				if kw in short and (best == "" or short.length() < best.get_slice("|", best.get_slice_count("|") - 1).length()):
					best = clip
			if best != "":
				clips[state] = best
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
