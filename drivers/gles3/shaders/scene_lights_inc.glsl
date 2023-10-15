// Directional light data.
#if !defined(DISABLE_LIGHT_DIRECTIONAL) || (!defined(ADDITIVE_OMNI) && !defined(ADDITIVE_SPOT))

struct DirectionalLightData {
	mediump vec3 direction;
	mediump float energy;
	mediump vec3 color;
	mediump float size;
	mediump vec2 pad;
	mediump float shadow_opacity;
	mediump float specular;
};

layout(std140) uniform DirectionalLights { // ubo:7
	DirectionalLightData directional_lights[MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS];
};

#if defined(USE_ADDITIVE_LIGHTING) && (!defined(ADDITIVE_OMNI) && !defined(ADDITIVE_SPOT))
// Directional shadows can be in the base pass or in the additive passes
uniform highp sampler2DShadow directional_shadow_atlas; // texunit:-3
#endif // defined(USE_ADDITIVE_LIGHTING) && (!defined(ADDITIVE_OMNI) && !defined(ADDITIVE_SPOT))

#endif // !DISABLE_LIGHT_DIRECTIONAL

// Omni and spot light data.
#if !defined(DISABLE_LIGHT_OMNI) || !defined(DISABLE_LIGHT_SPOT) || defined(ADDITIVE_OMNI) || defined(ADDITIVE_SPOT)

struct LightData { // This structure needs to be as packed as possible.
	highp vec3 position;
	highp float inv_radius;

	mediump vec3 direction;
	highp float size;

	mediump vec3 color;
	mediump float attenuation;

	mediump float cone_attenuation;
	mediump float cone_angle;
	mediump float specular_amount;
	mediump float shadow_opacity;
};

#if !defined(DISABLE_LIGHT_OMNI) || defined(ADDITIVE_OMNI)
layout(std140) uniform OmniLightData { // ubo:5
	LightData omni_lights[MAX_LIGHT_DATA_STRUCTS];
};
#ifdef BASE_PASS
uniform uint omni_light_indices[MAX_FORWARD_LIGHTS];
uniform uint omni_light_count;
#endif // BASE_PASS
#endif // DISABLE_LIGHT_OMNI

#if !defined(DISABLE_LIGHT_SPOT) || defined(ADDITIVE_SPOT)
layout(std140) uniform SpotLightData { // ubo:6
	LightData spot_lights[MAX_LIGHT_DATA_STRUCTS];
};
#ifdef BASE_PASS
uniform uint spot_light_indices[MAX_FORWARD_LIGHTS];
uniform uint spot_light_count;
#endif // BASE_PASS
#endif // DISABLE_LIGHT_SPOT
#endif // !defined(DISABLE_LIGHT_OMNI) || !defined(DISABLE_LIGHT_SPOT)

// Functions related to lighting

vec3 F0(float metallic, float specular, vec3 albedo) {
	float dielectric = 0.16 * specular * specular;
	// use albedo * metallic as colored specular reflectance at 0 angle for metallic materials;
	// see https://google.github.io/filament/Filament.md.html
	return mix(vec3(dielectric), albedo, vec3(metallic));
}
#ifndef MODE_RENDER_DEPTH
#if !defined(DISABLE_LIGHT_DIRECTIONAL) || !defined(DISABLE_LIGHT_OMNI) || !defined(DISABLE_LIGHT_SPOT) || defined(USE_ADDITIVE_LIGHTING)

float D_GGX(float cos_theta_m, float alpha) {
	float a = cos_theta_m * alpha;
	float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
	return k * k * (1.0 / M_PI);
}

// From Earl Hammon, Jr. "PBR Diffuse Lighting for GGX+Smith Microsurfaces" https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
float V_GGX(float NdotL, float NdotV, float alpha) {
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

float D_GGX_anisotropic(float cos_theta_m, float alpha_x, float alpha_y, float cos_phi, float sin_phi) {
	float alpha2 = alpha_x * alpha_y;
	highp vec3 v = vec3(alpha_y * cos_phi, alpha_x * sin_phi, alpha2 * cos_theta_m);
	highp float v2 = dot(v, v);
	float w2 = alpha2 / v2;
	float D = alpha2 * w2 * w2 * (1.0 / M_PI);
	return D;
}

float V_GGX_anisotropic(float alpha_x, float alpha_y, float TdotV, float TdotL, float BdotV, float BdotL, float NdotV, float NdotL) {
	float Lambda_V = NdotL * length(vec3(alpha_x * TdotV, alpha_y * BdotV, NdotV));
	float Lambda_L = NdotV * length(vec3(alpha_x * TdotL, alpha_y * BdotL, NdotL));
	return 0.5 / (Lambda_V + Lambda_L);
}

float SchlickFresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m; // pow(m,5)
}

void light_compute(vec3 N, vec3 L, vec3 V, float A, vec3 light_color, bool is_directional, float attenuation, vec3 f0, float roughness, float metallic, float specular_amount, vec3 albedo, inout float alpha,
#ifdef LIGHT_BACKLIGHT_USED
		vec3 backlight,
#endif
#ifdef LIGHT_RIM_USED
		float rim, float rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
		float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
#endif
#ifdef LIGHT_ANISOTROPY_USED
		vec3 B, vec3 T, float anisotropy,
#endif
		inout vec3 diffuse_light, inout vec3 specular_light) {

#if defined(LIGHT_CODE_USED)
	// light is written by the light shader

	highp mat4 model_matrix = world_transform;
	mat4 projection_matrix = scene_data.projection_matrix;
	mat4 inv_projection_matrix = scene_data.inv_projection_matrix;

	vec3 normal = N;
	vec3 light = L;
	vec3 view = V;

	/* clang-format off */

#CODE : LIGHT

	/* clang-format on */

#else
	float NdotL = min(A + dot(N, L), 1.0);
	float cNdotL = max(NdotL, 0.0); // clamped NdotL
	float NdotV = dot(N, V);
	float cNdotV = max(NdotV, 1e-4);

#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
	vec3 H = normalize(V + L);
#endif

#if defined(SPECULAR_SCHLICK_GGX)
	float cNdotH = clamp(A + dot(N, H), 0.0, 1.0);
#endif

#if defined(DIFFUSE_BURLEY) || defined(SPECULAR_SCHLICK_GGX) || defined(LIGHT_CLEARCOAT_USED)
	float cLdotH = clamp(A + dot(L, H), 0.0, 1.0);
#endif

	if (metallic < 1.0) {
		float diffuse_brdf_NL; // BRDF times N.L for calculating diffuse radiance

#if defined(DIFFUSE_LAMBERT_WRAP)
		// Energy conserving lambert wrap shader.
		// https://web.archive.org/web/20210228210901/http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
		diffuse_brdf_NL = max(0.0, (NdotL + roughness) / ((1.0 + roughness) * (1.0 + roughness))) * (1.0 / M_PI);
#elif defined(DIFFUSE_TOON)
		diffuse_brdf_NL = smoothstep(-roughness, max(roughness, 0.01), NdotL) * (1.0 / M_PI);
#elif defined(DIFFUSE_BURLEY)
		{
			float FD90_minus_1 = 2.0 * cLdotH * cLdotH * roughness - 0.5;
			float FdV = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotV);
			float FdL = 1.0 + FD90_minus_1 * SchlickFresnel(cNdotL);
			diffuse_brdf_NL = (1.0 / M_PI) * FdV * FdL * cNdotL;
		}
#else
		// Lambert
		diffuse_brdf_NL = cNdotL * (1.0 / M_PI);
#endif

		diffuse_light += light_color * diffuse_brdf_NL * attenuation;

#if defined(LIGHT_BACKLIGHT_USED)
		diffuse_light += light_color * (vec3(1.0 / M_PI) - diffuse_brdf_NL) * backlight * attenuation;
#endif

#if defined(LIGHT_RIM_USED)
		// Epsilon min to prevent pow(0, 0) singularity which results in undefined behavior.
		float rim_light = pow(max(1e-4, 1.0 - cNdotV), max(0.0, (1.0 - roughness) * 16.0));
		diffuse_light += rim_light * rim * mix(vec3(1.0), albedo, rim_tint) * light_color;
#endif
	}

	if (roughness > 0.0) { // FIXME: roughness == 0 should not disable specular light entirely

		// D

#if defined(SPECULAR_TOON)

		vec3 R = normalize(-reflect(L, N));
		float RdotV = dot(R, V);
		float mid = 1.0 - roughness;
		mid *= mid;
		float intensity = smoothstep(mid - roughness * 0.5, mid + roughness * 0.5, RdotV) * mid;
		diffuse_light += light_color * intensity * attenuation * specular_amount; // write to diffuse_light, as in toon shading you generally want no reflection

#elif defined(SPECULAR_DISABLED)
		// none..

#elif defined(SPECULAR_SCHLICK_GGX)
		// shlick+ggx as default
		float alpha_ggx = roughness * roughness;
#if defined(LIGHT_ANISOTROPY_USED)
		float aspect = sqrt(1.0 - anisotropy * 0.9);
		float ax = alpha_ggx / aspect;
		float ay = alpha_ggx * aspect;
		float XdotH = dot(T, H);
		float YdotH = dot(B, H);
		float D = D_GGX_anisotropic(cNdotH, ax, ay, XdotH, YdotH);
		float G = V_GGX_anisotropic(ax, ay, dot(T, V), dot(T, L), dot(B, V), dot(B, L), cNdotV, cNdotL);
#else
		float D = D_GGX(cNdotH, alpha_ggx);
		float G = V_GGX(cNdotL, cNdotV, alpha_ggx);
#endif // LIGHT_ANISOTROPY_USED
	   // F
		float cLdotH5 = SchlickFresnel(cLdotH);
		// Calculate Fresnel using cheap approximate specular occlusion term from Filament:
		// https://google.github.io/filament/Filament.html#lighting/occlusion/specularocclusion
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 F = f0 + (f90 - f0) * cLdotH5;

		vec3 specular_brdf_NL = cNdotL * D * F * G;

		specular_light += specular_brdf_NL * light_color * attenuation * specular_amount;
#endif

#if defined(LIGHT_CLEARCOAT_USED)
		// Clearcoat ignores normal_map, use vertex normal instead
		float ccNdotL = max(min(A + dot(vertex_normal, L), 1.0), 0.0);
		float ccNdotH = clamp(A + dot(vertex_normal, H), 0.0, 1.0);
		float ccNdotV = max(dot(vertex_normal, V), 1e-4);

#if !defined(SPECULAR_SCHLICK_GGX)
		float cLdotH5 = SchlickFresnel(cLdotH);
#endif
		float Dr = D_GGX(ccNdotH, mix(0.001, 0.1, clearcoat_roughness));
		float Gr = 0.25 / (cLdotH * cLdotH);
		float Fr = mix(.04, 1.0, cLdotH5);
		float clearcoat_specular_brdf_NL = clearcoat * Gr * Fr * Dr * cNdotL;

		specular_light += clearcoat_specular_brdf_NL * light_color * attenuation * specular_amount;
		// TODO: Clearcoat adds light to the scene right now (it is non-energy conserving), both diffuse and specular need to be scaled by (1.0 - FR)
		// but to do so we need to rearrange this entire function
#endif // LIGHT_CLEARCOAT_USED
	}

#ifdef USE_SHADOW_TO_OPACITY
	alpha = min(alpha, clamp(1.0 - attenuation, 0.0, 1.0));
#endif

#endif // LIGHT_CODE_USED
}

float get_omni_spot_attenuation(float distance, float inv_range, float decay) {
	float nd = distance * inv_range;
	nd *= nd;
	nd *= nd; // nd^4
	nd = max(1.0 - nd, 0.0);
	nd *= nd; // nd^2
	return nd * pow(max(distance, 0.0001), -decay);
}

#if !defined(DISABLE_LIGHT_OMNI) || defined(ADDITIVE_OMNI)
void light_process_omni(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 f0, float roughness, float metallic, float shadow, vec3 albedo, inout float alpha,
#ifdef LIGHT_BACKLIGHT_USED
		vec3 backlight,
#endif
#ifdef LIGHT_RIM_USED
		float rim, float rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
		float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
#endif
#ifdef LIGHT_ANISOTROPY_USED
		vec3 binormal, vec3 tangent, float anisotropy,
#endif
		inout vec3 diffuse_light, inout vec3 specular_light) {
	vec3 light_rel_vec = omni_lights[idx].position - vertex;
	float light_length = length(light_rel_vec);
	float omni_attenuation = get_omni_spot_attenuation(light_length, omni_lights[idx].inv_radius, omni_lights[idx].attenuation);
	vec3 color = omni_lights[idx].color;
	float size_A = 0.0;

	if (omni_lights[idx].size > 0.0) {
		float t = omni_lights[idx].size / max(0.001, light_length);
		size_A = max(0.0, 1.0 - 1.0 / sqrt(1.0 + t * t));
	}

	omni_attenuation *= shadow;

	light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, omni_attenuation, f0, roughness, metallic, omni_lights[idx].specular_amount, albedo, alpha,
#ifdef LIGHT_BACKLIGHT_USED
			backlight,
#endif
#ifdef LIGHT_RIM_USED
			rim * omni_attenuation, rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
			clearcoat, clearcoat_roughness, vertex_normal,
#endif
#ifdef LIGHT_ANISOTROPY_USED
			binormal, tangent, anisotropy,
#endif
			diffuse_light,
			specular_light);
}
#endif // !DISABLE_LIGHT_OMNI

#if !defined(DISABLE_LIGHT_SPOT) || defined(ADDITIVE_SPOT)
void light_process_spot(uint idx, vec3 vertex, vec3 eye_vec, vec3 normal, vec3 f0, float roughness, float metallic, float shadow, vec3 albedo, inout float alpha,
#ifdef LIGHT_BACKLIGHT_USED
		vec3 backlight,
#endif
#ifdef LIGHT_RIM_USED
		float rim, float rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
		float clearcoat, float clearcoat_roughness, vec3 vertex_normal,
#endif
#ifdef LIGHT_ANISOTROPY_USED
		vec3 binormal, vec3 tangent, float anisotropy,
#endif
		inout vec3 diffuse_light,
		inout vec3 specular_light) {

	vec3 light_rel_vec = spot_lights[idx].position - vertex;
	float light_length = length(light_rel_vec);
	float spot_attenuation = get_omni_spot_attenuation(light_length, spot_lights[idx].inv_radius, spot_lights[idx].attenuation);
	vec3 spot_dir = spot_lights[idx].direction;
	float scos = max(dot(-normalize(light_rel_vec), spot_dir), spot_lights[idx].cone_angle);
	float spot_rim = max(0.0001, (1.0 - scos) / (1.0 - spot_lights[idx].cone_angle));

	mediump float cone_attenuation = spot_lights[idx].cone_attenuation;
	spot_attenuation *= 1.0 - pow(spot_rim, cone_attenuation);

	vec3 color = spot_lights[idx].color;

	float size_A = 0.0;

	if (spot_lights[idx].size > 0.0) {
		float t = spot_lights[idx].size / max(0.001, light_length);
		size_A = max(0.0, 1.0 - 1.0 / sqrt(1.0 + t * t));
	}

	spot_attenuation *= shadow;

	light_compute(normal, normalize(light_rel_vec), eye_vec, size_A, color, false, spot_attenuation, f0, roughness, metallic, spot_lights[idx].specular_amount, albedo, alpha,
#ifdef LIGHT_BACKLIGHT_USED
			backlight,
#endif
#ifdef LIGHT_RIM_USED
			rim * spot_attenuation, rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
			clearcoat, clearcoat_roughness, vertex_normal,
#endif
#ifdef LIGHT_ANISOTROPY_USED
			binormal, tangent, anisotropy,
#endif
			diffuse_light, specular_light);
}
#endif // !defined(DISABLE_LIGHT_SPOT) || defined(ADDITIVE_SPOT)

#endif // !defined(DISABLE_LIGHT_DIRECTIONAL) || !defined(DISABLE_LIGHT_OMNI) || !defined(DISABLE_LIGHT_SPOT)

#endif // !MODE_RENDER_DEPTH