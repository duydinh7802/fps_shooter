shader_type spatial;
// Khói dạng chuỗi ảnh: trộn khung hiện tại (frame_a) với khung kế (frame_b) theo `blend`
// → chuỗi 24 khung/giây vẫn mượt khi game chạy 60 FPS (frame blending).
// Script MuzzleSmoke cập nhật frame_a, frame_b, blend, opacity mỗi frame.
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;

uniform sampler2D frame_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D frame_b : source_color, filter_linear_mipmap, repeat_disable;
uniform float blend : hint_range(0.0, 1.0) = 0.0;     // 0 = toàn frame_a, 1 = toàn frame_b
uniform float opacity : hint_range(0.0, 2.0) = 1.0;   // nhân với alpha của ảnh
uniform vec4 tint : source_color = vec4(1.0);         // màu khói (trắng = giữ màu ảnh)
uniform bool billboard = false;                       // true: tấm luôn quay mặt về camera (dùng cho Front)

void vertex() {
	if (billboard) {
		// Giống Billboard của StandardMaterial3D (có giữ scale của node)
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 color = mix(texture(frame_a, UV), texture(frame_b, UV), blend);
	ALBEDO = color.rgb * tint.rgb;
	ALPHA = clamp(color.a * opacity * tint.a, 0.0, 1.0);
}
