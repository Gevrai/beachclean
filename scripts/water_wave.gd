extends RefCounted
## CPU copy of the vertex wave in assets/shaders/water.gdshader (swell_at + chop, same amplitudes as
## assets/materials/water.tres). Floating debris and the net ride the surface with it. KEEP IN SYNC with the shader.
## Use via preload (no class_name).

const SWELL_AMP := 0.12
const CHOP_AMP := 0.06

static func time() -> float:
	return Time.get_ticks_msec() * 0.001

## Water surface height (world y) at x, z, time t.
static func height(x: float, z: float, t: float) -> float:
	var swell := sin(t * 0.55 + x * 0.05) * 0.6 + sin(t * 0.31 + x * 0.11 + 1.7) * 0.4
	var chop := sin(x * 0.3 + t * 0.8) * cos(z * 0.37 - t * 1.1) + 0.5 * sin(x * 0.71 - z * 0.53 + t * 1.7)
	return SWELL_AMP * swell + CHOP_AMP * chop

## Surface slope as (dh/dx, dh/dz).
static func slope(x: float, z: float, t: float) -> Vector2:
	var e := 0.35
	return Vector2(height(x + e, z, t) - height(x - e, z, t), height(x, z + e, t) - height(x, z - e, t)) / (2.0 * e)
