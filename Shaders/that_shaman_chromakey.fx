/**
 * Chroma key shader optimized for Guild Wars 2 by @that_shaman
 */

#include "ReShade.fxh"

uniform float3 Color <
	ui_label = "Chroma Key Color";
	ui_tooltip = "Color used for the chroma cutout.";
	ui_type = "color";
> = float3(0, 1, 0);

uniform float Near <
	ui_type = "drag";
	ui_min = -RESHADE_DEPTH_LINEARIZATION_FAR_PLANE; 
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 1.0;
	ui_label = "Near Plane";
	ui_tooltip = "Depth cutoff near the camera";
> = 0;

uniform float Far <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 1.0;
	ui_label = "Far Plane";
	ui_tooltip = "Depth cutoff away from the camera";
> = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;

uniform bool RemoveFlatSurfaces <
	ui_label = "Remove Flat Surfaces (Experimental)";
	ui_tooltip = "Tries to remove flat surfaces";
> = false;

uniform float3 FlatSurfaceUp <
	ui_label = "Flat Surface Normal";
	ui_type = "color";
> = float3( 0.51, 0.7, 0.51);

uniform int FlatSurfaceIterations <
	ui_label = "Flat Surface Sample Count";
	ui_type = "slider";
	ui_min = 1;
	ui_max = 16;
> = int(4);

uniform float FlatSurfaceScreenCutoff <
	ui_label = "Flat Surface Vertical Screen Cutoff";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = float(0.5);

uniform bool ShowDebug <
	ui_label = "Show Debug Output";
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

float3 ScreenSpaceNormal(float2 texcoord)
{
	float3 offset = float3(ReShade::PixelSize.x, ReShade::PixelSize.y, 0);
	float3 center = float3(texcoord.xy - 0.5, 1) * ReShade::GetLinearizedDepth(texcoord.xy);
	float3 top = float3((texcoord.xy - offset.zy) - 0.5, 1) * ReShade::GetLinearizedDepth((texcoord.xy - offset.zy));
	float3 right = float3((texcoord.xy + offset.xz) - 0.5, 1) * ReShade::GetLinearizedDepth((texcoord.xy + offset.xz));

	return normalize(cross(center - top, center - right)) * 0.5 + 0.5;
}

float3 PS_Chromakey(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
	float depth = GetDepth(texcoord, Near, Far);

	if (depth == 0 || depth == 1) {
		if (ShowDebug) return float3(1, 0, 0);
		return Color;
	}
	else if (RemoveFlatSurfaces && texcoord.y > FlatSurfaceScreenCutoff)
	{
		float3 normal = float3(0, 0, 0);

		if (texcoord.y > 1 - (FlatSurfaceIterations * ReShade::PixelSize.y)) {
			if (ShowDebug) return float3(0, 1, 0);
			return Color;
		}
		else {

			for (int y = 0; y < FlatSurfaceIterations; y++)
			{
				float offset = -(ReShade::PixelSize.y * FlatSurfaceIterations / 2) + (ReShade::PixelSize.y * y);
				normal += ScreenSpaceNormal(float2(texcoord.x, texcoord.y - offset));
			}

			normal /= FlatSurfaceIterations;

			if (normal.r < FlatSurfaceUp.r && normal.g > FlatSurfaceUp.g && normal.b < FlatSurfaceUp.b) {
				if (ShowDebug) return float3(0, 1, 0);
				return Color;
			}
			else 
			{
				if (ShowDebug) return float3(0, 0, 1);
				return tex2D(ReShade::BackBuffer, texcoord).rgb;
			}
		}		
	}
	else 
	{
		if (ShowDebug) return float3(0, 0, 1);
		return tex2D(ReShade::BackBuffer, texcoord).rgb;
	}
}

technique that_shaman_chromakey
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Chromakey;
	}
}