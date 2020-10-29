AddCSLuaFile('cl_init.lua')

include('shared.lua')

util.AddNetworkString('cave.applyBonus')
util.AddNetworkString('cave.removeBonus')

local maxVel = 400
local accel = 3
local rotAccel = 0.1
local shake = 1

local minRespRadius, maxRespRadius = caveMapSize / 6, caveMapSize / 6 * 2
local respRange = maxRespRadius - minRespRadius

function ENT:Reactivate()
  local r, a = minRespRadius + math.random() * respRange, math.random() * math.pi * 2
  local x, y = math.cos(a) * r, math.sin(a) * r
  constraint.RemoveAll(self)
  self:SetPos(Vector(x, y, caveHeightAtPoint(caveSeed, x, y) + caveMaxCeil / 2))
  self:SetAngles(angle_zero)
  self:SetMaxHealth(1000)
  self:SetHealth(self:GetMaxHealth())
  local p = self:GetPhysicsObject()
  p:EnableGravity(false)
  p:SetVelocity(vector_origin)
  local sparks = EffectData()
  sparks:SetOrigin(self:GetPos())
  util.Effect('cball_bounce', sparks, true, true)
  playSound(SOUND_RESPAWN, self:GetPos())
  local driver = self:GetDriver()
  self.Died = false

  if IsValid(driver) then
    driver:SetEyeAngles(angle_zero)
  end
end

local function BulletHole(_, tr, _)
  if tr.Entity:IsWorld() then return end
  local shell = EffectData()
  shell:SetOrigin(tr.HitPos)
  shell:SetNormal(tr.HitNormal)
  shell:SetRadius(0.5 + math.random(0, 0.2))
  util.Effect('AR2Explosion', shell, true, true)
end

function ENT:FireBullet(driver)
  local t = CurTime()
  if t - (self.lastBullet or 0) > 0.15 then
    self.lastBullet = t
    local eyePos, eyeAng = caveCalcView(driver, driver:EyePos(), driver:EyeAngles())
    local tr = util.TraceLine({
      start = eyePos,
      endpos = eyePos + eyeAng:Forward() * 100000,
      filter = self
    })
    driver:LagCompensation(true)
    local pos = self:GetPos()
    self:FireBullets({
      Attacker = driver,
      Damage = self.dmg and 250 or 100,
      Force = self.dmg and 5 or 1,
      Spread = Vector(0.02, 0.02, 0),
      IgnoreEntity = self,
      Src = pos,
      Dir = tr.HitPos - pos,
      TracerName = 'AR2Tracer',
      Callback = BulletHole
    })
    driver:LagCompensation(false)
    local muzzleFlash = EffectData()
    muzzleFlash:SetOrigin(self:LocalToWorld(Vector(15, 0, 0)))
    muzzleFlash:SetAngles(self:GetAngles())
    muzzleFlash:SetScale(1)
    util.Effect('MuzzleEffect', muzzleFlash, true, true)
    playSound(SOUND_SHOOT, self:GetPos())
  end
end

local hookDist = 300

function ENT:FireHook(driver)
  if IsValid(self.hook) then return end
  driver:LagCompensation(true)
  local eyePos, eyeAng = caveCalcView(driver, driver:EyePos(), driver:EyeAngles())
  local tr = util.TraceLine({
    start = eyePos,
    endpos = eyePos + eyeAng:Forward() * hookDist,
    filter = self
  })
  if not IsValid(tr.Entity) then return end
  local pos = self:GetPos()
  tr = util.TraceLine({
    start = pos,
    endpos = tr.HitPos,
    filter = self,
  })
  driver:LagCompensation(false)
  local ent = tr.Entity
  if not IsValid(ent) then return end
  local len = (tr.HitPos - pos):Length()
  self.hook = constraint.Rope(self, ent, 0, 0, vector_origin, ent:WorldToLocal(tr.HitPos), len, 0, 0, 10, 'cable/physbeam', false)
  if ent.SetLastHooker then
    ent:SetLastHooker(driver)
  end
end

proj_xy = Vector(1, 1, 0)

function ENT:PhysicsUpdate(p)
  if self.Died then return end
  local oldVel = p:GetVelocity()
  local oldRot = p:GetAngleVelocity()
  local rot = Vector(0, 0, 0)
  local vel = oldVel * 0.99
  local driver = self:GetDriver()
  self.driver = driver
  if IsValid(driver) then
    local ang = driver:EyeAngles()
    local fwd = ang:Forward()
    local rt = ang:Right()
    local up = ang:Up()
    local tilt = (self:GetForward() * proj_xy):GetNormalized():Dot((rt * proj_xy):GetNormalized()) * -40
    ang = ang + Angle(0, 0, tilt)
    local acc = driver:KeyDown(IN_SPEED) and (accel * 3) or accel
    if driver:KeyDown(IN_BACK) then
      vel = vel - fwd * acc / 2
    elseif driver:KeyDown(IN_FORWARD) then
      vel = vel + fwd * acc
    end
    if driver:KeyDown(IN_MOVERIGHT) then
      vel = vel + rt * acc
      ang:RotateAroundAxis(fwd, acc)
    elseif driver:KeyDown(IN_MOVELEFT) then
      vel = vel - rt * acc
      ang:RotateAroundAxis(fwd, -acc)
    end
    if driver:KeyDown(IN_JUMP) then
      vel = vel + up * acc
      -- print(vel:Angle(), vel:Angle():Up())
      ang:RotateAroundAxis(rt, vel:Angle():Up().p)
    elseif driver:KeyDown(IN_DUCK) then
      vel = vel - up * acc
      ang:RotateAroundAxis(rt, -vel:Angle():Up().p)
    end
    local velL = vel:Length()
    rot = rot + -oldRot * 0.05
    if velL > 5 then
      vel = vel + VectorRand(-shake, shake)
      rot = rot + VectorRand(-shake, shake)
    end
    local d = self:WorldToLocalAngles(ang)
    rot = rot + Vector(d.r, d.p, d.y) * rotAccel
    if driver:KeyDown(IN_ATTACK) then
      self:FireBullet(driver)
    end
    if driver:KeyDown(IN_ATTACK2) then
      self:FireHook(driver)
    elseif IsValid(self.hook) then
      self.hook:Remove()
    end
    vel = vel:GetNormalized() * math.min(velL, maxVel)
    p:SetVelocityInstantaneous(vel)
    p:AddAngleVelocity(rot)
  end
end

local dieSound = Sound('npc/turret_floor/die.wav')

function ENT:Die()
  self:SetHealth(0)
  self:RemoveAllBonuses()
  constraint.RemoveAll(self)
  self:EmitSound(dieSound)
  local driver = self:GetDriver()
  if IsValid(driver) then
    driver:AddDeaths(1)
  end
  local sparks = EffectData()
  sparks:SetEntity(self)
  sparks:SetOrigin(self:GetPos())
  util.Effect('ManhackSparks', sparks, true, true)
  playSound(SOUND_ZAP, self:GetPos())
  if IsValid(self.grabConstraint) then
    self.grabConstraint:Remove()
  end
  local p = self:GetPhysicsObject()
  p:EnableGravity(true)
  timer.Simple(3, function()
    if IsValid(self) and IsValid(self:GetDriver()) then
      self:Reactivate()
    else
      self:Remove()
    end
  end)
end

util.AddNetworkString('cave.kill')

function ENT:OnTakeDamage(dmg)
  if self.shield then return end
  if self:Health() <= 0 then return end
  self:SetHealth(self:Health() - dmg:GetDamage())
  local p = self:GetPhysicsObject()
  p:ApplyForceOffset(dmg:GetDamageForce(), dmg:GetDamagePosition())
  if self:Health() <= 0 then
    self:Die()
    local driver = self:GetDriver()
    local attacker = dmg:GetAttacker()
    net.Start('cave.kill')
      net.WriteEntity(attacker)
      net.WriteEntity(driver)
    net.Broadcast()
    if IsValid(attacker) then
      attacker:AddFrags(attacker == driver and -1 or 1)
    end
  end
end