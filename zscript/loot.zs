// Diablo loot, Minecraft items. Every kill sprays gold, potions, apples, fish and named gear that flips through
// the air, lands with a clink and shows its name in its rarity color (white, blue magic, yellow rare, gold unique).
// Gear adds to your stats (damage, speed, life regen): SICStats.

// Remembers a monster's max life and whether it is a champion (1) or a unique (2).
class SICTag : Inventory
{
	int kind, maxhp;
	Default { +INVENTORY.UNDROPPABLE +INVENTORY.UNTOSSABLE Inventory.MaxAmount 1; }
	clearscope static int KindOf(Actor a) { let t = SICTag(a.FindInventory("SICTag")); return t ? t.kind : 0; }
	clearscope static int MaxOf(Actor a) { let t = SICTag(a.FindInventory("SICTag")); return t && t.maxhp > 0 ? t.maxhp : a.SpawnHealth(); }
}

class SICStats : Inventory
{
	int gold, xp, lvl, dmgPct, regen, kills, items;
	double speedBonus;
	String lastItem;
	int lastColor, lastAt, levelAt, goldAt;

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.PERSISTENTPOWER
		Inventory.MaxAmount 1;
	}

	override void BeginPlay() { Super.BeginPlay(); lvl = 1; }

	clearscope int XPToNext() { return 60 + lvl * 50; }

	void AddXP(int n)
	{
		xp += n;
		while (xp >= XPToNext())
		{
			xp -= XPToNext();
			lvl++;
			levelAt = level.maptime;
			dmgPct += 3;
			if (Owner)
			{
				Owner.A_StartSound("loot/levelup", CHAN_AUTO, CHANF_UI, 1.0, ATTN_NONE);
				Owner.GiveBody(100);
				for (int i = 0; i < 20; i++)
					Owner.A_SpawnItemEx("SICEmber", frandom(-20, 20), frandom(-20, 20), frandom(0, 50), 0, 0, frandom(1, 3), 0, SXF_NOCHECKPOSITION);
			}
		}
	}

	// gear: +damage on everything you hit
	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (!passive && damage > 0 && dmgPct > 0) newdamage = damage + damage * dmgPct / 100;
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (!Owner || Owner.health <= 0) return;
		if (regen > 0 && level.maptime % 35 == 0 && Owner.health < Owner.GetMaxHealth(true)) Owner.GiveBody(regen);
		if (Owner.player) Owner.Speed = Owner.Default.Speed * (1.0 + speedBonus);
	}

	clearscope static SICStats Of(Actor a) { return a ? SICStats(a.FindInventory("SICStats")) : null; }
}

// Base of everything that drops: flips through the air (Diablo), lands with a clink, a name label, a beam when rare.
class SICLoot : Inventory
{
	String lootName;
	int rarity;        // 0 normal, 1 magic, 2 rare, 3 unique
	bool landed;
	int age;

	Default
	{
		Radius 12;
		Height 16;
		Inventory.PickupSound "";
		Inventory.PickupMessage "";
		+ROLLSPRITE
		+ROLLCENTER
		+INVENTORY.NOSCREENFLASH
		-NOGRAVITY
		Gravity 0.8;
	}

	static const int RARITY_COLOR[] = { Font.CR_WHITE, Font.CR_LIGHTBLUE, Font.CR_YELLOW, Font.CR_GOLD };

	clearscope int LabelColor() { return RARITY_COLOR[clamp(rarity, 0, 3)]; }

	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		age++;
		if (!landed)
		{
			roll += 33;  // the Diablo flip
			if (age > 3 && pos.z <= floorz + 1 && vel.z <= 0)
			{
				landed = true;
				roll = rarity >= 1 ? 0 : -30;
				A_StartSound(rarity >= 2 ? "loot/rare" : "loot/drop", CHAN_AUTO, CHANF_DEFAULT, rarity >= 2 ? 1.0 : 0.6);
				vel.xy = (0, 0);
			}
		}
		else if (rarity >= 1 && age % 4 == 0)
		{
			// light beam of the rarity color, rising
			Color c = rarity == 1 ? Color(80, 140, 255) : (rarity == 2 ? Color(255, 255, 60) : Color(255, 170, 30));
			A_SpawnParticle(c, SPF_FULLBRIGHT, 30, 4, 0, frandom(-4, 4), frandom(-4, 4), 4, 0, 0, frandom(1.2, 2.2), startalphaf: 0.9, fadestepf: 0.03);
		}
	}

	override bool TryPickup(in out Actor toucher)
	{
		if (!toucher.player || !landed) return false;
		let st = SICStats.Of(toucher);
		if (!st) return false;
		if (!OnPickup(toucher, st)) return false;
		GoAwayAndDie();
		return true;
	}

	virtual bool OnPickup(Actor toucher, SICStats st) { return true; }

	void Announce(SICStats st, String text, int col)
	{
		st.lastItem = text;
		st.lastColor = col;
		st.lastAt = level.maptime;
	}
}

class SICGold : SICLoot
{
	int amount;
	Default { Scale 0.8; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		st.gold += amount;
		st.goldAt = level.maptime;
		toucher.A_StartSound(random(0, 1) ? "loot/gold" : "loot/gold2", CHAN_AUTO);
		Announce(st, String.Format("%d Gold", amount), Font.CR_GOLD);
		return true;
	}
	States { Spawn: GEMS A -1; Stop; }
}

class SICHealthPotion : SICLoot
{
	Default { Scale 0.75; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		toucher.GiveBody(25);
		toucher.A_StartSound("loot/potion", CHAN_AUTO);
		Announce(st, "Potion of Healing", Font.CR_RED);
		return true;
	}
	States { Spawn: POTN A -1; Stop; }
}

// Mana potion: refills the ammo of your weapons (bow arrows, staff mana, TNT)
class SICManaPotion : SICLoot
{
	Default { Scale 0.75; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		toucher.A_GiveInventory("Clip", 20);
		toucher.A_GiveInventory("Shell", 6);
		toucher.A_GiveInventory("RocketAmmo", 2);
		toucher.A_StartSound("loot/potion", CHAN_AUTO);
		Announce(st, "Potion of Mana", Font.CR_LIGHTBLUE);
		return true;
	}
	States { Spawn: POTN B -1; Stop; }
}

class SICApple : SICLoot
{
	Default { Scale 1.0; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		toucher.GiveBody(10);
		toucher.A_StartSound("loot/potion", CHAN_AUTO);
		Announce(st, "Apple", Font.CR_WHITE);
		return true;
	}
	States { Spawn: GEMS E -1; Stop; }
}

// Cooked fish: the cat's favourite. The cat casts twice as fast for 20 s.
class SICFish : SICLoot
{
	Default { Scale 1.0; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		let it = ThinkerIterator.Create("SICCat");
		let c = SICCat(it.Next());
		if (c) c.fishUntil = level.maptime + 35 * 20;
		toucher.A_StartSound("cat/meow", CHAN_AUTO);
		Announce(st, "Cooked Fish (the cat is pleased)", Font.CR_ORANGE);
		SICHandler.CatQuip("FISH! You may live. My spells are twice as fast now.");
		return true;
	}
	States { Spawn: GEMS F -1; Stop; }
}

// Gems: worth gold, sparkly
class SICGem : SICLoot
{
	int amount;
	Default { Scale 1.0; }
	override bool OnPickup(Actor toucher, SICStats st)
	{
		st.gold += amount;
		st.goldAt = level.maptime;
		toucher.A_StartSound("loot/gold2", CHAN_AUTO);
		Announce(st, lootName, LabelColor());
		return true;
	}
	States { Spawn: GEMS # -1; Stop; }
}

// Named gear: a Minecraft tool with Diablo affixes and a funny name. Grants a stat when picked up.
class SICGear : SICLoot
{
	int stat, value;   // 0 damage %, 1 speed %, 2 life regen
	Default { Scale 0.9; }

	static const String BASES[] = { "Iron Sword", "Golden Sword", "Diamond Sword", "Iron Axe", "Diamond Axe",
		"Iron Flail", "Golden Flail", "Golden Hammer", "Diamond Pickaxe", "Bow", "Diamond Hammer", "Golden Shovel" };
	static const String PREFIXES[] = { "Sharp", "Blocky", "Enchanted", "Pixelated", "Cursed", "Cat-Scratched",
		"Suspiciously Square", "Crafted", "Heavy", "Glowing", "Slightly Haunted", "Horadric" };
	static const String SUFFIXES[] = { "of the Whale", "of Mild Inconvenience", "of Nine Lives", "of Creeper Slaying",
		"of the Lazy Afternoon", "of Hairballs", "of Infinite Dirt", "of the Bat", "of Leeching", "of Speed",
		"of Fresh Meat", "of the Litter Box", "of Pure Smugness", "of Tuna" };
	static const String UNIQUES[] = { "The Grandfather Fishbone", "Windforce, but Square", "Stormshield of Cardboard",
		"Herobrine's Spork", "The Butcher's Other Cleaver", "Deckard's Litter Scoop", "Cain's Laser Pointer",
		"The Creeper's Regret", "Nine Lives Reaper", "The Diamond Hairball" };

	void Roll(int r)
	{
		rarity = r;
		frame = random(0, 11);
		String base = BASES[frame];
		if (r == 3) lootName = UNIQUES[random(0, UNIQUES.Size() - 1)];
		else if (r == 2) lootName = String.Format("%s %s %s", PREFIXES[random(0, PREFIXES.Size() - 1)], base, SUFFIXES[random(0, SUFFIXES.Size() - 1)]);
		else if (r == 1) lootName = random(0, 1) ? String.Format("%s %s", PREFIXES[random(0, PREFIXES.Size() - 1)], base) : String.Format("%s %s", base, SUFFIXES[random(0, SUFFIXES.Size() - 1)]);
		else lootName = base;
		stat = r >= 2 ? random(0, 2) : random(0, 1);
		value = stat == 2 ? r - 1 : 2 + r * 2;
	}

	override bool OnPickup(Actor toucher, SICStats st)
	{
		String bonus;
		if (stat == 0) { st.dmgPct += value; bonus = String.Format("+%d%% damage", value); }
		else if (stat == 1) { st.speedBonus += value / 200.; bonus = String.Format("+%d%% speed", value / 2); }
		else { st.regen += value; bonus = String.Format("+%d life per second", value); }
		st.items++;
		toucher.A_StartSound(rarity >= 2 ? "loot/rare" : "loot/drop", CHAN_AUTO, CHANF_UI);
		Announce(st, String.Format("%s (%s)", lootName, bonus), LabelColor());
		if (st.items == 1) SICHandler.CatIdentify();
		return true;
	}
	States { Spawn: LOOT # -1; Stop; }
}

// Minecraft XP orb: drifts to the player, pling.
class SICXPOrb : Actor
{
	int worth;
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+BRIGHT
		+NOINTERACTION
		Scale 0.32;
		RenderStyle "Add";
	}
	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		let p = players[consoleplayer].mo;
		if (!p) return;
		if (GetAge() < 18) { vel *= 0.9; return; }
		Vector3 to = level.Vec3Diff(pos, p.pos + (0, 0, 6));
		double d = to.Length();
		if (d < 44)
		{
			let st = SICStats.Of(p);
			if (st) st.AddXP(worth);
			p.A_StartSound("loot/xp", CHAN_AUTO, CHANF_OVERLAP, 0.5);
			Destroy();
			return;
		}
		vel = to / d * min(18, 4 + GetAge() * 0.25);
	}
	States { Spawn: GEMS C 2; GEMS C 2 { scale = (frandom(0.26, 0.36), frandom(0.26, 0.36)); } Loop; }
}

// Shootable TNT block (replaces the exploding barrel): blinks white on its fuse, then a big boom with block debris.
class SICTNT : ExplosiveBarrel replaces ExplosiveBarrel
{
	Default
	{
		Tag "TNT";
		Health 20;
		Radius 14;
		Height 30;
		Scale 0.68;
		DeathSound "tnt/fuse";
		Obituary "%o found out what TNT does.";
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	Death:
		TNTB B 4 A_Scream;
		TNTB A 4;
		TNTB B 4;
		TNTB A 3;
		TNTB B 3;
		TNTB A 2;
		TNTB B 2;
		TNT1 A 0 { SICTNT.Blast(self, 128, 160); }
		TNT1 A 2;
		TNT1 A 1050 A_BarrelDestroy;
		TNT1 A 5 A_Respawn;
		Wait;
	}

	static void Blast(Actor a, int dmg, int radius)
	{
		a.A_StartSound("tnt/boom", CHAN_AUTO, CHANF_DEFAULT, 1.0, 0.6);
		a.A_Explode(dmg, radius);
		a.A_QuakeEx(3, 3, 2, 14, 0, 500, "");
		SICPoofFX.Poof(a, 24);
		SICPoofFX.Embers(a, 30, 6);
		SICBit.Spray(a, 16, 0, 7, 10);
		SICBit.Spray(a, 10, 2, 8, 10);
		let f = Actor.Spawn("SICBoomFlash", a.pos + (0, 0, 20), ALLOW_REPLACE);
	}
}

// the white-orange flash of a TNT blast
class SICBoomFlash : Actor
{
	Default { +NOINTERACTION +BRIGHT RenderStyle "Add"; Scale 2.2; }
	States
	{
	Spawn:
		FBAL AB 2 { scale *= 1.35; A_FadeOut(0.18); }
		FBAL CDAB 2 { scale *= 1.15; A_FadeOut(0.18); }
		Stop;
	}
}
