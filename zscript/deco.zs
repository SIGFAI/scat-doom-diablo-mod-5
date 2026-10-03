// Doom's decorations in Minecraft blocks: bookshelf pillars (Tristram's library), log pillars, glowstone posts,
// little oak trees, and flickering wall torches that light the dungeon (GLDEFS). Same collision as the originals.

class SICBookPillar : Column replaces Column
{
	Default { Scale 0.75; }
	States { Spawn: COLB A -1; Stop; }
}

class SICLogPillar : TechPillar replaces TechPillar
{
	Default { Scale 0.85; }
	States { Spawn: COLL A -1; Stop; }
}

class SICGlowPost : TallGreenColumn replaces TallGreenColumn
{
	Default { Scale 0.85; }
	States { Spawn: COLG A -1 Bright; Stop; }
}
class SICGlowPost2 : ShortGreenColumn replaces ShortGreenColumn { Default { Scale 0.6; } States { Spawn: COLG A -1 Bright; Stop; } }
class SICGlowPost3 : TallRedColumn replaces TallRedColumn { Default { Scale 0.85; } States { Spawn: COLG A -1 Bright; Stop; } }
class SICGlowPost4 : ShortRedColumn replaces ShortRedColumn { Default { Scale 0.6; } States { Spawn: COLG A -1 Bright; Stop; } }
class SICGlowLamp : TechLamp replaces TechLamp { Default { Scale 0.9; } States { Spawn: COLG A -1 Bright; Stop; } }
class SICGlowLamp2 : TechLamp2 replaces TechLamp2 { Default { Scale 0.7; } States { Spawn: COLG A -1 Bright; Stop; } }

class SICOakTree : BigTree replaces BigTree
{
	Default { Scale 0.9; }
	States { Spawn: COLT A -1; Stop; }
}
class SICOakTree2 : TorchTree replaces TorchTree { Default { Scale 0.7; } States { Spawn: COLT A -1; Stop; } }
class SICLogStalk : Stalagtite replaces Stalagtite { Default { Scale 0.7; } States { Spawn: COLL A -1; Stop; } }

// Minecraft torch, flickering
class SICTorch : RedTorch replaces RedTorch
{
	Default { Scale 0.85; }
	States { Spawn: TRCH ABCD 4 Bright; Loop; }
}
class SICTorch2 : SICTorch replaces GreenTorch {}
class SICTorch3 : SICTorch replaces BlueTorch {}
class SICTorch4 : SICTorch replaces ShortRedTorch { Default { Scale 0.65; } }
class SICTorch5 : SICTorch replaces ShortGreenTorch { Default { Scale 0.65; } }
class SICTorch6 : SICTorch replaces ShortBlueTorch { Default { Scale 0.65; } }
class SICTorch7 : SICTorch replaces Candlestick { Default { Scale 0.45; } }
class SICTorch8 : SICTorch replaces Candelabra { Default { Scale 0.9; } }
