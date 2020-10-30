AddCSLuaFile('cl_init.lua')
include('shared.lua')
util.AddNetworkString('cave.applyBonus')
util.AddNetworkString('cave.removeBonus')
util.AddNetworkString('cave.ship.attack')
util.AddNetworkString('cave.ship.reload')
local minRespRadius, maxRespRadius = caveMapSize / 6, caveMapSize / 6 * 2
local respRange = maxRespRadius - minRespRadius
local tr = {}

function ENT:Reactivate()
	local r, a = minRespRadius + math.random() * respRange, math.random() * math.pi * 2
	local x, y = math.cos(a) * r, math.sin(a) * r
	constraint.RemoveAll(self)
	local pos = Vector(x, y, caveHeightAtPoint(caveSeed, x, y) + caveMaxCeil / 2)
	tr.start = pos
	tr.endpos = pos - Vector(0, 0, 1000)
	local tr1 = util.TraceLine(tr)
	tr.endpos = pos + Vector(0, 0, 1000)
	local tr2 = util.TraceLine(tr)

	if not tr1.Hit or not tr1.Entity:IsValid() then
		pos = tr2.HitPos + Vector(0, 0, 20)
	end

	if not tr2.Hit or not tr2.Entity:IsValid() then
		pos = tr1.HitPos - Vector(0, 0, 20)
	end

	self:SetPos(pos)
	self:SetAngles(angle_zero)
	self:SetMaxHealth(1000)
	self:SetHealth(self:GetMaxHealth())
	self.Ammo = 50
	self.Reloading = false
	local p = self:GetPhysicsObject()
	self:SetLights(true)
	p:EnableGravity(false)
	p:SetVelocity(vector_origin)
	local sparks = EffectData()
	sparks:SetOrigin(self:GetPos())
	util.Effect('cball_bounce', sparks, true, true)
	net.Start("cave.ship.reload")
	net.Send(self:GetDriver())
	playSound(SOUND_RESPAWN, self:GetPos())
	local driver = self:GetDriver()
	self.Died = false
	driver:SetEyeAngles(angle_zero)
end

do
	local function BulletHole(ent, tr, dmg)
		if tr.Entity:GetClass() ~= "ship" then return end
		local trace = EffectData()
		trace:SetOrigin(tr.HitPos)
		trace:SetNormal(tr.HitNormal)
		local dist = ent:GetShip():GetPos():Distance(tr.HitPos) / 50
		dmg:SubtractDamage(math.min(dmg:GetDamage(), dist))
		trace:SetRadius(0.5 + dist / 50)
		util.Effect('AR2Explosion', trace, true, true)
	end

	local BulletData = {
		Attacker = false,
		Damage = false,
		Force = false,
		Spread = Vector(0.02, 0.02, 0),
		IgnoreEntity = false,
		Src = false,
		Dir = false,
		HullSize = 10,
		TracerName = 'AR2Tracer',
		Callback = BulletHole
	}

	local TraceResult = {}

	local TraceInfo = {
		start = false,
		endpos = false,
		filter = false,
		output = TraceResult
	}

	function ENT:FireBullet(driver)
		local t = CurTime()

		if not self.Reloading and self.Ammo > 0 and t - (self.lastBullet or 0) > 0.2 then
			self.lastBullet = t
			self.Ammo = self.Ammo - 1
			driver:LagCompensation(true)
			local pos = self:GetPos()

			do
				local BulletData = BulletData
				BulletData.Attacker = driver
				BulletData.Damage = (self.dmg and 250 or 100) + math.random(-10, 10)
				BulletData.Force = self.dmg and 10 or 5
				BulletData.IgnoreEntity = self
				BulletData.Src = pos
				BulletData.Dir = self:GetForward()
				self:FireBullets(BulletData)
			end

			driver:LagCompensation(false)
			local muzzleFlash = EffectData()
			muzzleFlash:SetOrigin(self:LocalToWorld(Vector(15, 0, 0)))
			muzzleFlash:SetAngles(self:GetAngles())
			muzzleFlash:SetScale(1)
			util.Effect('MuzzleEffect', muzzleFlash, true, true)
			net.Start("cave.ship.attack")
			net.Send(driver)
			playSound(SOUND_SHOOT, self:GetPos())
		end
	end
end

function ENT:Reload()
	if self.Reloading then return end
	self.Reloading = true
	self.ReloadingStart = CurTime()
end

function ENT:Think()
	if self.Reloading and CurTime() - self.ReloadingStart > 5 then
		self.Ammo = 50
		self.Reloading = false
		net.Start("cave.ship.reload")
		net.Send(self:GetDriver())
	end
end

function ENT:ToggleLight()
	self:SetLights(not self:GetLights())
end

do
	local TraceResult = {}

	local TraceInfo = {
		start = false,
		endpos = false,
		filter = false,
		output = TraceResult
	}

	local hookDist = 300

	function ENT:FireHook(driver)
		if self.hook and self.hook:IsValid() then return end
		driver:LagCompensation(true)
		local eyePos, eyeAng = caveCalcView(driver, driver:EyePos(), driver:EyeAngles())
		local TraceInfo = TraceInfo

		do
			TraceInfo.start = eyePos

			do
				local f = eyeAng:Forward()
				f:Mul(hookDist)
				TraceInfo.endpos = eyePos + f
			end

			TraceInfo.filter = self
		end

		local tr = util.TraceLine(TraceInfo)
		if not tr.Entity:IsValid() then return end
		local pos = self:GetPos()

		do
			TraceInfo.start = pos
			TraceInfo.endpos = tr.HitPos
			tr = util.TraceLine(TraceInfo)
		end

		driver:LagCompensation(false)
		local ent = tr.Entity
		if not ent:IsValid() then return end
		local len = (tr.HitPos - pos):Length()
		self.hook = constraint.Rope(self, ent, 0, 0, vector_origin, ent:WorldToLocal(tr.HitPos), len, 0, 0, 10, 'cable/physbeam', false)

		if ent.SetLastHooker then
			ent:SetLastHooker(driver)
		end
	end
end

local proj_xy = Vector(1, 1, 0)
local maxVel = 400
local accel = 1
local rotAccel = 0.1
local shake = 1

function ENT:PhysicsUpdate(p)
	if self.Died then return end
	local oldRot = p:GetAngleVelocity()
	local rot = Vector(0, 0, 0)
	local vel = p:GetVelocity() * 0.99
	local driver = self:GetDriver()

	if driver:IsValid() then
		local ang = driver:EyeAngles()
		local fwd = ang:Forward()
		local rt = ang:Right()
		local up = ang:Up()
		local tilt

		do
			local a, b = self:GetForward() * proj_xy, rt * proj_xy
			a:Normalize()
			b:Normalize()
			tilt = a:Dot(b) * -40
		end

		ang = ang + Angle(0, 0, tilt)
		local acc = driver:KeyDown(IN_SPEED) and (accel * 3) or accel

		if driver:KeyDown(IN_BACK) then
			vel = vel - fwd * acc / 2
		elseif driver:KeyDown(IN_FORWARD) then
			vel = vel + fwd * acc
		end

		if driver:KeyDown(IN_MOVERIGHT) then
			vel = vel + rt * acc
			ang:RotateAroundAxis(fwd, accel * 50)
			ang:RotateAroundAxis(up, -accel * 5)
		elseif driver:KeyDown(IN_MOVELEFT) then
			vel = vel - rt * acc
			ang:RotateAroundAxis(fwd, -accel * 50)
			ang:RotateAroundAxis(up, accel * 5)
		end

		if driver:KeyDown(IN_JUMP) then
			vel = vel + up * acc / 2
			ang:RotateAroundAxis(rt, accel * 30)
		elseif driver:KeyDown(IN_DUCK) then
			vel = vel - up * acc / 2
			ang:RotateAroundAxis(rt, -accel * 30)
		end

		local velL = vel:Length()
		rot = rot + -oldRot * 0.05

		if velL > 5 then
			vel = vel + VectorRand(-shake, shake)
			rot = rot + VectorRand(-shake, shake)
		end

		local d = self:WorldToLocalAngles(ang)
		rot = rot + Vector(d[3], d[1], d[2]) * rotAccel

		if driver:KeyDown(IN_ATTACK) then
			self:FireBullet(driver)
		end

		if driver:KeyDown(IN_ATTACK2) then
			self:FireHook(driver)
		elseif self.hook and self.hook:IsValid() then
			self.hook:Remove()
		end

		if self.Ammo ~= 50 and driver:KeyDown(IN_RELOAD) then
			self:Reload()
		end

		vel = vel:GetNormalized() * math.min(velL, maxVel)
		p:SetVelocityInstantaneous(vel)
		p:AddAngleVelocity(rot)
	end
end

local dieSound = Sound('npc/turret_floor/die.wav')

function ENT:Die(by)
	self:SetHealth(0)
	self:SetLights(false)
	self.Died = true
	self:RemoveAllBonuses()

	if self.grabConstraint and self.grabConstraint:IsValid() then
		self.grabConstraint:Remove()
	end

	constraint.RemoveAll(self)
	self:EmitSound(dieSound)
	local driver = self:GetDriver()

	if driver:IsValid() then
		driver:AddDeaths(1)
	end

	do
		local explosion = EffectData()
		explosion:SetEntity(self)
		explosion:SetOrigin(self:GetPos())
		explosion:SetMagnitude(50)
		explosion:SetScale(100)
		util.Effect('Explosion', explosion, true, true)
		util.BlastDamage(self, by or self, self:GetPos(), 250, 150)
	end

	playSound(SOUND_ZAP, self:GetPos())

	timer.Simple(3, function()
		if self:IsValid() and self:GetDriver():IsValid() then
			self:Reactivate()
		else
			self:Remove()
		end
	end)
end

util.AddNetworkString('cave.kill')
util.AddNetworkString('cave.hit')
local HitTable = {}
local Vector1 = Vector(100, 100, 100)

function ENT:OnTakeDamage(dmg)
	if self.shield then return end
	if self.Died then return end
	self:SetHealth(self:Health() - dmg:GetDamage())
	local p = self:GetPhysicsObject()
	p:ApplyForceOffset(dmg:GetDamageForce(), dmg:GetDamagePosition())
	local driver = self:GetDriver()
	local attacker = dmg:GetAttacker()

	if self:Health() <= 0 then
		p:ApplyForceOffset(Vector1, dmg:GetDamagePosition())
		self:Die(attacker)
		net.Start('cave.kill')
		net.WriteEntity(attacker)
		net.WriteEntity(driver)
		net.Broadcast()
		attacker:AddFrags(attacker == driver and -1 or 1)
	else
		net.Start('cave.hit')
		net.WriteUInt(dmg:GetDamage(), 14)
		net.WriteEntity(driver)
		local HitTable = HitTable
		HitTable[1] = attacker
		HitTable[2] = driver
		net.Send(HitTable)
	end
end