-- A smooth, floating pet that follows about five studs behind each player.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local template = workspace:WaitForChild("Float Brick", 20)
if not template or not template:IsA("BasePart") then
	warn("[Untitled Slayers] Workspace.Float Brick was not found.")
	return
end
template.Anchored = true
template.CanCollide = false
template.Parent = ServerStorage

local active = {}
local connections = {}

local function clearBrick(player)
	local state = active[player]
	if state then
		state.brick:Destroy()
		active[player] = nil
	end
end

local function setupCharacter(player, character)
	clearBrick(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not character.Parent then return end

	local brick = template:Clone()
	brick.Name = "Float Brick"
	brick.Anchored = true
	brick.CanCollide = false
	brick.CanTouch = false
	brick.CanQuery = false
	brick.CFrame = root.CFrame * CFrame.new(0, 1.5, 5)
	brick.Parent = workspace
	active[player] = {brick = brick, root = root, elapsed = 0}
end

local function addPlayer(player)
	local added = player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	local removing = player.CharacterRemoving:Connect(function()
		clearBrick(player)
	end)
	connections[player] = {added, removing}
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearBrick(player)
	for _, connection in connections[player] or {} do
		connection:Disconnect()
	end
	connections[player] = nil
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

RunService.Heartbeat:Connect(function(dt)
	for player, state in pairs(active) do
		local root, brick = state.root, state.brick
		if root.Parent and brick.Parent and player.Character == root.Parent then
			state.elapsed += dt
			local bob = math.sin(state.elapsed * 2.6) * 0.35
			local target = root.CFrame * CFrame.new(0, 1.5 + bob, 5)
			local alpha = 1 - math.exp(-7 * dt)
			brick.CFrame = brick.CFrame:Lerp(target, alpha)
		end
	end
end)
