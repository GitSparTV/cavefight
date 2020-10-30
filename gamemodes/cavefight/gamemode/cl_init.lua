include('shared.lua')

function GM:CalcView(ply, pos, ang, fov)
	local p, a = caveCalcView(ply, pos, ang)

	return {
		origin = p,
		angles = a,
		fov = 90,
		drawViewer = false
	}
end

function GM:SetupWorldFog()
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(500)
	render.FogEnd(2000)
	render.FogMaxDensity(0.5)
	render.FogColor(80, 80, 100)

	return true
end

local hiddenHud = {
	CHudAmmo = true,
	CHudBattery = true,
	CHudDamageIndicator = true,
	CHudCrosshair = true,
	CHudGeiger = true,
	CHudHealth = true,
	CHudPoisonDamageIndicator = true,
	CHudSecondaryAmmo = true,
	CHudSquadStatus = true,
	CHudTrain = true,
	CHudVehicle = true,
	CHudWeaponSelection = true,
	CHudZoom = true,
	CHUDQuickInfo = true,
	CHudSuitPower = true,
}

function GM:HUDShouldDraw(el)
	if hiddenHud[el] then return false end

	return true
end

local tips = {'[LMB] to shoot', '[RMB] to use hook', '[F3] to toggle firstperson/thirdperson', '[W/A/S/D] to fly', '[SHIFT] to accelerate', '[CTRL] to lower altitude', '[SPACE] to gain altitude',}

function GM:OnContextMenuOpen()
	for _, tip in ipairs(tips) do
		notification.AddProgress(tip, tip, 1)
	end
end

function GM:OnContextMenuClose()
	for _, tip in ipairs(tips) do
		notification.Kill(tip)
	end
end

local hudColor = Color(0, 200, 255, 255)
HUDColor = Color(0, 200, 255, 255)
local bgTint = Material('vgui/zoom')
local gradrt = Material('gui/gradient')

function GM:HUDPaintBackground()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(bgTint)
	local w, h = ScrW(), ScrH()
	surface.DrawTexturedRect(0, 0, w, h)
end

surface.CreateFont('CaveScore', {
	font = 'Roboto',
	size = 64
})

surface.CreateFont('CaveTimer', {
	font = 'Roboto',
	size = 24
})

surface.CreateFont('CaveMedium', {
	font = 'Roboto',
	size = 40
})

local Damaged, DamagedTime = false, 0
local Hit, HitTime, HitType, HitAmount = false, 0, false, 0

net.Receive("cave.hit", function()
	local dmg, target = net.ReadUInt(14), net.ReadEntity()
	if not target:IsValid() then return end

	if target == LocalPlayer() then
		Damaged = true
		DamagedTime = SysTime()
	else
		Hit = true
		HitAmount = dmg
		HitType = true
		HitTime = SysTime()
	end
end)

net.Receive('cave.kill', function(len)
	local attacker, driver = net.ReadEntity(), net.ReadEntity()
	notification.AddLegacy(attacker == driver and attacker:Nick() .. ' suicided' or attacker:Nick() .. ' killed ' .. driver:Nick(), NOTIFY_GENERIC, 3)

	if attacker == LocalPlayer() then
		Hit = true
		HitType = false
		HitTime = SysTime()
	end
end)

local redColor = Color(255, 0, 0)
local TraceResult = {}

local TraceData = {
	start = false,
	endpos = false,
	filter = false,
	output = TraceResult
}

function GM:HUDPaint()
	local w, h = ScrW(), ScrH()
	local driver = LocalPlayer()
	local ship = driver:GetShip()
	if not ship:IsValid() then return end
	-- local TraceData = TraceData
	-- TraceData.start = ship:GetPos()
	-- TraceData.endpos = TraceData.start + ship:GetForward() * 33000
	-- TraceData.filter = ship
	-- local tr = util.TraceLine(TraceData)
	-- TraceData.start = ship:GetPos()
	-- TraceData.endpos = tr.HitPos
	-- tr = util.TraceLine(TraceData)
	-- local pos = tr.HitPos:ToScreen()
	local pos = (ship:GetPos() + ship:GetForward() * 33000):ToScreen()
	local m = Matrix()
	DisableClipping(true)
	m:Translate(Vector(pos.x, pos.y, 0))
	surface.SetMaterial(gradrt)
	surface.SetDrawColor(hudColor)
	m:Rotate(Angle(0, ship:GetAngles()[3], 0))

	do
		cam.PushModelMatrix(m)
		local reload = ship.Reloading

		if reload then
			surface.SetAlphaMultiplier(0.7 + math.sin(SysTime() * 10) * 0.3)
		end

		draw.SimpleText(reload and "RELOADING" or ship.Ammo .. "/" .. 50, "CaveTimer", 70, -30, color_white, 1)

		if reload then
			surface.SetAlphaMultiplier(1)
		end

		surface.DrawTexturedRect(2 + ship:GetVelocity():Length() * 0.05, 0, 100, 2)
		cam.PopModelMatrix()
	end

	m:Rotate(Angle(0, 180, 0))

	do
		cam.PushModelMatrix(m)
		surface.DrawTexturedRect(2 + ship:GetVelocity():Length() * 0.05, -2, 100, 2)
		cam.PopModelMatrix()
	end

	if Hit then
		local delta = SysTime() - HitTime
		surface.SetAlphaMultiplier(1 - delta * 2)
		draw.SimpleText(HitType and "-" .. HitAmount .. " HIT" or "KILL", "CaveTimer", w / 2, h / 2 - 40, color_white, 1, 1)
		surface.SetAlphaMultiplier(1)

		if delta >= 0.5 then
			Hit = false
		end
	end

	DisableClipping(false)
	-- TraceData.endpos = TraceData.start + ship:GetForward() * 33000
	-- tr = util.TraceLine(TraceData)
	-- pos = tr.HitPos:ToScreen()
	surface.DrawCircle(w / 2, h / 2, 4)

	for k, v in ipairs(ents.FindByClass("ship")) do
		if v == ship then
			goto skip
		end

		local epos = v:GetPos() - v:GetVelocity() - ship:GetVelocity() * 1.1
		epos = epos:ToScreen()

		if not epos.visible then
			goto skip
		end

		local ewpos = v:GetPos():ToScreen()

		if not ewpos.visible then
			goto skip
		end

		surface.SetDrawColor(hudColor)
		surface.DrawLine(ewpos.x, ewpos.y, epos.x, epos.y)
		surface.DrawCircle(epos.x, epos.y, 6, math.abs((w / 2 - epos.x) + (h / 2 - epos.y)) > 2 and hudColor or redColor)
		::skip::
	end

	surface.SetDrawColor(hudColor)
	local hp = ship:Health() / ship:GetMaxHealth()
	surface.DrawRect(w / 3, h - 64, w / 3 * hp, 10)
	surface.DrawRect(w / 3 - 15, h - 74, 10, 30)
	surface.DrawRect(w / 3 * 2 + 5, h - 74, 10, 30)
	draw.SimpleText('Health', 'Trebuchet24', w / 2, h - 64, hudColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	draw.SimpleText(driver:Frags() .. '/' .. driver:Deaths(), 'CaveScore', ScrW() / 2, 0, hudColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	local tl = string.FormattedTime(timeleft())
	draw.SimpleText(string.format('%02i:%02i', tl.m, tl.s), 'CaveTimer', ScrW() / 2, 72, hudColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local ending = false
local waiting = false
local waitingFrom = 0
local loadingprogess, loadingprogessT, loadingprogessO = 0, 0, 0
local hudColorBG = Color(0, 100, 155, 255)
local tip = math.random(#tips)

local function oCuerp(t, d, b, c)
	return (c - b) * (math.pow(math.Clamp(t, 0, d) / d - 1, 3) + 1) + b
end

function GM:PostDrawHUD()
	local tl = timeleft()

	if tl < 8 then
		if not ending then
			ending = true
			self:ScoreboardShow()
			notification.AddLegacy('End of round!', NOTIFY_HINT, 5)
			loadingprogess = 0
			loadingprogessT = 0
			loadingprogessO = 0
			tip = math.random(#tips)
		else
			surface.SetDrawColor(0, 0, 0, (4 - tl / 2) * 255)
			surface.DrawRect(0, 0, ScrW(), ScrH())

			if tl <= 0 then
				if not waiting then
					self:ScoreboardHide()
					waiting = true
					waitingFrom = SysTime()
				else
					local delta = SysTime() - waitingFrom
					local w, h = ScrW(), ScrH()
					surface.SetAlphaMultiplier(delta)
					draw.SimpleText("Generating new map...", "CaveScore", w / 2, h / 2, color_white, 1, 1)
					draw.RoundedBox(4, w / 2 - 204, h / 2 + 46, 408, 68, hudColorBG)
					draw.RoundedBox(4, w / 2 - 200, h / 2 + 50, 400 * oCuerp(SysTime() - loadingprogessT, 1, loadingprogessO, loadingprogess), 60, hudColor)
					draw.SimpleText("Tip: " .. tips[tip], "CaveMedium", w / 2, h / 2 + 150, color_white, 1)
					surface.SetAlphaMultiplier(1)
				end
			end
		end
	elseif waiting then
		local delta = (CurTime() - roundStarted) / 2

		if delta > 1 then
			waiting = false
			ending = false
		end

		surface.SetDrawColor(0, 0, 0, 255 - (CurTime() - roundStarted) / 2 * 255)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
end

do
	local Color1 = Color(255, 255, 0)

	function GM:PreDrawHalos()
		halo.Add(ents.FindByClass('bomb'), Color1)
	end
end

function playSound(index, pos)
	sound.Play(sounds[index], pos, 75, 100, 1)
end

net.Receive("cave.restartProgress", function()
	loadingprogessT = SysTime()
	loadingprogessO = loadingprogess
	loadingprogess = net.ReadDouble()
end)

net.Receive('cave.sound', function(len)
	playSound(net.ReadUInt(16), net.ReadVector())
end)