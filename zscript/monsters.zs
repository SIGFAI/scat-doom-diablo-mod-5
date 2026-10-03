// The blocky Diablo bestiary. Every Doom monster becomes one of them (sprites rendered from 3D blocky models, 8 angles).
// They fall over like Minecraft mobs, then vanish in a white poof and leave their loot (SICHandler).

mixin class SICMonsterBits
{
	int champion;      // 0 normal, 1 champion (blue), 2 unique (gold): set by SICHandler at spawn
	int panicUntil;    // Fallen: run away until then
	String baseTag;

	action void SIC_Vanish()
	{
		SICPoofFX.Poof(self, 16);
	}

	// falls over: no more collision, a spray of cubes (0 bone, 1 blood, 2 embers)
	action void SIC_Fall(int cube = 1)
	{
		A_NoBlocking();
		SICBit.Spray(self, 6, cube, 4);
	}

	// Diablo's Fallen flee when a friend dies; the Lord flees from the cat.
	void SIC_Panic(int tics)
	{
		bFRIGHTENED = true;
		panicUntil = level.maptime + tics;
	}

	void SIC_PanicTick()
	{
		if (panicUntil && level.maptime >= panicUntil)
		{
			bFRIGHTENED = false;
			panicUntil = 0;
		}
	}
}

// ---------------------------------------------------------------- Skeleton Archer (ZombieMan, WolfensteinSS)
class SICSkeleton : ZombieMan replaces ZombieMan
{
	mixin SICMonsterBits;
	Default
	{
		Tag "Skeleton Archer";
		Health 40;
		Radius 16;
		Height 56;
		Scale 0.5;
		Speed 8;
		PainChance 200;
		SeeSound "skel/sight";
		ActiveSound "skel/active";
		PainSound "skel/pain";
		DeathSound "skel/death";
		BloodType "SICBoneDust";
		DropItem "None";
		Obituary "%o was shot by a Skeleton Archer.";
	}
	override void Tick() { Super.Tick(); SIC_PanicTick(); }
	States
	{
	Spawn:
		SKEL A 10 A_Look;
		SKEL C 10 A_Look;
		Loop;
	See:
		SKEL ABCD 4 A_Chase;
		Loop;
	Missile:
		SKEL E 10 A_FaceTarget;
		SKEL F 5 A_SpawnProjectile("SICArrow", 34);
		SKEL E 8 A_FaceTarget;
		Goto See;
	Pain:
		SKEL G 3;
		SKEL G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		SKEL H 4;
		SKEL I 4 A_Scream;
		SKEL J 4 SIC_Fall(0);
		SKEL K 4;
		SKEL L 30;
		SKEL L 1 SIC_Vanish;
		Stop;
	Raise:
		SKEL LKJIH 5;
		Goto See;
	}
}

class SICSkeletonSS : SICSkeleton replaces WolfensteinSS {
	States
	{
	See:
		SKEL ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		SKEL H 4;
		SKEL I 4 A_Scream;
		SKEL J 4 SIC_Fall(0);
		SKEL K 4;
		SKEL L 30;
		SKEL L 1 SIC_Vanish;
		Stop;
	}
}

// ---------------------------------------------------------------- Burning Dead (ShotgunGuy, ChaingunGuy, Revenant)
class SICBurningDead : ShotgunGuy replaces ShotgunGuy
{
	mixin SICMonsterBits;
	Default
	{
		Tag "Burning Dead Archer";
		Health 60;
		Radius 16;
		Height 56;
		Scale 0.5;
		Speed 8;
		PainChance 170;
		SeeSound "skel/sight";
		ActiveSound "skel/active";
		PainSound "skel/pain";
		DeathSound "skel/death";
		BloodType "SICBoneDust";
		DropItem "None";
		Obituary "%o was roasted by the Burning Dead.";
	}
	override void Tick()
	{
		Super.Tick();
		SIC_PanicTick();
		if (health > 0 && level.maptime % 4 == 0)
			A_SpawnItemEx("SICEmber", frandom(-8, 8), frandom(-8, 8), frandom(20, 50), 0, 0, frandom(0.3, 1.0), 0, SXF_NOCHECKPOSITION);
	}
	States
	{
	Spawn:
		SKBD A 10 A_Look;
		SKBD C 10 A_Look;
		Loop;
	See:
		SKBD ABCD 4 A_Chase;
		Loop;
	Missile:
		SKBD E 10 A_FaceTarget;
		SKBD F 5 Bright
		{
			A_SpawnProjectile("SICFireArrow", 34, 0, -6);
			A_SpawnProjectile("SICFireArrow", 34, 0, 0);
			A_SpawnProjectile("SICFireArrow", 34, 0, 6);
		}
		SKBD E 8 A_FaceTarget;
		Goto See;
	Pain:
		SKBD G 3;
		SKBD G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		SKBD H 4;
		SKBD I 4 A_Scream;
		SKBD J 4 SIC_Fall(2);
		SKBD K 4;
		SKBD L 30 { SICPoofFX.Embers(self, 10, 2); }
		SKBD L 1 SIC_Vanish;
		Stop;
	Raise:
		SKBD LKJIH 5;
		Goto See;
	}
}

class SICBurningCaptain : SICBurningDead replaces ChaingunGuy
{
	Default { Tag "Burning Dead Captain"; Health 70; }

	States
	{
	See:
		SKBD ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		SKBD H 4;
		SKBD I 4 A_Scream;
		SKBD J 4 SIC_Fall(2);
		SKBD K 4;
		SKBD L 30;
		SKBD L 1 SIC_Vanish;
		Stop;
	}
}

class SICSkeletonKing : SICBurningDead replaces Revenant
{
	Default
	{
		Tag "The Skeleton King";
		Health 300;
		Scale 0.7;
		Radius 20;
		Height 78;
		Speed 10;
		PainChance 100;
		Obituary "%o bowed before the Skeleton King.";
	}

	States
	{
	See:
		SKBD ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		SKBD H 4;
		SKBD I 4 A_Scream;
		SKBD J 4 SIC_Fall(2);
		SKBD K 4;
		SKBD L 30;
		SKBD L 1 SIC_Vanish;
		Stop;
	}
}

// ---------------------------------------------------------------- Fallen One (DoomImp, Archvile)
class SICFallen : DoomImp replaces DoomImp
{
	mixin SICMonsterBits;
	Default
	{
		Tag "Fallen One";
		Health 60;
		Radius 14;
		Height 46;
		Scale 0.5;
		Speed 9;
		PainChance 200;
		SeeSound "fallen/sight";
		ActiveSound "fallen/sight";
		PainSound "fallen/pain";
		DeathSound "fallen/death";
		BloodType "SICBlood";
		Obituary "%o was stabbed by a Fallen One.";
		HitObituary "%o was stabbed by a Fallen One.";
	}
	override void Tick() { Super.Tick(); SIC_PanicTick(); }
	States
	{
	Spawn:
		FALN A 10 A_Look;
		FALN C 10 A_Look;
		Loop;
	See:
		FALN ABCD 3 A_Chase;
		Loop;
	Melee:
		FALN E 6 A_FaceTarget;
		FALN F 6 A_CustomMeleeAttack(random(3, 8) * 3, "fallen/stab", "", "Melee", true);
		FALN E 4;
		Goto See;
	Missile:
		FALN E 8 A_FaceTarget;
		FALN F 6 A_SpawnProjectile("SICFireball", 30);
		FALN E 6;
		Goto See;
	Pain:
		FALN G 2;
		FALN G 2 A_Pain;
		Goto See;
	Death:
	XDeath:
		FALN H 4;
		FALN I 4 A_Scream;
		FALN J 4 SIC_Fall;
		FALN K 4;
		FALN L 30;
		FALN L 1 SIC_Vanish;
		Stop;
	Raise:
		FALN LKJIH 5;
		Goto See;
	}
}

class SICFallenShaman : SICFallen replaces Archvile
{
	Default
	{
		Tag "Fallen Shaman";
		Health 400;
		Scale 0.62;
		Radius 18;
		Height 58;
		Speed 11;
		PainChance 60;
		+QUICKTORETALIATE
	}
	States
	{
	Missile:
		FALN E 6 A_FaceTarget;
		FALN F 4 A_SpawnProjectile("SICFireball", 34, 0, -10);
		FALN F 4 A_SpawnProjectile("SICFireball", 34, 0, 0);
		FALN F 4 A_SpawnProjectile("SICFireball", 34, 0, 10);
		FALN E 6;
		Goto See;
	}
}

// ---------------------------------------------------------------- Zombie (Demon, Spectre, Arachnotron)
class SICZombie : Demon replaces Demon
{
	mixin SICMonsterBits;
	Default
	{
		Tag "Zombie";
		Health 150;
		Radius 18;
		Height 59;
		Scale 0.5;
		Speed 9;
		PainChance 180;
		SeeSound "zombie/sight";
		ActiveSound "zombie/active";
		PainSound "zombie/pain";
		DeathSound "zombie/death";
		AttackSound "zombie/bite";
		BloodType "SICBlood";
		Obituary "%o was eaten by a Zombie.";
	}
	override void Tick() { Super.Tick(); SIC_PanicTick(); }
	States
	{
	Spawn:
		ZOMB A 10 A_Look;
		ZOMB C 10 A_Look;
		Loop;
	See:
		ZOMB ABCD 4 A_Chase;
		Loop;
	Melee:
		ZOMB E 8 A_FaceTarget;
		ZOMB F 6 A_CustomMeleeAttack(random(1, 10) * 4, "zombie/bite", "", "Melee", true);
		ZOMB E 4;
		Goto See;
	Pain:
		ZOMB G 2;
		ZOMB G 2 A_Pain;
		Goto See;
	Death:
	XDeath:
		ZOMB H 4;
		ZOMB I 4 A_Scream;
		ZOMB J 4 SIC_Fall;
		ZOMB K 4;
		ZOMB L 30;
		ZOMB L 1 SIC_Vanish;
		Stop;
	Raise:
		ZOMB LKJIH 5;
		Goto See;
	}
}

class SICGhoul : SICZombie replaces Spectre
{
	Default { Tag "Ghoul"; RenderStyle "Translucent"; Alpha 0.5; }

	States
	{
	See:
		ZOMB ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		ZOMB H 4;
		ZOMB I 4 A_Scream;
		ZOMB J 4 SIC_Fall(1);
		ZOMB K 4;
		ZOMB L 30;
		ZOMB L 1 SIC_Vanish;
		Stop;
	}
}

class SICZombieBrute : SICZombie replaces Arachnotron
{
	Default { Tag "Zombie Brute"; Health 450; Scale 0.68; Radius 24; Height 80; Speed 10; PainChance 80; }

	States
	{
	See:
		ZOMB ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		ZOMB H 4;
		ZOMB I 4 A_Scream;
		ZOMB J 4 SIC_Fall(1);
		ZOMB K 4;
		ZOMB L 30;
		ZOMB L 1 SIC_Vanish;
		Stop;
	}
}

// ---------------------------------------------------------------- The Butcher (BaronOfHell, HellKnight, Fatso)
class SICButcher : BaronOfHell replaces BaronOfHell
{
	mixin SICMonsterBits;
	Default
	{
		Tag "The Butcher";
		Health 700;
		Radius 26;
		Height 74;
		Scale 0.5;
		Speed 12;
		PainChance 60;
		Mass 1000;
		SeeSound "butcher/sight";
		ActiveSound "zombie/active";
		PainSound "butcher/pain";
		DeathSound "butcher/death";
		BloodType "SICBlood";
		Obituary "%o was made into fresh meat.";
		HitObituary "%o was made into fresh meat.";
	}
	override void Tick() { Super.Tick(); SIC_PanicTick(); }
	States
	{
	Spawn:
		BTCH A 10 A_Look;
		BTCH C 10 A_Look;
		Loop;
	See:
		BTCH ABCD 4 A_Chase;
		Loop;
	Melee:
		BTCH E 6 A_FaceTarget;
		BTCH F 6 A_CustomMeleeAttack(random(2, 8) * 10, "butcher/chop", "butcher/swing", "Melee", true);
		BTCH E 4;
		Goto See;
	Missile:
		BTCH E 10 A_FaceTarget;
		BTCH F 6 A_SpawnProjectile("SICCleaver", 48);
		BTCH E 6;
		Goto See;
	Pain:
		BTCH G 3;
		BTCH G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		BTCH H 5;
		BTCH I 5 A_Scream;
		BTCH J 5 SIC_Fall;
		BTCH K 5;
		BTCH L 50;
		BTCH L 1 SIC_Vanish;
		Stop;
	Raise:
		BTCH LKJIH 5;
		Goto See;
	}
}

class SICApprentice : SICButcher replaces HellKnight
{
	Default
	{
		Tag "Butcher's Apprentice";
		Health 400;
		Scale 0.4;
		Radius 22;
		Height 60;
		Speed 11;
		PainChance 100;
		SeeSound "zombie/sight";
	}

	States
	{
	See:
		BTCH ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		BTCH H 4;
		BTCH I 4 A_Scream;
		BTCH J 4 SIC_Fall(1);
		BTCH K 4;
		BTCH L 30;
		BTCH L 1 SIC_Vanish;
		Stop;
	}
}

class SICFatButcher : SICButcher replaces Fatso
{
	Default { Tag "The Fat Butcher"; Health 600; Speed 8; }

	States
	{
	See:
		BTCH ABCD 4 A_Chase;
		Loop;
	Death:
	XDeath:
		BTCH H 4;
		BTCH I 4 A_Scream;
		BTCH J 4 SIC_Fall(1);
		BTCH K 4;
		BTCH L 30;
		BTCH L 1 SIC_Vanish;
		Stop;
	}
}

// ---------------------------------------------------------------- The Lord of Ssssterror (Cyberdemon, SpiderMastermind)
// Diablo turned Creeper: fire nova, hellfire, and a creeper swell-and-blast when you get close. Creepers fear cats.
class SICLord : Cyberdemon replaces Cyberdemon
{
	mixin SICMonsterBits;
	bool metCat;
	Default
	{
		Tag "The Lord of Ssssterror";
		Health 1800;
		Radius 40;
		Height 115;
		Scale 0.5;
		Speed 12;
		PainChance 30;
		Mass 2000;
		MinMissileChance 120;
		SeeSound "diablo/sight";
		ActiveSound "diablo/hiss";
		PainSound "diablo/pain";
		DeathSound "diablo/death";
		BloodType "SICBlood";
		Obituary "%o was terrorized by the Lord of Ssssterror.";
		+NOTARGET
		-NORADIUSDMG
		+DONTMORPH
	}
	override void Tick()
	{
		Super.Tick();
		SIC_PanicTick();
		if (health > 0 && level.maptime % 3 == 0)
			A_SpawnItemEx("SICEmber", frandom(-20, 20), frandom(-20, 20), frandom(30, 100), 0, 0, frandom(0.5, 1.5), 0, SXF_NOCHECKPOSITION);
	}

	// Creepers fear cats: the cat near him makes him run, hissing.
	void SIC_FearCat()
	{
		let it = ThinkerIterator.Create("SICCat"); Actor c;
		while (c = Actor(it.Next()))
		{
			if (Distance2D(c) < 520 && CheckSight(c))
			{
				if (!panicUntil)
				{
					A_StartSound("diablo/hiss", CHAN_6);
					SIC_Panic(90);
					SICPoofFX.Poof(self, 10);
					if (!metCat)
					{
						metCat = true;
						A_StartSound("diablo/cat", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
						SICHandler.Say("The Lord of Ssssterror", "Ssssss... not the cat! NOT THE CAT!", Font.CR_RED, 105);
					}
				}
				return;
			}
		}
	}

	action void SIC_Nova()
	{
		A_StartSound("fire/cast", CHAN_WEAPON);
		for (int i = 0; i < 16; i++)
		{
			let m = A_SpawnProjectile("SICNovaFire", 40, 0, i * 22.5, CMF_AIMDIRECTION | CMF_ABSOLUTEANGLE);
		}
	}

	States
	{
	Spawn:
		DIAB A 10 A_Look;
		DIAB C 10 A_Look;
		Loop;
	See:
		DIAB A 4 { A_Chase(); SIC_FearCat(); }
		DIAB B 4 A_Chase;
		DIAB C 4 { A_Chase(); SIC_FearCat(); }
		DIAB D 4 A_Chase;
		Loop;
	Missile:
		DIAB E 0 A_JumpIf(target && Distance2D(target) < 230, "Swell");
		DIAB E 0 A_Jump(110, "Nova");
		DIAB E 8 A_FaceTarget;
		DIAB F 6 Bright A_SpawnProjectile("SICHellfire", 70, -20);
		DIAB E 6 A_FaceTarget;
		DIAB F 6 Bright A_SpawnProjectile("SICHellfire", 70, 20);
		DIAB E 8;
		Goto See;
	Nova:
		DIAB E 12 Bright A_FaceTarget;
		DIAB F 4 Bright SIC_Nova;
		DIAB F 14 Bright;
		Goto See;
	Swell:
		// the creeper move: hiss, swell and flash white, BOOM (he survives: he is the Lord)
		DIAB E 0 A_StartSound("diablo/hiss", CHAN_6, CHANF_DEFAULT, 1.0, ATTN_NONE);
		DIAB EEEEEE 4
		{
			A_FaceTarget();
			scale *= 1.03;
			bool flash = (level.maptime / 4) % 2;
			A_SetRenderStyle(1.0, flash ? STYLE_AddStencil : STYLE_Normal);
			if (flash) SetShade("FFFFFF");
		}
		DIAB F 0
		{
			A_SetRenderStyle(1.0, STYLE_Normal);
			scale = (0.5, 0.5);
			A_StartSound("tnt/boom", CHAN_WEAPON, CHANF_DEFAULT, 1.0, 0.5);
			A_Explode(70, 240, XF_NOTMISSILE | XF_NOSPLASH, true, 60);
			SICPoofFX.Poof(self, 30);
			SICPoofFX.Embers(self, 40, 8);
			SICBit.Spray(self, 20, 0, 9);
			A_QuakeEx(3, 3, 2, 20, 0, 600, "");
		}
		DIAB F 20 Bright;
		Goto See;
	Pain:
		DIAB G 4;
		DIAB G 4 A_Pain;
		Goto See;
	Death:
	XDeath:
		DIAB H 8 Bright { A_SetRenderStyle(1.0, STYLE_Normal); scale = (0.5, 0.5); SICPoofFX.Embers(self, 40, 6); }
		DIAB I 8 A_Scream;
		DIAB J 8 { SIC_Fall(); A_QuakeEx(4, 4, 2, 30, 0, 800, ""); }
		DIAB K 8 { SICPoofFX.Embers(self, 30, 6); }
		DIAB L 70;
		DIAB L 1 { SICPoofFX.Poof(self, 40); A_StartSound("tnt/boom", CHAN_WEAPON); SICBit.Spray(self, 30, 2, 8); }
		Stop;
	}
}

class SICLord2 : SICLord replaces SpiderMastermind {
	States
	{
	See:
		DIAB A 4 { A_Chase(); SIC_FearCat(); }
		DIAB B 4 A_Chase;
		DIAB C 4 { A_Chase(); SIC_FearCat(); }
		DIAB D 4 A_Chase;
		Loop;
	Death:
	XDeath:
		DIAB H 4;
		DIAB I 4 A_Scream;
		DIAB J 4 SIC_Fall(1);
		DIAB K 4;
		DIAB L 30;
		DIAB L 1 SIC_Vanish;
		Stop;
	}
}
