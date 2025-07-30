-- CREDIT TO CREATOR: DISCORD - cubicunderscore

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rainBindableEvent = ReplicatedStorage:WaitForChild("RainBindable")

local RAIN_PARENT = workspace:WaitForChild("Rain")
local LOCAL_PLAYER = Players.LocalPlayer
local HRP = LOCAL_PLAYER.Character:WaitForChild("HumanoidRootPart")

local MAX_RAINDROPS = 125
local RAINDROPS_PER_SPAWN = 5
local SPAWN_DELAY = 0.1
local RAIN_RANGE = 60

local activeRaindrops = 0

local rainEnabled = false

local splashRingTemplate = Instance.new("ParticleEmitter")
splashRingTemplate.Brightness = 5
splashRingTemplate.LightEmission = 0
splashRingTemplate.LightInfluence = 0
splashRingTemplate.Lifetime = NumberRange.new(0.2, 0.4)
splashRingTemplate.Transparency = NumberSequence.new(0.85, 1)
splashRingTemplate.Size = NumberSequence.new(0.25, 0)
splashRingTemplate.Squash = NumberSequence.new(-0.8, 0)
splashRingTemplate.Orientation = Enum.ParticleOrientation.VelocityParallel
splashRingTemplate.Enabled = false
splashRingTemplate.Acceleration = Vector3.new(0, -30, 0)
splashRingTemplate.Speed = NumberRange.new(14)
splashRingTemplate.SpreadAngle = Vector2.new(20, 20)
splashRingTemplate.Drag = 3
splashRingTemplate.Texture = "rbxassetid://14643458094"

local rippleBurstTemplate = Instance.new("ParticleEmitter")
rippleBurstTemplate.Brightness = 3
rippleBurstTemplate.LightEmission = 0
rippleBurstTemplate.LightInfluence = 0
rippleBurstTemplate.Lifetime = NumberRange.new(0.6, 1)
rippleBurstTemplate.Transparency = NumberSequence.new(1, 1.5)
rippleBurstTemplate.Size = NumberSequence.new(0.5, 1.5)
rippleBurstTemplate.Orientation = Enum.ParticleOrientation.FacingCamera
rippleBurstTemplate.Enabled = false
rippleBurstTemplate.Acceleration = Vector3.new(0, -3, 0)
rippleBurstTemplate.Speed = NumberRange.new(7)
rippleBurstTemplate.Rotation = NumberRange.new(-360, 360)
rippleBurstTemplate.RotSpeed = NumberRange.new(-90, 90)
rippleBurstTemplate.SpreadAngle = Vector2.new(90, 90)
rippleBurstTemplate.Drag = 1
rippleBurstTemplate.Texture = "rbxassetid://14110422995"
rippleBurstTemplate.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
rippleBurstTemplate.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4

local rainLightTemplate = Instance.new("PointLight")
rainLightTemplate.Brightness = 1
rainLightTemplate.Color = Color3.fromRGB(111, 157, 255)
rainLightTemplate.Range = 10
rainLightTemplate.Enabled = false

local attachmentPool = {}
local particlePool = {splash = {}, ripple = {}}

local function getPooledAttachment()
	if #attachmentPool > 0 then
		return table.remove(attachmentPool)
	else
		return Instance.new("Attachment")
	end
end

local function returnAttachmentToPool(att)
	att.Parent = nil
	table.insert(attachmentPool, att)
end

local function createRaindrop()
	if activeRaindrops >= MAX_RAINDROPS then return end

	activeRaindrops = activeRaindrops + 1

	local raindrop = Instance.new("Part")
	raindrop.Name = "Raindrop"
	raindrop.CastShadow = false
	raindrop.Transparency = 1
	raindrop.Color = Color3.fromRGB(95, 122, 134)
	raindrop.Material = Enum.Material.Neon
	raindrop.Anchored = false
	raindrop.Size = Vector3.new(0.3, 0.5, 0.3)
	raindrop.Position = HRP.Position + Vector3.new(
		math.random(-RAIN_RANGE, RAIN_RANGE), 
		30, 
		math.random(-RAIN_RANGE, RAIN_RANGE)
	)
	raindrop.Parent = RAIN_PARENT

	if math.random() < 0.3 then
		rainLightTemplate:Clone().Parent = raindrop
	end

	local tween = TweenService:Create(raindrop, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = raindrop.Position - Vector3.new(0, 45, 0),
		Transparency = 0.5,
		Size = Vector3.new(0.1, 4, 0.1)
	})
	tween:Play()

	local hasHit = false
	local connection
	connection = raindrop.Touched:Connect(function(hit)
		if hasHit or hit.Parent == RAIN_PARENT then return end
		hasHit = true

		activeRaindrops = activeRaindrops - 1
		connection:Disconnect()

		raindrop:Destroy()

		local att = getPooledAttachment()
		att.WorldPosition = raindrop.Position
		att.Parent = workspace.Baseplate

		local splashRing = splashRingTemplate:Clone()
		local rippleBurst = rippleBurstTemplate:Clone()
		splashRing.Parent = att
		rippleBurst.Parent = att

		splashRing:Emit(2)
		rippleBurst:Emit(6)

		task.wait(1.5)
		splashRing:Destroy()
		rippleBurst:Destroy()
		returnAttachmentToPool(att)
	end)

	Debris:AddItem(raindrop, 2)
	task.spawn(function()
		task.wait(2)
		if raindrop.Parent then
			activeRaindrops = activeRaindrops - 1
		end
	end)
end

local lastSpawnTime = 0
RunService.Heartbeat:Connect(function()
	if not rainEnabled then return end

	local currentTime = tick()
	if currentTime - lastSpawnTime >= SPAWN_DELAY then
		for i = 1, RAINDROPS_PER_SPAWN do
			createRaindrop()
		end
		lastSpawnTime = currentTime
	end
end)

rainBindableEvent.Event:Connect(function(enabled)
	rainEnabled = enabled

	if not rainEnabled then
		script.RainSound:Stop()
	else
		script.RainSound:Play()
	end
end)