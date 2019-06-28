
#define MIN_F_STOPS 		1.4		
#define MAX_F_STOPS 		8.0
#define COC_CLAMP			25.0

uniform float FOCUS_PLANE_DEPTH <
    ui_type = "drag";
    ui_min = 0.002;
    ui_max = 1.0;
    ui_label = "Focal Plane Depth";
    ui_tooltip = "Distance to the focal plane. 0 means camera itself, 1 means infinity.\nThis value is internally converted to actual distance parameters.\nFor easier adjustment, this parameter reacts more sensitive to close areas.";  
    ui_category = "Focusing"; 
> = 0.1;

uniform int FOREGROUND_BLUR <
    ui_type = "drag";
    ui_min = 0;
    ui_max = 100;
    ui_label = "Foreground Blur Multiplier";
    ui_tooltip = "Physically incorrect adjustment for near field blur amount (in front of focal plane).";  
    ui_category = "Focusing"; 
> = 100;

uniform int BACKGROUND_BLUR <
    ui_type = "drag";
    ui_min = 0;
    ui_max = 100;
    ui_label = "Background Blur Multiplier";
    ui_tooltip = "Physically incorrect adjustment for far field blur amount (behind focal plane).";  
    ui_category = "Focusing"; 
> = 100;

uniform float FOCAL_LENGTH <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 100.0;
    ui_label = "Focal Length";
    ui_tooltip = "Focal length of the virtual camera. As with real cameras,\na higher focal length means smaller depth of field and more blur.";  
    ui_category = "Camera Parameters"; 
> = 25.0;

uniform float FSTOPS <
    ui_type = "slider";
    ui_min = MIN_F_STOPS;
    ui_max = MAX_F_STOPS;
    ui_label = "Aperture F-Stops";
    ui_tooltip = "Aperture size of the virtual camera (4 means f/4). The aperture opening directly influences\nthe bokeh shape curvature and the blur radius.";  
    ui_category = "Camera Parameters"; 
> = 4.0;

uniform int VERTEX_COUNT <
    ui_type = "drag";
    ui_min = 3;
    ui_max = 9;
    ui_label = "Aperture Blade Count";
    ui_tooltip = "Number of blades of the aperture. For small aperture, e.g. 6 results in hexagonal bokeh.";  
    ui_category = "Camera Parameters"; 
> = 6;

uniform int QUALITY_BIAS <
    ui_type = "drag";
    ui_min = 0;
    ui_max = 100;
    ui_label = "Quality";
    ui_tooltip = "Quality percentage as bias for the automatic blur quality calculation.\n";  
    ui_category = "Quality and Bokeh"; 
> = 50;

uniform float RENDER_SCALE <
    ui_type = "drag";
    ui_min = 0.5;
    ui_max = 1.0;
    ui_label = "Render Scale";
    ui_tooltip = "Render scale of bokeh blur. 1 means fullscreen, 0.5 means blur is computed in 1/2 screen width, 1/2 screen height.\nA value of 1/sqrt(2) ~ 0.7 means 1/2 the amount of pixels.";  
    ui_category = "Quality and Bokeh"; 
> = 0.7;

uniform float BOKEH_HIGHLIGHT <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Bokeh Intensity";
    ui_tooltip = "Amount of additional emphasis on the bokeh discs so bright pixels stand out.";  
    ui_category = "Quality and Bokeh"; 
> = 1.0;

uniform float4 tempF1 <
    ui_type = "drag";
    ui_min = -100.0;
    ui_max = 100.0;
> = float4(1,1,1,1);

uniform float4 tempF2 <
    ui_type = "drag";
    ui_min = -100.0;
    ui_max = 100.0;
> = float4(1,1,1,1);

/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#define TILE_SIZE	16
#define DILATE_SIZE	8

#define depth2distm  		RESHADE_DEPTH_LINEARIZATION_FAR_PLANE
#define depth2distmm  		(RESHADE_DEPTH_LINEARIZATION_FAR_PLANE * 1000.0)
#define distm2depth  		rcp(depth2distm)
#define distmm2depth  		rcp(depth2distmm)
#define screen2pixradius	length(qUINT::SCREEN_SIZE)

#define SINGULARITY_FIX		6.0

#define PERCENT_TO_DECIMAL	0.01

#define GAMMA_CORRECT_TAP(x) x = x / (lerp(2.0, 1.01, BOKEH_HIGHLIGHT) - x);//x*=x; /**/		//x *= x
#define GAMMA_CORRECT_SUM(x) x = lerp(2.0, 1.01, BOKEH_HIGHLIGHT) * x / (x + 1); ///**/ x = sqrt(x); 	//x= sqrt(x)

#define FULL_TO_HALF_RES_THRESHOLD 0  //(0.2 * i.focusdata.x)
#define FULL_TO_HALF_RES_PADDING 1.5

#include "qUINT_common.fxh"

texture2D TileCoC 					{ Width = BUFFER_WIDTH/TILE_SIZE;   Height = BUFFER_HEIGHT/TILE_SIZE;   Format = RG16F; };
texture2D DilatedTileCoC 			{ Width = BUFFER_WIDTH/TILE_SIZE;   Height = BUFFER_HEIGHT/TILE_SIZE;   Format = RG16F; };

texture2D HDR 					{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA16F; };

sampler2D sTileCoC					{ Texture = TileCoC;	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;		};
sampler2D sDilatedTileCoC			{ Texture = DilatedTileCoC;	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;	};
sampler2D sDilatedTileCoCLinear		{ Texture = DilatedTileCoC;	};
sampler2D sHDR						{ Texture = HDR;	};
/*=============================================================================
	Vertex Shader
=============================================================================*/

struct VSOUT
{
	float4 vpos 		: SV_Position;
    float2 uv   		: TEXCOORD0;
    float4 uv_scaled    : TEXCOORD1;
    nointerpolation float4 vertexmat    : TEXCOORD2;
    nointerpolation float4 vertexdata   : TEXCOORD3;
    nointerpolation float4 focusdata    : TEXCOORD4;
};

VSOUT VS_DOF(in uint id : SV_VertexID)
{
    VSOUT o;
    o.uv.x = (id == 2) ? 2.0 : 0.0;
    o.uv.y = (id == 1) ? 2.0 : 0.0;
    o.uv_scaled = o.uv.xyxy * float2(rcp(RENDER_SCALE), RENDER_SCALE).xxyy;
    o.vpos = float4(o.uv.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    sincos(radians(360.0 / VERTEX_COUNT), o.vertexmat.z, o.vertexmat.w);
    o.vertexmat.xy = float2(o.vertexmat.w, -o.vertexmat.z); 	

 	//-----------------------------------------------------------------
 	float F = FOCAL_LENGTH; //focal length in mm
	float D = FOCUS_PLANE_DEPTH * depth2distmm; //focal plane depth in mm
	float S = 36; //sensor with in mm
	float N = FSTOPS; //f/5 -> 5
	//-----------------------------------------------------------------

	float max_bgd_coc = 0.5 * F * F / (N * (D - F)) / S; //0.5 from diameter -> radius	

	float interp = saturate((N - MIN_F_STOPS) / (MAX_F_STOPS - MIN_F_STOPS)); //0 at min stops and 1 at max stops
	float theta = radians(lerp(359.9, 300.0, interp)); 
	float2 P0 = float2(cos(theta) - 1, sin(theta)); //center of one blade's curve circle
	float2 P1 = P0.xx * o.vertexmat.xy 
	          + P0.yy * o.vertexmat.zw; //center of next blade's curve circle
	float d = distance(P0, P1) + 1e-6;
	float a = d * 0.5; //both circles are unit circles, so (r0^2-r1^2+d^2)/2d resolves to d^2/2d = d/2
	float h = sqrt(1 - a * a); //again, r0^2 == 1
	float2 P2 = P0 + a * (P1-P0) / d;
	float2 P3 = P2 + h*(P1-P0) / d; //p3 is now our intersection point between the blade circles (positive solution only)
	float bokeh_r = length(P3); //distance from P3 from the center = the current bokeh radius
	float phi = atan2(P3.y, P3.x);

	float base_rotation = 0.2;

	sincos(phi + base_rotation, o.vertexdata.x, o.vertexdata.y);	
 	o.vertexdata.zw = o.vertexdata.xx * o.vertexmat.xy 
 	                + o.vertexdata.yy * o.vertexmat.zw;

 	o.focusdata.x = BUFFER_WIDTH * max_bgd_coc; 
 	o.focusdata.y = (1 - interp)*(1 - interp);
 	o.focusdata.zw = 0;

    return o;
}

//wrap the packed values into more readable form
#define MAX_BLUR_RADIUS i.focusdata.x
#define ROUNDNESS i.focusdata.y

/*=============================================================================
	Functions
=============================================================================*/

float restore_coc_range(in float coc, in VSOUT i)
{
	return (coc * 2 - 1) * MAX_BLUR_RADIUS;
}

struct FAccumulator
{
	float3 	Color;
	float  	CoCRadius;
	float 	Weight;
	float 	Translucency;	
};

struct GatherParameters
{
	float 		KernelRadius;
	float 		BorderingRadius;
	float		IntersectFeather;
	float 		VertexCount;
	float4 		VertexData;
	float4	 	VertexMatrix;
	float 		RingCount;
	float 		RingId;
	float 		RingSampleCount;
	float 		RingRadius;
	bool 		bIsFirstRing;
	float 		CoCRadiusError;
};

struct GatherSample
{
	float2 	Location;
	float4	Color;
	float CoCRadius;
	float Intersection;
};

void InitToZero(inout FAccumulator F)
{
	F.Color=0;F.CoCRadius=0;F.Weight=0;F.Translucency=0;
}

float ComputeIntersectionNear(in GatherParameters Gather, in GatherSample A)
{
	//return saturate(A.CoCRadius - Gather.RingRadius + 0.5);
	//return saturate((A.CoCRadius - Gather.RingRadius) / Gather.KernelRadius * Gather.RingCount + 1);
	return saturate((A.CoCRadius - Gather.RingRadius) * Gather.IntersectFeather + 1.0);
}

//atm the respective functions work better in their respective areas, need to unify this
float ComputeIntersectionFar(in GatherParameters Gather, in GatherSample A)
{
	return saturate(A.CoCRadius - Gather.RingRadius + 0.5);
}

void swap2(inout float4 A, inout float4 B)
{
	float4 t = A;
	A = min(A,B);
	B = max(t,B);
}

float4 faux_median(in sampler sTex, in float2 uv, in float2 radius)
{
	static const float2 offsets[9] = {   
	float2( 0.5, 1.5), float2( 1.5,-0.5), float2(-0.5,-1.5),
    float2(-1.5, 0.5), float2( 2.5, 1.5), float2( 1.5,-2.5),
    float2(-2.5,-1.5), float2(-1.5, 2.5), float2(0.0, 0.0) };

    float4 values[9];

    for(int i = 0; i < 9; i++)
    	values[i] = tex2Dlod(sTex, float4(uv + offsets[i] * radius,0,0));

    //1st layer
 	swap2(values[1],values[2]);
 	swap2(values[0],values[1]);
 	swap2(values[4],values[5]);
 	swap2(values[3],values[4]);
 	swap2(values[7],values[8]);
 	swap2(values[6],values[7]);

 	//2nd layer
 	swap2(values[0],values[3]);
 	swap2(values[3],values[6]);
 	swap2(values[5],values[8]);
 	swap2(values[2],values[5]);

 	//3rd layer
 	swap2(values[4],values[7]);
 	swap2(values[1],values[4]);
 	swap2(values[4],values[7]);

 	//4th layer
 	swap2(values[2],values[4]);
 	swap2(values[2],values[6]);
 	swap2(values[4],values[6]);

 	return values[4];
}

/*=============================================================================
	Pixel Shaders
=============================================================================*/

void PS_Get_CoC(in VSOUT i, out float4 o : SV_Target0)
{
	float D = FOCUS_PLANE_DEPTH * depth2distmm; //focal plane depth in mm
	float Z = qUINT::linear_depth(i.uv) * depth2distmm;

	float coc = (1 - D / Z);

	coc *= coc > 0 ? BACKGROUND_BLUR * PERCENT_TO_DECIMAL : FOREGROUND_BLUR * PERCENT_TO_DECIMAL;	

	coc *= MAX_BLUR_RADIUS;
	coc = clamp(coc, -COC_CLAMP, COC_CLAMP);
	coc /= MAX_BLUR_RADIUS;

	o.a = (coc * 0.5 + 0.5);
	o.rgb = tex2D(qUINT::sBackBufferTex, i.uv).rgb;
}

void PS_Tile_CoC(in VSOUT i, out float2 o : SV_Target0)
{
	o = float2(1, 0);

	float2 srcsize = tex2Dsize(sHDR);

	for(int x = 0; x < TILE_SIZE; x++)
	for(int y = 0; y < TILE_SIZE; y++)
	{
		float t = tex2Dlod(sHDR, float4(i.vpos.x * TILE_SIZE + x, i.vpos.y * TILE_SIZE + y, 0, 0) / srcsize.xyxy).a;//tex2Dfetch(sHDR, int4(i.vpos.x * TILE_SIZE + x, i.vpos.y * TILE_SIZE + y, 0, 0)).a;
		o.x = min(o.x, t); o.y = max(o.y, t);
	}
}

void PS_Tile_Dilate(in VSOUT i, out float2 o : SV_Target0)
{
	o = float2(1, 0);

	float2 srcsize = tex2Dsize(sTileCoC);

	for(int x = -DILATE_SIZE; x <= DILATE_SIZE; x++)
	for(int y = -DILATE_SIZE; y <= DILATE_SIZE; y++)
	{
		float2 t = tex2Dlod(sTileCoC, float4(i.vpos.x + x, i.vpos.y + y, 0, 0)/srcsize.xyxy).xy;//tex2Dfetch(sTileCoC, int4(i.vpos.x + x, i.vpos.y + y, 0, 0)).xy;
		o.x = min(o.x, t.x); o.y = max(o.y, t.y);
	}
}

float2 get_location(in GatherParameters Gather, in VSOUT i, in float blade_step)
{
	float2 Location = lerp(Gather.VertexData.xy, Gather.VertexData.zw, blade_step / (Gather.RingId + 1.0));
	Location *= (1.0 - ROUNDNESS) + rsqrt(dot(Location, Location)) * ROUNDNESS;
	Location *= Gather.RingRadius * qUINT::PIXEL_SIZE;
	return Location;
}

void PS_ComputeForeground(in VSOUT i, out float4 o :SV_Target0)
{
	if(max(i.uv_scaled.x, i.uv_scaled.y) > 1.01) discard;

	float2 DilatedTileCoCData = tex2D(sDilatedTileCoCLinear, i.uv_scaled.xy).xy;
	float MaxCoCForeground = restore_coc_range(DilatedTileCoCData.x, i);
	float MinCoCForeground = restore_coc_range(DilatedTileCoCData.y, i);
	MaxCoCForeground = max(-MaxCoCForeground, 0);
	MinCoCForeground = max(-MinCoCForeground, 0);

	if(MaxCoCForeground == 0) discard;

	FAccumulator Foreground;	InitToZero(Foreground);

	GatherParameters Gather;
	Gather.KernelRadius 	= MaxCoCForeground;	
	Gather.VertexCount 		= VERTEX_COUNT;
	Gather.RingCount 		= ceil(0.5 + sqrt(MaxCoCForeground) * (QUALITY_BIAS + 30) * 2 * PERCENT_TO_DECIMAL);
	Gather.RingId 			= Gather.RingCount - 1;
	Gather.RingSampleCount 	= (Gather.RingId + 1) * Gather.VertexCount;
	Gather.VertexMatrix 	= i.vertexmat;
	Gather.VertexData   	= i.vertexdata; 
	Gather.bIsFirstRing		= 1;
	Gather.CoCRadiusError   = 1.0;
	Gather.IntersectFeather = Gather.RingCount / Gather.KernelRadius;

	GatherSample A, B, C;
	float num_samples = 0;

	[loop]for(; Gather.RingId >= 0; Gather.RingId--)
	{
		Gather.RingRadius = Gather.KernelRadius * (Gather.RingId + 1) * rcp(Gather.RingCount);

		[loop]for(float k = 0; k < Gather.VertexCount; k++)
		{
			[loop]for(float l = 0; l < Gather.RingId + 1; l++)
			{
					A.Location = get_location(Gather, i, l);

					A.Color = tex2Dlod(sHDR, float4(i.uv_scaled.xy + A.Location, 0, 0));
					A.CoCRadius = -restore_coc_range(A.Color.w, i);
					GAMMA_CORRECT_TAP(A.Color.rgb);
#if 1
						//branch specific stuff starting here
						B.Color = tex2Dlod(sHDR, float4(i.uv_scaled.xy - A.Location, 0, 0));
						B.CoCRadius = -restore_coc_range(B.Color.w, i);
						GAMMA_CORRECT_TAP(B.Color.rgb);

						B.CoCRadius = max(A.CoCRadius, B.CoCRadius);
						A.CoCRadius = B.CoCRadius;
						//ending here
#endif
					A.Intersection = ComputeIntersectionNear(Gather, A);
					A.Intersection *= rcp(max(A.CoCRadius * A.CoCRadius, SINGULARITY_FIX * SINGULARITY_FIX) * 3.1415927);

					Foreground.Color += A.Color.rgb * A.Intersection;
					Foreground.Weight += A.Intersection;
					num_samples++;
						//branch specific stuff starting here
#if 1
						B.Intersection = ComputeIntersectionNear(Gather, B);
						B.Intersection *= rcp(max(B.CoCRadius * B.CoCRadius, SINGULARITY_FIX * SINGULARITY_FIX) * 3.1415927);

						Foreground.Color += B.Color.rgb * B.Intersection;
						Foreground.Weight += B.Intersection;
						num_samples++;
#endif
						//ending here
			}
			Gather.VertexData.xy = Gather.VertexData.zw;
			Gather.VertexData.zw = Gather.VertexData.xx * Gather.VertexMatrix.xy 
									+ Gather.VertexData.yy * Gather.VertexMatrix.zw;
		}
	}
	Gather.RingRadius = 0;

	float4 Center = tex2D(sHDR, i.uv_scaled.xy);

	C.Color = Center;
	C.CoCRadius = -restore_coc_range(C.Color.w, i);
	GAMMA_CORRECT_TAP(C.Color.rgb);

	C.Intersection = ComputeIntersectionNear(Gather, C); 
	C.Intersection *= rcp(max(MaxCoCForeground * MaxCoCForeground, SINGULARITY_FIX * SINGULARITY_FIX) * 3.1415927);

	Foreground.Color += C.Color.rgb * C.Intersection;
	Foreground.Weight += C.Intersection;
	num_samples++;

	Foreground.Color /= Foreground.Weight;
	GAMMA_CORRECT_SUM(Foreground.Color.rgb);

	o.rgb = Foreground.Color;
	o.w = saturate(Foreground.Weight / num_samples * 3.1415927 * max(SINGULARITY_FIX * SINGULARITY_FIX, MaxCoCForeground * MaxCoCForeground)); 
}

void AccumulateSample(in GatherParameters Gather, inout FAccumulator Current, inout FAccumulator Previous, in GatherSample A)
{
	float bBelongsToPrevious = saturate(A.CoCRadius - Gather.BorderingRadius + 0.5);
	bBelongsToPrevious = smoothstep(0.0, 1.0, bBelongsToPrevious);
	bBelongsToPrevious = saturate(bBelongsToPrevious - Gather.bIsFirstRing); //"if Gather.bIsFirstRing bBelongsToPrevious = 0"
	float bBelongsToCurrent = 1.0 - bBelongsToPrevious;

	float CurrentWeight = A.Intersection * bBelongsToCurrent;
	float PreviousWeight = A.Intersection * bBelongsToPrevious;

	Current.Color += CurrentWeight * A.Color.rgb;
	Current.CoCRadius += CurrentWeight * A.CoCRadius;
	Current.Weight += CurrentWeight;

	Previous.Color += PreviousWeight * A.Color.rgb;
	Previous.CoCRadius += PreviousWeight * A.CoCRadius;
	Previous.Weight += PreviousWeight;

	float SampleTranslucency = saturate(A.CoCRadius - Gather.BorderingRadius);
	Current.Translucency += SampleTranslucency;
}

void MergeCurrentBucketIntoPreviousBucket(inout FAccumulator Current, inout FAccumulator Previous, float SampleCount)
{
	if(Current.Weight < 1e-6) return;

	float CurrentRingOpacity = saturate(1 - Current.Translucency * rcp(SampleCount));

	float PreviousCocRadius = Previous.CoCRadius * rcp(Previous.Weight);
	float CurrentCocRadius = Current.CoCRadius * rcp(Current.Weight);

	float bOccludingCoC = saturate(PreviousCocRadius - CurrentCocRadius);

	float PreviousBucketFactor = Previous.Weight == 0.0 ? 0.0 : (1.0 - CurrentRingOpacity * bOccludingCoC);

	Previous.Color = Previous.Color * PreviousBucketFactor + Current.Color;
	Previous.CoCRadius = Previous.CoCRadius * PreviousBucketFactor + Current.CoCRadius;
	Previous.Weight = Previous.Weight * PreviousBucketFactor + Current.Weight;
}

void DigestRing(in GatherParameters Gather, inout FAccumulator Current, inout FAccumulator Previous)
{
	if(Gather.bIsFirstRing)
	{
		Previous.Color 				= Current.Color;
		Previous.CoCRadius 			= Current.CoCRadius;
		Previous.Weight 			= Current.Weight;
	}
	else
	{
		MergeCurrentBucketIntoPreviousBucket(Current, Previous, Gather.RingSampleCount);
	}

	InitToZero(Current);
}

void AccumulateCenterSample(in GatherParameters Gather, inout FAccumulator Current, inout FAccumulator Previous, inout GatherSample A, in VSOUT i)
{
	Gather.BorderingRadius = (0.5 + Gather.CoCRadiusError) * Gather.KernelRadius * rcp(0.5 + Gather.RingCount);
	Gather.RingRadius = 0.5 / Gather.RingCount;

	A.Color = tex2D(sHDR, i.uv_scaled.xy);
	GAMMA_CORRECT_TAP(A.Color.rgb);
	A.CoCRadius = restore_coc_range(A.Color.w, i);
	A.Intersection = ComputeIntersectionFar(Gather, A);

	AccumulateSample(Gather, Current, Previous, A);
	MergeCurrentBucketIntoPreviousBucket(Current, Previous, 1.0);
}

void PS_ComputeBackground(in VSOUT i, out float4 o :SV_Target0)
{
	if(max(i.uv_scaled.x, i.uv_scaled.y) > 1.01) discard;

	float2 DilatedTileCoCData = tex2D(sDilatedTileCoC, i.uv_scaled.xy).xy;
	float MaxCoCBackground = restore_coc_range(DilatedTileCoCData.y, i);
	MaxCoCBackground = max(MaxCoCBackground, 0);

	if(MaxCoCBackground == 0) discard;

	FAccumulator Previous;	InitToZero(Previous);
	FAccumulator Current;	InitToZero(Current);

	GatherParameters Gather;
	Gather.KernelRadius 	= MaxCoCBackground;
	Gather.VertexCount 		= VERTEX_COUNT;
	Gather.RingCount 		= ceil(0.5 + sqrt(MaxCoCBackground) * (QUALITY_BIAS + 30) * 2 * PERCENT_TO_DECIMAL);
	Gather.RingId 			= Gather.RingCount - 1;
	Gather.RingSampleCount 	= (Gather.RingId + 1) * Gather.VertexCount;
	Gather.VertexMatrix 	= i.vertexmat;
	Gather.VertexData   	= i.vertexdata; 
	Gather.bIsFirstRing		= 1;
	Gather.CoCRadiusError   = 1.0;


	GatherSample A, B;

	[loop]for(; Gather.RingId >= 0; Gather.RingId--)
	{
		Gather.BorderingRadius = (Gather.RingId + 1.5 + Gather.CoCRadiusError) * (Gather.KernelRadius * rcp(0.5 + Gather.RingCount)); 
		Gather.RingSampleCount = Gather.VertexCount * Gather.RingId + Gather.VertexCount;
		Gather.RingRadius = Gather.KernelRadius * (Gather.RingId + 1) / Gather.RingCount;

		[loop]for(float k = 0; k < Gather.VertexCount; k++)
		{
			[loop]for(float l = 0; l < Gather.RingId + 1; l++)
			{
				A.Location = get_location(Gather, i, l);
				A.Color = tex2Dlod(sHDR, float4(i.uv_scaled.xy + A.Location, 0, 0));

				GAMMA_CORRECT_TAP(A.Color.rgb); 

				A.CoCRadius = restore_coc_range(A.Color.w, i);
				A.Intersection = ComputeIntersectionFar(Gather, A);
				AccumulateSample(Gather, Current, Previous, A);
			}
			Gather.VertexData.xy = Gather.VertexData.zw;
			Gather.VertexData.zw = Gather.VertexData.xx * Gather.VertexMatrix.xy 
			                     + Gather.VertexData.yy * Gather.VertexMatrix.zw; 
		}
		DigestRing(Gather, Current, Previous);
		Gather.bIsFirstRing = 0;
	}
	AccumulateCenterSample(Gather, Current, Previous, A, i);	

	Previous.Color.rgb /= Previous.Weight;
	GAMMA_CORRECT_SUM(Previous.Color.rgb);
	o.rgb = Previous.Color.rgb;
	o.w = 1;
}

void PS_Combine(in VSOUT i, out float4 o : SV_Target0)
{
	float4 Background = tex2D(qUINT::sBackBufferTex, i.uv_scaled.zw);
	float4 Foreground = tex2D(qUINT::sCommonTex1,    i.uv_scaled.zw);

	float4 Center     = tex2D(sHDR,    i.uv.xy);
	float CoCRadius = restore_coc_range(Center.w, i);

#if 1
	//doing scatter in full res for low radius only
	GatherParameters Gather;
	Gather.KernelRadius 	= abs(CoCRadius);
	Gather.VertexCount 		= VERTEX_COUNT;
	Gather.RingCount 		= 3; 
	Gather.RingId 			= Gather.RingCount - 1;
	Gather.RingSampleCount 	= (Gather.RingId + 1) * Gather.VertexCount;
	Gather.VertexMatrix 	= i.vertexmat;
	Gather.VertexData   	= i.vertexdata; 
	Gather.CoCRadiusError   = 1.0;

	FAccumulator NearOutOfFocus;	InitToZero(NearOutOfFocus);
	GatherSample A;

	//if(CoCRadius > -(FULL_TO_HALF_RES_THRESHOLD + FULL_TO_HALF_RES_PADDING))

	[loop]for(; Gather.RingId >= 0; Gather.RingId--)
	{
		Gather.RingRadius = Gather.KernelRadius * (Gather.RingId + 1) * rcp(Gather.RingCount);

		[loop]for(float k = 0; k < Gather.VertexCount; k++)
		{
			[loop]for(float l = 0; l < Gather.RingId + 1; l++)
			{
					A.Location = get_location(Gather, i, l);

					A.Color = tex2Dlod(sHDR, float4(i.uv.xy + A.Location, 0, 0));
					A.CoCRadius = abs(restore_coc_range(A.Color.w, i));
					GAMMA_CORRECT_TAP(A.Color.rgb);
					A.Intersection = ComputeIntersectionFar(Gather, A);

					NearOutOfFocus.Color += A.Color.rgb * A.Intersection;
					NearOutOfFocus.Weight += A.Intersection;

			}
			Gather.VertexData.xy = Gather.VertexData.zw;
			Gather.VertexData.zw = Gather.VertexData.xx * Gather.VertexMatrix.xy 
									+ Gather.VertexData.yy * Gather.VertexMatrix.zw;
		}
	}
	Gather.RingRadius = 0;

	A.Color = Center;
	A.CoCRadius = abs(CoCRadius);
	GAMMA_CORRECT_TAP(A.Color.rgb);
	A.Intersection = ComputeIntersectionFar(Gather, A);
	
	NearOutOfFocus.Color += A.Color.rgb * A.Intersection;
	NearOutOfFocus.Weight += A.Intersection;
	
	NearOutOfFocus.Color.rgb /= NearOutOfFocus.Weight;
	GAMMA_CORRECT_SUM(NearOutOfFocus.Color.rgb);
#endif
	//Background = faux_median(qUINT::sBackBufferTex, i.uv_scaled.zw, RENDER_SCALE * qUINT::PIXEL_SIZE * tempF1.z * saturate(CoCRadius * 0.1));
	//Foreground = faux_median(qUINT::sCommonTex1,    i.uv_scaled.zw, RENDER_SCALE * qUINT::PIXEL_SIZE * tempF1.z * saturate(-CoCRadius * 0.25));

	float BackgroundAlpha = saturate(CoCRadius);

	float4 Combined = lerp(Center.rgbb,   Background, BackgroundAlpha);
		   Combined = lerp(Combined, Foreground, Foreground.a);

	o = Combined;
	o.w = max(BackgroundAlpha, Foreground.a);

	float fg = CoCRadius < -(FULL_TO_HALF_RES_THRESHOLD - FULL_TO_HALF_RES_PADDING);
	o.w = fg - Foreground.a;
	o.w *= saturate(-CoCRadius -(FULL_TO_HALF_RES_THRESHOLD - FULL_TO_HALF_RES_PADDING) * 2);
}

void PS_PostFilter(in VSOUT i, out float4 o : SV_Target0)
{
	float4 color = tex2D(qUINT::sBackBufferTex, i.uv.xy);

	float needs_holefill = color.w;
	float CoCRadius = restore_coc_range(tex2D(sHDR, i.uv.xy).w, i);

	if(needs_holefill)	
	{
		float depth = qUINT::linear_depth(i.uv);
		float4 holefill = 0;

		for(int x = -2; x <=2; x++)
		for(int y = -2; y <=2; y++)
		{
			float4 tap = tex2D(qUINT::sBackBufferTex, i.uv.xy + float2(x,y) * qUINT::ASPECT_RATIO * sqrt(abs(CoCRadius)) * 0.00015 * tempF1.z);
			holefill += float4(tap.rgb, 1) * saturate(1 - tap.w);
		}

		holefill.rgb /= holefill.w + 0.00001;
		color.rgb = lerp(color.rgb, holefill.rgb, saturate(needs_holefill * holefill.w * 0.25));
	}

	o = color;

	//o = tex2D(sDilatedTileCoC, i.uv.xy).y*2-1;
	//o = -o;
}

/*=============================================================================
	Techniques
=============================================================================*/

technique PhysicalDOF
{
    pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_Get_CoC;
		RenderTarget = HDR;
	}
	pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_Tile_CoC;
		RenderTarget = TileCoC;
	}
	pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_Tile_Dilate;
		RenderTarget = DilatedTileCoC;
	}
	pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_ComputeForeground;
		RenderTarget = qUINT::CommonTex1;
	}
	pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_ComputeBackground;
	}
	pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_Combine;
	}
	/*pass
	{
		VertexShader = VS_DOF;
		PixelShader  = PS_PostFilter;
	}*/
}