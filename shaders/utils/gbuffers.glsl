#if !defined GBUFFERS_GLSL_INCLUDED
#define GBUFFERS_GLSL_INCLUDED 1

#if defined GBUFFERS_ARMOR_GLINT || defined GBUFFERS_BEACONBEAM || defined GBUFFERS_BLOCK || defined GBUFFERS_CLOUDS || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_SKYTEXTURED || defined GBUFFERS_SPIDEREYES || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#	define USE_TEXTURES 1
#endif

#if defined GBUFFERS_BASIC || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#   define USE_LIGHTMAP 1
#endif

#if defined GBUFFERS_TERRAIN || defined GBUFFERS_WATER
#	define USE_CHUNK_OFFSET 1
#endif

#if defined GBUFFERS_BASIC || defined GBUFFERS_BEACONBEAM || defined GBUFFERS_BLOCK || defined GBUFFERS_CLOUDS || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND_WATER || defined GBUFFERS_HAND || defined GBUFFERS_LINE || defined GBUFFERS_SPIDEREYES || defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED_LIT || defined GBUFFERS_TEXTURED || defined GBUFFERS_WATER || defined GBUFFERS_WEATHER
#	define USE_ALPHA_TEST 1
#endif

#if defined GBUFFERS_FSH
#	extension GL_ARB_explicit_attrib_location : enable

#	if defined USE_TEXTURES
		uniform sampler2D gtexture;
#	endif
#	if defined USE_LIGHTMAP
		uniform sampler2D lightmap;
#	endif
#	if defined GBUFFERS_BASIC
		uniform int renderStage;
#	endif
#	if defined USE_ALPHA_TEST
		uniform float alphaTestRef;
#	endif
#	if defined GBUFFERS_ENTITIES
		uniform vec4 entityColor;
#	endif

#	if defined USE_TEXTURES
		in vec2 uv0;
#	endif
#	if defined USE_LIGHTMAP
		in vec2 uv1;
#	endif
	in vec4 col;
	in vec4 fog;

	/* DRAWBUFFERS:0 */
	layout(location = 0) out vec4 fragData0;

	void main() {
	vec4 albedo = col;
#	if defined USE_TEXTURES
		albedo *= texture(gtexture, uv0);
#	endif
#	if defined USE_ALPHA_TEST
		if (albedo.a < alphaTestRef) discard;
#	endif
#	if defined USE_LIGHTMAP
#		if defined GBUFFERS_BASIC
			/*
			 ** Leads have light levels, but chunk borders don't.
			 * And for whatever reason, chunk borders use gbuffers_basic
			 * instead of gbuffers_line, so we detect them with renderStage.
			*/
			if (renderStage != MC_RENDER_STAGE_DEBUG) {
				albedo *= texture(lightmap, uv1);
			}
#		else
			albedo *= texture(lightmap, uv1);
#		endif
#	endif
#	if defined GBUFFERS_ENTITIES
		albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#	endif

	albedo.rgb = mix(albedo.rgb, fog.rgb, fog.a);

		fragData0 = albedo;
	}
#endif /* defined GBUFFERS_FSH */

#if defined GBUFFERS_VSH
#	if defined GBUFFERS_LINE
		const float LINE_WIDTH  = 2.0;
		const float VIEW_SHRINK = 0.9609375 /* 1.0 - (1.0 / 256.0) */ ;
		const mat4 VIEW_SCALE   = mat4(
			VIEW_SHRINK, 0.0, 0.0, 0.0,
			0.0, VIEW_SHRINK, 0.0, 0.0,
			0.0, 0.0, VIEW_SHRINK, 0.0,
			0.0, 0.0, 0.0, 1.0
		);
		
		uniform float viewHeight, viewWidth;
#	endif
	uniform mat4 modelViewMatrix;
	uniform mat4 projectionMatrix;
#	if defined USE_TEXTURES
		// Set a default value when the uniform is not bound.
		uniform mat4 textureMatrix = mat4(1.0);
#	endif
#	if defined USE_CHUNK_OFFSET
		uniform vec3 chunkOffset;
#	endif
	uniform vec3 fogColor;
	uniform float fogStart, fogEnd;

#	if defined USE_TEXTURES
		in vec2 vaUV0;
#	endif
#	if defined USE_LIGHTMAP
		in ivec2 vaUV2;
#	endif
	in vec3 vaNormal;
	in vec3 vaPosition;
	in vec4 vaColor;

#	if defined USE_TEXTURES
		out vec2 uv0;
#	endif
#	if defined USE_LIGHTMAP
		out vec2 uv1;
#	endif
	out vec4 col;
	out vec4 fog;

	void main() {
#	if defined USE_TEXTURES
		uv0 = (textureMatrix * vec4(vaUV0, 0.0, 1.0)).xy;
#	endif
#	if defined USE_LIGHTMAP
		uv1 = clamp(vaUV2 / 256.0, vec2(0.03125 /* 0.5 / 16.0 */ ), vec2(0.96875 /* 15.5 / 16.0 */ ));
#	endif
	col = vaColor;

	vec4 worldPos = vec4(vaPosition, 1.0);
#	if defined USE_CHUNK_OFFSET
		worldPos.xyz += chunkOffset;
#	endif

	fog.rgb = fogColor;
	fog.a = clamp((length(worldPos.xyz) - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

#		if defined GBUFFERS_LINE
		vec2 resolution   = vec2(viewWidth, viewHeight);
		vec4 linePosStart = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition, 1.0)));
		vec4 linePosEnd   = projectionMatrix * (VIEW_SCALE * (modelViewMatrix * vec4(vaPosition + vaNormal, 1.0)));

		vec3 ndc1 = linePosStart.xyz / linePosStart.w;
		vec3 ndc2 = linePosEnd.xyz   / linePosEnd.w;

		vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * resolution);
		vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * LINE_WIDTH / resolution;

		if (lineOffset.x < 0.0) lineOffset = -lineOffset;
		if (gl_VertexID % 2 != 0) lineOffset = -lineOffset;
			
			gl_Position = vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
#		else
			gl_Position = projectionMatrix * (modelViewMatrix * worldPos);
#		endif
	}
#endif /* defined GBUFFERS_VSH */

#endif /* !defined GBUFFERS_GLSL_INCLUDED */
