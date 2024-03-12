/*
Copyright (c) 2024 Turánszki János

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
 */
#version 450

#include "compiled.inc"
#include "std/math.glsl"
#include "std/gbuffer.glsl"
#include "std/shadows.glsl"
#include "std/imageatomic.glsl"
#include "std/conetrace.glsl"

#ifdef _VoxelGI
uniform sampler3D voxelsSampler;
uniform layout(r32ui) uimage3D voxels;
uniform layout(rgba8) image3D voxelsB;
uniform layout(r32ui) uimage3D voxelsEmission;
uniform layout(r32ui) uimage3D voxelsNor;
uniform layout(rgba8) image3D voxelsOut;

uniform vec3 lightPos;
uniform vec3 lightColor;
uniform int lightType;
uniform vec3 lightDir;
uniform vec2 spotData;
#ifdef _ShadowMap
uniform int lightShadow;
uniform vec2 lightProj;
uniform float shadowsBias;
uniform mat4 LVP;
#endif

#ifdef _ShadowMap
uniform sampler2DShadow shadowMap;
uniform sampler2DShadow shadowMapSpot;
uniform samplerCubeShadow shadowMapPoint;
#endif
#endif
#ifdef _VoxelAOvar
uniform layout(r8) image3D voxels;
uniform layout(r8) image3D voxelsB;
uniform layout(r8) image3D voxelsOut;
#endif

uniform vec3 clipmap_center;
uniform vec3 clipmap_offset_prev;
uniform int clipmapLevel;

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
	int res = voxelgiResolution.x;
	#ifdef _VoxelGI
	vec4 aniso_colors[6];
	#else
	float opac;
	float aniso_colors[6];
	#endif

	for (int i = 0; i < 6 + DIFFUSE_CONE_COUNT; i++)
	{
		ivec3 src = ivec3(gl_GlobalInvocationID.xyz);
		src.x += i * res;
		ivec3 dst = src;
		dst.y += clipmapLevel * res;
		#ifdef _VoxelGI
		vec4 radiance = vec4(0.0);
		vec4 emission = vec4(0.0);
		vec3 N = vec3(0.0);
		#else
		float opac = 0.0;
		#endif

		if (i < 6) {
			#ifdef _VoxelGI
			radiance = convRGBA8ToVec4(imageLoad(voxels, src).r);
			#else
			opac = imageLoad(voxels, src).r;
			#endif

			#ifdef _VoxelGI
			if (radiance.a > 0.0)
			#else
			if (opac > 0.0)
			#endif
			{
				if (any(notEqual(clipmap_offset_prev, vec3(0.0))))
				{
					ivec3 coords = ivec3(dst - clipmap_offset_prev);
					int aniso_face_start_x = i * res;
					int aniso_face_end_x = aniso_face_start_x + res;
					int clipmap_face_start_y = clipmapLevel * res;
					int clipmap_face_end_y = clipmap_face_start_y + res;
					if (
						coords.x >= aniso_face_start_x && coords.x < aniso_face_end_x &&
						coords.y >= clipmap_face_start_y && coords.y < clipmap_face_end_y &&
						coords.z >= 0 && coords.z < res
					)
						#ifdef _VoxelGI
						radiance = mix(imageLoad(voxelsB, dst), radiance, 0.5);
						#else
						opac = mix(imageLoad(voxelsB, dst).r, opac, 0.5);
						#endif
				}
				else
					#ifdef _VoxelGI
					radiance = mix(imageLoad(voxelsB, dst), radiance, 0.5);
					#else
					opac = mix(imageLoad(voxelsB, dst).r, opac, 0.5);
					#endif
			}
			else
				#ifdef _VoxelGI
				radiance = vec4(0.0);
				#else
				opac = 0.0;
				#endif
			#ifdef _VoxelGI
			aniso_colors[i] = radiance;
			#else
			aniso_colors[i] = opac;
			#endif
		}
		else {
			// precompute cone sampling:
			vec3 coneDirection = DIFFUSE_CONE_DIRECTIONS[i - 6];
			vec3 aniso_direction = -coneDirection;
			uvec3 face_offsets = uvec3(
				aniso_direction.x > 0 ? 0 : 1,
				aniso_direction.y > 0 ? 2 : 3,
				aniso_direction.z > 0 ? 4 : 5
			);
			vec3 direction_weights = abs(coneDirection);
			#ifdef _VoxelGI
			vec4 sam =
				aniso_colors[face_offsets.x] * direction_weights.x +
				aniso_colors[face_offsets.y] * direction_weights.y +
				aniso_colors[face_offsets.z] * direction_weights.z
				;
			radiance = sam;
			#else
			float sam =
				aniso_colors[face_offsets.x] * direction_weights.x +
				aniso_colors[face_offsets.y] * direction_weights.y +
				aniso_colors[face_offsets.z] * direction_weights.z
				;
			opac = sam;
			#endif
		}
		#ifdef _VoxelGI
		imageStore(voxelsOut, dst, radiance);
		#else
		imageStore(voxelsOut, dst, vec4(opac));
		#endif
	}
}
