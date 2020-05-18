#include "ReShade.fxh"

#ifndef REMOVE_TINT_MINMAX_STEP
	#define REMOVE_TINT_MINMAX_STEP BUFFER_WIDTH/64
#endif

uniform float fUISpeed <
	ui_type = "drag";
	ui_label = "Speed";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.01;
> = 0.3;

#ifdef REMOVE_TINT_CUSTOM_COLORS
uniform bool bUIUseCustomColors <
	ui_type = "radio";
	ui_label = "Use Custom Colors";
> = false;

uniform float3 fUIColorMin <
	ui_type = "color";
	ui_label = "Color Min";
> = float3(0.0, 0.0, 0.0);

uniform float3 fUIColorMax <
	ui_type = "color";
	ui_label = "Color Max";
> = float3(1.0, 1.0, 1.0);
#endif

uniform float fUIStrength <
	ui_type = "slider";
	ui_label = "Strength";
	ui_min = 0.0; ui_max = 1.0;
	ui_step = 0.01;
> = 1.0;

#ifdef REMOVE_TINT_DEBUG
uniform bool bUIShowDebug <
	ui_type = "radio";
	ui_label = "Show Debug Values";
	ui_tooltip = "Shows the min/max RGB values";
> = true;
#endif

uniform float frametime < source = "frametime"; >;

#define MAX3(v) max(v.x, max(v.y, v.z))
#define MIN3(v) min(v.x, min(v.y, v.z))

namespace RemoveTint {

	texture2D texMinRGB { Width = 1; Height = 1; Format = RGBA16F; };
	sampler2D samplerMinRGB { Texture = texMinRGB; };
	texture2D texMaxRGB { Width = 1; Height = 1; Format = RGBA16F; };
	sampler2D samplerMaxRGB { Texture = texMaxRGB; };

	texture2D texMinRGBLastFrame { Width = 1; Height = 1; Format = RGBA16F; };
	sampler2D samplerMinRGBLastFrame { Texture = texMinRGBLastFrame; };
	texture2D texMaxRGBLastFrame { Width = 1; Height = 1; Format = RGBA16F; };
	sampler2D samplerMaxRGBLastFrame { Texture = texMaxRGBLastFrame; };

#ifdef REMOVE_TINT_DEBUG
	float3 DrawDebugCurveXY(float3 background, float2 texcoord, float value, float3 color, float curveDiv) {
		float p = exp(-(BUFFER_HEIGHT/curveDiv) * length(texcoord - float2(texcoord.x, 1.0 - value)));
		return lerp(background, color, saturate(p));
	}
	float3 DrawDebugCurveYX(float3 background, float2 texcoord, float value, float3 color, float curveDiv) {
		float p = exp(-(BUFFER_HEIGHT/curveDiv) * length(texcoord - float2(value, texcoord.y)));
		return lerp(background, color, saturate(p));
	}
#endif

	void MinMaxRGB_PS(float4 vpos : SV_Position, float2 texcoord : TexCoord, out float4 minRGB : SV_Target0, out float4 maxRGB : SV_Target1) {
		float3 color;
		minRGB = 1.0;
		maxRGB = 0.0;

		// Cycle through backbuffer and get the min/max values
		for(int y = 0; y < BUFFER_HEIGHT; y+=REMOVE_TINT_MINMAX_STEP) {
			for(int x = 0; x < BUFFER_WIDTH; x+=REMOVE_TINT_MINMAX_STEP) {
				color = tex2Dfetch(ReShade::BackBuffer, int4(x, y, 0, 0)).rgb;

				maxRGB.r = lerp(maxRGB.r, color.r, step(maxRGB.r, color.r));
				maxRGB.g = lerp(maxRGB.g, color.g, step(maxRGB.g, color.g));
				maxRGB.b = lerp(maxRGB.b, color.b, step(maxRGB.b, color.b));

				minRGB.r = lerp(minRGB.r, color.r, step(color.r, minRGB.r));
				minRGB.g = lerp(minRGB.g, color.g, step(color.g, minRGB.g));
				minRGB.b = lerp(minRGB.b, color.b, step(color.b, minRGB.b));
			}
		}

#ifdef REMOVE_TINT_CUSTOM_COLORS
		minRGB.rgb = lerp(minRGB.rgb, fUIColorMin, bUIUseCustomColors);
		maxRGB.rgb = lerp(maxRGB.rgb, fUIColorMax, bUIUseCustomColors);
#endif

		// Saturate the lerp factor - it could get higher than 1.0 when the game hangs
		float factor = saturate(fUISpeed * frametime * 0.01);
		// Set alpha channel to 1.0 so the texture can be viewed in the statistics page.
		minRGB = float4(lerp(tex2Dfetch(samplerMinRGBLastFrame, int4(0, 0, 0, 0)).rgb, minRGB.rgb, factor), 1.0);
		maxRGB = float4(lerp(tex2Dfetch(samplerMaxRGBLastFrame, int4(0, 0, 0, 0)).rgb, maxRGB.rgb, factor), 1.0);
	}

	void MinMaxRGBBackup_PS(float4 vpos : SV_Position, float2 texcoord : TexCoord, out float4 minRGB : SV_Target0, out float4 maxRGB : SV_Target1) {
		minRGB = tex2Dfetch(samplerMinRGB, int4(0, 0, 0, 0));
		maxRGB = tex2Dfetch(samplerMaxRGB, int4(0, 0, 0, 0));
	}

	float3 Apply_PS(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
		float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
		float3 minRGB = tex2Dfetch(RemoveTint::samplerMinRGB, int4(0, 0, 0, 0)).rgb;
		float3 maxRGB = tex2Dfetch(RemoveTint::samplerMaxRGB, int4(0, 0, 0, 0)).rgb;

#ifdef REMOVE_TINT_DEBUG
	if(bUIShowDebug)
	{
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, minRGB.r, float3(1.0, 0.0, 0.0), 1.0);
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, minRGB.g, float3(0.0, 1.0, 0.0), 1.0);
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, minRGB.b, float3(0.0, 0.0, 1.0), 1.0);
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, maxRGB.r, float3(1.0, 0.0, 0.0), 1.0);
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, maxRGB.g, float3(0.0, 1.0, 0.0), 1.0);
		color = RemoveTint::DrawDebugCurveYX(color, texcoord, maxRGB.b, float3(0.0, 0.0, 1.0), 1.0);
	}
#endif

		return saturate(lerp(color, (color - minRGB) / (maxRGB-minRGB), fUIStrength));
	}
}

technique RemoveTint <
	ui_tooltip =	"This shader reduces tinting of the image.\n\n"
					"Available preprocessor definitions:\n"
					"REMOVE_TINT_MINMAX_STEP\n"
					"REMOVE_TINT_CUSTOM_COLORS\n"
					"REMOVE_TINT_DEBUG";
>
{
	pass {
		VertexShader = PostProcessVS;
		PixelShader = RemoveTint::MinMaxRGB_PS;
		RenderTarget0 = RemoveTint::texMinRGB;
		RenderTarget1 = RemoveTint::texMaxRGB;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = RemoveTint::MinMaxRGBBackup_PS;
		RenderTarget0 = RemoveTint::texMinRGBLastFrame;
		RenderTarget1 = RemoveTint::texMaxRGBLastFrame;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = RemoveTint::Apply_PS;
		/* RenderTarget = BackBuffer */
	}
}
