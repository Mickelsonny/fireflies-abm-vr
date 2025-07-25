local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireflyClass = require(ReplicatedStorage:WaitForChild("FireflyClass"))

local fireflyTemplate = ReplicatedStorage:WaitForChild("FireflyModel")
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

for i = 1, NUM_FIREFLIES do
	local firefly = fireflyTemplate:Clone()
	firefly.Parent = fireflyFolder

	local spawnPosition = getRandomPositionInBounds(spawnBounds)
	firefly:PivotTo(CFrame.new(spawnPosition))

	FireflyClass.new(firefly)
end

while true do
	task.wait(0.1)

	local litCount = 0
	for _, firefly in ipairs(fireflyFolder:GetChildren()) do
		if firefly:IsA("Model") and firefly:GetAttribute("LitUp") == true then
			litCount += 1
		end
	end

	billboardGui.FirefliesLitUp.Text = "Lit Fireflies: " .. litCount
	billboardGui.FirefliesDark.Text = "Dark Fireflies: " .. NUM_FIREFLIES - litCount
end