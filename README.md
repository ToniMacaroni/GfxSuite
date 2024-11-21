# GfxSuite ( [Discord Discussion](https://discord.com/channels/710082165253079061/1292527375028064276) | [Forum Discussion](https://www.beamng.com/threads/gfx-suite-graphics-utility-skybox-manager-more.100512/) )
A mod that aims to change various parts of the graphics pipeline in the game and also gives players more control over not only the final look but all sorts of settings.

It's my first mod, so if there are any issues please let me know ^^.
I am pretty sure you will run into issues when using other graphic mods at the same time (I haven't tried out this theory yet).

The mod has some very opinionated defaults and is definitely more tailored towards higher end PCs, but you are free to change anything around to your preference. I'm also very open to any sort of suggestion.

**By default you can toggle the window with the `=` key**

## Tonemapping (Changed games ACES tonemapper to Uchimura)
- Uchimura parameters with artist friendly names

## Custom Color Correction after tonemapping
- LUT
- Hue
- Saturation
- Exposure

## Custom Post-Processing
- Chromatic Aberration
- Highpass sharpen

## Game Settings
Many controls for various existing graphic settings (also many that are not exposed via the interface)
- SSAO samples, radius and contrast
- Shadow quality and softness 
- Terrain and object LOD adjustment
- Foliage density
- Time
- Sun direction (azimuth override)
- Light brightness
- Sky brightness
- Sun scale
- Fog
- Camera FOV
- Couple of light ray settings
- Bloom threshold and knee

## Skybox Manager
- Change loaded skyboxes via a dropdown menu
- Reload the selected skybox with a button click
- Load in your own skybox (create skyboxes either manually or via python utility)
- Toggle between the game's procedural skybox and custom one via checkbox

## Profiles
All of the above can be saved into profiles


## Todo
Some things I already know I want to add
- Contact Shadows
- Subsurface Scattering (although low SSAO samples and soft shadow already softens the foliage)
- Custom rendering of the Skybox that allows for color correction of the HDRI and other stuff


## Python script for converting HDRIs
In `art/custom_skies/` ([or here](https://github.com/ToniMacaroni/GfxSuite/tree/main/art/custom_skies)) you will find a python script (and a bat file) that will allow you to convert hdri's to cubemaps used by BeamNG (it's also able to tonemap .hdr files into ldr, but you will need to tweak the values in the script yourself). To run the script you need python installed and "opencv-python", "pillow" and "numpy" installed via pip. Using the script is as simple as dragging the .png or .hdr file onto the bat and. The script will then place the output files in a new folder with the same name as the input file. Move this folder into "%localappdata%/BeamNG.drive/latest/settings/gfxSuite/skies" (create the folders if they don't exist)

## Screenshots & Previews
To state the obvious, all of the screenshots are unedited and made in normal gameplay (not in photo mode)  
[PREVIEW VIDEO](http://www.youtube.com/watch?v=KGs69jbgEbU)

<img src="https://i.ibb.co/5Fmp3Zz/Sd-Hy-Yyz-Ow-B.png" width="250"/>
<img src="https://i.ibb.co/R0CNYL2/EP4y-Z1g-ZXr.png" width="250"/>
<img src="https://i.ibb.co/yyLzvNV/nk-Lvm3y4r-T.jpg" width="250"/>
<img src="https://i.ibb.co/Xstbjd2/PHd9l-Bq-Jm-G.png" width="250"/>
<img src="https://i.ibb.co/NC5D7ZZ/PV4-Ivs3k9-L.jpg" width="250"/>
<img src="https://i.ibb.co/z43RLGM/Ep86-JTQmg-J.jpg" width="250"/>
<img src="https://i.ibb.co/Pm3VjmG/hk-GGAAs1-QT.png" width="250"/>

## Credits
Highpass Sharpen https://github.com/Adolon/FFXI-ReShade/blob/master/reshade-shaders/Shaders/HighPassSharpen.fx  
Uchimura https://github.com/dmnsgn/glsl-tone-map/blob/main/uchimura.glsl  
### Included HDRIs
https://polyhaven.com/a/sunflowers_puresky  
https://polyhaven.com/a/farm_field_puresky  
https://polyhaven.com/a/mud_road_puresky  
https://polyhaven.com/a/table_mountain_1_puresky
