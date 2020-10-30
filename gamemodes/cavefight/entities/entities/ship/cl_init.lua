include('shared.lua')
local shieldMat = Material('effects/com_shield004a')

function ENT:Draw()
	local driver = self:GetDriver()
	local thirdperson = driver ~= LocalPlayer() or driver:GetThirdperson()

	if not self.invis and thirdperson then
		self:DrawModel()
	end

	if self:Health() > 0 then
		if self.shield then
			render.SetMaterial(shieldMat)
			render.DrawSphere(self:GetPos(), 15, 30, 30, color_white)
		end

		if self.idleSound then
			local vel = self:GetVelocity():Length()
			self.idleSound:ChangePitch(50 + math.Clamp(vel * 0.1, 0, 100), 0)
		end
	end

	self.emitter:Draw()
end

function ENT:OnRemove()
	if self.idleSound then
		self.idleSound:Stop()
	end
end

local particleMat = Material('effects/select_ring')
local SmokeParticleMat = Material('particle/particle_smokegrenade')
local LightOffset = Vector(20, -10, 10)

function ENT:Think()
	if self.Ammo ~= 50 and LocalPlayer():KeyDown(IN_RELOAD) then
		self.Reloading = true
	end

	if self:GetLights() then
		local dlight = DynamicLight(self:EntIndex())

		if (dlight) then
			dlight.pos = self:LocalToWorld(LightOffset)
			dlight.r = 200
			dlight.g = 200
			dlight.b = 200
			dlight.brightness = 0.05
			dlight.Decay = 0
			dlight.Size = 800
			dlight.DieTime = CurTime() + FrameTime()
		end
	end

	do
		local h = self:Health()

		if h > 0 then
			local t = CurTime()
			local vel = self:GetVelocity():Length()
			local mul = math.Clamp(vel / 400, 0, 1)

			if mul > 0.1 and not self.invis and t - self.lastParticle > 0.05 then
				self.lastParticle = t
				local particle = self.emitter:Add(particleMat, self:LocalToWorld(self.EngineMuzzlePos))

				if particle then
					particle:SetDieTime(mul)
					particle:SetStartAlpha(255 * mul)
					particle:SetEndAlpha(0)
					particle:SetStartSize(2 * mul)
					particle:SetEndSize(0)
					particle:SetGravity(Vector(0, 0, 100))
					particle:SetVelocity(-self:GetForward() * 5 + VectorRand() * 30)
					particle:SetColor(HUDColor:Unpack())
				end
			end

			local maxh3 = self:GetMaxHealth() * 0.3

			if h < maxh3 and t - self.lastSmokeParticle > h / maxh3 then
				self.lastSmokeParticle = t
				local particle = self.emitter:Add(SmokeParticleMat, self:LocalToWorld(self.EngineMuzzlePos))

				if particle then
					particle:SetDieTime(2)
					particle:SetStartAlpha(255)
					particle:SetEndAlpha(0)
					particle:SetStartSize(math.random(-3, 3) + 10)
					particle:SetEndSize(2)
					particle:SetRoll(math.random(-1, 1) * math.pi)
					particle:SetGravity(Vector(0, 0, 0))
					particle:SetVelocity(self:GetVelocity() + self:GetUp() * 20)
				end
			end
		end
	end
end

net.Receive('cave.applyBonus', function()
	local ship = net.ReadEntity()
	local bonusType = net.ReadUInt(8)
	local endTime = net.ReadFloat()

	if ship:IsValid() then
		ship:ApplyBonus(bonusType, endTime)
	end
end)

net.Receive('cave.removeBonus', function()
	local ship = net.ReadEntity()
	local bonusType = net.ReadUInt(8)

	if ship:IsValid() then
		ship:RemoveBonus(bonusType)
	end
end)

net.Receive('cave.ship.attack', function()
	local ship = LocalPlayer():GetShip()

	if ship:IsValid() then
		ship.Ammo = ship.Ammo - 1
	end
end)

net.Receive('cave.ship.reload', function()
	local lply = LocalPlayer()
	if not lply:IsValid() then return end
	local ship = lply:GetShip()

	if ship:IsValid() then
		ship.Ammo = 50
		ship.Reloading = false
	end
end)