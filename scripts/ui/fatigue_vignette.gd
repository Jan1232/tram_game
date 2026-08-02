extends CanvasLayer

## Полноэкранная виньетка усталости. Шейдер и ColorRect создаются в коде.

const _SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.5;
	float v = smoothstep(0.32, 1.05, d) * intensity;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v, 0.0, 1.0));
}
"""

var _mat: ShaderMaterial


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = _SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("intensity", 0.0)
	rect.material = _mat
	add_child(rect)

	var fs := get_node("/root/FatigueSystem")
	fs.fatigue_changed.connect(_on_fatigue)
	_on_fatigue(fs.level())


func _on_fatigue(_level: float) -> void:
	if _mat == null:
		return
	var fs := get_node("/root/FatigueSystem")
	_mat.set_shader_parameter("intensity", fs.vignette_intensity())
