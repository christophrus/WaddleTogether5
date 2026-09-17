extends Node
class_name WaddleTest
## Base for one-file tests. Every check prints its actual values, so a failure says
## *what* broke. finish() prints exactly one RESULT line and exits with a code.

var test_name := "TEST"
var _failures: Array[String] = []
var _checks := 0
var _finished := false

func run(_main: Node) -> void:
	push_error("run() not implemented")
	finish()

func check(cond: bool, label: String, actual = null) -> bool:
	_checks += 1
	var detail := "" if actual == null else " (actual: %s)" % str(actual)
	if cond:
		print("[%s] ok   - %s%s" % [test_name, label, detail])
	else:
		print("[%s] FAIL - %s%s" % [test_name, label, detail])
		_failures.append(label)
	return cond

func check_eq(actual, expected, label: String, _detail = null) -> bool:
	return check(actual == expected, label, "%s, expected %s" % [str(actual), str(expected)])

func check_near(actual: float, expected: float, tol: float, label: String) -> bool:
	return check(absf(actual - expected) <= tol, label, "%s, expected %s ±%s" % [actual, expected, tol])

func finish() -> void:
	if _finished:
		return
	_finished = true
	if _failures.is_empty():
		print("[%s] RESULT: PASS (%d checks)" % [test_name, _checks])
		get_tree().quit(0)
	else:
		print("[%s] RESULT: FAIL (%d/%d failed): %s" % [test_name, _failures.size(), _checks, ", ".join(_failures)])
		get_tree().quit(1)

# --- Helpers used by nearly every test ------------------------------------------

## Advance the simulation by n physics frames.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Byte-level backup of a file so a test that can save never destroys real data.
static func backup_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)

static func restore_file(path: String, bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

## Signal spy: returns a one-element array (a reference, see 8.E.1) that counts emissions.
func spy(sig: Signal) -> Array:
	var count := [0]
	sig.connect(func(_a = null, _b = null, _c = null): count[0] += 1)
	return count

func park(main: Node) -> Node3D:
	return main.park

func mother(main: Node) -> Node3D:
	return main.park.mother

func nest(main: Node) -> Node3D:
	return main.park.nest

func ducklings(main: Node) -> Array:
	return main.park.ducklings()

## Bootstrap: build the nest, lay n eggs, hatch them. Almost every test needs this.
func bootstrap_brood(main: Node, egg_count: int) -> Array:
	var p := park(main)
	p.nest.debug_complete()
	for i in egg_count:
		p.nest.lay_egg()
	p.nest.debug_hatch_all()
	await frames(2)
	return p.ducklings()
