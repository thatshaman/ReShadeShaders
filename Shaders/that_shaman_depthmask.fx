/**
 * Depth mask shader optimized for Guild Wars 2 by @that_shaman
 */

#include "ReShade.fxh"

uniform float Near <
	ui_type = "drag";
	ui_min = -RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 0.1;
	ui_label = "Near Plane";
	ui_tooltip = "Depth cutoff near the camera";
> = 0;

uniform float Far <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 0.1;
	ui_label = "Far Plane";
	ui_tooltip = "Depth cutoff away from the camera";
> = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;


uniform bool Visualize <
	ui_tooltip = "Visualize the depth";
> = false;

uniform bool Invert <
	ui_tooltip = "Invert the mask";
> = false;


float GetDepth(float2 texcoord, float near, float far)
{
#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
		texcoord.y = 1 - texcoord.y;
#endif
	
	float depth = ReShade::GetLinearizedDepth(texcoord);

#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
	const float C = 0.01;
	depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif

#if RESHADE_DEPTH_INPUT_IS_REVERSED
	depth = 1.0 - depth;
#endif

	float max = (1 / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE) * far;
	float min = (1 / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE) * near;
	if (min > max) min = max - 0.0001;

	return clamp((depth - min) / (max - min), 0, 1);
}

float3 PS_Depthmask(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
	float depth = GetDepth(texcoord, Near, Far);

	if (Visualize) {
		float3 retval = tex2D(ReShade::BackBuffer, texcoord).rgb;
		if (depth >= 1) {
			retval.r += 0.5;
		}
		else if (depth <= 0) {
			retval.g += 0.5;
		}
		else if (depth > 0.995 || depth < 0.005) {
			retval.r += 0.5;
			retval.b += 0.5;
		}

		return retval;

	}
	else if(Invert)
	{
		return float3(1,1,1) - float3(depth, depth, depth);
	}
	else
	{
		return float3(depth, depth, depth);
	}

}

technique that_shaman_depthmask
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Depthmask;
	}
}