/*=============================================================================

    Copyright (c) Pascal Gilcher. All rights reserved.

 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 
=============================================================================*/

#pragma once 

//Functions and primitives required to trace/march rays in screen space
//against the depth buffer.

/*===========================================================================*/

namespace RayTracing
{

struct Ray 
{
    float3 pos;
    float3 dir;
    float2 uv;
    float currlen;
    float maxlen;
    float steplen;
    float width; //faux cone tracing
};

bool compute_intersection(inout Ray ray, in RTConstants rtconstants, in VSOUT i)
{
	bool intersected = 0;
	bool inside_screen = 1;

	while(ray.currlen < ray.maxlen && inside_screen)
    {   
    	float lambda = ray.currlen / ray.maxlen;    
    	lambda = 0.25 * lambda * (0.5 + lambda * (5 * lambda - 1.5)); //fitted ray length growth

       	ray.pos = rtconstants.pos + ray.dir * lambda * ray.maxlen;

        ray.uv = Projection::proj_to_uv(ray.pos);
        inside_screen = all(saturate(-ray.uv * ray.uv + ray.uv));
        ray.width = clamp(log2(length((ray.uv - i.uv_scaled.xy) * qUINT::SCREEN_SIZE)) - 4.0, 0, MIP_AMT);

        float3 pos = Projection::uv_to_proj(ray.uv, sZTex, ray.width);

        float3 delta = pos - ray.pos;

		[branch]
        if(delta.z < 0 && delta.z > -ray.maxlen * RT_Z_THICKNESS * RT_Z_THICKNESS)
        {   
        	float lambda = ray.currlen / ray.maxlen;             
            intersected = inside_screen;
            ray.currlen = 10000;

            if(RT_HIGHP_LIGHT_SPREAD)
            	ray.dir = normalize(pos - rtconstants.pos);
        }
      
        ray.currlen += ray.steplen;
    }

    return intersected;
}

} //namespace