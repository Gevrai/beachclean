@tool
class_name BeachLook
extends Resource
## One keyframe of the day (sun, sky, fog, grading, water/sand/grass/palm tints).
## Beach.looks is a list of these, each placed at its `health`; Beach.set_health(t) blends the two
## neighbouring keyframes with `mix()` (morning -> midday -> afternoon -> sunset, see assets/env/look_*.tres).
## Edit the .tres files in the inspector; with Beach selected in the editor, the `health` slider previews live.

## Where this keyframe sits on the health axis (0 = fresh morning .. 1 = sunset).
@export_range(0.0, 1.0, 0.01) var health := 0.0

@export_group("Sun")
## Position on the sun's arc: 0 = on the horizon behind the player (over the dunes, -Z), 90 = overhead,
## 180 = on the sea horizon (+Z). Elevation above the horizon = min(arc, 180 - arc). Interpolated as an angle,
## so the sun travels along the arc and never cuts through the ground.
@export_range(0.0, 180.0) var sun_arc_deg := 60.0
## Rotates the arc plane around the vertical axis (degrees off the dune-sea axis) for nicer shadows.
@export_range(-90.0, 90.0) var sun_tilt_deg := 20.0
@export var sun_color := Color(1, 1, 1)
@export_range(0.0, 4.0) var sun_energy := 1.0

@export_group("Sky")
@export var sky_zenith := Color(0.15, 0.4, 0.8)
@export var sky_mid := Color(0.45, 0.7, 0.95)
@export var sky_horizon := Color(1.0, 0.78, 0.6)
## Horizon colour on the side away from the sun (blended by azimuth), e.g. lavender at sunset.
@export var sky_horizon_away := Color(1.0, 0.78, 0.6)
@export var sky_ground := Color(0.7, 0.6, 0.5)
@export var sky_sun_color := Color(1.0, 0.75, 0.45)
@export_range(0.0, 2.0) var sky_glow := 0.0
@export_range(0.0, 1.0) var cloud_cover := 0.5
@export var cloud_lit := Color(1.0, 0.9, 0.8)
@export var cloud_shade := Color(0.6, 0.55, 0.7)

@export_group("Fog and grading")
@export var fog_color := Color(0.7, 0.7, 0.7)
@export_range(0.0, 0.05, 0.0001) var fog_density := 0.002
@export_range(0.0, 0.05, 0.0001) var volumetric_fog_density := 0.002
@export var volumetric_fog_albedo := Color(0.8, 0.8, 0.8)
@export_range(0.0, 4.0) var ambient_energy := 0.6
@export_range(0.0, 2.0) var saturation := 1.0
@export_range(0.5, 1.5) var contrast := 1.0
@export_range(0.0, 2.0) var glow_intensity := 0.5

@export_group("Water")
@export var water_shallow := Color(0.22, 0.95, 0.82)
@export var water_deep := Color(0.0, 0.4, 0.5)
@export var water_foam := Color(1, 1, 1)
@export_range(0.1, 4.0) var water_absorb := 0.9
## Sun glitter on the water (sparkle path towards the sun).
@export_range(0.0, 6.0) var water_glitter := 0.0

@export_group("Sand, grass, palms")
@export var sand_dry := Color(0.78, 0.52, 0.22)
@export var sand_light := Color(0.88, 0.66, 0.34)
@export var sand_grass_tint := Color(0.55, 0.68, 0.25)
@export var grass_root := Color(0.2, 0.45, 0.15)
@export var grass_tip := Color(0.72, 0.88, 0.28)
@export var leaf_albedo := Color(1, 1, 1)
@export var leaf_backlight := Color(0.4, 0.5, 0.08)

## New look with every float/Color property lerped from this to `other` by t.
func mix(other: BeachLook, t: float) -> BeachLook:
	var r := BeachLook.new()
	for p in get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p.name
		r.set(n, lerp(get(n), other.get(n), t))
	return r
