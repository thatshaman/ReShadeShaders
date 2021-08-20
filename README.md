# that_shaman's ReShade Shaders

Some ReShade shaders I've put together. These will work on any ReShade based application that has its depth buffer unlocked.

## Usage

Place the .fx files in your shader folder and activate them in your ReShade based application of choice.

|Name|Usage|
|--|--| 
|that_shaman_2bpp.fx|Two bits per pixel effect (CGA, Game Boy, Monochrome)|
|that_shaman_2bpp_gw2hook.fx|Two bits per pixel effect (gw2hook compatible)|
|that_shaman_chromakey.fx|Generates a green screen effect using the depth buffer and tries to cull out flat surfaces|
|that_shaman_depthmask.fx|Display the depth mask|
|that_shaman_multirender|Render 4 outputs to your screen: unprocessed + screen space normals + 2x depth map|