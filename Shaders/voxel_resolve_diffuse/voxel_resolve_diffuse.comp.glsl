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

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "compiled.inc"
#include "std/math.glsl"
#include "std/gbuffer.glsl"
#include "std/imageatomic.glsl"
#include "std/conetrace.glsl"

uniform sampler3D voxels;
uniform sampler2D gbufferD;
uniform sampler2D gbuffer0;
uniform layout(rgba8) image2D voxels_diffuse;

uniform mat4 InvVP;
uniform vec3 eye;

void main() {
	const vec2 pixel = gl_GlobalInvocationID.xy;
	const vec2 uv = (pixel + 0.5) / postprocess_resolution;

	float depth = textureLod(gbufferD, uv, 0.0).r;

	float x = uv.x * 2 - 1;
	#ifdef _InvY
	float y = (1 - uv.y) * 2 - 1;
	#else
	float y = uv.y * 2 - 1;
	#endif
	vec4 position_s = vec4(x, y, depth, 1);
	vec4 position_v = InvVP * position_s;
	vec3 P = position_v.xyz / position_v.w;

	vec4 g0 = textureLod(gbuffer0, uv, 0.0);
	vec3 n;
	n.z = 1.0 - abs(g0.x) - abs(g0.y);
	n.xy = n.z >= 0.0 ? g0.xy : octahedronWrap(g0.xy);
	n = normalize(n);

	vec3 color = traceDiffuse(P, n, voxels, eye).rgb;

	imageStore(voxels_diffuse, ivec2(pixel), vec4(color, 1.0));
}
