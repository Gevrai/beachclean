extends RefCounted
## The five messages in bottles. Readable in any order. [i]...[/i] = photo description.

const SPOTS := [  # [x, depth behind the shoreline in m]
	[9.0, 13.0],    # near the shack path
	[19.0, 17.0],   # beside the shack
	[-43.0, 6.0],   # far west end
	[43.0, 21.0],   # east dunes
	[-18.0, 29.0],  # back dunes
]

const TEXTS := [
	"Dear Tomas,\nPapa let me light the lamp tonight. I told it to shine all the way to your side of the water.\nIf you can see it, blink twice.\n- Ida, age 9",
	"[i]A photograph, one corner burnt away. Two children on a rocky jetty, squinting into the sun. One of them holds up a crab like a trophy.\nOn the back, in pencil: \"summer, before the ships\".[/i]",
	"Tomas,\nThe spring storm took our jetty. I stood on what was left and shouted your name.\nThe gulls were very polite about it.\n- Ida, 24",
	"T.,\nThe lamp turns by itself now. Nobody climbs the stairs. I go up anyway and sit in the warm glass.\nI stopped counting the sweeps of light. I count bottles instead.\n- I., 51",
	"To whoever finds this,\nIf a boy with a crab-red sunburn ever asks the way to a lighthouse, point him up the beach.\nI will leave the lamp on.\n- Ida, 78",
]
