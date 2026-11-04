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

~340 pieces at start. Every **tide** (90 s) a wave washes in a few new pieces near the waterline, fewer as the beach heals,
so there is always a little to do.

**Bins** (blue Cans, green Plastic bottles, amber Glass, orange Other plastic) share one sell zone. On E each bin that has
matching items opens its lid in turn and the items fly in with soft rising "bloobs"; at the end the cash sound plays and the money counts up.

## Upgrades (each has levels, cost ×1.6 per level; base costs $3.00 bag, $3.60 arms, $6.00 grabber, $3.00 sandals, $7.20 rake)
| Upgrade | Effect |
|---|---|
| Bigger bag | +5 bag space (start 10) |
| Long arms | +0.75 m pickup reach (start 2.5 m) |
| Grabber | hold click to vacuum debris in a cone |
| Sandals | +10% move speed |
| Beach rake | picking up also grabs everything within a radius |

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
