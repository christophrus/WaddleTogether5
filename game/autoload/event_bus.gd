extends Node
## Signal-only coupling hub. No logic lives here on purpose: every system talks
## through these signals so features stay independent and tests can spy on a
## signal instead of wiring up objects.

# --- Nest & brood --------------------------------------------------------------
signal nest_material_delivered(count: int, needed: int)
signal nest_completed
signal egg_laid(egg_id: int)
signal egg_hatched(duckling_id: int)
signal duckling_fed(duckling_id: int)
signal duckling_grew(duckling_id: int, stage: int)
signal duckling_left_nest(duckling_id: int)
signal duckling_fledged(duckling_id: int)
signal duckling_named(duckling_id: int, duck_name: String)
signal duckling_slept(duckling_id: int)
signal duckling_cuddled(duckling_id: int)
## First cuddle of a nameless duckling: the HUD opens the naming scene (5.4).
signal naming_requested(duckling_id: int, suggestion: String)

# --- Learning ------------------------------------------------------------------
## Deliberately NOT "mother_did_x": in the generations cycle grown helpers emit
## the exact same signal, which makes that feature a zero-change on the learner.
signal mother_demonstrated(skill: String, position: Vector3, amount: float)
## Internal notification for tests / journal. Must never drive a UI bar (rule 3.1).
signal duckling_learned(duckling_id: int, skill: String, threshold: int)

# --- Mother --------------------------------------------------------------------
signal pickup_collected(kind: String)
signal call_made(kind: String) # gather | look | far | lullaby
signal dabble_finished(result: String) # food | keepsake | nothing

# --- World ---------------------------------------------------------------------
signal zone_unlocked(zone_id: String)
signal adventure_started(adventure_id: String)
signal adventure_completed(adventure_id: String)
signal neighbour_befriended(neighbour_id: String)
signal keepsake_placed(kind: String, finder: String)
signal night_fell
signal dawn_broke(day_index: int)

# --- Generations ---------------------------------------------------------------
signal new_generation(egg_count: int)
signal helper_promoted(duckling_id: int)

# --- Meta ----------------------------------------------------------------------
signal journal_entry_added(text: String)
signal game_saved
signal game_loaded
signal new_game_started
