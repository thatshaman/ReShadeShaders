/**
 * 2 bits per pixel shader by @that_shaman
 */


#include "ReShade.fxh"

uniform int Palette <
	ui_label = "Color Preset";
ui_type = "combo";
ui_items = "Custom\0CGA 0\0CGA 1\0GB\0Grayscale\0Green phosphor\0Orange phosphor\0Vapor\0";
> = 0;

uniform float3 Color0 <
	ui_label = "Color 75% - 100%";
ui_type = "color";
> = float3(1, 1, 1);

uniform float3 Color1 <
	ui_label = "Color 50% - 75%";
ui_type = "color";
> = float3(0, 1, 1);

uniform float3 Color2 <
	ui_label = "Color 25% - 50%";
ui_type = "color";
> = float3(1, 0, 1);

uniform float3 Color3 <
	ui_label = "Color 0% - 25%";
ui_type = "color";
> = float3(0, 0, 0);

uniform int2 Scale <
	ui_label = "Pixel Scale";
ui_type = "slider";
ui_min = 1;
ui_max = 8;
> = int2 (2, 2);

uniform bool dither <
	ui_label = "Dither";
> = true;

uniform bool usedepth <
	ui_label = "Increase depth contrast";
> = true;


static const float3 presets[28] = {
	float3(1, 1, 1), float3(0, 1, 1), float3(1, 0, 1), float3(0, 0, 0) , // CGA 0
	float3(1, 1, 0), float3(0, 1, 0), float3(1, 0, 0), float3(0, 0, 0), // CGA 1
	float3(0.878, 0.972, 0.815), float3(0.533, 0.752, 0.439), float3(0.203, 0.407, 0.337), float3(0.031, 0.094, 0.125), // GB
	float3(1, 1, 1), float3(0.666, 0.666, 0.666), float3(0.333, 0.333, 0.333), float3(0, 0, 0), // Black and white
	float3(0.771, 1, 0.224), float3(0.467, 0.754, 0), float3(0.293, 0.509, 0), float3(0.046, 0.075, 0), // Green
	float3(1, 0.771, 0.224), float3(0.754,0.467,0), float3(0.509, 0.293, 0), float3(0.075, 0.046, 0), // Orange
	float3(0.976, 0.674, 0.325), float3(0.964, 0.180, 0.592), float3(0.580, 0.086, 0.498), float3(0.011, 0.105, 0.313) // Vapor
};


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


float3 getColorValue(float2 texcoord, float x, float y) {

	float3 pixel = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float grayscale = (pixel.r * 0.2126) + (pixel.g * 0.8) + (pixel.b * 0.0722);

	if (usedepth) {
		grayscale += GetDepth(texcoord, 0, RESHADE_DEPTH_LINEARIZATION_FAR_PLANE / 4);
	}


	float3 pal[4] = { float3(1,1,1), float3(0.666,0.666,0.666), float3(0.333,0.333,0.333), float3(0, 0, 0) };

	if (Palette > 0) {
		int index = (Palette - 1) * 4;
		pal = { presets[index], presets[index + 1], presets[index + 2],presets[index + 3] };
	}
	else {
		pal = { Color0 , Color1, Color2, Color3 };
	}

	if (dither) {
		bool odd = false;

		if (y % (Scale.y * 2) == 0) {
			if (x % (Scale.x * 2) == 0) {
				grayscale += 0.125;
			}
		}
		else {
			if ((x + Scale.x) % (Scale.x * 2) == 0) {
				grayscale += 0.125;
			}
		}
	}

	int index = clamp(floor((1 - grayscale) * 4), 0, 4);
	float3 retval = pal[index];


	return retval;

}

float3 PS_2bpp(float4 vpos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
	float2 pixels = 1.0 / ReShade::ScreenSize;

	float screenX = texcoord.x / pixels.x;
	float x = (screenX - (screenX % pow(2, Scale.x - 1)));

	float screenY = texcoord.y / pixels.y;
	float y = (screenY - (screenY % pow(2, Scale.y - 1)));

	return getColorValue(float2(x * pixels.x, y * pixels.y), x, y);

}

technique that_shaman_2bpp
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_2bpp;
	}
}