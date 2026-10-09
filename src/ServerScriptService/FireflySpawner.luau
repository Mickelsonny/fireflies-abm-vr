local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FireflyClass = require(ReplicatedStorage:WaitForChild("FireflyClass"))

local fireflyTemplate = ReplicatedStorage:WaitForChild("FireflyModel")

local pauseEvent = ReplicatedStorage:WaitForChild("Pause")
local resetEvent = ReplicatedStorage:WaitForChild("Reset")
local rainRemoteEvent = ReplicatedStorage:WaitForChild("RainRemote")

local fireflyFolder = workspace:WaitForChild("FireflyFolder")
local spawnBounds = workspace:WaitForChild("FireflyBounds")
local displayFireflyCounter = workspace.Map.Lamps:WaitForChild("FireflyCounterLamp")
local billboardGui = displayFireflyCounter.Lamp:WaitForChild("BillboardGui")

local NUM_FIREFLIES = 150

local function getRandomPositionInBounds(part)
	local size = part.Size
	local pos = part.Position

	local x = math.random() * size.X - size.X / 2
	local y = math.random() * size.Y - size.Y / 2
	local z = math.random() * size.Z - size.Z / 2

	return Vector3.new(x, y, z) + pos
end

local fireflyInstances = {}

local function spawnAllFireflies()
	for i = 1, NUM_FIREFLIES do
		local firefly = fireflyTemplate:Clone()
		firefly.Parent = fireflyFolder

		local spawnPosition = getRandomPositionInBounds(spawnBounds)
		firefly:PivotTo(CFrame.new(spawnPosition))

		local instance = FireflyClass.new(firefly)
		table.insert(fireflyInstances, instance)
	end
end

local function resetFireflies()
	for _, instance in ipairs(fireflyInstances) do
		instance:Destroy()
	end
	fireflyInstances = {}
	spawnAllFireflies()
end

spawnAllFireflies()

pauseEvent.OnServerEvent:Connect(function(player)
	for _, instance in ipairs(fireflyInstances) do
		if instance.model then
			instance.model:SetAttribute("Paused", not instance.model:GetAttribute("Paused"))
		end
	end
end)

resetEvent.OnServerEvent:Connect(function(player)
	resetFireflies()
end)

rainRemoteEvent.OnServerEvent:Connect(function(player, isRaining)
	for _, firefly in ipairs(workspace.FireflyFolder:GetChildren()) do
		if firefly:IsA("Model") then
			firefly:SetAttribute("Rain", isRaining)
		end
	end
end)

-- Simulation runs:
local NUM_TRIALS = 30
local TRIAL_DURATION = 20
local sampleInterval = 1
local NUM_SAMPLES = (TRIAL_DURATION / sampleInterval) + 1

local results = {}
for i = 1, NUM_SAMPLES do
	results[i] = {}
end

task.spawn(function()
	for trial = 1, NUM_TRIALS do
		resetFireflies()
		
		task.wait(1)

		local startTime = os.clock()
		local nextSample = 0
		local sampleIndex = 0

		while os.clock() - startTime <= TRIAL_DURATION do
			task.wait(0.1)

			local litCount = 0
			for _, firefly in ipairs(fireflyFolder:GetChildren()) do
				if firefly:IsA("Model") and firefly:GetAttribute("LitUp") == true then
					litCount += 1
				end
			end
			
			local darkCount = NUM_FIREFLIES - litCount
			billboardGui.FirefliesLitUp.Text = "Lit Fireflies: " .. litCount
			billboardGui.FirefliesDark.Text = "Dark Fireflies: " .. darkCount

			local elapsed = os.clock() - startTime
			if elapsed >= nextSample then
				sampleIndex += 1
				local R = FireflyClass.GetOrderParameter()
				results[sampleIndex][trial] = R
				nextSample += sampleInterval
			end
		end

		print(string.format("Trial %d/%d complete", trial, NUM_TRIALS))
	end

	print("======= BEGIN =======")

	local header = {"time"}
	for trial = 1, NUM_TRIALS do
		table.insert(header, "trial_" .. trial)
	end
	print(table.concat(header, ","))

	for i = 1, NUM_SAMPLES do
		local row = {tostring((i - 1) * sampleInterval)}
		for trial = 1, NUM_TRIALS do
			local R = results[i][trial]
			table.insert(row, R and string.format("%.4f", R) or "")
		end
		print(table.concat(row, ","))
	end

	print("======= END =======")
end)