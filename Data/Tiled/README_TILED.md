# !!! Before reading this file !!!

To read this file the intended way, open this file using Visual Studio Code (VSCode) and type CTRL+K, then V. It will open the preview of this file.

Enjoy your reading!

# Preface

Hello maker!

If you're reading this, then congratulations, you're curious enough to open a README, and you'll learn a lot from this file!

This README will teach you every tip & trick there is to know to handle Tiled and use it in the Pokémon Studio and PokémonSDK workflow!
It will also list some of the errors you SHOULDN'T do, unless you want to have to create a #support ticket on the Discord
server. No one wants to have to open #support ticket, so make sure to read this README and remember its content!

Tiled might look daunting at first glance, but it's insanely more powerful than RPG Maker XP. Tiled is also well documented.
Here are a few links you should review first, as this README won't go in depth about how to use Tiled:
- [ EN ] Tiled's manual in French: https://doc.mapeditor.org/fr/stable/
- [ FR ] Tiled's manual in French: https://doc.mapeditor.org/fr/stable/
- [ EN ] Invatorzen's Tiled tutorial: https://www.youtube.com/watch?v=5A8gjBRGAAI
- [ FR ] SirLinfey's Tiled tutorial: https://www.youtube.com/watch?v=0WnjTuulYMY

# Tips and tricks

This section will handle tips, tricks, and things to know about Tiled and its use in the Studio/SDK workflow, and give you useful information
about parts of the process.

## About the Technical Demo maps
As stated in the [project's README](../../README.md), which I absolutely invite you to read, it is advised you keep the Demo maps.
Of course, we can't stop you from deleting those, but it's good practice to refer to its events to know how some things are done.

## About the architecture of the Data/Tiled folder

The ``Data/Tiled`` folder is where everything related to Tiled is located. Out of the four folders, three are useful to you:
- The ``Maps`` folder must contain the Tiled maps of your project, saved as .tmx files exclusively.
- The ``Tilesets`` folder must contain the Tiled tilesets of your project, saved as .tsx files exclusively.
- The .png files associated to your Tiled tilesets must be located in the ``Assets`` folder.

## Create a Tiled tileset

Creating a Tiled tileset is easy:
- Add the png of the tileset inside the ``Assets`` folder
- In Tiled, File > New > New Tileset
- Search for the png file inside the ``Data/Tiled/Assets`` of your project
- Set the type to "Based on Tileset image" if it's not already the case
- Make sure "Embed in map" is **unchecked**. Embedded tilesets are **not supported**.
- Width and height of the tileset should already be 32 and 32. If not, make sure to do that.
  - Note: You should verify your tileset is a 32x32 one. To know if a tileset is a 32x32 tileset, open the tileset in a Image software editor and select one tile (a square one preferably). The width and height of the selection should be 32 and 32
- Apply a transparency if needed
- Save your tileset in the ``Data/Tiled/Tilesets`` folder of your project

## About the Blank Template

The Blank template you'll find in ``Data/Tiled/Maps`` is a template specifically made with SirMalo's HGSS tilesets in mind.
This means that the layers available in the Blank template are ready for use with some of the automapping rules that SirMalo
prepared for these tilesets. If you don't intend on using the HGSS tilesets at all, you are totally free to create your own
template that will suit your own needs.

## About layers

Layers in Tiled are quite simple to use but to ensure compatibility between PSDK and RMXP, and to convert them correctly, there are some rules to follow:
- Systemtags (tags that gives properties to a specific tile) must be put on a layer named `systemtags`. Warning: if your map doesn't need any Systemtag, make sure to NOT add that layer.
- Terraintags (tags that lets you differentiate a specific tile into multiple version, useful to have different encounter groups between patches of tall grass) must be put on a layer named `terrain_tag`. Warning: if your map doesn't need any Terraintags, make sure to NOT add that layer.
- Passages must be put on a layer named `passages`.
Note: You can check the Marsh map which contains those three layers to see how things work!
- Layers other than the systemtags, terrain_tag and passages layers must tell the system about its superposition priority. There is two ways to do so:
  - Add a _X at the end of the layer's name, X being a number starting from 1 and going up to 6. Example: I want a layer for the roof of my houses, so a layer with a high superposition priority, I should name my layer `roof_6`.
  - The other way is using folders. In Tiled, you can create folders for your layers and put layers with the same superposition priority in it. The folder needs to be named `Z=X`, with X being a number from 0 to 5.
  - Note: 1 to 6 for the layers' names is the same thing as 0 to 5 for folders' names.

## About making animated tiles

Since Studio 2.0, Tiled's animated tiles are supported by Tiled2Rxdata (only from its version 2 onward). To create animated tiles, you need to have each frame of your animation on the same tileset. To check how a good tileset with animated tiles is done, you can check the tileset from the Technical Demo.

Also, we strongly recommend using the Bulk Animation plugin for Tiled, which you can find here: https://github.com/lukas-shawford/tiled-bulk-animations
Don't forget to add the contributors of Tiled this plugin to your credits, great work should always be credited! 😁

Creating an animated tile is also subject to a set of rules:
- The timings in Tiled (in milliseconds) should be a multiple of 100
- The max number of frames for one animated tile is 32
  - Using 4/8/16/32 frames is the most recommended way but shouldn't pose a problem if not respected

Using animated tiles also obeys to a set of rules:
- Don't use too many **different** animated tiles on your maps. For example, the Beach map from the Technical Demo uses more than half the allowed count of different animated tiles. "Different" here means either
- The rule of 3:
  - when placing an animated tile on the map, make sure you don't have more than 3 tiles superposed on this position. Otherwise, the converter will merge all the layers for that position, and this will add more tiles to your animated tile count. Basically: learn to map only what's visible. If you can't see the tiles under a layer, don't include them. 👍
  - this rule doesn't apply for superposed animated tiles as the converter will try to fuse as many animated tiles as possible, depending on their timings.

Note: Some of these rules/limitations will be relaxed when Studio 3.0 will release and we'll leave RMXP, which enforces some of these limitations.

# Things you should NEVER DO

As stated in the [Preface](#preface), there are things you should never do if you want to make sure you won't encounter any problems during the conversion of your maps.
This section will list each of these errors and tell you how to not make these.

## Use the Import map button from Studio

This button shouldn't be used to add new maps to your project. This button should only be used if you're converting from RMXP and you have Tiled maps to link to an existing RMXP map after the transition. Or if your project was already using Tiled in 1.4.3 and you're just now converting from Studio 1.4.3 to Studio 2.0.

If you want to create a map in Studio, create it using the New Map button, then during the creation of the map in Studio, link it the existing Tiled map. If you happen to not have the map ready to be linked, you can link it later by clicking on the case that contains the name of the Map in the Map UI part of Studio.

## Open maps from different projects at the same time

As stated in the title, you should not open maps from different projects at the same time. When you're loading different maps, Tiled
loads the tilesets for all of them, and makes these tilesets available for every map open at the moment. This means that, if you open
Map 1 which uses Tileset 1 and 2, and Map 2, which uses Tileset 2 and 3, then Tileset 1 becomes available to use for Map 3,
and Tileset 3 becomes available to use for Map 1.

In the context of the same project, you are totally free to open multiples maps, as long as they all come from the same ``Data/Tiled/Maps`` folder.
In the context of two different projects, you should make sure to open two instances of Tiled. One Tiled for project 1, one Tiled for project 2.
This way, Tiled won't make any exterior tileset available when it shouldn't.

## Give the wrong Tiled filepath when Studio asks for it

In order for Studio to be able to open maps in Tiled directly and generate the overviews when needed, it needs to have access to Tiled's location.
When you're invited to set the installation path of Tiled, please make sure you are pointing to where it's exactly installed, and not some Temp folder or something.
- On Windows, Tiled is generally installed in `C:/Program Files/Tiled`.
- On Linux, you need to point to Tiled's AppImage.
- On Mac, just go to the Applications folder.

## Putting wrong tiles into the wrong layers

As stated in the [About layers](#about-layers), there are some rules about layers and their names. The converter follows these rules,
and waits for specific tiles for the passages/system_tags/terraintag layers. As such, you need to ensure to not put any tile from any other tilesets
than the one required to use for each specific layers:
- ``passages.tsx`` for the passages layer
- ``systemtags.tsx`` for the systemtags layer
- ``terrain_tag.tsx`` for the terrain_tag layer

# Closing remarks

Congratulations for reading all of these!

Now that you know everything there is to know, the only thing left is to practice your mapping skills with Tiled!

Making maps isn't innate and will require you to train, and to learn the principles of Game Design and Level Design.
A quick research on Google can give you links to good tutorials!

Of course, Pokémon Workshop and its [mapping channel](https://discord.com/channels/143824995867557888/360857021777707009)
are there if you want to show your maps and get feedbacks!

Godspeed, maker, we hope to learn from you soon! :D

-Rey
