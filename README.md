# that_shaman's ReShade Shaders

Some ReShade shaders I've put together. These will work on any ReShade based application that has its depth buffer unlocked (full add-on support)

## Usage

Place the .fx files in your shader folder and activate them in your ReShade based application of choice.

## Preprocessor Definitions

These shaders require the following `Preprocessor Definitions` to be set:

`RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0`

`RESHADE_DEPTH_INPUT_IS_REVERSED=0`

`RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0`

# Shaders

|Name|Usage|
|--|--| 
|that_shaman_2bpp.fx|Two bits per pixel effect (CGA, Game Boy, Monochrome)|
|that_shaman_chromakey.fx|Generates a green screen effect using the depth buffer and tries to cull out flat surfaces|
|that_shaman_chromakey_legacy.fx|Previous version of that_shaman_chromakey.fx|
|that_shaman_depthmask.fx|Display the depth mask|
|that_shaman_multirender|Render 4 outputs to your screen: unprocessed + screen space normals + 2x depth map|
