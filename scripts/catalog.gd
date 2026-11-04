extends RefCounted
## The single place that defines the debris catalog, sorting bins, loose change and money formatting.
## Money is always integer cents. `space` = bag space units. Use via preload (no class_name).

## Everything on the beach is modelled at real size ("cm" = longest side) and drawn VIS_SCALE times bigger
## for readability (one uniform factor, so relative sizes stay true).
const VIS_SCALE := 1.4
## Minimum click/aim radius (m) so tiny items (caps, straws, coins) stay easy to pick.
const MIN_PICK_RADIUS := 0.16

## id -> name, space (bag units), value (cents), bin, weight (spawn odds).
const ITEMS := {
	"cap": {"name": "Bottle cap", "cm": 3, "space": 0.25, "value": 1, "bin": "plastic", "weight": 22.0},
	"straw": {"name": "Straw", "cm": 20, "space": 0.25, "value": 1, "bin": "plastic", "weight": 18.0},
	"bag": {"name": "Plastic bag", "cm": 35, "space": 0.5, "value": 2, "bin": "plastic", "weight": 14.0},
	"can": {"name": "Soda can", "cm": 12, "space": 1.0, "value": 10, "bin": "cans", "weight": 14.0},
	"pbottle": {"name": "Plastic bottle", "cm": 25, "space": 1.5, "value": 10, "bin": "bottles", "weight": 11.0},
	"flipflop": {"name": "Flip-flop", "cm": 25, "space": 1.5, "value": 5, "bin": "plastic", "weight": 8.0},
	"gbottle": {"name": "Glass bottle", "cm": 25, "space": 2.0, "value": 25, "bin": "glass", "weight": 6.0},
	"bucket": {"name": "Toy bucket", "cm": 16, "space": 2.0, "value": 30, "bin": "plastic", "weight": 4.0},
	"rope": {"name": "Fishing net", "cm": 50, "space": 3.0, "value": 50, "bin": "plastic", "weight": 2.5},
	"hose": {"name": "Garden hose", "cm": 45, "space": 3.0, "value": 60, "bin": "plastic", "weight": 2.5},
}

## Sorting bins at the shack, in the order they are emptied. icon = catalog id drawn on the bin.
const BIN_ORDER := ["cans", "bottles", "glass", "plastic"]
const BINS := {
	"cans": {"name": "CANS", "color": Color(0.22, 0.5, 0.95), "icon": "can", "icon_scale": 3.0},
	"bottles": {"name": "BOTTLES", "color": Color(0.25, 0.75, 0.38), "icon": "pbottle", "icon_scale": 1.45},
	"glass": {"name": "GLASS", "color": Color(0.96, 0.72, 0.16), "icon": "gbottle", "icon_scale": 1.75},
	"plastic": {"name": "OTHER", "color": Color(0.96, 0.5, 0.15), "icon": "bucket", "icon_scale": 2.5},
}

## Real coin radius in metres (2.0-2.6 cm across).
static func coin_radius(cents: int) -> float:
	return 0.0105 if cents < 10 else (0.0100 if cents < 25 else (0.0120 if cents < 100 else 0.0130))

## Loose change on the sand: cents, spawn weight.
const COINS := [[5, 50.0], [10, 30.0], [25, 15.0], [100, 5.0]]

static func random_id(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in ITEMS:
		total += float(ITEMS[id].weight)
	var r := rng.randf() * total
	for id in ITEMS:
		r -= float(ITEMS[id].weight)
		if r < 0.0:
			return id
	return "cap"

static func random_coin(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for c in COINS:
		total += float(c[1])
	var r := rng.randf() * total
	for c in COINS:
		r -= float(c[1])
		if r < 0.0:
			return int(c[0])
	return 5

## Weighted averages (used by the economy sim).
static func avg_value() -> float:
	var w := 0.0
	var v := 0.0
	for id in ITEMS:
		w += float(ITEMS[id].weight)
		v += float(ITEMS[id].weight) * float(ITEMS[id].value)
	return v / w

static func avg_space() -> float:
	var w := 0.0
	var s := 0.0
	for id in ITEMS:
		w += float(ITEMS[id].weight)
		s += float(ITEMS[id].weight) * float(ITEMS[id].space)
	return s / w

## "$12.34"
static func money(cents: int) -> String:
	return "%s$%d.%02d" % ["-" if cents < 0 else "", absi(cents) / 100, absi(cents) % 100]

## "10¢" under a dollar, otherwise "$1.50".
static func price(cents: int) -> String:
	return "%d¢" % cents if cents < 100 else money(cents)

## Bag space as text: 6.5, 10, 0.25
static func num(x: float) -> String:
	var s := "%.2f" % x
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s
