/*=============================================================================

	ReShade 4 effect file
    github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Paint Shader by Marty McFly / P.Gilcher
    part of qUINT shader library for ReShade 4

    CC BY-NC-ND 3.0 licensed.

=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/

#ifndef NUM_PASSES
 #define NUM_PASSES 				3		//1 to 5
#endif

/*=============================================================================
	UI Uniforms
=============================================================================*/
/*
uniform bool DEBUG_PICTURE <
	ui_label = "Enable Debug Picture";
> = false;
*/
uniform float OUTLINE_INTENSITY <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Outline Intensity";
> = 0.5;

uniform float SHARPEN_INTENSITY <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Sharpen Intensity";
> = 0.5;

uniform int NUM_DIRS <
    ui_type = "slider";
    ui_min = 3;
    ui_max = 7;
    ui_label = "Paintstroke Precision";
> = 5;

uniform int NUM_STEPS_PER_PASS <
    ui_type = "slider";
    ui_min = 1;
    ui_max = 9;
    ui_label = "Paintstroke Length";
> = 6;

/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#define RESHADE_QUINT_COMMON_VERSION_REQUIRE 200
#include "qUINT_common.fxh"

/*
texture DebugTex < source = "debug.png"; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler	sDebugTex { Texture = DebugTex;};
*/
/*=============================================================================
	Vertex Shader
=============================================================================*/

struct VSOUT
{
	float4   vpos        : SV_Position;
    float2   uv          : TEXCOORD0;
};

VSOUT VS_Paint(in uint id : SV_VertexID)
{
    VSOUT o;
    o.uv.x = (id == 2) ? 2.0 : 0.0;
    o.uv.y = (id == 1) ? 2.0 : 0.0;       
    o.vpos = float4(o.uv.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return o;
}

/*=============================================================================
	Functions
=============================================================================*/

float3 paint_filter(in VSOUT i, in float pass_id)
{
	float3 least_divergent = 0;
	float3 total_sum = 0;
	float min_divergence = 1e10;

	[loop]
	for(int j = 0; j < NUM_DIRS; j++)
	{
		float2 dir; sincos(radians(180.0 * (j + pass_id / NUM_PASSES) / NUM_DIRS), dir.y, dir.x);

		float3 col_avg_per_dir = 0;
		float curr_divergence = 0;

		float3 col_prev = tex2Dlod(qUINT::sBackBufferTex, float4(i.uv.xy - dir * NUM_STEPS_PER_PASS * qUINT::PIXEL_SIZE, 0, 0)).rgb;

		for(int k = -NUM_STEPS_PER_PASS + 1; k <= NUM_STEPS_PER_PASS; k++)
		{
			float3 col_curr = tex2Dlod(qUINT::sBackBufferTex, float4(i.uv.xy + dir * k * qUINT::PIXEL_SIZE, 0, 0)).rgb;
			col_avg_per_dir += col_curr;

			float3 color_diff = abs(col_curr - col_prev);

			curr_divergence += max(max(color_diff.x, color_diff.y), color_diff.z);
			col_prev = col_curr;
		}

		[flatten]
		if(curr_divergence < min_divergence)
		{
			least_divergent = col_avg_per_dir;
			min_divergence = curr_divergence;
		}

		total_sum += col_avg_per_dir;
	}

	least_divergent /= 2 * NUM_STEPS_PER_PASS;
	total_sum /= 2 * NUM_STEPS_PER_PASS * NUM_DIRS;
	min_divergence /= 2 * NUM_STEPS_PER_PASS;

	float lumasharpen = dot(least_divergent - total_sum, 0.333);
	least_divergent += lumasharpen * SHARPEN_INTENSITY;

	least_divergent *= saturate(1 - min_divergence * OUTLINE_INTENSITY);
	return least_divergent;
}

/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_Debug(in VSOUT i, out float4 o : SV_Target0)
{
	o = tex2D(qUINT::sBackBufferTex, i.uv);
	//if(DEBUG_PICTURE) o = tex2D(sDebugTex, i.uv);
}

void PS_Paint_1(in VSOUT i, out float4 o : SV_Target0)
{
	o.rgb = paint_filter(i, 1);
	o.w = 1;
}

void PS_Paint_2(in VSOUT i, out float4 o : SV_Target0)
{
	o.rgb = paint_filter(i, 2);
	o.w = 1;
}

void PS_Paint_3(in VSOUT i, out float4 o : SV_Target0)
{
	o.rgb = paint_filter(i, 3);
	o.w = 1;
}

void PS_Paint_4(in VSOUT i, out float4 o : SV_Target0)
{
	o.rgb = paint_filter(i, 4);
	o.w = 1;
}

void PS_Paint_5(in VSOUT i, out float4 o : SV_Target0)
{
	o.rgb = paint_filter(i, 5);
	o.w = 1;
}

/*=============================================================================
	Techniques
=============================================================================*/

technique Paint
{
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Debug;
	}
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Paint_1;
	}
#if(NUM_PASSES >= 2)
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Paint_2;
	}
#endif
#if(NUM_PASSES >= 3)
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Paint_3;
	}
#endif
#if(NUM_PASSES >= 4)
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Paint_4;
	}
#endif
#if(NUM_PASSES >= 5)
	pass
	{
		VertexShader = VS_Paint;
		PixelShader  = PS_Paint_5;
	}
#endif
}
