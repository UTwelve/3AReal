//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// SmartNoise by Bapho - https://github.com/Bapho https://www.shadertoy.com/view/3tBGzw
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// I created this shader because i did not liked the the noise behaviour
// of most shaders. Time based noise shaders, which are changing the noise
// pattern every frame, are very noticeable when the "image isn't moving".
// "Static shaders", which are never changing the noise pattern, are very
// noticeable when the "image is moving". So i was searching a way to
// bypass those disadvantages. I used the unique position of the current
// texture in combination with the color and depth to get a unique seed
// for the noise function. The result is a noise pattern that is only
// changing when the color or depth of the position is changing.
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

uniform float noise <
	ui_type = "drag";
ui_min = 0.0; ui_max = 4.0;
ui_label = "噪点数量";
> = 1.0;

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#include "ReShade.fxh"

static const float PHI = 1.61803398874989484820459 * 00000.1; // Golden Ratio   
static const float PI = 3.14159265358979323846264 * 00000.1; // PI
static const float SQ2 = 1.41421356237309504880169 * 10000.0; // Square Root of Two

float gold_noise(float2 coordinate, float seed) {
	return frac(tan(distance(coordinate*(seed + PHI), float2(PHI, PI)))*SQ2);
}

float3 SmartNoise(float4 pos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
	float amount = noise * 0.08;
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

	// the luminance/brightness
	float luminance = (0.2126 * color.r) + (0.7152 * color.g) + (0.0722 * color.b);

	// calculating a unique position
	float uniquePos = (ReShade::ScreenSize.x * texcoord.y) + texcoord.x;

	// depth is also used
	float depthSeed = ReShade::GetLinearizedDepth(texcoord) * ReShade::ScreenSize.y;

	// adjusting "noise contrast"
	if (luminance < 0.5) {
		amount *= (luminance / 0.5);
	}
 else {
  amount *= ((1.0 - luminance) / 0.5);
}

	// reddishly pixels will get less noise 
	float redDiff = color.r - ((color.g + color.b) / 2.0);
	if (redDiff > 0.0) {
		amount *= (1.0 - (redDiff * 0.5));
	}

	// a very low unique seed will lead to slow noise pattern changes on slow moving color gradients
	float uniqueSeed = ((luminance * ReShade::ScreenSize.y) + uniquePos + depthSeed) * 0.0001;

	// a high fictive position will give good golden noise results
	float2 coordinate = texcoord * ReShade::ScreenSize.y * 2.0;

	// average noise luminance to subtract
	float sub = (0.5 * amount);

	// "noise clipping"
	if (luminance - sub < 0.0) {
	   amount *= (luminance / sub);
	   sub *= (luminance / sub);
	}
 else if (luminance + sub > 1.0) {
  if (luminance > sub) {
	  amount *= (sub / luminance);
	  sub *= (sub / luminance);
  }
else {
 amount *= (luminance / sub);
 sub *= (luminance / sub);
}
}

	// calculating and adding/subtracting the golden noise
	float ran = gold_noise(coordinate, uniqueSeed);
	float add = ran * amount;
	color += (add - sub);

	return color;
}

technique SmartNoise
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = SmartNoise;
	}
}
