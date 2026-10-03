// The SuperIntelligent Cat: your companion (Deckard Cain, but a cat in a wizard hat). Follows you a little behind
// and to the side, casts homing arcane bolts at demons, comments on everything, dances when a boss falls.
// Creepers fear cats: the Lord of Ssssterror runs from it (SICLord.SIC_FearCat).
class SICCat : Actor
{
	enum EMode { M_STAND, M_WALK, M_CAST, M_DANCE }
	int mode, castCool, lostFor, danceUntil, fishUntil;
	bool metLord;
	int sciAt; Actor foe;

	Default
	{
		Tag "SuperIntelligent Cat";
		Health 1000;
		Radius 14;
		Height 40;
		Scale 0.5;
		Speed 9;
		Mass 200;
		+SOLID
		+SHOOTABLE
		+NODAMAGE
		+FRIENDLY
		+NOTARGET
		+NOBLOOD
		+DROPOFF
		+NOBLOCKMONST
		+DONTTHRUST
		+PUSHABLE
		-COUNTKILL
		PainChance 0;
	}

	PlayerPawn Owner() { return players[consoleplayer].mo; }

	override void Tick()
	{
		Super.Tick();
		if (isFrozen()) return;
		let p = Owner();
		if (!p) return;
		if (castCool > 0) castCool--;

		if (level.maptime < danceUntil)
		{
			// the victory dance happens in front of the player, where everyone can see it
			Vector2 spot = p.Vec2Angle(110, p.angle);
			Vector2 dd = level.Vec2Diff(pos.xy, spot);
			if (dd.Length() > 90) BlinkTo(spot, p);
			else if (dd.Length() > 20) vel.xy = dd.Unit() * 6;
			else vel.xy = (0, 0);
			angle = AngleTo(p);
			SetMode(M_DANCE);
			return;
		}
		if (level.maptime % 8 == 0) foe = FindFoe(p);

		// stay a step behind the player, on the left, out of the line of fire;
		// but when the Lord of Ssssterror shows up, march at him: creepers fear cats
		Vector2 goal = p.Vec2Angle(150, p.angle + 46);   // ahead on the left: in view, out of the line of fire
		let lord = SICHandler.Get() ? SICHandler.Get().lord : null;
		if (lord && lord.health > 0 && Distance2D(lord) < 1400 && CheckSight(lord))
		{
			// first sight of the Lord: blink between him and the player, in view
			if (!metLord)
			{
				metLord = true;
				double dl = p.Distance2D(lord);
				if (!BlinkTo(p.Vec2Angle(min(260, dl * 0.55), p.AngleTo(lord) + 24), p)) BlinkTo(p.Vec2Angle(min(260, dl * 0.55), p.AngleTo(lord) - 24), p);
				A_StartSound("cat/hiss", CHAN_VOICE);
			}
			goal = lord.Vec2Angle(min(240, Distance2D(lord) - 40), lord.AngleTo(self));
			if (level.maptime % 70 == 0) A_StartSound("cat/hiss", CHAN_VOICE);
		}
		Vector2 d = level.Vec2Diff(pos.xy, goal);
		double far = d.Length();
		double distP = Distance2D(p);
		if (distP > 800 || (lostFor > 105))
		{
			Rejoin(p);
			return;
		}
		lostFor = CheckSight(p) ? 0 : lostFor + 1;

		if (foe && castCool <= 0)
		{
			Cast(foe);
			return;
		}
		if (mode == M_CAST && InStateSequence(CurState, ResolveState("Cast"))) { vel.xy *= 0.5; return; }

		if (far > 36)
		{
			double sp = far > 220 ? 15 : (far > 100 ? 10 : 6);
			Vector2 dir = d / far;
			vel.xy = dir * sp;
			angle = foe ? AngleTo(foe) : VectorAngle(dir.x, dir.y);
			SetMode(M_WALK);
		}
		else
		{
			vel.xy *= 0.6;
			angle = foe ? AngleTo(foe) : p.angle;
			SetMode(M_STAND);
		}
	}

	void SetMode(int m)
	{
		if (m == mode && !(m == M_CAST)) return;
		mode = m;
		switch (m)
		{
		case M_STAND: SetStateLabel("Stand"); break;
		case M_WALK: SetStateLabel("Walk"); break;
		case M_CAST: SetStateLabel("Cast"); break;
		case M_DANCE: SetStateLabel("Dance"); break;
		}
	}

	Actor FindFoe(PlayerPawn p)
	{
		// the SuperIntelligent move: demons standing next to TNT? shoot the TNT.
		let ti = ThinkerIterator.Create("SICTNT");
		SICTNT tnt;
		while (tnt = SICTNT(ti.Next()))
		{
			if (tnt.health <= 0 || Distance2D(tnt) > 1000 || Distance2D(tnt) < 160 || !CheckSight(tnt)) continue;
			int near = 0;
			let mi = BlockThingsIterator.Create(tnt, 140);
			while (mi.Next()) if (mi.thing.bIsMonster && mi.thing.health > 0 && !mi.thing.bFRIENDLY && tnt.Distance2D(mi.thing) < 140) near++;
			if (near >= 1 && p.Distance2D(tnt) > 200)
			{
				if (level.maptime > sciAt + 35 * 6) { sciAt = level.maptime; SICHandler.CatQuip("Demons next to TNT? Watch this. Science.", true); }
				return tnt;
			}
		}
		Actor best = null;
		double bd = 1100;
		let it = ThinkerIterator.Create("Actor"); Actor a;
		while (a = Actor(it.Next()))
		{
			if (!a.bIsMonster || a.health <= 0 || a.bFRIENDLY || a == self) continue;
			double dd = Distance2D(a);
			if (dd < bd && CheckSight(a)) { best = a; bd = dd; }
		}
		return best;
	}

	void Cast(Actor t)
	{
		angle = AngleTo(t);
		target = t;
		SetMode(M_CAST);
		vel.xy = (0, 0);
		castCool = level.maptime < fishUntil ? 18 : 38;
	}

	// a cat-wizard blink: poof here, poof there (only where it fits and the player can see it)
	bool BlinkTo(Vector2 xy, PlayerPawn p)
	{
		Vector3 old = pos;
		double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
		if (abs(z - p.pos.z) > 40) return false;
		SetOrigin((xy, z), false);
		if (!TestMobjLocation() || !CheckSight(p)) { SetOrigin(old, false); return false; }
		Vector3 here = pos;
		SetOrigin(old, false);
		SICPoofFX.Poof(self, 8);
		SetOrigin(here, false);
		SICPoofFX.Poof(self, 12);
		for (int i = 0; i < 10; i++)
			A_SpawnItemEx("SICSparkle", frandom(-10, 10), frandom(-10, 10), frandom(4, 40), 0, 0, frandom(0.5, 2), 0, SXF_NOCHECKPOSITION);
		vel = (0, 0, 0);
		return true;
	}

	void Rejoin(PlayerPawn p)
	{
		SICPoofFX.Poof(self, 10);
		Vector2 xy = p.Vec2Angle(64, p.angle + 150);
		SetOrigin((xy, p.pos.z), false);
		if (!TestMobjLocation()) SetOrigin(p.Vec3Angle(40, p.angle + 180), false);
		SICPoofFX.Poof(self, 10);
		A_StartSound("cat/meow", CHAN_VOICE);
		lostFor = 0;
	}

	void Dance(int tics)
	{
		danceUntil = level.maptime + tics;
		mode = -1;
		SetMode(M_DANCE);
	}

	action void SIC_Bolt()
	{
		if (!target || target.health <= 0) return;
		let m = A_SpawnProjectile("SICCatBolt", 26);
		if (m) m.tracer = target;
		for (int i = 0; i < 6; i++)
			A_SpawnItemEx("SICSparkle", 8, frandom(-8, 8), frandom(20, 44), frandom(-1, 1), frandom(-1, 1), frandom(0.5, 1.5), 0, SXF_NOCHECKPOSITION);
	}

	States
	{
	Spawn:
	Stand:
		CATS L 6;
		Loop;
	Walk:
		CATS ABCD 3;
		Loop;
	Cast:
		CATS K 6 Bright;
		CATS K 4 Bright SIC_Bolt;
		CATS K 6;
		CATS L 4;
		Goto Stand;
	Dance:
		CATS GHIJ 4;
		Loop;
	}
}
