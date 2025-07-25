local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local catchFireflyEvent = ReplicatedStorage:WaitForChild("CatchFirefly")
local releaseFireflyEvent = ReplicatedStorage:WaitForChild("ReleaseFireflies")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local tool = script.Parent
local animation = tool:WaitForChild("Catch")
local animationTrack = character.Humanoid:LoadAnimation(animation)
local nextActivate = os.clock()
local debounceTime = 1

tool.RequiresHandle = false
tool.CanBeDropped = false

tool.Parent = character

tool.Unequipped:Connect(function()
	tool.Parent = character
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	tool.Parent = character
	animationTrack = character:WaitForChild("Humanoid"):LoadAnimation(animation)
end)

tool.Activated:Connect(function()
	if os.clock() > nextActivate then
		catchFireflyEvent:FireServer()

		nextActivate = os.clock() + debounceTime
		animationTrack:Play()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
		releaseFireflyEvent:FireServer()
	end
end)