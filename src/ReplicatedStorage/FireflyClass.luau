local FireflyClass = {}
FireflyClass.__index = FireflyClass

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local AllFireflies = {}

local function enableParticles(effect, enabled)
	for i, particle in pairs(effect:GetDescendants()) do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = enabled
		end
		if particle:IsA("Beam") then
			particle.Enabled = enabled
		end
		if particle:IsA("Trail") then
			particle.Enabled = enabled
		end
		if particle:IsA("PointLight") then
			particle.Enabled = enabled
		end
	end
end

local function emitParticles(effect)
	for i, particles in pairs(effect:GetDescendants()) do
		if particles:IsA("ParticleEmitter") then
			particles:Emit(particles:GetAttribute("EmitCount"))
		end
	end
end

-- multi-octave perlin noise to get natural movement (fractal brownian motion)
local function fbm(x, y, z, octaves)
	local value = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0
	for i = 1, octaves do
		value = value + math.noise(x * frequency, y * frequency, z * frequency) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * 0.5
		frequency = frequency * 2
	end
	return value / maxValue
end

function FireflyClass.new(model)
	local self = setmetatable({}, FireflyClass)

	self.model = model
	self.root = model.PrimaryPart
	self.root.Buzzing:Play()

	if not self.root then
		warn("Firefly missing PrimaryPart!")
		return nil
	end

	-- for blinking particle emitter(s)
	self.light = model.Lighting
	self.model:SetAttribute("LitUp", false)
	
	-- for capturing fireflies
	self.model:SetAttribute("Paused", false)
	self.model:SetAttribute("Captured", false)

	-- ID for uniquely identifying firefly
	self.id = HttpService:GenerateGUID(false)

	-- Fractal Brownian Motion parameters (movement)
	-- these offsets create a random seed so each firefly has a unique movement pattern
	self.offsetX = math.random() * 1000
	self.offsetY = math.random() * 1000
	self.offsetZ = math.random() * 1000
	
	self.speed = 35 -- how fast fireflies move through space
	self.frequency = 1.5 -- controls how rapidly motion direction changes

	-- for calculating proper facing direction
	self.previousPosition = self.root.Position

	-- Kuramoto model parameters
	self.phase = math.random() * 2 * math.pi  -- random initial phase
	self.naturalFrequency = 1.0 + math.random() * 0.2  -- base frequency (1.0 - 1.2 Hz)
	self.coupling = 1.3 -- coupling strength (how much fireflies influence each other)
	self.lastBlink = 0  -- track when we last blinked
	self.blinkThreshold = 2 * math.pi  -- phase threshold for blinking

	-- tracking all fireflies
	table.insert(AllFireflies, self)

	self:_initBlink()
	self:_startMovement()

	return self
end

-- Kuramoto order parameter: Z(t) = R(t)*e^(i*phi(t)) = (1/N) * sum(e^(i*theta_j(t)))
function FireflyClass.GetOrderParameter()
	local sumCos, sumSin, n = 0, 0, 0

	for _, firefly in ipairs(AllFireflies) do
		if firefly.root and firefly.root.Parent then
			sumCos = sumCos + math.cos(firefly.phase)
			sumSin = sumSin + math.sin(firefly.phase)
			n = n + 1
		end
	end

	if n == 0 then
		return 0, 0, 0
	end

	local realPart = sumCos / n
	local imagPart = sumSin / n

	local R = math.sqrt(realPart^2 + imagPart^2)
	local phi = math.atan2(imagPart, realPart)

	return R, phi, n
end

function FireflyClass:_startMovement()
	self.connection = RunService.Heartbeat:Connect(function(dt)
		if not self.root then 
			if self.connection then
				self.connection:Disconnect()
			end
			return 
		end

		if self.model:GetAttribute("Paused") then
			return -- skip movement while paused
		end

		local time = tick() * self.frequency

		-- multi-octave noise
		local noiseX = fbm(time + self.offsetX, self.offsetY, self.offsetZ, 3)
		local noiseY = fbm(self.offsetX, time + self.offsetY, self.offsetZ, 2) * 0.3 -- y-movement is less pronounced
		local noiseZ = fbm(self.offsetX, self.offsetY, time + self.offsetZ, 3)

		local moveVector = Vector3.new(noiseX, noiseY, noiseZ) * self.speed * dt
		local currentPosition = self.root.Position
		local newPosition = currentPosition + moveVector
		local direction = (newPosition - currentPosition).Unit

		-- raycast setup
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {self.model}
		rayParams.IgnoreWater = true

		-- downward raycast
		local downRay = workspace:Raycast(newPosition, Vector3.new(0, -5, 0), rayParams)
		if downRay then
			-- terrain detected below - bounce upward slightly depending on distance
			local distance = (newPosition.Y - downRay.Position.Y)
			if distance < 3 then
				-- smoothly lift based on closeness to ground
				local upwardForce = math.clamp((3 - distance) * 0.2, 0, 0.5)
				moveVector += Vector3.new(0, upwardForce, 0)
				newPosition = currentPosition + moveVector
			end
		end

		-- forward raycast
		local forwardRay = workspace:Raycast(currentPosition, direction * 3, rayParams)
		if forwardRay then
			-- terrain ahead - nudge in a new randomized direction
			local avoidDir = (Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)).Unit
			moveVector += avoidDir * 2
			newPosition = currentPosition + moveVector
		end

		-- apply new cframe
		direction = (newPosition - currentPosition).Unit
		if direction.Magnitude > 0.01 then
			self.root.CFrame = CFrame.lookAt(newPosition, newPosition + direction)
		else
			self.root.CFrame = CFrame.new(newPosition) * self.root.CFrame.Rotation
		end
	end)
end

function FireflyClass:_getNeighboringFireflies(maxDistance)
	local neighbors = {}
	local myPosition = self.root.Position

	for _, firefly in ipairs(AllFireflies) do
		if firefly ~= self and firefly.root and firefly.root.Parent then
			local distance = (firefly.root.Position - myPosition).Magnitude
			if distance <= maxDistance then
				table.insert(neighbors, firefly)
			end
		end
	end

	return neighbors
end

function FireflyClass:_updateKuramotoPhase(dt)
	-- get neighboring fireflies within influence range
	local neighbors = self:_getNeighboringFireflies(120) -- influence radius

	-- calculate phase derivative using Kuramoto model
	local phaseDot = self.naturalFrequency * 2 * math.pi -- convert Hz to rad/s

	-- add coupling term
	if #neighbors > 0 then
		local couplingSum = 0
		for _, neighbor in ipairs(neighbors) do
			couplingSum = couplingSum + math.sin(neighbor.phase - self.phase)
		end
		phaseDot = phaseDot + (self.coupling / #neighbors) * couplingSum
	end

	-- update phase
	self.phase = self.phase + phaseDot * dt

	-- keep phase in [0, 2π] range
	if self.phase > 2 * math.pi then
		self.phase = self.phase - 2 * math.pi
	elseif self.phase < 0 then
		self.phase = self.phase + 2 * math.pi
	end
end

function FireflyClass:_initBlink()
	-- start the Kuramoto synchronization loop
	self.kuramotoConnection = RunService.Heartbeat:Connect(function(dt)
		if not self.root or not self.root.Parent then
			if self.kuramotoConnection then
				self.kuramotoConnection:Disconnect()
			end
			return
		end
		
		if self.model:GetAttribute("Paused") then
			return -- skip blinking while paused
		end
		
		if self.model:GetAttribute("Rain") then
			return -- skip blinking while it's raining
		end

		-- update phase using Kuramoto model
		self:_updateKuramotoPhase(dt)

		-- check if we should blink (when phase crosses the threshold)
		local normalizedPhase = (math.sin(self.phase) + 1) / 2 -- normalize to [0,1]

		-- blink when the normalized phase crosses above 0.9 (near the peak)
		if normalizedPhase > 0.8 and not self.model:GetAttribute("LitUp") then
			-- only blink if enough time has passed since last blink (prevent rapid flickering)
			local currentTime = tick()
			if currentTime - self.lastBlink > 0.2 then
				self:_performBlink()
				self.lastBlink = currentTime
			end
		end
	end)
end

function FireflyClass:_performBlink()
	if self.light then
		emitParticles(self.light)
		
		self.model:SetAttribute("LitUp", true)

		task.delay(0.2, function()
			if self.model then
				self.model:SetAttribute("LitUp", false)
			end
		end)
	end
end

function FireflyClass:Destroy()
	if self.connection then
		self.connection:Disconnect()
	end

	if self.kuramotoConnection then
		self.kuramotoConnection:Disconnect()
	end

	if self.model then
		self.model:Destroy()
	end

	for i, firefly in ipairs(AllFireflies) do
		if firefly == self then
			table.remove(AllFireflies, i)
			break
		end
	end
end

return FireflyClass