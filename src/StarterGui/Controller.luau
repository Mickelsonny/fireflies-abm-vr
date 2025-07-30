local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local surfaceGui = workspace:WaitForChild("GuiController"):WaitForChild("SurfaceGui")

local pauseButton = surfaceGui:WaitForChild("Pause")
local resetButton = surfaceGui:WaitForChild("Reset")
local rainButton = surfaceGui:WaitForChild("Rain")

local pauseEvent = ReplicatedStorage:WaitForChild("Pause")
local resetEvent = ReplicatedStorage:WaitForChild("Reset")
local rainRemoteEvent = ReplicatedStorage:WaitForChild("RainRemote")
local rainBindableEvent = ReplicatedStorage:WaitForChild("RainBindable")

local raining = false

pauseButton.Activated:Connect(function()
	pauseEvent:FireServer()
end)

resetButton.Activated:Connect(function()
	resetEvent:FireServer()
end)

rainButton.Activated:Connect(function()
	raining = not raining
	
	rainRemoteEvent:FireServer(raining)
	rainBindableEvent:Fire(raining)
end)