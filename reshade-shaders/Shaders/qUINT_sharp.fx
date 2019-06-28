/*=============================================================================


=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform float SHARP_STRENGTH <
    ui_type = "drag";
    ui_label = "Sharpen Strength";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.2;

uniform bool DEPTH_MASK_ENABLE <
    ui_label = "Use Depth Mask";
> = true;


/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#include "qUINT_common.fxh"

/*=============================================================================
	Vertex Shader
=============================================================================*/

struct VSOUT
{
	float4                  vpos        : SV_Position;
    float2                  uv          : TEXCOORD0;
};

VSOUT VS_Sharp(in uint id : SV_VertexID)
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

#define get_luma(x) dot(x, float3(0.25,0.5,0.25))
#define BlendOverlayf(base, blend)     (base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend)))
/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_Sharp(in VSOUT i, out float4 o : SV_Target0)
{
    float4 color = tex2D(qUINT::sBackBufferTex, i.uv.xy);   

    //  1   2 1
    //  2 -12 2
    //  1   2 1        

    float  edge_color = 0.0;
    float  edge_depth = 0.0;

    float3 offsets = float3(1, 0, -1);

    float2 corners = 0;
    float2 neighbours = 0;
    float2 center = float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv).rgb), qUINT::linear_depth(i.uv));

    corners +=    float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.xx * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.xx * qUINT::PIXEL_SIZE));
    corners +=    float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.xz * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.xz * qUINT::PIXEL_SIZE));
    corners +=    float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.zx * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.zx * qUINT::PIXEL_SIZE));
    corners +=    float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.zz * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.zz * qUINT::PIXEL_SIZE));
    neighbours += float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.yx * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.yx * qUINT::PIXEL_SIZE));
    neighbours += float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.yz * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.yz * qUINT::PIXEL_SIZE));
    neighbours += float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.xy * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.xy * qUINT::PIXEL_SIZE));
    neighbours += float2(get_luma(tex2D(qUINT::sBackBufferTex, i.uv + offsets.zy * qUINT::PIXEL_SIZE).rgb), qUINT::linear_depth(i.uv + offsets.zy * qUINT::PIXEL_SIZE));

    edge_color = corners.x + 2.0 * neighbours.x - 12.0 * center.x;
    edge_depth = corners.y + 2.0 * neighbours.y - 12.0 * center.y; 

    float depth_mask = saturate(1.0 - abs(edge_depth) * 4000.0);
    depth_mask = DEPTH_MASK_ENABLE ? depth_mask : 1;

    float sharpen = -edge_color * depth_mask * SHARP_STRENGTH * 0.25;
    sharpen = sign(sharpen) * log(abs(sharpen) * 10.0 + 1.0)*0.3;

    o.rgb = BlendOverlayf(color.rgb, (0.5 + sharpen));

    o.w = 1;
}

/*=============================================================================
	Techniques
=============================================================================*/



technique TestSharpen
{
    pass
	{
		VertexShader = VS_Sharp;
		PixelShader  = PS_Sharp;
	}
}