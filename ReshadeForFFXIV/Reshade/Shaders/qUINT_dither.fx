/*=============================================================================

	ReShade 4 effect file
    github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Dither / Deband filter based on Weyl pseudorandom low discrepancy sequence

    * Unauthorized copying of this file, via any medium is strictly prohibited
 	* Proprietary and confidential

=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform int BIT_DEPTH <
	ui_type = "slider";
	ui_min = 4; ui_max = 10;
    ui_label = "Bit depth of data to be debanded";
> = 8;

uniform int DEBAND_MODE <
	ui_type = "radio";
    ui_label = "Dither mode";
	ui_items = "None\0Dither\0Deband\0";
> = 1;

uniform bool SKY_ONLY <
    ui_label = "Apply to sky only";
> = false;

/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#define RESHADE_QUINT_COMMON_VERSION_REQUIRE 200
#include "qUINT_common.fxh"

/*=============================================================================
	Vertex Shader
=============================================================================*/

struct VSOUT
{
	float4                  vpos        : SV_Position;
    float2                  uv          : TEXCOORD0;
};

VSOUT VS_Dither(in uint id : SV_VertexID)
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

float3 dither(in VSOUT i)
{
    const float2 magicdot = float2(0.75487766624669276, 0.569840290998);
    const float3 magicadd = float3(0, 0.025, 0.0125) * dot(magicdot, 1);

    const int dither_bit = 8;
    const float lsb = exp2(dither_bit) - 1;

    float3 dither = frac(dot(i.vpos.xy, magicdot) + magicadd) - 0.5;
    dither /= lsb;
    
    return dither;
}

float frac_noise(float2 uv)
{
    return frac(frac(dot(uv, float2(217.304, 18.961))) * 262.193);
}


/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_Dither(in VSOUT i, out float3 o : SV_Target0)
{
	o = tex2D(qUINT::sBackBufferTex, i.uv).rgb;  

	const float2 magicdot = float2(0.75487766624669276, 0.569840290998);
    const float3 magicadd = float3(0, 0.025, 0.0125) * dot(magicdot, 1);
    float3 dither = frac(dot(i.vpos.xy, magicdot) + magicadd);

    if(SKY_ONLY)
    {
    	if(qUINT::linear_depth(i.uv) < 0.98) return;
    }

    float lsb = rcp(exp2(BIT_DEPTH) - 1.0);

    if(DEBAND_MODE == 2)
    {
     	float2 shift;
     	sincos(6.283 * 30.694 * dither.x, shift.x, shift.y); //2.3999632 * 16
     	shift = shift * dither.x - 0.5;

     	float3 scatter = tex2D(qUINT::sBackBufferTex, i.uv + shift * 0.025).rgb;
     	float4 diff; 
     	diff.rgb = abs(o.rgb - scatter);
     	diff.w = max(max(diff.x, diff.y), diff.z);

     	o = lerp(o, scatter, diff.w <= lsb);
    }
    else if(DEBAND_MODE == 1)
    {
    	o += (dither - 0.5) * lsb;
    }
}

/*=============================================================================
	Techniques
=============================================================================*/

technique DitherMcFly
{
    pass
	{
		VertexShader = VS_Dither;
		PixelShader  = PS_Dither;
	}
}