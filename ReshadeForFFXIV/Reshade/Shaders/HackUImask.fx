//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
// HackUImask
// by UTwelve
// work for FF14， Other game...can try...so subtle,so hack
// 1.2 增加了背景色调节
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#include "ReShade.fxh"
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uniform float BlackMaskPower <
	ui_category = "程度";
	ui_label = "黑色蒙版权重";
	ui_tooltip = "可以溢出范围.";
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
	ui_category = "钳制范围";
	ui_label = "透明度";
	ui_tooltip = "钳制透明度捕获的范围.";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.1;

uniform float3 BackColor <
	ui_category = "背景颜色";
	ui_label = "颜色";
	ui_tooltip = "填充被扣掉的UI.";
	ui_type = "color";
> = float3(0.1, 0.1, 0.1) / 255.0;


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
    color.rgb = BackColor.rgb ;
	color.a = GameScreen.a * BlackMaskPower  ;

}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//////////////////////////////////////////////

technique HackUIMask
< ui_tooltip = "                      >> HackUIMask <<\n\n"
			   "HackUIMask的作用是在流程中去除UI并在流程后加回\n"
			   "  1.HackUIMask放在最顶部，用来捕捉流程初始原画面\n"
               "  2.HackUICut放在之后，用来返回一个UI变为黑色的画面，减小UI对流程的影响\n"
			   "  3.HackUIRestore放在最后，将UI放回画面\n"
               "\nby Haikui"; >
{
	pass PS_HackUIMask
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_HackUIMask;
		RenderTarget = HackUIMask_Tex;
		
	}

}
//////////////////////////////////////////////
technique HackUICut <
	ui_tooltip = "2.HackUICut放在之后，返回一个UI变为黑色的画面，减小UI对流程的影响";
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
 
//////////////////////////////////////////////
technique HackUIRestore <
	ui_tooltip = "3.HackUIRestore放在最后，将UI放回画面";
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
