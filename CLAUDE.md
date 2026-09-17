# WaddleTogether – working notes for agents

Read REBUILD-BRIEF.md sections 3 (hard design rules) and 8 (bug catalogue) before
touching gameplay. The four rules are a checklist for every feature:

1. No UI bar, number or stat for anything relational (learning, bond, temperament,
   neighbour trust). Behaviour is the only display. Object counters are fine.
2. No penalty, no loss, nothing dies or expires.
3. Rituals need a place or an action as condition, never just a time of day.
4. Never scrape assets from third-party web viewers. CC0 packs are fine.

## Conventions

- Player-facing text: German. Code and comments: English, explaining *why*.
- Systems talk through `EventBus` signals only. The learning signal is
  `mother_demonstrated` (neutral name: helpers emit it too).
- Entities reference each other by id in `GameState`; all progress lives there and in
  the one save file.
- Interactables: nodes in group `interactable` with `get_interaction_prompt(duck)` and
  `interact(duck)`. No base class.
- Groups as runtime registry: `duck`, `duckling`, `pickup`, `nest_site`, `neighbour`,
  `zone_gate`, `adventure_zone`, `keep_out`, `water`, `park`.
- Collision: layer 1 = everything solid (mask 0). Mother layer 2, ducklings layer 8,
  both mask 1. New solid props need no layer setup.
- `.uid` files are committed. Run the script check after adding scripts.

## Commands

```bash
tools/run_tests.sh                       # full suite, ordered (smoke, save_load first)
tools/run_tests.sh <name>                # one test: game/tests/<name>_test.gd
godot --headless --path . res://tools/check_scripts.tscn   # parse check
godot --headless --path . res://tools/inspect_model.tscn   # model sizes / clips
WADDLE_VIEW=pond WADDLE_SHOT=out.png godot --path . res://tools/screenshot.tscn  # GUI only
```

Godot 4.7.1 lives in the winget package folder; `tools/run_tests.sh` has the path and
honours `$GODOT`.

## Test rules

- One test = one file, `extends WaddleTest`, `run(main)`, exactly one `RESULT:` line.
- Print actual values on every check. Reset state between repeated steps (a fed duckling
  is a no-op target). Before "fixing" code for a failing test, ask whether the scenario is
  reachable in the real game.
- Tests that can save back up the real save file bytewise (`backup_file`/`restore_file`).
- Time-lapse levers: `Nest.incubation_seconds`, `Daytime.day_length_seconds`,
  `NeedsComponent.hunger_rate`, `Neighbour.calm_rate`, `Daytime.set_time()`.
- Visual work is not done until a screenshot has been looked at (build → look → adjust).
