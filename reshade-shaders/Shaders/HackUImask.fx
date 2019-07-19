//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
// HackUImask
// by UTwelve
// work for FF14， Other game...can try...so subtle,so hack
// 
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#include "ReShade.fxh"
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uniform float BlackMaskPower <
	ui_category = "Amount";
	ui_label = "BlackMaskAmount";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
> = 1.0;
/*

uniform float ClampMax <
	ui_category = "Clamp";
	ui_label = "ClampMax";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 1;
> = 1.0;
//+*/
uniform float Alpha <
	ui_category = "Clamp";
	ui_label = "Alpha";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.1;
> = 0.1;

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

texture HackUIMask_Tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler HackUIMask_Sampler { Texture = HackUIMask_Tex; };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

void PS_HackUIMask(float4 pos : SV_Position, float2 texcoord : TEXCOORD, out float4 color : SV_Target)

{
    float4 UIMask = tex2D(ReShade::BackBuffer, texcoord).a ;
    float4 MaskS = step(Alpha, UIMask) ;
	color = tex2D(ReShade::BackBuffer, texcoord) ;
	color.a = MaskS.a ;
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

void PS_HackUIRestore(float4 pos : SV_Position, float2 texcoord : TEXCOORD, out float4 color : SV_Target)
{
	color = tex2D(HackUIMask_Sampler, texcoord);
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

void PS_HackUICut(float4 pos : SV_Position, float2 texcoord : TEXCOORD, out float4 color : SV_Target)
{
	float4 GameScreen = tex2D(HackUIMask_Sampler, texcoord).a ;
	float4 CutS = step(Alpha, GameScreen) ;
    color.rgb = 0 ;
	color.a = GameScreen.a * BlackMaskPower  ;

}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//////////////////////////////////////////////

technique HackUIMask <
	ui_tooltip = "Keep UI";
	enabled = true;
>
{
	pass PS_HackUIMask
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_HackUIMask;
		RenderTarget = HackUIMask_Tex;
		
	}

}

//////////////////////////////////////////////
technique HackUIRestore <
	ui_tooltip = "Restore UI";
	enabled = true;
>
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_HackUIRestore;

		ClearRenderTargets = false;
		
		BlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
}
//////////////////////////////////////////////
technique HackUICut <
	ui_tooltip = "black mask,prevent UI from affecting other fx";
	enabled = true;
>
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_HackUICut;
		
		ClearRenderTargets = false;
		
		BlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		
	}
}
 