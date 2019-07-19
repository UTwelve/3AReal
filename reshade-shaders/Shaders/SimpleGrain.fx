/*
Simple Grain PS v1.0.3 (c) 2018 Jacob Maximilian Fober

This work is licensed under the Creative Commons 
Attribution-ShareAlike 4.0 International License. 
To view a copy of this license, visit 
http://creativecommons.org/licenses/by-sa/4.0/.
*/

  ////////////////////
 /////// MENU ///////
////////////////////

#ifndef ShaderAnalyzer
uniform float Intensity <
	ui_label = "Noise intensity";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.002;
> = 0.4;

uniform int Coefficient <
	ui_label = "Luma coefficient";
	ui_tooltip = "For digital connection use BT.709, for analog (like VGA) use BT.601";
	ui_type = "combo";
	ui_items = "BT.709\0BT.601\0";
> = 0;

uniform int Framerate <
	ui_label = "Noise framerate";
	ui_tooltip = "Zero will match in-game framerate";
	ui_type = "drag";
	ui_min = 0; ui_max = 120; ui_step = 1;
> = 12;

  //////////////////////
 /////// SHADER ///////
//////////////////////

uniform float Timer < source = "timer"; >;
uniform int FrameCount < source = "framecount"; >;
#endif

// Overlay blending mode
float Overlay(float LayerA, float LayerB)
{
	float MinA = min(LayerA, 0.5);
	float MinB = min(LayerB, 0.5);
	float MaxA = max(LayerA, 0.5);
	float MaxB = max(LayerB, 0.5);
	return 2 * (MinA * MinB + MaxA + MaxB - MaxA * MaxB) - 1.5;
}

// Noise generator
float SimpleNoise(float p)
{
	return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

#include "ReShade.fxh"

// Shader pass
void SimpleGrainPS(float4 vois : SV_Position, float2 TexCoord : TEXCOORD, out float3 Image : SV_Target)
{
	// Choose luma coefficient, if True BT.709 Luma, else BT.601 Luma
	const float3 LumaCoefficient = (Coefficient == 0) ?
		float3( 0.2126,  0.7152,  0.0722) : float3( 0.299,  0.587,  0.114)
	;
	// Sample image
	Image = tex2D(ReShade::BackBuffer, TexCoord).rgb;
	// Mask out bright pixels  gamma: (sqrt(5)+1)/2
	const float GoldenAB = sqrt(5) * 0.5 + 0.5;
	float Mask = pow(1 - dot(Image.rgb, LumaCoefficient), GoldenAB);
	// Calculate seed change
	float Seed = Framerate == 0 ? FrameCount : floor(Timer * 0.001 * Framerate);
	// Protect from enormous numbers
	Seed = frac(Seed * 0.0001) * 10000;
	// Generate noise *  (sqrt(5) + 1) / 4  (to remain brightness)
	const float GoldenABh = sqrt(5) * 0.25 + 0.25;
	float Noise = saturate(SimpleNoise(Seed * TexCoord.x * TexCoord.y) * GoldenABh);
	Noise = lerp(0.5, Noise, Intensity * 0.1 * Mask);
	// Blend noise with image
	Image.rgb = float3(
		Overlay(Image.r, Noise),
		Overlay(Image.g, Noise),
		Overlay(Image.b, Noise)
	);
}

technique SimpleGrain
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = SimpleGrainPS;
	}
}