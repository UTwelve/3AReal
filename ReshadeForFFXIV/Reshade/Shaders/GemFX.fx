/**
* Copyright (C) 2015 Lucifer Hawk ()
*
* Permission is hereby granted, free of charge, to any person obtaining a copy of
* this software and associated documentation files (the "Software"), to deal in
* the Software with restriction, including without limitation the rights to
* use and/or sell copies of the Software, and to permit persons to whom the Software
* is furnished to do so, subject to the following conditions:
*
* The above copyright notice and the permission notices (this and below) shall
* be included in all copies or substantial portions of the Software.
*
* Permission needs to be specifically granted by the author of the software to any
* person obtaining a copy of this software and associated documentation files
* (the "Software"), to deal in the Software without restriction, including without
* limitation the rights to copy, modify, merge, publish, distribute, and/or
* sublicense the Software, and subject to the following conditions:
*
* The above copyright notice and the permission notices (this and above) shall
* be included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/
//±©Â¶²ÎÊý//
#include "ReShade.fxh"

uniform bool ambDepth_Check <
	ui_type = "boolean";
ui_label = "Depth dependent motion blur [Adv. MBlur]";
> = true;

uniform float ambDepthRatio <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 1.0;
ui_step = 0.001;
ui_label = "Motion Blur Depth Ratio [Adv. MBlur]";
ui_tooltip = "Amount of addition MB due to distance; Lower Value => Higher Amount";
> = 0;

uniform float ambRecall <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 1.0;
ui_step = 0.001;
ui_label = "Motion Blur Recall [Adv. MBlur]";
ui_tooltip = "Increases detection level of relevant smart motion blur";
> = 1;

uniform float ambPrecision <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 1.0;
ui_step = 0.001;
ui_label = "Motion Blur Precision [Adv. MBlur]";
ui_tooltip = "Increases relevance level of detected smart motion blur";
> = 0;

uniform float ambSoftness <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 10.0;
ui_step = 0.001;
ui_label = "Softness [Adv. MBlur]";
ui_tooltip = "Softness of consequential streaks";
> = 10.0;

uniform float ambSmartMult <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 10.0;
ui_step = 0.001;
ui_label = "Smart Multiplication [Adv. MBlur]";
ui_tooltip = "Multiplication of relevant smart motion blur";
> = 10.0;

uniform float ambIntensity <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 1.0;
ui_step = 0.001;
ui_label = "Intensity [Adv. MBlur]";
ui_tooltip = "Intensity of base motion blur effect";
> = 0;

uniform float ambSmartInt <
	ui_type = "drag";
ui_min = 0.0;
ui_max = 1.0;
ui_step = 0.001;
ui_label = "Smart Intensity [Adv. MBlur]";
ui_tooltip = "Intensity of smart motion blur effect";
> = 0;
//tex//
texture2D ambCurrBlurTex{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture2D ambPrevBlurTex{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture2D ambPrevTex{ Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

sampler2D ambCurrBlurColor{ Texture = ambCurrBlurTex; };
sampler2D ambPrevBlurColor{ Texture = ambPrevBlurTex; };
sampler2D ambPrevColor{ Texture = ambPrevTex; };

float4 PS_AMBCombine(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 prev = tex2D(ambPrevBlurColor, texcoord);
	float4 curr = tex2D(ReShade::BackBuffer, texcoord);
	float4 currBlur = tex2D(ambCurrBlurColor, texcoord);

	float diff = (abs(currBlur.r - prev.r) + abs(currBlur.g - prev.g) + abs(currBlur.b - prev.b)) / 3;
	diff = min(max(diff - ambPrecision, 0.0f)*ambSmartMult, ambRecall);

	if (ambDepth_Check != 0) {
		float depth = tex2D(ReShade::DepthBuffer, texcoord).r;
		return lerp(curr, prev, min(ambIntensity + diff * ambSmartInt, 1.0f) / (depth.r + ambDepthRatio));
	} else {
  return lerp(curr, prev, min(ambIntensity + diff * ambSmartInt, 1.0f));
}
}

void PS_AMBCopyPreviousFrame(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 prev : SV_Target0)
{
	prev = tex2D(ReShade::BackBuffer, texcoord);
}

void PS_AMBBlur(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 curr : SV_Target0, out float4 prev : SV_Target1)
{
	float4 currVal = tex2D(ReShade::BackBuffer, texcoord);
	float4 prevVal = tex2D(ambPrevColor, texcoord);

	float weight[11] = { 0.082607, 0.040484, 0.038138, 0.034521, 0.030025, 0.025094, 0.020253, 0.015553, 0.011533, 0.008218, 0.005627 };
	currVal *= weight[0];
	prevVal *= weight[0];

	float ratio = -1.0f;

	float pixelBlur = ambSoftness / max(1.0f, 1.0f + (-1.0f)*ratio) * (BUFFER_RCP_HEIGHT);

	[unroll]
	for (int z = 1; z < 11; z++) //set quality level by user
	{
		currVal += tex2D(ReShade::BackBuffer, texcoord + float2(z*pixelBlur, 0)) * weight[z];
		currVal += tex2D(ReShade::BackBuffer, texcoord - float2(z*pixelBlur, 0)) * weight[z];
		currVal += tex2D(ReShade::BackBuffer, texcoord + float2(0, z*pixelBlur)) * weight[z];
		currVal += tex2D(ReShade::BackBuffer, texcoord - float2(0, z*pixelBlur)) * weight[z];

		prevVal += tex2D(ambPrevColor, texcoord + float2(z*pixelBlur, 0)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord - float2(z*pixelBlur, 0)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord + float2(0, z*pixelBlur)) * weight[z];
		prevVal += tex2D(ambPrevColor, texcoord - float2(0, z*pixelBlur)) * weight[z];
	}

	curr = currVal;
	prev = prevVal;
}

technique AdvancedMotionBlur_Tech
{
	pass AMBBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_AMBBlur;
		RenderTarget0 = ambCurrBlurTex;
		RenderTarget1 = ambPrevBlurTex;
	}

	pass AMBCombine
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_AMBCombine;
	}

	pass AMBPrev
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_AMBCopyPreviousFrame;
		RenderTarget0 = ambPrevTex;
	}
}