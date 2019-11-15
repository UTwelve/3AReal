#if   __RENDERER__ >= 0x14300
	#define RENDERER_IS_OGL   1
		
#elif __RENDERER__ >= 0x09100 && __RENDERER__ <= 0x09300
	#define RENDERER_IS_D3D9  1
		
#elif __RENDERER__ == 0x0A000 || __RENDERER__ == 0x0A100
	#define RENDERER_IS_D3D10 1
		
#elif __RENDERER__ >= 0x0B000 && __RENDERER__ <= 0x0B200
	#define RENDERER_IS_D3D11 1
		
#endif

#include "ReShade.fxh"

namespace ShoterXX
{	
	#ifndef RENDERER_IS_D3D9
		#define SAFEINT		uint
	#else 
		#define SAFEINT		int
	#endif
	
	uniform SAFEINT fCntr < source = "framecount"; >;
	uniform float fTime < source = "frametime"; >;
	
	//MACRO FUNCTIONS
	
	#define fetchMe() tex2D(ReShade::BackBuffer, xy)
	
	#define CreateLQTexture(NAME, x, y)\
	\
	texture2D NAME##Tex\
	{\
		Width = ##x;\
		Height = ##y;\
		Format = RGBA8;\
	};\
	\
	sampler2D NAME\
	{\
		Texture = NAME##Tex;\
	};
	
	#define CreateMQTexture(NAME, x, y)\
	\
	texture2D NAME##Tex\
	{\
		Width = ##x;\
		Height = ##y;\
		Format = RGBA16F;\
	};\
	\
	sampler2D NAME\
	{\
		Texture = NAME##Tex;\
	};
	
	//FUNCTIONS
	
	float4   sqr(in float4   sqrMe) { return sqrMe * sqrMe; }
	float3   sqr(in float3   sqrMe) { return sqrMe * sqrMe; }
	float    sqr(in float    sqrMe) { return sqrMe * sqrMe; }
	
}


namespace ShoterXX
{

	CreateMQTexture(F0, BUFFER_WIDTH, BUFFER_HEIGHT);	
	CreateMQTexture(F0Copy, BUFFER_WIDTH, BUFFER_HEIGHT);
	CreateLQTexture(FB, BUFFER_WIDTH, BUFFER_HEIGHT);
	CreateLQTexture(FBCopy, BUFFER_WIDTH, BUFFER_HEIGHT);
	
	uniform SAFEINT tFRate <
		ui_type = "drag";
		ui_label = "Target Framerate";
		ui_min = 1; ui_max = 255;
		ui_tooltip = "显示器的刷新率。当帧率过低时，效果会有所补偿。";
	> = 60;
	
	uniform float tFThres <
		ui_type = "drag";
		ui_label = "Frame Drop Threshold";
		ui_min = 0.0; ui_max = 2.0;
		ui_tooltip = "允许多少帧下降，提供一个更平滑的整体。过多会导致帧频补偿不足，造成视觉上的卡顿，过少则会导致帧频过早的下降，画面不流畅。";
		> = 1.125;
	
	uniform float blurStr <
		ui_type = "drag";
		ui_label = "Blur Strength";
		ui_min = 0.0; ui_max = 1.0;
		ui_tooltip = "改变缓冲区和最新帧之间的偏差。";
	> = 0.5;
	
	void FB_CopyFrames(in float4 vpos : SV_Position, in float2 xy : TEXCOORD, out float4 frame0 : SV_Target0, out float4 frameB : SV_Target1)
	{	
		frame0 = tex2D(F0, xy);
		frameB = tex2D(FB, xy);
	}
	
	void FB_DisplayFrames(in float4 vpos : SV_Position, in float2 xy : TEXCOORD, out float4 put : SV_Target0)
	{	
		put = tex2D(FB, xy);
	}
	
	void FB_AddFrames(in float4 vpos : SV_Position, in float2 xy : TEXCOORD, out float4 frame0 : SV_Target0, out float4 frameB : SV_Target1)
	{
		frameB = tex2D(FBCopy, xy);
		frame0 = tex2D(F0Copy, xy);
		
		int curFrameN = frameB.a * 255;
		
		int lastNFrame = ((1000./frame0.a)/tFRate * (1 + tFThres));
		
		int nFrame = ((1000./fTime)/tFRate * (1 + tFThres));
		
		nFrame = floor((nFrame + lastNFrame * lastNFrame)/(nFrame + lastNFrame));
		
		[branch]
		if (!curFrameN)
		{
			frame0 = fetchMe();
		}
		else
		{
			frame0 = sqrt((sqr(frame0) * curFrameN + sqr(fetchMe())*(1./blurStr))/(curFrameN+(1./blurStr)));
		}
		
		[branch]
		if (curFrameN > (nFrame - 2))
		{
			frameB = float4(frame0.rgb,0.);
		}
		else
		{
			frameB.a = ((++curFrameN)/255.);
		}
		
		frame0.a = fTime;
	}

technique FrameBlend
{

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ShoterXX::FB_AddFrames;
		RenderTarget0 = ShoterXX::F0Tex;
		RenderTarget1 = ShoterXX::FBTex;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ShoterXX::FB_CopyFrames;
		RenderTarget0 = ShoterXX::F0CopyTex;
		RenderTarget1 = ShoterXX::FBCopyTex;
	}
	

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ShoterXX::FB_DisplayFrames;
	}

}

}