-- Lightweight, asset-free sword swing animation.
-- Runs locally so the sword responds immediately when clicked or tapped.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local function bindSword(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("SwingClientBound") then return end
	tool:SetAttribute("SwingClientBound", true)

	local restingGrip = tool.Grip
	local swinging = false
	local windup = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local slash = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local recover = TweenInfo.new(0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	tool.Activated:Connect(function()
		if swinging or tool.Parent ~= player.Character then return end
		swinging = true
		-- Rotate the held sword back, sweep it down across the player, then reset.
		local base = restingGrip
		local back = base * CFrame.Angles(math.rad(-50), math.rad(5), math.rad(-25))
		local forward = base * CFrame.Angles(math.rad(65), math.rad(-15), math.rad(35))
		local t1 = TweenService:Create(tool, windup, {Grip = back})
		local t2 = TweenService:Create(tool, slash, {Grip = forward})
		local t3 = TweenService:Create(tool, recover, {Grip = base})
		t1:Play()
		t1.Completed:Wait()
		if tool.Parent ~= player.Character then tool.Grip = base swinging = false return end
		t2:Play()
		t2.Completed:Wait()
		if tool.Parent ~= player.Character then tool.Grip = base swinging = false return end
		t3:Play()
		t3.Completed:Wait()
		tool.Grip = base
		swinging = false
	end)
	tool.Unequipped:Connect(function()
		tool.Grip = restingGrip
	end)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character)
	watch(character)
end)
if player.Character then watch(player.Character) end
