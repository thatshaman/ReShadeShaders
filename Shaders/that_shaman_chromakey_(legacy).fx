/**
* Chroma key shader optimized for Guild Wars 2 by @that_shaman
*
* Works best with the following preprocessor definitions:
*
*   RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN          0
*   RESHADE_DEPTH_INPUT_IS_REVERSED             0
*   RESHADE_DEPTH_INPUT_IS_LOGARITHMIC          0
*
*/

#include "ReShade.fxh"

uniform float3 Color <
	ui_label = "Key Color";
	ui_tooltip = "Color used for the chroma cutout.";
	ui_type = "color";
> = float3(0, 1, 0);

uniform float Near <
	ui_type = "drag";
	ui_min = -RESHADE_DEPTH_LINEARIZATION_FAR_PLANE; 
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 0.10;
	ui_label = "Near Plane";
	ui_tooltip = "Depth cutoff near the camera";
> = 0;

uniform float Far <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	ui_step = 0.10;
	ui_label = "Far Plane";
	ui_tooltip = "Depth cutoff away from the camera";
> = 15.0;

uniform int RemoveFlatSurfaces <
    ui_tooltip = "Tries to remove flat surfaces";
	ui_label = "Remove Flat Surfaces";
    ui_type = "combo";
    ui_items = "Never\0Automatic\0Manual\0";
> = 1;


uniform float2 AutoDetectSamplePoint <
    ui_min = 0.0;
    ui_max = 1.0; 
	ui_type = "drag";
	ui_label = "Sample Point";
    ui_category = "Flat Surfaces (Automatic)";
> = float2(0.8f, 0.8f);

uniform bool ShowSamplePoint <
	ui_label = "Show Sample Point";
    ui_category = "Flat Surfaces (Automatic)";
> = false;


uniform float3 FlatSurfaceUp <
	ui_label = "Normal Direction";
	ui_type = "color";
    ui_category = "Flat Surfaces (Manual)";
> = float3( 0.51, 0.7, 0.51);


uniform float2 FlatSurfaceIterations <
	ui_label = "Sample Count";
	ui_type = "slider";
	ui_min = 1;
	ui_max = 16;
    ui_step = 1;
	ui_tooltip = "Higher values increases precision but at creates a border and decreases performance";
    ui_category = "Flat Surfaces (Advanced)";
> = float2(2,2);

uniform float FlatSurfaceScreenCutoff <
	ui_label = "Screen Cutoff";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_tooltip = "Vertical cutoff position for the surface removal function\n(0 = full screen. 0.5 = bottom half, 1 = bottom of the screen)";
    ui_category = "Flat Surfaces (Advanced)";
> = float(0);

uniform bool ShowDebug <
	ui_label = "Show Debug Output";
    ui_category = "Debug";
> = false;

static float3 DynamicFlatSurfaceNormal = float3(1, 1, 1);

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
    if (min > max)
        min = max - 0.0001;

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
    
    // Return if skybox or beyond near / far plane
    if (depth == 0 || depth == 1)
    {
        if (ShowDebug)
        {
            return float3(1, 0, 0);
        }
        
        return Color;
    }
    else if (RemoveFlatSurfaces > 0 && texcoord.y > FlatSurfaceScreenCutoff)
    {
        // Show a pink targeting rectangle if ShowSamplePoint is enabled 
        if (ShowSamplePoint && abs(texcoord.y - AutoDetectSamplePoint.y) < ReShade::PixelSize.y * 8 && abs(texcoord.x - AutoDetectSamplePoint.x) < ReShade::PixelSize.x * 8)
        {
            return float3(1, 1, 1) - Color;
        }
        
        
        // Clip pixels at the bottom of the screen to compensate for vertical FlatSurfaceIterations
        if (texcoord.y > 1 - (FlatSurfaceIterations.y * ReShade::PixelSize.y))
        {
            if (ShowDebug)
            {
                return float3(1,1,1);
            }
            return Color;
        }
        else
        {
            // Find normal at AutoDetectSamplePoint
            if (RemoveFlatSurfaces == 1)
            {
                // TODO: Optimize this by sampling only once per frame
                DynamicFlatSurfaceNormal = ScreenSpaceNormal(AutoDetectSamplePoint);
            }
        
            // Calculate multisampled normal
            float3 normal = float3(0, 0, 0);
            for (int y = 0; y < FlatSurfaceIterations.y; y++)
            {
                float offsetY = -(ReShade::PixelSize.y * FlatSurfaceIterations.y / 2) + (ReShade::PixelSize.y * y);
                for (int x = 0; x < FlatSurfaceIterations.x; x++)
                {
                    float offsetX = -(ReShade::PixelSize.x * FlatSurfaceIterations.x / 2) + (ReShade::PixelSize.x * x);
                    normal += ScreenSpaceNormal(float2(texcoord.x - offsetX, texcoord.y - offsetY));
                }
            }
            normal /= (FlatSurfaceIterations.x * FlatSurfaceIterations.y);
            
            // Automatic surface removal
            if (RemoveFlatSurfaces == 1 && abs(normal.x - DynamicFlatSurfaceNormal.x) < 0.01f && abs(normal.y - DynamicFlatSurfaceNormal.y) < 0.02f && abs(normal.z - DynamicFlatSurfaceNormal.z) < 0.04f)
            {
                if (ShowDebug)
                {
                    return float3(0, 0, 1);
                }
                return Color;
            }
            // Manual surface removal
            else if (RemoveFlatSurfaces == 2 && normal.r < FlatSurfaceUp.r && normal.g > FlatSurfaceUp.g && normal.b < FlatSurfaceUp.b)
            {
                if (ShowDebug)
                {
                    return float3(0, 1, 1);
                }
                return Color;
            }
            else
            {
                if (ShowDebug)
                {
                    return float3(1, 1, 0);
                }
                return tex2D(ReShade::BackBuffer, texcoord).rgb;
            }
        }
    }
    else
    {
        if (ShowDebug)
        {
            return float3(0, 0, 1);
        }
        return tex2D(ReShade::BackBuffer, texcoord).rgb;
    }

}

technique that_shaman_chromakey_legacy
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Chromakey;
    }
}