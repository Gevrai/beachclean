extends Node

const Catalog := preload("res://scripts/catalog.gd")
const DM := preload("res://scripts/debris_manager.gd")
## Rough economy estimate (not a pass/fail test): godot --headless --path . res://tools/tests/tune_sim.tscn -- --fresh
## Models a reasonable player (aim ~0.9 s/piece, walking, shack trips, buys the best value-per-coin upgrade).
## Reads costs/effects from GameState and item values/space/weights from Catalog (money in cents, bag in space units).
## Pools: BEACH pieces (sand clusters + wrack line + loners + floaters within waist-deep reach, N - FAR) and FAR floaters
## (only reachable with the casting net: a cast catches density x pi r^2 pieces, reeled in ~1 s).
## Net policy: the player buys level 1 once ~30% of the beach is clean (or when only far pieces are left).
## Args: --n=INITIAL --far=FAR --aim=SECONDS --cost=MULT

const AREA := 2200.0      # m^2 of debris field
const SHACK_DIST := 25.0  # avg one-way walk from field to shack (m)
const SELL_TIME := 4.0    # s spent at the shack (sell + shop)
const CLUSTER_SIZE := 6.0 # avg pieces per cluster: within a cluster the next piece is ~0.9 m away, then walk to the next cluster
const SEA_BAND := 1620.0  # m^2 of sea between waist depth and 25 m out, along the part of the beach that is worked (90 m)
const SEA_BAND_W := 18.0  # m from the wading line to the 25 m limit
const NET_CAST_TIME := 3.0  # aim 0.9 + fly 0.7 + reel 1.0 + reposition
const NET_TRIP_EXTRA := 8.0 # s wading out and back after each shack trip

var N := 4070
var FAR := 320
var AIM := 0.9
var COST := 1.0   # multiplier on base costs (to try tunings without editing GameState)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): N = int(a.trim_prefix("--n="))
		if a.begins_with("--far="): FAR = int(a.trim_prefix("--far="))
		if a.begins_with("--aim="): AIM = float(a.trim_prefix("--aim="))
		if a.begins_with("--cost="): COST = float(a.trim_prefix("--cost="))
	var r := run()
	print("SIM n=%d far=%d aim=%.1f cost=x%.1f  first_upgrade=%.1f min  net=%.1f  25%%=%.1f 50%%=%.1f 75%%=%.1f 100%%=%.1f min  levels=%s trips=%d" % [
		N, FAR, AIM, COST, r.first / 60.0, r.net / 60.0, r.t25 / 60.0, r.t50 / 60.0, r.t75 / 60.0, r.t100 / 60.0, str(r.levels), r.trips])
	get_tree().quit()

func _avg(w: Dictionary, key: String) -> float:
	var tw := 0.0
	var t := 0.0
	for id in w:
		tw += float(w[id])
		t += float(w[id]) * float(Catalog.ITEMS[id][key])
	return t / tw

## Average (value, space) of beach pieces: a third wrack-line mix, the rest the general mix (+ near floaters, folded in).
func beach_mix() -> Vector2:
	return Vector2(0.65 * Catalog.avg_value() + 0.35 * _avg(DM.WRACK_WEIGHTS, "value"), 0.65 * Catalog.avg_space() + 0.35 * _avg(DM.WRACK_WEIGHTS, "space"))

func far_mix() -> Vector2:
	return Vector2(_avg(DM.FLOAT_WEIGHTS, "value"), _avg(DM.FLOAT_WEIGHTS, "space"))

## Seconds per picked piece (excluding shack trips) and pieces per action, at `remaining` beach pieces.
func piece_time(lv: Dictionary, remaining: float) -> Vector2:
	var gs := GameState
	var reach := gs.reach_for(lv.arms)
	var speed := gs.speed_for(lv.sandals)
	var clusters := maxf(remaining, 1.0) / CLUSTER_SIZE
	var d_cl := 0.5 / sqrt(clusters / AREA) * 1.3  # walk between clusters
	var hop := maxf(0.0, 0.9 - reach * 0.8)         # walk between neighbours inside a cluster
	var walk := ((CLUSTER_SIZE - 1.0) * hop + maxf(0.0, d_cl - reach * 0.8)) / CLUSTER_SIZE / speed
	var aim := AIM if lv.grabber == 0 else maxf(1.0 / gs.grab_rate_for(lv.grabber), 0.35)
	var dens := maxf(remaining, 1.0) / AREA
	var extra := (dens * 3.0) * PI * pow(gs.rake_radius_for(lv.rake), 2)  # neighbours swept per pick (clusters are ~3x denser than average)
	var per := 1.0 + minf(extra, 5.0)
	return Vector2((walk + aim) / per, per)

## Far floaters caught per cast (0 if the net doesn't reach any), and the share of the far band it can reach.
func net_cast(lv: Dictionary, far_left: float) -> Vector2:
	var l: int = lv.net
	if l <= 0 or far_left < 0.5:
		return Vector2.ZERO
	var cover := minf(GameState.net_range_for(l) / SEA_BAND_W, 1.0)
	var dens := far_left / SEA_BAND  # remaining far pieces are spread over the whole band; only `cover` of it is reachable
	var n := dens * PI * pow(GameState.net_radius_for(l), 2) * 1.8  # x1.8: floaters drift in groups and the player aims at them
	n = maxf(n, 2.5)  # the player sees what is left and casts at the groups, so it never collapses to a random scan
	return Vector2(minf(n, far_left * cover), cover)

func trip_time(lv: Dictionary, sea: bool) -> float:
	return 2.0 * SHACK_DIST / GameState.speed_for(lv.sandals) + SELL_TIME + (NET_TRIP_EXTRA if sea else 0.0)

## Time per piece including trips (beach work).
func total_per_piece(lv: Dictionary, remaining: float) -> float:
	var pt := piece_time(lv, remaining)
	var cap := float(GameState.bag_for(lv.bag)) / beach_mix().y
	return pt.x + trip_time(lv, false) / cap

## The player wants the next net level: level 1 once ~30% of the beach is clean, the next ones from 50% (while the net
## doesn't reach the whole far band yet) or when the beach is empty.
func _saving_for_net(lv: Dictionary, picked: float, rem: float) -> bool:
	if lv.net >= int(GameState.UPGRADES.net.max):
		return false
	if lv.net == 0:
		return picked >= 0.3 * N or rem < 1.0
	return GameState.net_range_for(lv.net) / SEA_BAND_W < 1.0 and (picked >= 0.5 * N or rem < 1.0)

func cost_of(id: String, lv: Dictionary) -> int:
	return roundi(COST * float(GameState.UPGRADES[id].base) * pow(GameState.COST_GROWTH, lv[id]))

func run() -> Dictionary:
	var lv := {"bag": 0, "arms": 0, "grabber": 0, "sandals": 0, "rake": 0, "net": 0}
	var t := 0.0
	var coins := 0.0
	var far_left := float(FAR)
	var rem := float(N - FAR)  # beach pieces on the sand/in the shallows
	var picked := 0.0
	var bag := 0.0  # space used
	var next_tide := 90.0
	var res := {"first": -1.0, "net": -1.0, "t25": 0.0, "t50": 0.0, "t75": 0.0, "t100": 0.0, "trips": 0}
	var bm := beach_mix()
	var fm := far_mix()
	while picked < N - 0.5 and t < 7200.0:
		var cap := float(GameState.bag_for(lv.bag))
		var nc := net_cast(lv, far_left)
		var vpp := bm.x
		var spp := bm.y
		var n := 0.0
		if rem >= 1.0 and (nc.x < 0.5 or rem > far_left * 0.5):  # beach first, net work once it is mostly done
			var pt := piece_time(lv, rem)
			t += pt.x * pt.y
			n = minf(pt.y, rem)
			rem -= n
		elif nc.x >= 0.5:
			t += NET_CAST_TIME
			n = nc.x
			far_left -= n
			vpp = fm.x
			spp = fm.y
		elif rem >= 1.0:
			var pt := piece_time(lv, rem)
			t += pt.x * pt.y
			n = minf(pt.y, rem)
			rem -= n
		else:
			t += 5.0  # nothing reachable: wait for the tide / more cash
		bag += n * spp
		coins += n * vpp
		picked += n
		while t >= next_tide:
			next_tide += 90.0
			rem = minf(rem + lerpf(DM.TIDE_MAX, DM.TIDE_MIN, minf(picked / N, 1.0)) + 1.0, float(DM.MAX_ALIVE))
		if OS.get_cmdline_user_args().has('--trace') and int(t) % 120 < 8 and n > 0:
			print('t=%.1f picked=%.0f rem=%.1f far=%.1f coins=%.0f lv=%s' % [t / 60.0, picked, rem, far_left, coins, str(lv)])
		for k in [[0.25, "t25"], [0.5, "t50"], [0.75, "t75"], [1.0, "t100"]]:
			if picked >= N * k[0] and res[k[1]] == 0.0:
				res[k[1]] = t
		var stuck := rem < 1.0 and net_cast(lv, far_left).x < 0.5 and far_left >= 0.5
		if bag + spp > cap - 0.01 or (bag >= cap - 1.0 and rem < 3.0) or stuck:
			t += trip_time(lv, far_left > 0.5 and lv.net > 0)
			res.trips += 1
			bag = 0.0
			# shop: buy best gain per coin while affordable
			var buying := true
			while buying:
				buying = false
				var base := total_per_piece(lv, rem)
				var best := ""
				var best_score := 0.0
				for id in GameState.UPGRADE_ORDER:
					if lv[id] >= int(GameState.UPGRADES[id].max):
						continue
					var c := cost_of(id, lv)
					if c > coins:
						continue
					if id != "net" and _saving_for_net(lv, picked, rem) and coins - c < cost_of("net", lv):
						continue  # saving up for the net
					var gain: float
					var score: float
					if id == "net":
						if not _saving_for_net(lv, picked, rem):
							continue
						gain = 1.0
						score = 1.0e-3 if lv[id] == 0 else 2.0e-4  # level 1 ahead of everything else when its time comes
					else:
						var lv2 := lv.duplicate()
						lv2[id] += 1
						gain = (base - total_per_piece(lv2, rem)) / base
						score = gain / float(c)
					if gain > 0.0 and score > best_score:
						best_score = score
						best = id
				if best != "":
					coins -= cost_of(best, lv)
					lv[best] += 1
					if res.first < 0.0:
						res.first = t
					if best == "net" and res.net < 0.0:
						res.net = t
					buying = true
	res.t100 = t if res.t100 == 0.0 else res.t100
	res.levels = lv
	return res
