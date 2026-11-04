extends Node
## Autoload. Owns money (integer cents), bag (space units), upgrades and beach health.

const Catalog := preload("res://scripts/catalog.gd")
const SAVE_VERSION := 2

signal bag_changed
signal money_changed
signal health_changed(value: float)
signal bag_full
signal upgrades_changed
## Cents paid out for a recycled bag (emitted once the sorting animation ends).
signal sold(amount: int)
## Emitted once per milestone id (see MILESTONES) when health first reaches it.
signal milestone_reached(id: String)

const MILESTONES := [
	{"id": "crabs", "at": 0.25, "msg": "The crabs are back!"},
	{"id": "gulls", "at": 0.5, "msg": "Gulls are circling overhead!"},
	{"id": "turtle", "at": 0.75, "msg": "A sea turtle has come ashore!"},
	{"id": "hatchlings", "at": 1.0, "msg": "The hatchlings are heading to the sea!"},
]

## Upgrade table (base cost in cents). cost(id) = base * 1.6^level. Order = order in the shack panel.
const UPGRADE_ORDER := ["bag", "arms", "grabber", "sandals", "rake", "net"]
const UPGRADES := {
	"bag": {"name": "Bigger bag", "base": 200, "max": 8},
	"arms": {"name": "Long arms", "base": 300, "max": 6},
	"grabber": {"name": "Grabber", "base": 480, "max": 5},
	"sandals": {"name": "Sandals", "base": 240, "max": 5},
	"rake": {"name": "Beach rake", "base": 600, "max": 4},
	"net": {"name": "Casting net", "base": 1200, "max": 3},
}
## Casting net by level (index = level; 0 = not owned): how far from the player it can land, and its radius (m).
const NET_RANGE := [0.0, 12.0, 18.0, 22.0]
const NET_RADIUS := [0.0, 2.0, 3.0, 4.0]
const BASE_BAG := 10.0  # bag space units
const BASE_REACH := 2.5
const BASE_SPEED := 5.0
const COST_GROWTH := 1.5

var levels: Dictionary = {"bag": 0, "arms": 0, "grabber": 0, "sandals": 0, "rake": 0, "net": 0}

var cents: int = 0
## Cents of a bag being sorted at the bins: already out of the bag, not yet paid (saved with the money).
var pending: int = 0
var bag_capacity: float = BASE_BAG
## Items in the bag: {id: String, value: int (cents), space: float}
var bag: Array[Dictionary] = []
var cleared_count: int = 0
var initial_count: int = 0
## Milestone ids already reached (task 7: restore on load).
var reached: Array[String] = []
## The "buy a casting net" hint was already shown (saved, so it appears once per game).
var net_hint_shown := false

func bag_used() -> float:
	var n := 0.0
	for it in bag:
		n += float(it.space)
	return n

func bag_value() -> int:
	var n := 0
	for it in bag:
		n += int(it.value)
	return n

func can_add(space: float) -> bool:
	return bag_used() + space <= bag_capacity + 0.0001

## Put a catalog item in the bag. False (and `bag_full`) if it doesn't fit.
func add_to_bag(id: String) -> bool:
	var it: Dictionary = Catalog.ITEMS[id]
	if not can_add(float(it.space)):
		bag_full.emit()
		return false
	bag.append({"id": id, "value": int(it.value), "space": float(it.space)})
	bag_changed.emit()
	return true

func add_money(n: int) -> void:
	cents += n
	money_changed.emit()

## Beach health 0..1 = cleared / initial pieces.
func health() -> float:
	if initial_count <= 0:
		return 0.0
	return clampf(float(cleared_count) / float(initial_count), 0.0, 1.0)

func set_initial_count(n: int) -> void:
	initial_count = n

## Call when any piece is picked up. Tide pieces count too, but never beyond the initial total.
func register_clear() -> void:
	var before := cleared_count
	cleared_count = mini(cleared_count + 1, initial_count)
	if cleared_count != before:
		health_changed.emit(health())
		var h := health()
		for m in MILESTONES:
			if h >= float(m.at) - 0.0001 and not reached.has(m.id):
				reached.append(m.id)
				milestone_reached.emit(m.id)

## Message-bottle ids (0..4) already found; see scripts/notes.gd.
var found_notes: Array[int] = []
## Saved debris [{type,x,y,z}] from the last load, or null (= scatter a new beach).
var loaded_debris = null
var save_path := "user://save.json"
## True with --fresh: ignore the save file and never write one.
var no_save := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	no_save = args.has("--fresh")
	if not no_save:
		load_game()
	for a in args:  # dev: --coins=CENTS, --found=0,2
		if a.begins_with("--coins="):  # dev: starting money in CENTS
			cents = int(a.trim_prefix("--coins="))
		elif a.begins_with("--found="):
			found_notes.clear()
			for s in a.trim_prefix("--found=").split(",", false):
				found_notes.append(int(s))
	sold.connect(func(_n): save_game())
	var t := Timer.new()
	t.wait_time = 30.0
	t.timeout.connect(save_game)
	add_child(t)
	t.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func find_note(id: int) -> void:
	if not found_notes.has(id):
		found_notes.append(id)
		save_game()

# ---- save / load (user://save.json)

func to_dict() -> Dictionary:
	var deb: Array = []
	for d in get_tree().get_nodes_in_group("debris"):
		var p: Vector3 = d.global_position
		deb.append({"id": d.id, "x": snappedf(p.x, 0.001), "y": snappedf(p.y, 0.001), "z": snappedf(p.z, 0.001)})
	var ids: Array = []
	for it in bag:
		ids.append(it.id)
	return {"version": SAVE_VERSION, "cents": cents + pending, "bag": ids, "levels": levels, "cleared": cleared_count,
		"initial": initial_count, "reached": reached, "net_hint": net_hint_shown, "found": found_notes, "debris": deb}

func from_dict(d: Dictionary) -> void:
	cents = int(d.get("cents", 0))
	pending = 0
	bag.clear()
	for bid in d.get("bag", []):
		if Catalog.ITEMS.has(str(bid)):
			var it: Dictionary = Catalog.ITEMS[str(bid)]
			bag.append({"id": str(bid), "value": int(it.value), "space": float(it.space)})
	for id in levels:
		levels[id] = clampi(int(d.get("levels", {}).get(id, 0)), 0, int(UPGRADES[id].max))
	cleared_count = int(d.get("cleared", 0))
	initial_count = int(d.get("initial", 0))
	reached.clear()
	for r in d.get("reached", []):
		reached.append(str(r))
	found_notes.clear()
	for f in d.get("found", []):
		found_notes.append(int(f))
	net_hint_shown = bool(d.get("net_hint", false))
	loaded_debris = d.get("debris", null)
	_apply()

## Back to a brand-new game (cheats reset). The caller reloads the scene.
func reset() -> void:
	cents = 0
	pending = 0
	bag.clear()
	for id in levels:
		levels[id] = 0
	cleared_count = 0
	initial_count = 0
	reached.clear()
	net_hint_shown = false
	found_notes.clear()
	loaded_debris = null
	_apply()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func save_game() -> void:
	if no_save:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

## Returns true if a valid save was applied; otherwise leaves a fresh game.
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (d is Dictionary) or int(d.get("version", 1)) != SAVE_VERSION:
		return false  # corrupt or an old (pre-cents) save: start fresh
	from_dict(d)
	return true

## Empty the bag for sorting at the bins. Returns the items; their total value waits in `pending` until pay().
func take_bag() -> Array[Dictionary]:
	var items := bag.duplicate()
	pending += bag_value()
	bag.clear()
	bag_changed.emit()
	return items

## Pay out `n` pending cents (end of the sorting animation).
func pay(n: int) -> void:
	pending = maxi(pending - n, 0)
	if n > 0:
		add_money(n)
		sold.emit(n)

## Sell the whole bag at once, no animation (tests / tools). Returns the cents earned.
func sell_bag() -> int:
	var n := bag_value()
	take_bag()
	pay(n)
	return n

func level(id: String) -> int:
	return int(levels.get(id, 0))

func is_maxed(id: String) -> bool:
	return level(id) >= int(UPGRADES[id].max)

func cost(id: String) -> int:
	return roundi(float(UPGRADES[id].base) * pow(COST_GROWTH, level(id)))

func can_buy(id: String) -> bool:
	return not is_maxed(id) and cents >= cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	cents -= cost(id)
	levels[id] = level(id) + 1
	_apply()
	money_changed.emit()
	upgrades_changed.emit()
	return true

## Effects (the player reads these on `upgrades_changed`).
func reach_for(lvl: int) -> float:
	return BASE_REACH + 0.75 * lvl

func speed_for(lvl: int) -> float:
	return BASE_SPEED * (1.0 + 0.1 * lvl)

func grab_rate_for(lvl: int) -> float:  # pieces per second
	return 0.0 if lvl <= 0 else 1.5 + 1.0 * lvl

func rake_radius_for(lvl: int) -> float:
	return 0.6 * lvl

func net_range_for(lvl: int) -> float:
	return NET_RANGE[clampi(lvl, 0, NET_RANGE.size() - 1)]

func net_radius_for(lvl: int) -> float:
	return NET_RADIUS[clampi(lvl, 0, NET_RADIUS.size() - 1)]

func bag_for(lvl: int) -> float:
	return BASE_BAG + 5.0 * lvl

func reach() -> float: return reach_for(level("arms"))
func move_speed() -> float: return speed_for(level("sandals"))
func grab_rate() -> float: return grab_rate_for(level("grabber"))
func rake_radius() -> float: return rake_radius_for(level("rake"))
func net_range() -> float: return net_range_for(level("net"))  ## 0 = no net
func net_radius() -> float: return net_radius_for(level("net"))

func _apply() -> void:
	bag_capacity = bag_for(level("bag"))
	bag_changed.emit()

## "current -> next" effect text for the panel.
func effect_text(id: String) -> String:
	var l := level(id)
	var m := is_maxed(id)
	match id:
		"bag":
			return "Space %s" % Catalog.num(bag_for(l)) if m else "Space %s  >  %s" % [Catalog.num(bag_for(l)), Catalog.num(bag_for(l + 1))]
		"arms":
			return "Reach %.2f m" % reach_for(l) if m else "Reach %.2f m  >  %.2f m" % [reach_for(l), reach_for(l + 1)]
		"grabber":
			if l == 0:
				return "Hold click to vacuum litter in a cone (%.1f/s)" % grab_rate_for(1)
			return "Vacuum %.1f/s" % grab_rate_for(l) if m else "Vacuum %.1f/s  >  %.1f/s" % [grab_rate_for(l), grab_rate_for(l + 1)]
		"sandals":
			return "Speed +%d%%" % (l * 10) if m else "Speed +%d%%  >  +%d%%" % [l * 10, (l + 1) * 10]
		"rake":
			if l == 0:
				return "Pickups also grab litter within %.1f m" % rake_radius_for(1)
			return "Sweep radius %.1f m" % rake_radius_for(l) if m else "Sweep radius %.1f m  >  %.1f m" % [rake_radius_for(l), rake_radius_for(l + 1)]
		"net":
			if l == 0:
				return "Hold right-click to aim, release to cast: %d m, %d m radius" % [net_range_for(1), net_radius_for(1)]
			if m:
				return "Range %d m, radius %d m" % [net_range_for(l), net_radius_for(l)]
			return "Range %d > %d m, radius %d > %d m" % [net_range_for(l), net_range_for(l + 1), net_radius_for(l), net_radius_for(l + 1)]
	return ""
