// The Minecraft arsenal in a Diablo hand (first-person frames rendered from a 3D blocky arm):
// bare hands, Enchanted Bow, Multishot Bow, Fire Staff (sets demons on fire), TNT (thrown, blinks, BOOM).

class SICPunch : Fist replaces Fist
{
	Default { Tag "Bare Hands"; Weapon.SlotNumber 1; }
	States
	{
	Ready:
		PNCH A 1 A_WeaponReady;
		Loop;
	Deselect:
		PNCH A 1 A_Lower;
		Loop;
	Select:
		PNCH A 1 A_Raise;
		Loop;
	Fire:
		PNCH B 4;
		PNCH B 4 A_Punch;
		PNCH A 5;
		PNCH A 4 A_ReFire;
		Goto Ready;
	}
}

// ---------------------------------------------------------------- bows
class SICBow : Weapon replaces Pistol
{
	Default
	{
		Tag "Enchanted Bow";
		Weapon.SlotNumber 2;
		Weapon.AmmoType "Clip";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 20;
		Weapon.SelectionOrder 1900;
		Inventory.PickupMessage "You found the Enchanted Bow!";
		Obituary "%o was shot by %k's Enchanted Bow.";
		+WEAPON.NOALERT
	}
	States
	{
	Spawn:
		LOOT J -1;
		Stop;
	Ready:
		BOWG A 1 A_WeaponReady;
		Loop;
	Deselect:
		BOWG A 1 A_Lower;
		Loop;
	Select:
		BOWG A 1 A_Raise;
		Loop;
	Fire:
		BOWG B 7;
		BOWG C 3 { A_FireProjectile("SICPlayerArrow"); A_AlertMonsters(); }
		BOWG C 3;
		BOWG A 5 A_ReFire;
		Goto Ready;
	}
}

class SICMultishot : SICBow replaces Chaingun
{
	Default
	{
		Tag "Multishot Bow";
		Weapon.SlotNumber 4;
		Weapon.AmmoUse 3;
		Weapon.SelectionOrder 700;
		Inventory.PickupMessage "You found a Multishot Bow! Three arrows at once.";
	}
	States
	{
	Fire:
		BOWG B 5;
		BOWG C 3
		{
			A_FireProjectile("SICPlayerArrow", -5, false);
			A_FireProjectile("SICPlayerArrow", 0, true);
			A_FireProjectile("SICPlayerArrow", 5, false);
			A_AlertMonsters();
		}
		BOWG A 4 A_ReFire;
		Goto Ready;
	}
}

class SICPlayerArrow : SICArrow
{
	Default
	{
		Speed 42;
		DamageFunction (random(14, 24));
		SeeSound "skel/shoot";
		Obituary "%o was shot by %k.";
	}
	States
	{
	Spawn:
		ARRW A 1 A_SpawnItemEx("SICSparkle", -8, 0, 0, 0, 0, 0.2, 0, SXF_NOCHECKPOSITION);
		Loop;
	}
}

// ---------------------------------------------------------------- Fire Staff
class SICFireStaff : Weapon replaces Shotgun
{
	Default
	{
		Tag "Fire Staff";
		Weapon.SlotNumber 3;
		Weapon.AmmoType "Shell";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 12;
		Weapon.SelectionOrder 1300;
		Inventory.PickupMessage "You found the Fire Staff! Burn, demons, burn.";
	}
	States
	{
	Spawn:
		STAF A -1;
		Stop;
	Ready:
		STFG A 1 A_WeaponReady;
		Loop;
	Deselect:
		STFG A 1 A_Lower;
		Loop;
	Select:
		STFG A 1 A_Raise;
		Loop;
	Fire:
		STFG C 3;
		STFG B 3 Bright
		{
			A_Light1();
			A_StartSound("fire/cast", CHAN_WEAPON);
			A_FireProjectile("SICPlayerFireball", -6, false);
			A_FireProjectile("SICPlayerFireball", 0, true);
			A_FireProjectile("SICPlayerFireball", 6, false);
			A_AlertMonsters();
		}
		STFG B 3 Bright A_Light2;
		STFG C 5 A_Light0;
		STFG A 8 A_ReFire;
		Goto Ready;
	}
}

class SICSuperStaff : SICFireStaff replaces SuperShotgun
{
	Default { Tag "Inferno Staff"; Weapon.SlotNumber 3; Weapon.AmmoUse 2; Weapon.SelectionOrder 400; Inventory.PickupMessage "You found the Inferno Staff!"; }
	States
	{
	Fire:
		STFG C 3;
		STFG B 3 Bright
		{
			A_Light1();
			A_StartSound("fire/cast", CHAN_WEAPON);
			for (int i = -2; i <= 2; i++) A_FireProjectile("SICPlayerFireball", i * 5, i == 0);
			A_AlertMonsters();
		}
		STFG B 3 Bright A_Light2;
		STFG C 7 A_Light0;
		STFG A 10 A_ReFire;
		Goto Ready;
	}
}

class SICPlayerFireball : SICFireball
{
	Default
	{
		Speed 30;
		DamageFunction (random(14, 22));
		Scale 0.75;
		SeeSound "";
		Obituary "%o was burned by %k.";
	}
	// the target catches fire
	override int DoSpecialDamage(Actor victim, int damage, Name damagetype)
	{
		if (victim && victim.bIsMonster && victim.health > 0)
		{
			let b = SICBurn(victim.FindInventory("SICBurn"));
			if (!b) { victim.GiveInventory("SICBurn", 1); b = SICBurn(victim.FindInventory("SICBurn")); }
			if (b) { b.left = 105; b.burner = target; }
		}
		return damage;
	}
	States
	{
	Death:
		FBAL A 0 Bright { SICPoofFX.Embers(self, 14, 3); A_Explode(16, 48, XF_NOTMISSILE); A_SetRenderStyle(1.0, STYLE_Add); }
		FBAL ABCDAB 2 Bright { scale *= 1.25; A_FadeOut(0.15); }
		Stop;
	}
}

// Burning: flames and embers on the monster, a few damage every third of a second, for 3 s.
class SICBurn : Inventory
{
	int left; Actor burner;
	Default { +INVENTORY.UNDROPPABLE Inventory.MaxAmount 1; }
	override void DoEffect()
	{
		Super.DoEffect();
		let o = Owner;
		if (!o || o.health <= 0 || --left <= 0) { Destroy(); return; }
		if (left % 2 == 0)
			o.A_SpawnItemEx("SICEmber", frandom(-o.radius, o.radius), frandom(-o.radius, o.radius), frandom(4, o.height), 0, 0, frandom(0.8, 2.0), 0, SXF_NOCHECKPOSITION);
		if (left % 5 == 0)
		{
			let fl = Actor.Spawn("SICFlame", o.pos + (frandom(-o.radius, o.radius) * 0.6, frandom(-o.radius, o.radius) * 0.6, frandom(0, o.height * 0.7)), ALLOW_REPLACE);
			if (fl) fl.vel = o.vel * 0.5;
		}
		if (left % 12 == 0) o.DamageMobj(self, burner, 3, 'Fire', DMG_THRUSTLESS);
	}
}

// a lick of flame that rises off a burning thing
class SICFlame : Actor
{
	Default { +NOINTERACTION +BRIGHT RenderStyle "Add"; Scale 0.45; Alpha 0.95; }
	States
	{
	Spawn:
		FBAL A 0 NoDelay { frame = random(0, 3); }
		FBAL # 2 { vel.z = 1.2; A_FadeOut(0.12); scale *= 0.95; }
		Wait;
	}
}

// ---------------------------------------------------------------- TNT
class SICTNTLauncher : Weapon replaces RocketLauncher
{
	Default
	{
		Tag "TNT";
		Weapon.SlotNumber 5;
		Weapon.AmmoType "RocketAmmo";
		Weapon.AmmoUse 1;
		Weapon.AmmoGive 4;
		Weapon.SelectionOrder 2500;
		Inventory.PickupMessage "You found a stack of TNT!";
		+WEAPON.NOAUTOFIRE
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	Ready:
		TNTG A 1 A_WeaponReady;
		Loop;
	Deselect:
		TNTG A 1 A_Lower;
		Loop;
	Select:
		TNTG A 1 A_Raise;
		Loop;
	Fire:
		TNTG B 8 A_StartSound("tnt/fuse", CHAN_WEAPON);
		TNTG C 4 { A_FireProjectile("SICThrownTNT", 0, true, 0, 0, FPF_NOAUTOAIM, -6); A_AlertMonsters(); }
		TNTG D 10;
		TNTG A 8 A_ReFire;
		Goto Ready;
	}
}

// Thrown TNT: flies in an arc, sticks where it lands, blinks white (lit fuse), then explodes.
class SICThrownTNT : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		Gravity 0.55;
		Radius 8;
		Height 10;
		Speed 26;
		Damage 4;
		Scale 0.28;
		+ROLLSPRITE
		+ROLLCENTER
		+FORCERADIUSDMG
		Obituary "%o was blown up by %k's TNT.";
	}
	override int SpecialMissileHit(Actor victim) { return victim is "SICCat" ? 1 : -1; }
	States
	{
	Spawn:
		TNTB A 1 { roll += 25; }
		Loop;
	Death:
	XDeath:
		TNTB B 0 { roll = 0; A_StartSound("tnt/fuse", CHAN_BODY); }
		TNTB BABABA 3;
		TNTB BB 2;
		TNT1 A 0 { SICTNT.Blast(self, 170, 200); }
		TNT1 A 10;
		Stop;
	}
}

// ---------------------------------------------------------------- Doom pickups in Minecraft clothes
class SICArrows : Clip replaces Clip
{
	Default { Inventory.PickupMessage "Picked up a bundle of arrows."; Scale 0.9; }
	States { Spawn: ARRW A -1; Stop; }
}
class SICArrowBox : ClipBox replaces ClipBox
{
	Default { Inventory.PickupMessage "Picked up a quiver of arrows."; Scale 1.2; }
	States { Spawn: ARRW A -1; Stop; }
}
class SICManaShard : Shell replaces Shell
{
	Default { Inventory.PickupMessage "Picked up a mana shard."; }
	States { Spawn: GEMS D -1; Stop; }
}
class SICManaCrystal : ShellBox replaces ShellBox
{
	Default { Inventory.PickupMessage "Picked up a big mana crystal."; Scale 1.5; }
	States { Spawn: GEMS D -1; Stop; }
}
class SICTNTAmmo : RocketAmmo replaces RocketAmmo
{
	Default { Inventory.PickupMessage "Picked up a TNT block."; Scale 0.45; }
	States { Spawn: TNTB A -1; Stop; }
}
class SICTNTBox : RocketBox replaces RocketBox
{
	Default { Inventory.PickupMessage "Picked up a crate of TNT."; Scale 0.6; }
	States { Spawn: TNTB A -1; Stop; }
}
class SICStim : Stimpack replaces Stimpack
{
	Default { Inventory.PickupMessage "Ate an apple."; }
	States { Spawn: GEMS E -1; Stop; }
}
class SICMedikit : Medikit replaces Medikit
{
	Default { Inventory.PickupMessage "Drank a big Potion of Healing."; Scale 1.0; }
	States { Spawn: POTN A -1; Stop; }
}
