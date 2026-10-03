// Blocky effects: Minecraft death poof, block bits (blood, bone dust, debris), fire embers, sparkles,
// and the projectiles (arrows that stick in walls, pixel fireballs, the cat's arcane bolt, TNT).

// White puff squares that rise and fade: the Minecraft "mob poof".
class SICPoof : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		RenderStyle "Translucent";
		Alpha 0.75;
		Scale 0.36;
	}
	States
	{
	Spawn:
		PFXS # 1
		{
			A_FadeOut(0.035);
			scale *= 0.975;
			vel *= 0.93;
			vel.z += 0.03;
		}
		Loop;
	}
}

// A little cube that flies, falls and bounces: blood (red), bone dust (white), embers (orange), mana (blue).
class SICBit : Actor
{
	int life;
	Default
	{
		Radius 2;
		Height 2;
		Gravity 0.7;
		+NOBLOCKMAP
		+DROPOFF
		+MISSILE
		+NOTELEPORT
		+THRUACTORS
		+BOUNCEONFLOORS
		+BOUNCEONWALLS
		+CANBOUNCEWATER
		BounceFactor 0.45;
		WallBounceFactor 0.4;
		BounceCount 4;
		Scale 0.22;
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		life = random(40, 80);
	}
	States
	{
	Spawn:
	Death:
		PFXS # 1
		{
			if (--life < 15) A_FadeOut(0.07);
		}
		Loop;
	}

	// Sprays n cubes of one color (frame 0 white, 1 red, 2 orange, 3 blue) from a point.
	static void Spray(Actor at, int n, int col, double speed = 4, double z = -1)
	{
		if (z < 0) z = at.height * 0.6;
		for (int i = 0; i < n; i++)
		{
			let b = Actor.Spawn("SICBit", at.pos + (frandom(-6, 6), frandom(-6, 6), z), ALLOW_REPLACE);
			if (!b) continue;
			b.frame = col;
			b.scale *= frandom(0.6, 1.3);
			b.vel = (frandom(-speed, speed), frandom(-speed, speed), frandom(speed * 0.5, speed * 1.5));
			if (col == 2 || col == 3) { b.bBRIGHT = true; }
		}
	}
}

// Rising orange spark that flickers out: trails of fireballs, burning things, fire nova.
class SICEmber : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		RenderStyle "Add";
		Alpha 1.0;
		Scale 0.35;
	}
	States
	{
	Spawn:
		PFXS C 1
		{
			A_FadeOut(frandom(0.04, 0.08));
			vel.z += 0.06;
			vel.xy *= 0.94;
			scale *= 0.97;
		}
		Loop;
	}
}

// Blue magic sparkle (the cat's spells, enchanted loot).
class SICSparkle : SICEmber
{
	States
	{
	Spawn:
		PFXS D 1
		{
			A_FadeOut(0.05);
			vel.z += 0.03;
			scale *= 0.96;
		}
		Loop;
	}
}

class SICPoofFX play
{
	// Minecraft death poof: a cloud of white squares where the mob stood.
	static void Poof(Actor at, int n = 14)
	{
		for (int i = 0; i < n; i++)
		{
			let p = Actor.Spawn("SICPoof", at.pos + (frandom(-at.radius, at.radius), frandom(-at.radius, at.radius), frandom(2, at.height * 0.8)), ALLOW_REPLACE);
			if (!p) continue;
			p.vel = (frandom(-1.2, 1.2), frandom(-1.2, 1.2), frandom(0.3, 1.6));
			p.scale *= frandom(0.7, 1.5);
		}
		at.A_StartSound("mc/poof", CHAN_7, CHANF_OVERLAP);
	}

	static void Embers(Actor at, int n, double speed = 3)
	{
		for (int i = 0; i < n; i++)
		{
			let e = Actor.Spawn("SICEmber", at.pos + (0, 0, at.height * 0.5), ALLOW_REPLACE);
			if (e) { e.vel = (frandom(-speed, speed), frandom(-speed, speed), frandom(-speed * 0.5, speed)); e.scale *= frandom(0.8, 2.0); }
		}
	}
}

// Blocky blood: hits spray red cubes instead of Doom's splats.
class SICBlood : Blood
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SICBit.Spray(self, random(3, 5), 1, 3, 0);
		Destroy();
	}
}

class SICBoneDust : Blood
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SICBit.Spray(self, random(3, 5), 0, 3, 0);
		Destroy();
	}
}

// ---------------------------------------------------------------- projectiles

// Skeleton arrow: sparkle trail; sticks in the wall a moment, like Minecraft.
class SICArrow : Actor
{
	Default
	{
		Projectile;
		Radius 4;
		Height 4;
		Speed 26;
		DamageFunction (random(4, 10));
		Scale 0.7;
		SeeSound "skel/shoot";
		DeathSound "arrow/hit";
		Obituary "%o was shot by a Skeleton Archer.";
	}
	// nothing ever explodes on the SuperIntelligent Cat: shots fly through it
	override int SpecialMissileHit(Actor victim) { return victim is "SICCat" ? 1 : -1; }
	States
	{
	Spawn:
		ARRW A 1 { if (level.maptime % 3 == 0) A_SpawnItemEx("SICPoof", 0, 0, 0, 0, 0, 0.2, 0, SXF_NOCHECKPOSITION); }
		Loop;
	Death:
		ARRW A 40;
		ARRW A 1 A_FadeOut(0.1);
		Wait;
	XDeath:
		TNT1 A 0;
		Stop;
	}
}

// Burning Dead: the same arrow on fire.
class SICFireArrow : SICArrow
{
	Default
	{
		DamageFunction (random(6, 12));
		+BRIGHT
		Obituary "%o was roasted by the Burning Dead.";
	}
	States
	{
	Spawn:
		ARRW A 1 A_SpawnItemEx("SICEmber", -6, 0, 0, frandom(-0.5, 0.5), frandom(-0.5, 0.5), frandom(0.2, 1), 0, SXF_NOCHECKPOSITION);
		Loop;
	Death:
		ARRW A 0 { SICPoofFX.Embers(self, 8, 2); }
		Goto Super::Death;
	}
}

// Pixel fireball (the Fallen, and every Doom imp ball): ember trail, flash of fire on impact.
class SICFireball : DoomImpBall replaces DoomImpBall
{
	Default
	{
		Radius 6;
		Height 8;
		Speed 12;
		Scale 0.85;
		RenderStyle "Normal";
		SeeSound "fire/cast";
		DeathSound "fire/boom";
		Obituary "%o was burned by a Fallen One.";
	}
	// nothing ever explodes on the SuperIntelligent Cat: shots fly through it
	override int SpecialMissileHit(Actor victim) { return victim is "SICCat" ? 1 : -1; }
	States
	{
	Spawn:
		FBAL ABCD 2 Bright
		{
			A_SpawnItemEx("SICEmber", -4, frandom(-3, 3), frandom(-3, 3), frandom(-0.5, 0.5), frandom(-0.5, 0.5), frandom(0.3, 1.2), 0, SXF_NOCHECKPOSITION);
		}
		Loop;
	Death:
		FBAL A 0 Bright { SICPoofFX.Embers(self, 14, 3); A_SetRenderStyle(1.0, STYLE_Add); }
		FBAL ABCDAB 2 Bright { scale *= 1.25; A_FadeOut(0.15); }
		Stop;
	}
}

// The Lord's fire nova: a ring of red fire.
class SICNovaFire : SICFireball
{
	Default
	{
		Speed 11;
		DamageFunction (random(8, 14));
		Scale 1.0;
		Obituary "%o was caught in the Lord of Ssssterror's fire nova.";
	}
	States
	{
	Spawn:
		NOVA ABCD 2 Bright A_SpawnItemEx("SICEmber", -4, 0, 0, 0, 0, frandom(0.3, 1), 0, SXF_NOCHECKPOSITION);
		Loop;
	Death:
		NOVA A 0 Bright { SICPoofFX.Embers(self, 10, 3); A_SetRenderStyle(1.0, STYLE_Add); }
		NOVA ABCDAB 2 Bright { scale *= 1.25; A_FadeOut(0.15); }
		Stop;
	}
}

// The Lord's big aimed fireball.
class SICHellfire : SICFireball
{
	Default
	{
		Speed 15;
		DamageFunction (random(20, 32));
		Scale 1.6;
		Radius 10;
		Height 14;
		Obituary "%o was incinerated by the Lord of Ssssterror.";
	}
	States
	{
	Death:
		FBAL A 0 Bright { SICPoofFX.Embers(self, 24, 5); A_Explode(40, 96, XF_NOTMISSILE); A_SetRenderStyle(1.0, STYLE_Add); }
		FBAL ABCDAB 2 Bright { scale *= 1.3; A_FadeOut(0.15); }
		Stop;
	}
}

// The Butcher's thrown cleaver, spinning.
class SICCleaver : Actor
{
	Default
	{
		Projectile;
		Radius 8;
		Height 8;
		Speed 16;
		DamageFunction (random(12, 20));
		Scale 1.5;
		+ROLLSPRITE
		+ROLLCENTER
		SeeSound "butcher/swing";
		DeathSound "butcher/chop";
		Obituary "%o was chopped by The Butcher.";
	}
	// nothing ever explodes on the SuperIntelligent Cat: shots fly through it
	override int SpecialMissileHit(Actor victim) { return victim is "SICCat" ? 1 : -1; }
	States
	{
	Spawn:
		LOOT D 1 { roll += 40; }
		Loop;
	Death:
		LOOT D 30;
		LOOT D 1 A_FadeOut(0.1);
		Wait;
	XDeath:
		TNT1 A 0 { SICBit.Spray(self, 6, 1, 3, 0); }
		Stop;
	}
}

// The SuperIntelligent Cat's arcane bolt: homes in on demons, never hurts the player.
class SICCatBolt : Actor
{
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 18;
		DamageFunction (random(14, 22));
		Scale 0.75;
		+SEEKERMISSILE
		+BRIGHT
		RenderStyle "Add";
		SeeSound "cat/cast";
		DeathSound "cat/boltboom";
	}
	override int SpecialMissileHit(Actor victim)
	{
		if (victim.player || victim.bFRIENDLY) return 1; // passes through friends
		return -1;
	}
	States
	{
	Spawn:
		ABOL ABCD 2
		{
			A_SeekerMissile(4, 8, SMF_LOOK);
			A_SpawnItemEx("SICSparkle", -4, frandom(-3, 3), frandom(-3, 3), 0, 0, frandom(0.2, 0.8), 0, SXF_NOCHECKPOSITION);
		}
		Loop;
	Death:
		ABOL A 0 { SICBit.Spray(self, 6, 3, 3, 0); for (int i = 0; i < 8; i++) A_SpawnItemEx("SICSparkle", 0, 0, 0, frandom(-2, 2), frandom(-2, 2), frandom(0, 2), 0, SXF_NOCHECKPOSITION); }
		ABOL AB 2 A_FadeOut(0.4);
		Stop;
		Stop;
	}
}
