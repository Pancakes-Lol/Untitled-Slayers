-- Handles stat upgrades and level-up rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local assets = ReplicatedStorage:WaitForChild("Assets")
local configs = assets:WaitForChild("Configs")
local StatConfig = require(configs:WaitForChild("StatConfig"))

local upgradeRemote = ReplicatedStorage:FindFirstChild("UpgradeStat") or Instance.new("RemoteEvent")
upgradeRemote.Name = "UpgradeStat"
upgradeRemote.Parent = ReplicatedStorage

local STAT_POINTS_PER_LEVEL = 2
local GEMS_PER_LEVEL = 5
local lastUpgradeRequest = {}

local function setupPlayer(player)
	PlayerData.LoadPlayer(player)

	local leaderstats = player:WaitForChild("leaderstats")
	local level = leaderstats:WaitForChild("Level")
	local currency = player:WaitForChild("Currency")
	local gems = currency:WaitForChild("Gems")
	local statsFolder = player:WaitForChild("Stats")
	local statPoints = statsFolder:WaitForChild("StatPoints")

	local lastLevel = level.Value
	level:GetPropertyChangedSignal("Value"):Connect(function()
		local newLevel = level.Value
		if newLevel > lastLevel then
			local gained = newLevel - lastLevel
			statPoints.Value += gained * STAT_POINTS_PER_LEVEL
			gems.Value += gained * GEMS_PER_LEVEL
			task.spawn(PlayerData.SavePlayer, player)
		end
		lastLevel = newLevel
	end)
end

upgradeRemote.OnServerEvent:Connect(function(player, statId)
	if type(statId) ~= "string" then return end
	local definition = StatConfig[statId]
	if type(definition) ~= "table" then return end

	local now = os.clock()
	if now - (lastUpgradeRequest[player] or 0) < 0.08 then return end
	lastUpgradeRequest[player] = now

	local statsFolder = player:FindFirstChild("Stats")
	if not statsFolder then return end
	local statPoints = statsFolder:FindFirstChild("StatPoints")
	local statValue = statsFolder:FindFirstChild(statId)
	if not statPoints or not statPoints:IsA("IntValue") then return end
	if not statValue or not statValue:IsA("IntValue") then return end

	local cost = math.max(1, math.floor(tonumber(definition.UpgradeCost) or 1))
	if statPoints.Value < cost then return end

	statPoints.Value -= cost
	statValue.Value += 1
	task.spawn(PlayerData.SavePlayer, player)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	lastUpgradeRequest[player] = nil
end)
