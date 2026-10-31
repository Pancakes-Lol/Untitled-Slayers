-- Secret one-time collectible that permanently unlocks the Float Brick follower
-- and grants +5% strength, money, and XP.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local unlockStore = DataStoreService:GetDataStore("UntitledSlayers_FollowBrick_v1")
local collectible = workspace:WaitForChild("Float Brick", 20)
if not collectible or not collectible:IsA("BasePart") then
	warn("[Untitled Slayers] Workspace.Float Brick was not found.")
	return
end

collectible.Anchored = true
collectible.CanCollide = false
collectible.CanTouch = false
collectible.CanQuery = true

-- Keep the secret brick hidden, but always place it above valid ground so it is findable.
local function placeCollectibleAboveGround()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then return end

	-- Hidden off to the side/back of the starting area rather than directly beside spawn.
	local targetXZ = spawn.Position + Vector3.new(-48, 0, -38)
	local rayOrigin = Vector3.new(targetXZ.X, 150, targetXZ.Z)
	local rayDirection = Vector3.new(0, -300, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {collectible}

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result then
		local halfHeight = collectible.Size.Y * 0.5
		collectible.Position = result.Position + Vector3.new(0, halfHeight + 0.35, 0)
	else
		collectible.Position = Vector3.new(targetXZ.X, spawn.Position.Y + 2, targetXZ.Z)
	end
end

placeCollectibleAboveGround()

local clickDetector = collectible:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 12
clickDetector.Parent = collectible

local active = {}
local connections = {}
local unlocked = {}

local function applyBuffs(player, isUnlocked)
	player:SetAttribute("FollowBrickUnlocked", isUnlocked == true)
	player:SetAttribute("StrengthMultiplier", isUnlocked and 1.05 or 1)
	player:SetAttribute("MoneyMultiplier", isUnlocked and 1.05 or 1)
	player:SetAttribute("XPMultiplier", isUnlocked and 1.05 or 1)
end

local function clearFollower(player)
	local state = active[player]
	if state then
		if state.brick and state.brick.Parent then
			state.brick:Destroy()
		end
		active[player] = nil
	end
end

local function spawnFollower(player, character)
	clearFollower(player)
	if not unlocked[player] then return end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not character.Parent then return end

	local brick = collectible:Clone()
	brick.Name = "Float Brick Follower"
	brick.Anchored = true
	brick.CanCollide = false
	brick.CanTouch = false
	brick.CanQuery = false
	for _, obj in ipairs(brick:GetDescendants()) do
		if obj:IsA("ClickDetector") then obj:Destroy() end
		if obj:IsA("Script") or obj:IsA("LocalScript") then obj.Disabled = true end
	end
	brick.CFrame = root.CFrame * CFrame.new(2.5, 1.5, 4.5)
	brick.Parent = workspace
	active[player] = {brick = brick, root = root, elapsed = 0}
end

local function saveUnlock(player)
	local key = "u_" .. player.UserId
	local ok, err = pcall(function()
		unlockStore:UpdateAsync(key, function()
			return true
		end)
	end)
	if not ok then
		warn("[FollowBrick] Could not save permanent unlock for " .. player.Name .. ": " .. tostring(err))
	end
end

local function unlockForPlayer(player)
	if unlocked[player] then return end
	unlocked[player] = true
	applyBuffs(player, true)
	saveUnlock(player)
	if player.Character then
		task.spawn(spawnFollower, player, player.Character)
	end
end

clickDetector.MouseClick:Connect(unlockForPlayer)

local function addPlayer(player)
	applyBuffs(player, false)

	local key = "u_" .. player.UserId
	local ok, result = pcall(function()
		return unlockStore:GetAsync(key)
	end)
	if ok and result == true then
		unlocked[player] = true
		applyBuffs(player, true)
	elseif not ok then
		warn("[FollowBrick] Could not load permanent unlock for " .. player.Name .. ": " .. tostring(result))
	end

	local added = player.CharacterAdded:Connect(function(character)
		spawnFollower(player, character)
	end)
	local removing = player.CharacterRemoving:Connect(function()
		clearFollower(player)
	end)
	connections[player] = {added, removing}

	if player.Character then
		task.spawn(spawnFollower, player, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearFollower(player)
	for _, connection in ipairs(connections[player] or {}) do
		connection:Disconnect()
	end
	connections[player] = nil
	unlocked[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(addPlayer, player)
end

RunService.Heartbeat:Connect(function(dt)
	for player, state in pairs(active) do
		local root, brick = state.root, state.brick
		if root and brick and root.Parent and brick.Parent and player.Character == root.Parent then
			state.elapsed += dt
			local bob = math.sin(state.elapsed * 2.6) * 0.35
			local target = root.CFrame * CFrame.new(2.5, 1.5 + bob, 4.5)
			local alpha = 1 - math.exp(-7 * dt)
			brick.CFrame = brick.CFrame:Lerp(target, alpha)
		else
			clearFollower(player)
		end
	end
end)
