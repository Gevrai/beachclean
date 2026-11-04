shader_type spatial;
render_mode cull_front, unshaded;
// Pulsing yellow outline drawn as material_overlay on the item the player aims at.
void vertex() { VERTEX += NORMAL * 0.02; }
void fragment() { ALBEDO = vec3(1.0, 0.8, 0.15) * (1.3 + 0.4 * sin(TIME * 8.0)); }
