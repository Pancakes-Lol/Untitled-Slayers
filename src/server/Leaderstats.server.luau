-- Session-only player progression and currency.
-- Saving is intentionally disabled for now.
local Players = game:GetService("Players")

local function xpNeededForLevel(level)
	return 100 + math.max(0, level - 1) * 50
end

local function ensureInt(folder, name, defaultValue)
	local value = folder:FindFirstChild(name)
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Value = defaultValue
		value.Parent = folder
	end
	return value
end

local function setup(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	ensureInt(stats, "Level", 1)
	ensureInt(stats, "XP", 0)
	ensureInt(stats, "XPToNextLevel", xpNeededForLevel(1))
	ensureInt(stats, "Coins", 0)
	ensureInt(stats, "Gems", 0)
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	setup(player)
end
