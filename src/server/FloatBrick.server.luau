-- Keeps a personal Float Brick approximately five studs ahead of every player.
-- The original Workspace["Float Brick"] is used as a template and stored away.
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
	if active[player] then
		active[player]:Destroy()
		active[player] = nil
	end
end

local function setupCharacter(player, character)
	clearBrick(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local brick = template:Clone()
	brick.Name = "Float Brick"
	brick.Anchored = true
	brick.CanCollide = false
	brick.CanTouch = false
	brick.CanQuery = false
	brick.Parent = workspace
	active[player] = brick
end

local function addPlayer(player)
	connections[player] = player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		clearBrick(player)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearBrick(player)
	if connections[player] then
		connections[player]:Disconnect()
		connections[player] = nil
	end
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

RunService.Heartbeat:Connect(function()
	for player, brick in pairs(active) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and brick.Parent then
			brick.CFrame = root.CFrame * CFrame.new(0, 1.5, -5)
		end
	end
end)
