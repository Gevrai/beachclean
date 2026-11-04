extends Node

const Catalog := preload("res://scripts/catalog.gd")
## Rough economy estimate (not a pass/fail test): godot --headless --path . res://tools/tests/tune_sim.tscn -- --fresh
## Models a reasonable player (aim ~0.9 s/piece, walking, shack trips, buys the best value-per-coin upgrade).
## Reads costs/effects from GameState and item values/space/weights from Catalog (money in cents, bag in space units). Args: --n=INITIAL --aim=SECONDS

const AREA := 2200.0      # m^2 of debris field
const SHACK_DIST := 25.0  # avg one-way walk from field to shack (m)
const SELL_TIME := 4.0    # s spent at the shack (sell + shop)

var N := 340
var AIM := 0.9
var COST := 1.0   # multiplier on base costs (to try tunings without editing GameState)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): N = int(a.trim_prefix("--n="))
		if a.begins_with("--aim="): AIM = float(a.trim_prefix("--aim="))
		if a.begins_with("--cost="): COST = float(a.trim_prefix("--cost="))
	var r := run()
	print("SIM n=%d aim=%.1f cost=x%.1f  first_upgrade=%.1f min  25%%=%.1f 50%%=%.1f 75%%=%.1f 100%%=%.1f min  levels=%s trips=%d" % [
		N, AIM, COST, r.first / 60.0, r.t25 / 60.0, r.t50 / 60.0, r.t75 / 60.0, r.t100 / 60.0, str(r.levels), r.trips])
	get_tree().quit()

func avg_value() -> float:
	return Catalog.avg_value()

func avg_slots() -> float:
	return Catalog.avg_space()

## Seconds per picked piece (excluding shack trips) and pieces per action, at `remaining` pieces on the beach.
func piece_time(lv: Dictionary, remaining: float) -> Vector2:
	var gs := GameState
	var dens := maxf(remaining, 1.0) / AREA
	var reach := gs.reach_for(lv.arms)
	var speed := gs.speed_for(lv.sandals)
	var d_nn := 0.5 / sqrt(dens) * 1.3
	var walk := maxf(0.0, d_nn - reach * 0.8) / speed
	var aim := AIM if lv.grabber == 0 else maxf(1.0 / gs.grab_rate_for(lv.grabber), 0.35)
	var extra := dens * PI * pow(gs.rake_radius_for(lv.rake), 2)  # neighbours swept per pick
	var per := 1.0 + minf(extra, 4.0)
	return Vector2((walk + aim) / per, per)

func trip_time(lv: Dictionary) -> float:
	return 2.0 * SHACK_DIST / GameState.speed_for(lv.sandals) + SELL_TIME

## Time per piece including trips.
func total_per_piece(lv: Dictionary, remaining: float) -> float:
	var pt := piece_time(lv, remaining)
	var cap := float(GameState.bag_for(lv.bag)) / avg_slots()
	return pt.x + trip_time(lv) / cap

func cost_of(id: String, lv: Dictionary) -> int:
	return roundi(COST * float(GameState.UPGRADES[id].base) * pow(GameState.COST_GROWTH, lv[id]))

func run() -> Dictionary:
	var lv := {"bag": 0, "arms": 0, "grabber": 0, "sandals": 0, "rake": 0}
	var t := 0.0
	var coins := 0.0
	var remaining := float(N)
	var picked := 0.0
	var bag := 0.0  # slots used
	var next_tide := 90.0
	var res := {"first": -1.0, "t25": 0.0, "t50": 0.0, "t75": 0.0, "t100": 0.0, "trips": 0}
	var vpp := avg_value()
	var spp := avg_slots()
	while picked < N and t < 7200.0:
		var pt := piece_time(lv, remaining)
		var cap := float(GameState.bag_for(lv.bag))
		t += pt.x * pt.y
		var n := pt.y
		bag += n * spp
		coins += n * vpp
		picked += n
		remaining = maxf(remaining - n, 0.0)
		while t >= next_tide:
			next_tide += 90.0
			var add := lerpf(7.0, 2.0, minf(picked / N, 1.0))
			remaining = minf(remaining + add, 200.0)
		for k in [[0.25, "t25"], [0.5, "t50"], [0.75, "t75"], [1.0, "t100"]]:
			if picked >= N * k[0] and res[k[1]] == 0.0:
				res[k[1]] = t
		if bag + spp > cap - 0.01 or (bag >= cap - 1.0 and remaining < 3.0):
			t += trip_time(lv)
			res.trips += 1
			bag = 0.0
			# shop: buy best gain per coin while affordable
			var buying := true
			while buying:
				buying = false
				var base := total_per_piece(lv, remaining)
				var best := ""
				var best_score := 0.0
				for id in GameState.UPGRADE_ORDER:
					if lv[id] >= int(GameState.UPGRADES[id].max):
						continue
					var c := cost_of(id, lv)
					if c > coins:
						continue
					var lv2 := lv.duplicate()
					lv2[id] += 1
					var gain := (base - total_per_piece(lv2, remaining)) / base
					var score := gain / float(c)
					if gain > 0.0 and score > best_score:
						best_score = score
						best = id
				if best != "":
					coins -= cost_of(best, lv)
					lv[best] += 1
					if res.first < 0.0:
						res.first = t
					buying = true
	res.t100 = t if res.t100 == 0.0 else res.t100
	res.levels = lv
	return res
