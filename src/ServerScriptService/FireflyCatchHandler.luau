local ReplicatedStorage = game:GetService("ReplicatedStorage")
local catchFireflyEvent = ReplicatedStorage:WaitForChild("CatchFirefly")
local releaseFireflyEvent = ReplicatedStorage:WaitForChild("ReleaseFireflies")

local captured = {} -- [player] = {firefly1, firefly2, ...}

-- create a weld from firefly root to net and position it inside
local function weldToNet(fireflyRoot, netPart)
	-- position firefly inside the net
	local netCFrame = netPart.CFrame
	local offsetPosition = netCFrame.Position + netCFrame.LookVector * 0.5 -- slight offset forward
	fireflyRoot.CFrame = CFrame.new(offsetPosition, offsetPosition + netCFrame.LookVector)
	
	fireflyRoot.Anchored = false
	
	local weld = Instance.new("WeldConstraint")
	weld.Name = "FireflyNetWeld"
	weld.Part0 = fireflyRoot
	weld.Part1 = netPart
	weld.Parent = fireflyRoot
	return weld
end

catchFireflyEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end

	local net = character:FindFirstChild("FireflyCatcher") or character:FindFirstChildWhichIsA("Tool")
	if not net or not net:IsA("Tool") then return end

	local netPart = net:FindFirstChild("Net") or net:FindFirstChildWhichIsA("BasePart")
	if not netPart then return end

	-- search for fireflies within 5 studs
	for _, fireflyModel in ipairs(workspace.FireflyFolder:GetChildren()) do
		local root = fireflyModel:FindFirstChild("PrimaryPart") or fireflyModel.PrimaryPart
		if root and (root.Position - netPart.Position).Magnitude <= 7.7 then
			-- tag as captured (prevent double capture)
			if not fireflyModel:GetAttribute("Captured") then
				fireflyModel:SetAttribute("Captured", true)

				-- stop movement logic (custom flag)
				fireflyModel:SetAttribute("Paused", true)

				-- weld and position to net
				weldToNet(root, netPart)

				-- track it per player
				captured[player] = captured[player] or {}
				table.insert(captured[player], fireflyModel)
			end
		end
	end
end)

releaseFireflyEvent.OnServerEvent:Connect(function(player)
	if not captured[player] then return end

	for _, fireflyModel in ipairs(captured[player]) do
		local root = fireflyModel.PrimaryPart

		-- remove weld and reanchor
		if root then
			root.Anchored = true
			
			root:FindFirstChild("FireflyNetWeld"):Destroy()
		end

		-- resume motion
		fireflyModel:SetAttribute("Paused", false)
		fireflyModel:SetAttribute("Captured", false)
	end

	captured[player] = nil
end)