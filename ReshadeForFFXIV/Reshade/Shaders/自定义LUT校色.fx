//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ReShade effect file
// visit facebook.com/MartyMcModding for news/updates
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Marty's LUT shader 1.0 for ReShade 3.0
// Copyright © 2008-2016 Marty McFly
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


/*

替换其中的LUT：
   将你的LUT放入...\ReshadeForFFXIV\Reshade\Textures\LUTs

   在下方LUT选择一个替换名称：

#ifndef fLUT5_TextureName
	#define fLUT5_TextureName "LUTs/(替换→)XXXX.png(←替换)"
#endif

*/

//-------------------------------------------------------------
#ifndef fLUT_TextureName
	#define fLUT_TextureName "3AReal_Lut.png"
#endif
#ifndef fLUT2_TextureName
	#define fLUT2_TextureName "LUTs/City_Trees.png"//(←替换（举例）)
#endif

#ifndef fLUT3_TextureName
	#define fLUT3_TextureName "LUTs/K2_Analog.png"
#endif
#ifndef fLUT4_TextureName
	#define fLUT4_TextureName "LUTs/KP8_Kodak_Portra_800.png"
#endif
#ifndef fLUT5_TextureName
	#define fLUT5_TextureName "LUTs/L8_Beach.png"
#endif
#ifndef fLUT6_TextureName
	#define fLUT6_TextureName "LUTs/MusicClip_Log_V1_CatPlectre.png"
#endif
#ifndef fLUT7_TextureName
	#define fLUT7_TextureName "LUTs/NightCity_1.H004_C006_1211TB.png"
#endif
#ifndef fLUT8_TextureName
	#define fLUT8_TextureName "LUTs/T&O_RMN_O2.png"
#endif
#ifndef fLUT9_TextureName
	#define fLUT9_TextureName "LUTs/U1_Bright_Sun.png"
#endif
#ifndef fLUT10_TextureName
	#define fLUT10_TextureName "LUTs/VINTAGE_MOOD_ET.png"
#endif
//-------------------------------------------------------------

#ifndef fLUT_TileSizeXY
	#define fLUT_TileSizeXY 64
#endif
#ifndef fLUT_TileAmount
	#define fLUT_TileAmount 64
#endif

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uniform int iLUT_Source <
	ui_type = "combo";
	ui_items = fLUT_TextureName  "\0"
				fLUT2_TextureName "\0"//;
				///*
				fLUT3_TextureName "\0"
				fLUT4_TextureName "\0"
				fLUT5_TextureName "\0"
				fLUT6_TextureName "\0"
				fLUT7_TextureName "\0"
				fLUT8_TextureName "\0"
				fLUT9_TextureName "\0"	
				fLUT10_TextureName "\0";
				//*/
	ui_label = "LUT选项";
	ui_tooltip = "选择LUT.";
> = 1;
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uniform float fLUT_AmountChroma <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "LUT 色度";
	ui_tooltip = "LUT颜色/色度变化的强度(建议默认)";
> = 1.00;

uniform float fLUT_AmountLuma <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "LUT 流明量";
	ui_tooltip = "LUT的光强变化(建议默认)";
> = 1.00;

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#include "ReShade.fxh"

texture texLUT < source = fLUT_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT2 < source = fLUT2_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
///*
texture texLUT3 < source = fLUT3_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT4 < source = fLUT4_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT5 < source = fLUT2_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT6 < source = fLUT3_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT7 < source = fLUT4_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT8 < source = fLUT2_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT9 < source = fLUT3_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
texture texLUT10 < source = fLUT4_TextureName;> { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
//*/
//
sampler SamplerLUT { Texture = texLUT;};
sampler SamplerLUT2 { Texture = texLUT2;};
///*
sampler SamplerLUT3 { Texture = texLUT3;};
sampler SamplerLUT4 { Texture = texLUT4;};
sampler SamplerLUT5 { Texture = texLUT;};
sampler SamplerLUT6 { Texture = texLUT2;};
sampler SamplerLUT7 { Texture = texLUT3;};
sampler SamplerLUT8 { Texture = texLUT4;};
sampler SamplerLUT9 { Texture = texLUT4;};
sampler SamplerLUT10 { Texture = texLUT4;};
//*/

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

void PS_LUT_Apply(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 res : SV_Target0)
{

	float4 color = tex2D(ReShade::BackBuffer, texcoord.xy);
	float2 texelsize = 1.0 / fLUT_TileSizeXY;
	texelsize.x /= fLUT_TileAmount;

	float3 lutcoord = float3((color.xy*fLUT_TileSizeXY-color.xy+0.5)*texelsize.xy,color.z*fLUT_TileSizeXY-color.z);
	float lerpfact = frac(lutcoord.z);
	lutcoord.x += (lutcoord.z-lerpfact)*texelsize.y;
	
	if(iLUT_Source == 0){float3 lutcolor = lerp(tex2D(SamplerLUT, lutcoord.xy).xyz, tex2D(SamplerLUT, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 1){float3 lutcolor = lerp(tex2D(SamplerLUT2, lutcoord.xy).xyz, tex2D(SamplerLUT2, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
///*	
	if(iLUT_Source == 2){float3 lutcolor = lerp(tex2D(SamplerLUT3, lutcoord.xy).xyz, tex2D(SamplerLUT3, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 3){float3 lutcolor = lerp(tex2D(SamplerLUT4, lutcoord.xy).xyz, tex2D(SamplerLUT4, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
		
	if(iLUT_Source == 4){float3 lutcolor = lerp(tex2D(SamplerLUT, lutcoord.xy).xyz, tex2D(SamplerLUT, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 5){float3 lutcolor = lerp(tex2D(SamplerLUT2, lutcoord.xy).xyz, tex2D(SamplerLUT2, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 6){float3 lutcolor = lerp(tex2D(SamplerLUT3, lutcoord.xy).xyz, tex2D(SamplerLUT3, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 7){float3 lutcolor = lerp(tex2D(SamplerLUT4, lutcoord.xy).xyz, tex2D(SamplerLUT4, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
		
	if(iLUT_Source == 8){float3 lutcolor = lerp(tex2D(SamplerLUT2, lutcoord.xy).xyz, tex2D(SamplerLUT2, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 9){float3 lutcolor = lerp(tex2D(SamplerLUT3, lutcoord.xy).xyz, tex2D(SamplerLUT3, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
	
	if(iLUT_Source == 10){float3 lutcolor = lerp(tex2D(SamplerLUT4, lutcoord.xy).xyz, tex2D(SamplerLUT4, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), fLUT_AmountChroma) * 
	    lerp(length(color.xyz),    length(lutcolor.xyz),    fLUT_AmountLuma);}
//*/
	res.xyz = color.xyz;
	res.w = 1.0;
	
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


technique LUT_DIY< 
ui_tooltip = "    > 自定义LUT <<\n\n"
			   "自定义校色LUT\n"
			   "初始设置为3AReal校色\n"
			   " \n"
			   "替换方法见：ReshadeForFFXIV/Reshade/Shaders/自定义LUT.fx\n"
               "\nby Haikui"; >
{
	pass LUT_Apply
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LUT_Apply;
	}
}