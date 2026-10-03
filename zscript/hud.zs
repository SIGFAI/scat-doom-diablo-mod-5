// Diablo meets Minecraft on the HUD: the red life orb and the blue mana orb (ammo of the weapon in hand) on the
// sides, the Minecraft hotbar with the weapons in the middle, the green XP bar with your level, your gold.
class SICStatusBar : BaseStatusBar
{
	TextureID orbFrame, orbRed, orbBlue, orbEmpty, goldIcon;

	override void Init()
	{
		Super.Init();
		SetSize(0, 320, 200);
		orbFrame = TexMan.CheckForTexture("ORBFRAME", TexMan.Type_Any);
		orbRed = TexMan.CheckForTexture("ORBRED", TexMan.Type_Any);
		orbBlue = TexMan.CheckForTexture("ORBBLUE", TexMan.Type_Any);
		orbEmpty = TexMan.CheckForTexture("ORBEMPTY", TexMan.Type_Any);
		goldIcon = TexMan.CheckForTexture("GEMSA0", TexMan.Type_Sprite);
	}

	override void Draw(int state, double TicFrac)
	{
		Super.Draw(state, TicFrac);
		if (state == HUD_None || state == HUD_AltHud || !CPlayer || !CPlayer.mo) return;
		BeginHUD(1, false);
		double s = Screen.GetHeight() / 540.;
		let mo = CPlayer.mo;
		let st = SICStats.Of(mo);
		int H = Screen.GetHeight(), W = Screen.GetWidth();
		Font f = NewSmallFont;

		// orbs
		double ow = 104 * s, oh = 110 * s;
		double maxH = mo.GetMaxHealth(true);
		double life = clamp(mo.health / maxH, 0, 1);
		DrawOrb(orbRed, 14 * s, H - oh - 8 * s, ow, oh, life);
		String lt = String.Format("Life %d / %d", max(0, mo.health), int(maxH));
		Screen.DrawText(f, Font.CR_RED, 14 * s + (ow - f.StringWidth(lt) * s * 0.8) / 2, H - oh - 24 * s, lt, DTA_ScaleX, s * 0.8, DTA_ScaleY, s * 0.8);

		let wpn = CPlayer.ReadyWeapon;
		double mana = 1;
		String mt = "Mana  -";
		if (wpn && wpn.Ammo1)
		{
			mana = clamp(double(wpn.Ammo1.Amount) / max(1, wpn.Ammo1.MaxAmount / 2), 0, 1);
			mt = String.Format("Mana %d", wpn.Ammo1.Amount);
		}
		double mx = W - ow - 14 * s;
		DrawOrb(orbBlue, mx, H - oh - 8 * s, ow, oh, mana);
		Screen.DrawText(f, Font.CR_LIGHTBLUE, mx + (ow - f.StringWidth(mt) * s * 0.8) / 2, H - oh - 24 * s, mt, DTA_ScaleX, s * 0.8, DTA_ScaleY, s * 0.8);

		// gold
		if (st)
		{
			String g = String.Format("%d", st.gold);
			double gy = H - oh - 46 * s;
			double pulse = level.maptime - st.goldAt < 12 ? 1.25 : 1.0;
			if (goldIcon.IsValid())
				Screen.DrawTexture(goldIcon, false, mx + 10 * s, gy, DTA_DestWidthF, 16 * s, DTA_DestHeightF, 14 * s, DTA_TopOffset, 0, DTA_LeftOffset, 0);
			Screen.DrawText(f, Font.CR_GOLD, mx + 30 * s, gy, g .. " Gold", DTA_ScaleX, s * pulse, DTA_ScaleY, s * pulse);
		}

		DrawHotbar(mo, st, s, W, H, f);
	}

	void DrawOrb(TextureID liquid, double x, double y, double w, double h, double frac)
	{
		// the liquid level: wobbles a little, like Diablo's
		double wob = sin(level.maptime * 6) * 0.012;
		double top = y + h * (1 - clamp(frac + (frac > 0 && frac < 1 ? wob : 0), 0, 1));
		Screen.DrawTexture(orbEmpty, false, x, y, DTA_DestWidthF, w, DTA_DestHeightF, h, DTA_TopOffset, 0, DTA_LeftOffset, 0);
		Screen.DrawTexture(liquid, false, x, y, DTA_DestWidthF, w, DTA_DestHeightF, h, DTA_TopOffset, 0, DTA_LeftOffset, 0, DTA_ClipTop, int(top));
		Screen.DrawTexture(orbFrame, false, x, y, DTA_DestWidthF, w, DTA_DestHeightF, h, DTA_TopOffset, 0, DTA_LeftOffset, 0);
	}

	void DrawHotbar(PlayerPawn mo, SICStats st, double s, int W, int H, Font f)
	{
		double cell = 40 * s;
		double x0 = (W - cell * 9) / 2, y0 = H - cell - 10 * s;
		Screen.Dim(Color(20, 20, 20), 0.55, int(x0 - 3 * s), int(y0 - 3 * s), int(cell * 9 + 6 * s), int(cell + 6 * s));
		let ready = CPlayer.ReadyWeapon;
		for (int i = 0; i < 9; i++)
		{
			double cx = x0 + i * cell;
			Color edge = Color(255, 139, 139, 139);
			Screen.DrawThickLine(cx + 2 * s, y0 + 2 * s, cx + cell - 2 * s, y0 + 2 * s, 2 * s, edge);
			Screen.DrawThickLine(cx + 2 * s, y0 + cell - 2 * s, cx + cell - 2 * s, y0 + cell - 2 * s, 2 * s, Color(255, 60, 60, 60));
			Screen.DrawThickLine(cx + 2 * s, y0 + 2 * s, cx + 2 * s, y0 + cell - 2 * s, 2 * s, edge);
			Screen.DrawThickLine(cx + cell - 2 * s, y0 + 2 * s, cx + cell - 2 * s, y0 + cell - 2 * s, 2 * s, Color(255, 60, 60, 60));
		}
		// weapons by slot (1..9)
		for (let it = mo.Inv; it; it = it.Inv)
		{
			let w = Weapon(it);
			if (!w || w.SlotNumber < 1 || w.SlotNumber > 9) continue;
			double cx = x0 + (w.SlotNumber - 1) * cell;
			TextureID icon = GetInventoryIcon(w, 0);
			if (icon.IsValid())
			{
				Vector2 sz = TexMan.GetScaledSize(icon);
				double k = (cell - 10 * s) / max(sz.x, sz.y);
				Screen.DrawTexture(icon, false, cx + (cell - sz.x * k) / 2, y0 + (cell - sz.y * k) / 2, DTA_DestWidthF, sz.x * k, DTA_DestHeightF, sz.y * k, DTA_TopOffset, 0, DTA_LeftOffset, 0);
			}
			if (w.Ammo1)
			{
				String n = String.Format("%d", w.Ammo1.Amount);
				Screen.DrawText(f, Font.CR_WHITE, cx + cell - 4 * s - f.StringWidth(n) * s * 0.8, y0 + cell - 16 * s, n, DTA_ScaleX, s * 0.8, DTA_ScaleY, s * 0.8);
			}
			if (w == ready)
			{
				Color sel = Color(255, 255, 255, 255);
				double t = 3 * s;
				Screen.DrawThickLine(cx - t, y0 - t, cx + cell + t, y0 - t, t, sel);
				Screen.DrawThickLine(cx - t, y0 + cell + t, cx + cell + t, y0 + cell + t, t, sel);
				Screen.DrawThickLine(cx - t, y0 - t, cx - t, y0 + cell + t, t, sel);
				Screen.DrawThickLine(cx + cell + t, y0 - t, cx + cell + t, y0 + cell + t, t, sel);
			}
		}
		// XP bar and level, Minecraft green
		if (!st) return;
		double bw = cell * 9, by = y0 - 12 * s;
		Screen.Dim(Color(0, 0, 0), 0.8, int(x0), int(by), int(bw), int(6 * s));
		double fr = clamp(double(st.xp) / st.XPToNext(), 0, 1);
		Screen.Clear(int(x0), int(by), int(x0 + bw * fr), int(by + 6 * s), Color(255, 128, 255, 32));
		String lv = String.Format("%d", st.lvl);
		double k = s * 1.3;
		Screen.DrawText(f, Font.CR_GREEN, (W - f.StringWidth(lv) * k) / 2, by - 18 * s, lv, DTA_ScaleX, k, DTA_ScaleY, k);
	}
}
