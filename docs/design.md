# Beachclean — design (MVP prototype)

**Pitch.** A relaxing first-person incremental game. You clean a polluted beach, sell the debris, buy better tools.
As the beach heals, colour, warm light and wildlife come back.

**Tech.** Godot 4.7, GDScript, Forward+ renderer. Stylized, vibrant, cartoony; lighting does the heavy lifting.

## Core loop
1. Walk the beach (WASD + mouse). Look at debris (a small label shows its name and value), **left-click** to pick it up into your **bag**. Loose change on the sand is picked up straight into your wallet.
2. Bag full (it holds **space**, not item count) → walk to the **sorting bins** beside the shack, press **E**: the bag is sorted into four bins (under 2 s) and paid out.
3. At the shack **counter**, press **E** to buy **upgrades**. Repeat, faster.

## Money and debris
Money is dollars and cents, shown as `$12.34` (stored as integer cents). Every item has a **size** (bag space units) and a **value**.
All data lives in one table, `scripts/catalog.gd`.

| Item | Size | Value | Bin |
|---|---|---|---|
| Bottle cap | 0.25 | 1¢ | other plastic |
| Straw | 0.25 | 1¢ | other plastic |
| Plastic bag | 0.5 | 2¢ | other plastic |
| Soda can | 1 | 10¢ (deposit) | cans |
| Plastic bottle | 1.5 | 10¢ (deposit) | plastic bottles |
| Flip-flop | 1.5 | 5¢ | other plastic |
| Glass bottle | 2 | 25¢ | glass |
| Toy bucket | 2 | 30¢ | other plastic |
| Fishing net | 3 | 50¢ | other plastic |
| Garden hose | 3 | 60¢ | other plastic |

Small cheap things are common, big ones rare. **Loose change** (rare, a small sparkle on the sand): 5¢/10¢/25¢/$1, instant money, never in the bag.
A pickup is refused if the item doesn't fit. Bag capacity starts at 10 space.

~4000 pieces at start, placed naturally, never evenly: a wavy **wrack line** along the high-tide mark (dense band of small mixed debris, nets and rope, with gaps),
piles against rocks and at the foot of the dunes, many small clusters (3-16 pieces) and some loners. About 500 pieces **float** in the sea (bottles, caps, bags,
flip-flops, buckets, nets), bobbing with the waves, out to ~25 m. Every **tide** (90 s) a wave washes in 36 new pieces (down to 12) near the waterline as small clusters
(and a couple of floaters into the shallows), fewer as the beach heals, so there is always a little to do.

**Wading.** The player can walk into the sea until the water is waist deep (~1 m); walking slows with depth (up to -50%), the head bob gets gentler, steps
become faint splashes. Past waist depth an invisible soft limit eases you back. Floating pieces within reach can be picked up by hand; the ones further out need the **casting net**.

**Bins** (blue Cans, green Plastic bottles, amber Glass, orange Other plastic) share one sell zone. On E each bin that has
matching items opens its lid in turn and the items fly in with soft rising "bloobs"; at the end the cash sound plays and the money counts up.

## Upgrades (each has levels, cost ×1.5 per level; base costs $1.80 bag, $2.70 arms, $4.30 grabber, $2.15 sandals, $5.40 rake, $10.80 casting net)
| Upgrade | Effect |
|---|---|
| Bigger bag | +7 bag space (start 10) |
| Long arms | +0.75 m pickup reach (start 2.5 m) |
| Grabber | hold click to vacuum debris in a cone |
| Sandals | +10% move speed |
| Beach rake | picking up also grabs everything within a radius (0.9 m per level, 4 levels) |
| Casting net | hold **right-click** to aim a landing circle on the sea, release to cast: the net arcs out, lands, and reels back in ~1 s with the floating litter inside its radius (as much as fits in the bag; the rest stays). 3 levels: range 12/18/22 m, radius 3/4.5/6 m |

**Pacing target** (tools/tests/tune_sim): first upgrade ~1.2 min, 25% ~9.5, 50% ~14.5, 75% ~19.5, 100% ~24.6 min of good play.

## Twist: the beach comes back
**Beach health** = share of the starting debris cleared, shown as a %. As it rises, the day passes: it starts as a
fresh, pretty morning (sun low over the dunes behind you), reaches bright midday at about 50%, a golden afternoon at 80%,
and ends at 100% in the perfect sunset (sun half-sunk on the sea horizon). It is never night, and never grey. At milestones, animals come back. They only have simple ambient animations, no AI.
- 25%: crabs scuttle along the sand
- 50%: gulls circle overhead
- 75%: a sea turtle rests on the shore
- 100%: turtle hatchlings run to the sea, plus the perfect sunset

## Wink: messages in bottles
A few special glass bottles hold short notes or photo fragments that hint at a small story. Collecting them is optional;
read them anytime from the pause menu.

## Out of scope for the prototype
Prestige, new beaches, animal behaviours, audio beyond a simple ambient loop, settings menu.

Progress autosaves (`user://save.json`).
