// SuperIntelligent Cat: the rules of the mod. Story and dialogue, the quest chain (cleanse the cathedral, slay
// The Butcher, banish the Lord of Ssssterror), champion and unique monsters, loot fountains, XP, Fallen panic,
// the scripted demo waves (sic_demo), and everything drawn over the world (labels, damage numbers, banners).
class SICHandler : EventHandler
{
	// ---------------------------------------------------------------- state
	String sayWho, sayText;
	int sayColor, sayUntil, sayStart, nextQuip, quipIndex;
	String bannerText, bannerSub;
	int bannerColor, bannerUntil, bannerStart;

	int quest, questKills, questNeed, questAt;
	Actor butcher, lord;
	int bossDeadAt;

	Actor lookTarget;               // the monster under the crosshair (or the boss in view): name + health bar
	Array<Actor> lootNear;          // labels
	Array<Actor> specials;          // champions and uniques (their aura)
	Array<double> dmgX, dmgY, dmgZ;
	Array<int> dmgVal, dmgAt, dmgCol;
	int demoNext, demoWave;
	bool introDone;

	static const String UNIQUE_NAMES[] = { "Snagglemeow the Unwashed", "Rakanishoe", "Bonebreaker Steve",
		"Gharbad the Weakest", "Pixelface the Bloody", "Creepy Carl", "Sir Clicksalot", "Bishibash the Blocky",
		"Griswold's Ex", "Lord Notch-Eater" };
	static const String QUIPS[] = {
		"I have read every Horadric scroll. They taste like paper.",
		"Shoot the Fallen first. When one dies, the others panic. Like dogs.",
		"Did you know creepers fear cats? I am the cat.",
		"Gold is pointless. Buy me tuna.",
		"That skeleton had no guts. I checked.",
		"Diablo used to be scary. Now he is a square. Progress.",
		"Pick up that loot. Shiny things make you stronger. Also me.",
		"I could cast faster with a cooked fish. Just saying.",
		"Shoot the TNT when they gather around it. Science."
	};

	// ---------------------------------------------------------------- dialogue
	static SICHandler Get() { return SICHandler(EventHandler.Find("SICHandler")); }

	static void Say(String who, String text, int color = Font.CR_GOLD, int tics = 140)
	{
		let h = Get();
		if (!h) return;
		h.sayWho = who;
		h.sayText = text;
		h.sayColor = color;
		h.sayStart = level.maptime;
		h.sayUntil = level.maptime + tics;
		h.nextQuip = max(h.nextQuip, level.maptime + tics + 35 * 12);
	}

	static void CatSay(String text, Sound voice = "", int tics = 140)
	{
		Say("SuperIntelligent Cat", text, Font.CR_GOLD, tics);
		let p = players[consoleplayer].mo;
		if (p) p.A_StartSound(voice == "" ? Sound("cat/meow") : voice, CHAN_VOICE, CHANF_UI, 1.0, ATTN_NONE);
	}

	// a quip never cuts a line in progress (unless it matters right now)
	static void CatQuip(String text, bool force = false)
	{
		let h = Get();
		if (!h || (!force && level.maptime < h.sayUntil)) return;
		CatSay(text, "", 120);
	}

	static void CatIdentify() { CatSay("Let me identify that for you. Hmm. It is a stick. Meow.", "cat/identify", 120); }

	static void Banner(String text, String sub, int color, int tics = 105)
	{
		let h = Get();
		if (!h) return;
		h.bannerText = text;
		h.bannerSub = sub;
		h.bannerColor = color;
		h.bannerStart = level.maptime;
		h.bannerUntil = level.maptime + tics;
	}

	// ---------------------------------------------------------------- level start
	override void WorldLoaded(WorldEvent e)
	{
		S_ChangeMusic("TRISTRAM", 0, true, true);
		quest = 0;
		questKills = 0;
		nextQuip = 35 * 25;
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo) return;
		if (!mo.FindInventory("SICStats")) mo.GiveInventory("SICStats", 1);
		// the Minecraft arsenal replaces the Doom one (hands first, then the bow, then select the bow)
		if (!mo.FindInventory("SICPunch")) { mo.TakeInventory("Fist", 1); mo.GiveInventory("SICPunch", 1); }
		if (mo.FindInventory("Pistol"))
		{
			mo.TakeInventory("Pistol", 1);
			mo.GiveInventory("SICBow", 1);
		}
		let bow = Weapon(mo.FindInventory("SICBow"));
		if (bow) mo.player.PendingWeapon = bow;
		let it = ThinkerIterator.Create("SICCat");
		if (!it.Next())
		{
			let c = Actor.Spawn("SICCat", mo.Vec3Angle(64, mo.angle + 150), ALLOW_REPLACE);
			if (c) { if (!c.TestMobjLocation()) c.SetOrigin(mo.pos, false); SICPoofFX.Poof(c, 12); }
		}
	}

	bool Demo() { return sic_demo; }

	// ---------------------------------------------------------------- monsters
	clearscope static bool IsSIC(Actor a)
	{
		return a is "SICSkeleton" || a is "SICBurningDead" || a is "SICFallen" || a is "SICZombie" || a is "SICButcher" || a is "SICLord";
	}

	clearscope static bool IsBoss(Actor a) { return a is "SICButcher" || a is "SICLord" || a is "SICSkeletonKing"; }

	override void WorldThingSpawned(WorldEvent e)
	{
		let a = e.Thing;
		if (!a || !a.bIsMonster || a.bFRIENDLY || !IsSIC(a)) return;
		a.GiveInventory("SICTag", 1);
		let tg = SICTag(a.FindInventory("SICTag"));
		if (tg) tg.maxhp = a.health;   // for the health bar and the loot tier
		if (IsBoss(a)) return;
		int r = random(1, 100);
		if (r <= 4) MakeSpecial(a, 2);
		else if (r <= 14) MakeSpecial(a, 1);
	}

	// Diablo champions (blue, tougher) and uniques (gold, a silly name, much tougher, better loot)
	void MakeSpecial(Actor a, int kind)
	{
		if (!a) return;
		let tg = SICTag(a.FindInventory("SICTag"));
		if (!tg) { a.GiveInventory("SICTag", 1); tg = SICTag(a.FindInventory("SICTag")); }
		if (!tg) return;
		tg.kind = kind;
		if (kind == 2)
		{
			a.SetTag(UNIQUE_NAMES[random(0, UNIQUE_NAMES.Size() - 1)]);
			a.health *= 4;
			a.A_SetScale(a.scale.x * 1.18);
		}
		else
		{
			a.SetTag("Champion " .. a.GetTag());
			a.health = a.health * 5 / 2;
			a.A_SetScale(a.scale.x * 1.1);
			a.speed *= 1.25;
		}
		tg.maxhp = a.health;
		specials.Push(a);
	}

	override void WorldThingDamaged(WorldEvent e)
	{
		let a = e.Thing;
		if (!a || e.Damage <= 0 || a.player || a is "SICCat") return;
		if (!a.bIsMonster && !(a is "SICTNT")) return;
		dmgX.Push(a.pos.x + frandom(-8, 8));
		dmgY.Push(a.pos.y + frandom(-8, 8));
		dmgZ.Push(a.pos.z + a.height * 0.9);
		dmgVal.Push(min(e.Damage, max(a.health + e.Damage, 1), 999));
		dmgAt.Push(level.maptime);
		dmgCol.Push(e.Damage >= 40 ? Font.CR_ORANGE : (e.Inflictor is "SICCatBolt" ? Font.CR_LIGHTBLUE : Font.CR_WHITE));
	}

	override void WorldThingDied(WorldEvent e)
	{
		let a = e.Thing;
		if (!a || !a.bIsMonster || a.bFRIENDLY) return;
		let p = players[consoleplayer].mo;
		let st = SICStats.Of(p);
		if (st) st.kills++;
		int mh = SICTag.MaxOf(a), kind = SICTag.KindOf(a);
		int tier = mh <= 80 ? 1 : (mh <= 200 ? 2 : (mh <= 700 ? 3 : 4));
		if (IsBoss(a)) tier = 4;
		DropLoot(a, tier, kind);
		for (int i = 0; i < 2 + tier * 2; i++)
		{
			let o = SICXPOrb(Actor.Spawn("SICXPOrb", a.pos + (0, 0, 20), ALLOW_REPLACE));
			if (o) { o.worth = 3 + tier * 3; o.vel = (frandom(-3, 3), frandom(-3, 3), frandom(2, 5)); }
		}

		// Fallen panic when one of them falls (Diablo)
		if (a is "SICFallen")
		{
			bool any = false;
			let it = ThinkerIterator.Create("SICFallen");
			SICFallen f;
			while (f = SICFallen(it.Next()))
			{
				if (f == a || f.health <= 0 || f.Distance2D(a) > 700) continue;
				f.SIC_Panic(105);
				if (!any) f.A_StartSound("fallen/panic", CHAN_VOICE);
				any = true;
			}
			if (any && random(0, 2) == 0) CatQuip("Look at them run! The Fallen always panic when a friend drops.");
		}

		if (a == butcher)
		{
			butcher = null;
			quest = 2;
			questAt = level.maptime;
			bossDeadAt = level.maptime;
			Banner("QUEST COMPLETE", "The Butcher is dead. Something hisses in the dark...", Font.CR_GOLD);
			if (p) p.A_StartSound("quest/done", CHAN_AUTO, CHANF_UI, 1.0, ATTN_NONE);
			if (st) st.AddXP(150);
			CatDance(105);
		}
		else if (a == lord)
		{
			lord = null;
			quest = 4;
			questAt = level.maptime;
			Banner("THE LORD OF SSSSTERROR IS BANISHED", "The cathedral is saved. The cat demands tuna.", Font.CR_GOLD, 175);
			if (p) p.A_StartSound("quest/done", CHAN_AUTO, CHANF_UI, 1.0, ATTN_NONE);
			if (st) st.AddXP(400);
			CatDance(35 * 8);
			CatSay("Purrfect. The evil is vanquished. Now, feed me.", "cat/victory", 175);
		}
		else if (quest == 0)
		{
			questKills++;
			if (questKills >= questNeed)
			{
				quest = 1;
				questAt = level.maptime;
				Banner("QUEST COMPLETE", "The cathedral trembles. The Butcher smells fresh meat...", Font.CR_GOLD);
				if (p) p.A_StartSound("quest/done", CHAN_AUTO, CHANF_UI, 1.0, ATTN_NONE);
				if (st) st.AddXP(80);
			}
		}
	}

	void CatDance(int tics)
	{
		let it = ThinkerIterator.Create("SICCat");
		let c = SICCat(it.Next());
		if (c) c.Dance(tics);
	}

	// The loot fountain: gold always, potions, food, gems, named gear (more and better for champions and bosses)
	void DropLoot(Actor a, int tier, int special)
	{
		SpawnLoot(a, "SICGold", 0, random(3, 9) * tier * (special + 1));
		if (special || tier >= 3) SpawnLoot(a, "SICGold", 0, random(8, 20) * tier);
		if (random(1, 100) <= 28) SpawnLoot(a, "SICHealthPotion", 0, 0);
		if (random(1, 100) <= 20) SpawnLoot(a, "SICManaPotion", 0, 0);
		if (random(1, 100) <= 10) SpawnLoot(a, "SICApple", 0, 0);
		if (random(1, 100) <= 5 + tier * 2) SpawnLoot(a, "SICFish", 0, 0);
		if (random(1, 100) <= 8 * tier) SpawnLoot(a, "SICGem", random(1, 3), 0);
		int gear = tier >= 4 ? 3 : (random(1, 100) <= (tier == 1 ? 22 : (tier == 2 ? 40 : 65)) ? 1 : 0);
		gear += special;
		for (int i = 0; i < gear; i++)
		{
			int r = random(1, 100);
			int rar = r <= 2 ? 3 : (r <= 12 ? 2 : (r <= 40 ? 1 : 0));
			rar = min(3, rar + special);
			if (tier >= 4 && i == 0) rar = 3;
			SpawnLoot(a, "SICGear", rar, 0);
		}
	}

	void SpawnLoot(Actor a, Class<Actor> cls, int rarity, int amount)
	{
		let l = SICLoot(Actor.Spawn(cls, a.pos + (0, 0, max(20, a.height * 0.6)), ALLOW_REPLACE));
		if (!l) return;
		double ang = frandom(0, 360), sp = frandom(1.5, 4.5);
		l.vel = (cos(ang) * sp, sin(ang) * sp, frandom(6, 9.5));
		l.bDROPPED = true;
		if (l is "SICGold") { SICGold(l).amount = max(1, amount); l.lootName = String.Format("%d Gold", SICGold(l).amount); l.rarity = 0; }
		else if (l is "SICGem")
		{
			l.frame = rarity;    // 1 ruby, 2 emerald, 3 diamond
			static const String GEM[] = { "Gold Nugget", "Ruby", "Emerald", "Diamond" };
			l.lootName = GEM[rarity];
			SICGem(l).amount = 25 * rarity;
			l.rarity = rarity == 3 ? 2 : 1;
		}
		else if (l is "SICGear") SICGear(l).Roll(rarity);
		else
		{
			l.rarity = 0;
			if (l is "SICHealthPotion") l.lootName = "Potion of Healing";
			else if (l is "SICManaPotion") l.lootName = "Potion of Mana";
			else if (l is "SICApple") l.lootName = "Apple";
			else if (l is "SICFish") l.lootName = "Cooked Fish";
		}
	}

	// ---------------------------------------------------------------- spawning near the player, in view
	Actor SpawnInView(PlayerPawn mo, Class<Actor> cls, double minD, double maxD, double cone = 50)
	{
		for (int i = 0; i < 40; i++)
		{
			Vector2 xy = mo.Vec2Angle(frandom(minD, maxD), mo.angle + frandom(-cone, cone));
			if (!level.IsPointInLevel((xy, mo.pos.z + 8))) continue;
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 96) continue;
			let m = Actor.Spawn(cls, (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(mo))
			{
				m.ClearCounters();
				m.Destroy();
				continue;
			}
			m.angle = m.AngleTo(mo);
			if (m.bIsMonster)
			{
				m.target = mo;
				SICPoofFX.Poof(m, 12);
			}
			return m;
		}
		return null;
	}

	// a monster right next to another thing (demons gathered around a TNT block)
	Actor SpawnAround(Actor c, Class<Actor> cls, PlayerPawn mo)
	{
		if (!c) return SpawnFront(mo, cls);
		for (int i = 0; i < 24; i++)
		{
			Vector2 xy = c.Vec2Angle(frandom(40, 90), frandom(0, 360));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - c.pos.z) > 24) continue;
			let m = Actor.Spawn(cls, (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(mo)) { m.ClearCounters(); m.Destroy(); continue; }
			m.angle = m.AngleTo(mo);
			m.target = mo;
			SICPoofFX.Poof(m, 12);
			return m;
		}
		return SpawnFront(mo, cls);
	}

	// in front first, then wider, then anywhere around: corridors leave little room
	Actor SpawnFront(PlayerPawn mo, Class<Actor> cls, double cone = 25)
	{
		let m = SpawnInView(mo, cls, 300, 520, cone);
		if (!m) m = SpawnInView(mo, cls, 220, 640, 65);
		if (!m) m = SpawnInView(mo, cls, 180, 800, 180);
		return m;
	}

	void SpawnBoss(int which)
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		if (which == 1)
		{
			butcher = SpawnInView(mo, "SICButcher", 380, 700, 40);
			if (!butcher) butcher = SpawnInView(mo, "SICButcher", 200, 900, 180);
			if (butcher)
			{
				butcher.A_StartSound("butcher/sight", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
				Say("The Butcher", "Ah... fresh meat!", Font.CR_RED, 70);
				questAt = level.maptime;
			}
		}
		else
		{
			lord = SpawnInView(mo, "SICLord", 340, 560, 30);
			if (!lord) lord = SpawnInView(mo, "SICLord", 250, 1000, 180);
			if (lord)
			{
				lord.A_StartSound("diablo/sight", CHAN_VOICE, CHANF_DEFAULT, 1.0, ATTN_NONE);
				SICPoofFX.Embers(lord, 60, 8);
				A_QuakeAll(lord);
				quest = 3;
				questAt = level.maptime;
			}
		}
	}

	static void A_QuakeAll(Actor a) { a.A_QuakeEx(4, 4, 3, 50, 0, 3000, ""); }

	// ---------------------------------------------------------------- every tic
	override void WorldTick()
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		int t = level.maptime;
		questNeed = Demo() ? 5 : 12;

		if (!introDone && t >= 35)
		{
			introDone = true;
			CatSay("Stay awhile and listen! The cathedral has turned into blocks, and the Lord of Terror is now a Creeper. Luckily for you, creepers fear cats.", "cat/intro", 35 * 7);
			Banner("THE BLOCKY CATHEDRAL", "Quest: slay the demons of the cathedral", Font.CR_GOLD, 105);
		}

		// the quest chain
		if (quest == 1 && !butcher && t - questAt >= 35 * 3)
		{
			CatSay("The Butcher is coming. He smells like pork chops. Do not let him make you into one.", "cat/butcher", 35 * 5);
			SpawnBoss(1);
			if (!butcher) questAt = t;  // no room yet: retry
		}
		if (quest == 2 && !lord && t - questAt >= 35 * 4)
		{
			SpawnBoss(2);
			if (lord) CatSay("Hsssss! Lord of Ssssterror! Meet your worst nightmare: a cat.", "cat/diablo", 35 * 5);
			else questAt = t;
		}
		if (quest == 1 && butcher && butcher.health <= 0) butcher = null;

		if (Demo()) DemoTick(mo, t);

		// the cat comments now and then
		if (t >= nextQuip && t > sayUntil)
		{
			CatQuip(QUIPS[quipIndex % QUIPS.Size()]);
			quipIndex++;
			nextQuip = t + 35 * random(18, 26);
		}

		if (t % 4 == 0) Scan(mo);
		Auras(t);

		// old damage numbers out
		while (dmgAt.Size() && t - dmgAt[0] > 45)
		{
			dmgX.Delete(0); dmgY.Delete(0); dmgZ.Delete(0); dmgVal.Delete(0); dmgAt.Delete(0); dmgCol.Delete(0);
		}
	}

	// Scripted waves for the stream demo: content in view from the first seconds, a TNT block among them.
	void DemoTick(PlayerPawn mo, int t)
	{
		mo.player.cheats |= CF_GODMODE;
		// the stream bot never looks at the ceiling (a stray mouse on the stream desktop pitches the view)
		if (abs(mo.pitch) > 0.5) mo.A_SetPitch(mo.pitch * 0.8, SPF_INTERPOLATE);
		if (t == 2)
		{
			// the stage: only the mod's monsters, in front of the player (the map's own hide behind walls)
			let mi = ThinkerIterator.Create("Actor"); Actor m;
			while (m = Actor(mi.Next()))
			{
				if (m.bIsMonster && !m.bFRIENDLY && m.health > 0) { m.ClearCounters(); m.Destroy(); }
			}
		}
		if (t == 20)
		{
			mo.GiveInventory("SICFireStaff", 1);
			mo.GiveInventory("SICTNTLauncher", 1);
			mo.GiveInventory("Shell", 40);
			mo.GiveInventory("RocketAmmo", 20);
			mo.GiveInventory("Clip", 100);
			mo.player.PendingWeapon = Weapon(mo.FindInventory("SICFireStaff"));
			demoNext = 50;
		}
		// bosses get the TNT, the rest the Fire Staff
		if (t > 50 && t % 10 == 5)
		{
			bool boss = (butcher && butcher.health > 0) || (lord && lord.health > 0);
			let want = Weapon(mo.FindInventory(boss ? "SICTNTLauncher" : "SICFireStaff"));
			if (want && mo.player.ReadyWeapon != want && mo.player.PendingWeapon != want) mo.player.PendingWeapon = want;
		}
		if (demoNext == 0 || t < 50 || t % 10) return;
		if (t < demoNext - 35 * 4) return;
		int alive = 0;
		let it = ThinkerIterator.Create("Actor"); Actor a;
		while (a = Actor(it.Next())) if (a.bIsMonster && a.health > 0 && !a.bFRIENDLY) alive++;
		// a new wave on time, or right away when the room is clear
		if (t < demoNext && !(alive == 0 && t > demoNext - 35 * 4)) return;
		demoWave++;
		if (alive < 6)
		{
			switch (demoWave % 4)
			{
			case 1:
			{
				let tnt = demoWave == 1 ? SpawnInView(mo, "SICTNT", 300, 420, 12) : null;
				SpawnAround(tnt, "SICFallen", mo);
				SpawnAround(tnt, "SICFallen", mo);
				SpawnAround(tnt, "SICSkeleton", mo);
				break;
			}
			case 2:
				SpawnFront(mo, "SICZombie");
				SpawnFront(mo, "SICBurningDead");
				SpawnFront(mo, "SICFallen");
				break;
			case 3:
			{
				let tnt = SpawnInView(mo, "SICTNT", 300, 460, 20);
				MakeSpecial(SpawnAround(tnt, "SICFallen", mo), 1);
				SpawnAround(tnt, "SICFallen", mo);
				SpawnAround(tnt, "SICSkeleton", mo);
				break;
			}
			case 0:
				MakeSpecial(SpawnFront(mo, "SICSkeleton"), 2);
				SpawnFront(mo, "SICZombie");
				break;
			}
		}
		demoNext = t + 35 * (quest >= 1 && quest < 4 ? 11 : 7);
	}

	// what the HUD shows: the monster you aim at (else the boss), the loot around
	void Scan(PlayerPawn mo)
	{
		FLineTraceData d;
		lookTarget = null;
		if (mo.LineTrace(mo.angle, 2000, mo.pitch, 0, mo.player.viewheight, data: d) && d.HitType == TRACE_HitActor && d.HitActor.bIsMonster && d.HitActor.health > 0)
			lookTarget = d.HitActor;
		if (!lookTarget)
		{
			if (lord && lord.health > 0 && mo.CheckSight(lord)) lookTarget = lord;
			else if (butcher && butcher.health > 0 && mo.CheckSight(butcher)) lookTarget = butcher;
		}
		lootNear.Clear();
		let it = ThinkerIterator.Create("SICLoot");
		SICLoot l;
		while (l = SICLoot(it.Next()))
		{
			if (l.Owner) continue;
			double dd = mo.Distance3D(l);
			if (dd < 900)
			{
				int at = 0;
				while (at < lootNear.Size() && mo.Distance3D(lootNear[at]) < dd) at++;
				if (at < 10) lootNear.Insert(at, l);
				if (lootNear.Size() > 10) lootNear.Pop();
			}
			// Minecraft item magnet: landed loot close to you flies into your pocket
			double pull = Demo() ? 260 : 110;
			if (l.landed && l.age > 25 && dd < pull)
			{
				Vector3 to = level.Vec3Diff(l.pos, mo.pos);
				to.z = 0;
				l.vel = to.Unit() * 8;
				l.bNOGRAVITY = true;
			}
		}
	}

	void Auras(int t)
	{
		if (t % 3) return;
		for (int i = specials.Size() - 1; i >= 0; i--)
		{
			let a = specials[i];
			if (!a || a.health <= 0) { specials.Delete(i); continue; }
			Color c = SICTag.KindOf(a) == 2 ? Color(255, 190, 40) : Color(70, 130, 255);
			for (int k = 0; k < 2; k++)
				a.A_SpawnParticle(c, SPF_FULLBRIGHT, 24, 5, 0, frandom(-a.radius, a.radius), frandom(-a.radius, a.radius), frandom(0, a.height), 0, 0, frandom(0.5, 1.5), startalphaf: 0.9, fadestepf: 0.04);
		}
	}

	// ---------------------------------------------------------------- drawing over the world
	ui Vector3 Project(RenderEvent e, Vector3 wp)
	{
		Vector3 d = level.Vec3Diff(e.ViewPos, wp);
		double ca = cos(e.ViewAngle), sa = sin(e.ViewAngle);
		double fwd = d.x * ca + d.y * sa;
		double side = d.x * sa - d.y * ca;
		double up = d.z * 1.2;
		double cp = cos(e.ViewPitch), sp = sin(e.ViewPitch);
		double depth = fwd * cp - up * sp;
		double y = up * cp + fwd * sp;
		if (depth < 8) return (0, 0, -1);
		double W = Screen.GetWidth(), H = Screen.GetHeight();
		double fov = players[consoleplayer].FOV;
		double tv = tan(fov / 2) * 0.75;
		double sx = W / 2 + side / depth / (tv * W / H) * W / 2;
		double sy = H / 2 - y / depth / tv * H / 2;
		return (sx, sy, depth);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (automapactive) return;
		double s = Screen.GetHeight() / 540.;
		DrawLootLabels(e, s);
		DrawDamage(e, s);
		DrawTargetBar(s);
		DrawQuest(s);
		DrawPickup(s);
		DrawBanner(s);
		DrawSay(s);
	}

	ui void DrawLootLabels(RenderEvent e, double s)
	{
		Font f = NewSmallFont;
		Array<double> rx, ry, rw, rh;   // labels already drawn: the next one moves up instead of overlapping
		for (int i = 0; i < lootNear.Size(); i++)
		{
			let l = SICLoot(lootNear[i]);
			if (!l || !l.landed) continue;
			Vector3 p = Project(e, l.pos + (0, 0, 22));
			if (p.z < 0 || p.z > (l.rarity >= 1 ? 800 : 260)) continue;
			double k = clamp(1.4 - p.z / 900., 0.55, 1.0) * s;
			String t = l.lootName;
			double w = f.StringWidth(t) * k;
			double lh = f.GetHeight() * k + 4 * k;
			for (int tries = 0; tries < 8; tries++)
			{
				bool hit = false;
				for (int j = 0; j < rx.Size(); j++)
				{
					if (abs(rx[j] - p.x) < (rw[j] + w) / 2 && abs(ry[j] - p.y) < lh) { hit = true; break; }
				}
				if (!hit) break;
				p.y -= lh;
			}
			rx.Push(p.x); ry.Push(p.y); rw.Push(w); rh.Push(lh);
			Screen.Dim(0, 0.6, int(p.x - w / 2 - 3 * k), int(p.y - 2 * k), int(w + 6 * k), int(f.GetHeight() * k + 3 * k));
			Screen.DrawText(f, l.LabelColor(), p.x - w / 2, p.y, t, DTA_ScaleX, k, DTA_ScaleY, k);
		}
	}

	ui void DrawDamage(RenderEvent e, double s)
	{
		Font f = BigFont;
		for (int i = 0; i < dmgVal.Size(); i++)
		{
			double age = (level.maptime - dmgAt[i]) + e.FracTic;
			Vector3 p = Project(e, (dmgX[i], dmgY[i], dmgZ[i] + age * 0.9));
			if (p.z < 0) continue;
			double k = s * clamp(1.2 - p.z / 1600., 0.5, 1.1) * 0.7;
			double alpha = clamp(1.0 - age / 45., 0, 1);
			String t = String.Format("%d", dmgVal[i]);
			Screen.DrawText(f, dmgCol[i], p.x - f.StringWidth(t) * k / 2, p.y, t, DTA_ScaleX, k, DTA_ScaleY, k, DTA_Alpha, alpha);
		}
	}

	// Diablo: name and life bar of what you aim at, at the top of the screen
	ui void DrawTargetBar(double s)
	{
		let a = lookTarget;
		if (!a || a.health <= 0) return;
		Font f = NewSmallFont;
		int W = Screen.GetWidth();
		int bw = int(300 * s), bh = int(14 * s), x = (W - bw) / 2, y = int(14 * s);
		double frac = clamp(double(a.health) / max(1, SICTag.MaxOf(a)), 0, 1);
		int kind = SICTag.KindOf(a);
		Screen.Dim(0, 0.7, x - int(3 * s), y - int(3 * s), bw + int(6 * s), bh + int(6 * s));
		Screen.Clear(x, y, x + int(bw * frac), y + bh, Color(255, 170, 16, 16));
		Screen.Clear(x, y, x + int(bw * frac), y + bh / 3, Color(255, 220, 60, 50));
		String n = a.GetTag();
		int col = kind == 2 ? Font.CR_GOLD : (kind == 1 ? Font.CR_LIGHTBLUE : (IsBoss(a) ? Font.CR_ORANGE : Font.CR_WHITE));
		double k = s * 1.1;
		Screen.DrawText(f, col, (W - f.StringWidth(n) * k) / 2, y + bh + 5 * s, n, DTA_ScaleX, k, DTA_ScaleY, k);
		if (kind)
		{
			String sub = kind == 2 ? "Unique  -  Extra Strong, Cursed Loot" : "Champion  -  Extra Strong";
			Screen.DrawText(f, Font.CR_GRAY, (W - f.StringWidth(sub) * s * 0.8) / 2, y + bh + 22 * s, sub, DTA_ScaleX, s * 0.8, DTA_ScaleY, s * 0.8);
		}
	}

	ui void DrawQuest(double s)
	{
		Font f = NewSmallFont;
		int W = Screen.GetWidth();
		String title = "QUEST", line;
		if (quest == 0) line = String.Format("Slay the demons of the cathedral  %d / %d", questKills, questNeed);
		else if (quest == 1) line = "Slay The Butcher";
		else if (quest == 2) line = "Something hisses in the dark...";
		else if (quest == 3) line = "Banish the Lord of Ssssterror";
		else line = "Done! The cat demands tuna.";
		double k = s * 0.95;
		double tw = max(f.StringWidth(line), 120) * k;
		int x = int(W - tw - 22 * s), y = int(64 * s);
		Screen.Dim(0, 0.55, x - int(8 * s), y - int(6 * s), int(tw + 16 * s), int(42 * s));
		Screen.DrawText(f, Font.CR_GOLD, x, y, title, DTA_ScaleX, k, DTA_ScaleY, k);
		Screen.DrawText(f, quest >= 4 ? Font.CR_GREEN : Font.CR_WHITE, x, y + 16 * s, line, DTA_ScaleX, k, DTA_ScaleY, k);
	}

	ui void DrawPickup(double s)
	{
		let st = SICStats.Of(players[consoleplayer].mo);
		if (!st || st.lastItem == "" || level.maptime - st.lastAt > 70) return;
		Font f = NewSmallFont;
		double k = s * 1.15;
		double a = clamp((70 - (level.maptime - st.lastAt)) / 20., 0, 1);
		String t = "+ " .. st.lastItem;
		Screen.DrawText(f, st.lastColor, (Screen.GetWidth() - f.StringWidth(t) * k) / 2, Screen.GetHeight() * 0.62, t, DTA_ScaleX, k, DTA_ScaleY, k, DTA_Alpha, a);
		if (level.maptime - st.levelAt < 90 && st.levelAt > 0)
		{
			String lv = String.Format("LEVEL UP!  Level %d  (+3%% damage, full life)", st.lvl);
			Screen.DrawText(f, Font.CR_GOLD, (Screen.GetWidth() - f.StringWidth(lv) * k) / 2, Screen.GetHeight() * 0.62 - 22 * s, lv, DTA_ScaleX, k, DTA_ScaleY, k);
		}
	}

	ui void DrawBanner(double s)
	{
		if (level.maptime >= bannerUntil) return;
		double age = level.maptime - bannerStart;
		double a = clamp(min(age / 10., (bannerUntil - level.maptime) / 15.), 0, 1);
		Font f = BigFont;
		double k = s * 1.4;
		int W = Screen.GetWidth();
		int y = int(Screen.GetHeight() * 0.33);
		Screen.Dim(0, 0.55 * a, 0, y - int(10 * s), W, int(70 * s));
		Screen.DrawText(f, bannerColor, (W - f.StringWidth(bannerText) * k) / 2, y, bannerText, DTA_ScaleX, k, DTA_ScaleY, k, DTA_Alpha, a);
		Font sf = NewSmallFont;
		Screen.DrawText(sf, Font.CR_WHITE, (W - sf.StringWidth(bannerSub) * s) / 2, y + 34 * s, bannerSub, DTA_ScaleX, s, DTA_ScaleY, s, DTA_Alpha, a);
	}

	// Diablo-style dialogue box: a portrait of the speaker, the name in color, the line typed out.
	ui void DrawSay(double s)
	{
		if (level.maptime >= sayUntil || sayText == "") return;
		Font f = NewSmallFont;
		int w = Screen.GetWidth();
		int boxW = int(430 * s), boxH = int(76 * s);
		int x = int(12 * s), y = int(66 * s);
		Screen.Dim(0, 0.75, x, y, boxW, boxH);
		Color gold = Color(255, 170, 130, 50);
		Screen.DrawThickLine(x, y, x + boxW, y, 2 * s, gold);
		Screen.DrawThickLine(x, y + boxH, x + boxW, y + boxH, 2 * s, gold);
		int tx = x + int(14 * s);
		if (sayWho.IndexOf("Cat") >= 0)
		{
			TextureID face = TexMan.CheckForTexture("CATSK1", TexMan.Type_Sprite);
			if (face.IsValid())
			{
				Vector2 sz = TexMan.GetScaledSize(face);
				double ph = 64 * s;
				Screen.DrawTexture(face, false, x + 8 * s, y + 6 * s, DTA_DestWidthF, sz.x * ph / sz.y, DTA_DestHeightF, ph, DTA_TopOffset, 0, DTA_LeftOffset, 0);
				tx = x + int((16 + 64 * sz.x / sz.y) * s);
			}
		}
		int shown = min(sayText.CodePointCount(), (level.maptime - sayStart) * 2);
		String t = sayText.Left(shown);
		Screen.DrawText(f, sayColor, tx, y + 7 * s, sayWho, DTA_ScaleX, s * 1.1, DTA_ScaleY, s * 1.1);
		double avail = (x + boxW - tx) / s - 14;
		BrokenLines lines = f.BreakLines(t, int(avail));
		for (int i = 0; i < lines.Count() && i < 3; i++)
			Screen.DrawText(f, Font.CR_WHITE, tx, y + (27 + i * 15) * s, lines.StringAt(i), DTA_ScaleX, s, DTA_ScaleY, s);
	}
}
