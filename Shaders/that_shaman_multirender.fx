/**
 * Multiple output render shader by @that_shaman
 */

#include "ReShade.fxh"

uniform float Bottom_Left_Near <
	ui_type = "drag";
	ui_step = 0.1;
	ui_min = -RESHADE_DEPTH_LINEARIZATION_FAR_PLANE; ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_label = "Bottom Left Near Plane";
	ui_tooltip = "Depth cutoff near the camera";
> = 0;

uniform float Bottom_Left_Far <
	ui_type = "drag";
	ui_step = 0.1;
	ui_min = 0; ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_label = "Bottom Left Far Plane";
	ui_tooltip = "Depth cutoff away from the camera";
> = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;

uniform float Bottom_Right_Near <
	ui_type = "drag";
	ui_step = 0.1;
	ui_min = -RESHADE_DEPTH_LINEARIZATION_FAR_PLANE; ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_label = "Bottom Right Near Plane";
	ui_tooltip = "Depth cutoff near the camera";
> = 0;

uniform float Bottom_Right_Far <
	ui_type = "drag";
	ui_step = 0.1;
	ui_min = 0; ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_label = "Bottom Right Far Plane";
	ui_tooltip = "Depth cutoff away from the camera";
> = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;


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


float3 ScreenSpaceNormal(float2 texcoord)
{
	float3 offset = float3(ReShade::PixelSize.x, ReShade::PixelSize.y, 0);
	float3 center = float3(texcoord.xy - 0.5, 1) * ReShade::GetLinearizedDepth(texcoord.xy);
	float3 top = float3((texcoord.xy - offset.zy) - 0.5, 1) * ReShade::GetLinearizedDepth((texcoord.xy - offset.zy));
	float3 right = float3((texcoord.xy + offset.xz) - 0.5, 1) * ReShade::GetLinearizedDepth((texcoord.xy + offset.xz));

	return normalize(cross(center - top, center - right)) * 0.5 + 0.5;
}

float3 PS_Multirender(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
	float2 texcoordHalf = float2(texcoord.x, texcoord.y) * 2;
	float3 retval = float3(0, 0, 0);
	float3 one = float3(1, 1, 1);

	if (texcoord.x < 0.5 && texcoord.y < 0.5)
	{
		retval = tex2D(ReShade::BackBuffer, texcoordHalf).rgb;
	}
	else if (texcoord.x > 0.5 && texcoord.y < 0.5)
	{
		texcoordHalf.x -= 1;
		retval = ScreenSpaceNormal(texcoordHalf);
	}
	else if (texcoord.x < 0.5 && texcoord.y > 0.5)
	{
		texcoordHalf.y -= 1;

		float depth = GetDepth(texcoordHalf, Bottom_Left_Near, Bottom_Left_Far);
		retval = float3(depth, depth, depth);
	}
	else if (texcoord.x > 0.5 && texcoord.y > 0.5)
	{
		texcoordHalf.y -= 1;
		texcoordHalf.x -= 1;

		float depth = GetDepth(texcoordHalf, Bottom_Right_Near, Bottom_Right_Far);
		retval = float3(depth, depth, depth);
	}

	return retval;
}

technique that_shaman_multirender
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Multirender;
	}
}