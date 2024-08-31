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
	ui_label = "Method";
    ui_type = "combo";
    ui_items = "Never\0Normal\0Depth\0Depth + Normal\0";
    ui_category = "Flat Surfaces";
> = 3;

uniform float SamplePoint <
	ui_label = "Depth Sample Point";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 1;
    ui_step = 0.001;
	ui_tooltip = "";
    ui_category = "Flat Surfaces";
> = 0.95;


uniform float2 NormalIterations <
	ui_label = "Normal Sample Count";
	ui_type = "slider";
	ui_min = 1;
	ui_max = 8;
    ui_step = 1;
	ui_tooltip = "Higher values increases precision but at creates a border and decreases performance";
    ui_category = "Flat Surfaces";
> = float2(2,2);

uniform bool ShowSamplePoint <
	ui_label = "Show Sample Point";
    ui_category = "Flat Surfaces";
> = false;

uniform bool Debug <
	ui_label = "Show Debug Output";
    ui_category = "Debug";
> = false;



float GetDepth(float2 texcoord, float near, float far)
{
    float depth = ReShade::GetLinearizedDepth(texcoord);
    float max = (1 / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE) * far;
    float min = (1 / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE) * near;
    if (min > max)
    {
        min = max - 0.0001;
    }
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

static bool huh = false;

float3 PS_Chromakey(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
    
    if (ShowSamplePoint)
    {
        if (texcoord.x > SamplePoint - 0.005 && texcoord.x < SamplePoint + 0.005)
        {
            
            if (Debug)
            {
                return float3(1, 0, 0);
            }
            else
            {
                return float3(1, 1, 1) - Color;
            }
            
        }
    }
    
    float depth = GetDepth(texcoord, Near, Far);
    if (depth <= 0 || depth >= 1)
    {
        if (Debug)
        {
            return 0;
        }
        else
        {
            return Color;
        }
    }
    else if (RemoveFlatSurfaces == 0)
    {
        return tex2D(ReShade::BackBuffer, texcoord).rgb;
        
    }
    
    float depthFloor = GetDepth(float2(SamplePoint, texcoord.y), Near, Far);
    if (depthFloor <= 0 || depthFloor >= 1)
    {
        if (Debug)
        {
            return float3(1, 0, 0);
        }
        else
        {
            return tex2D(ReShade::BackBuffer, texcoord).rgb;
        }
    }
    
    if (depthFloor - depth > 0.005 && (RemoveFlatSurfaces == 2 || RemoveFlatSurfaces == 3))
    {
        if (Debug)
        {
            return float3(1, 1, 0);
        }
        else
        {
            return tex2D(ReShade::BackBuffer, texcoord).rgb;
        }
    }
        
    /////////
    
    float3 normalFloor = ScreenSpaceNormal(float2(SamplePoint, texcoord.y));
    float3 normalScreen;//    ScreenSpaceNormal(texcoord);
    
    if (RemoveFlatSurfaces == 2)
    {
        if (Debug)
        {
            return 0.5;
        }
        else
        {
            return Color;
        }
    }
    else
    {
        float2 offset = float2(0, 0);
    
        int left = NormalIterations[0] / 2;
        int top = NormalIterations[1] / 2;
    
        for (int y = 0; y < NormalIterations[1]; y++)
        {
            offset.y = (y - top) * ReShade::PixelSize.y;
            for (int x = 0; x < NormalIterations[0]; x++)
            {
                offset.x = (x - left) * ReShade::PixelSize.x;
                normalScreen += ScreenSpaceNormal(texcoord + offset);
            }
        }
    
        normalScreen /= NormalIterations[0] * NormalIterations[1];
    
        float3 normalDif = normalFloor - normalScreen;
        if (normalDif.r < 0.04 && normalDif.g < 0.04 && normalDif.b < 0.04)
        {
            if (Debug)
            {
                return 0.5;
            }
            else
            {
                return Color;
            }
        }
        else
        {
            if (Debug)
            {
                return float3(0, 1, 1);
            }
            else
            {
                return tex2D(ReShade::BackBuffer, texcoord).rgb;
            }
        
        }
    }
}

technique that_shaman_chromakey
{
    pass OutputPass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Chromakey;
    }
}