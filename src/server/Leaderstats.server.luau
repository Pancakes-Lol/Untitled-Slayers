-- Session-only player progression and currency.
-- Saving is intentionally disabled for now.
local Players = game:GetService("Players")

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

	-- Coins and Gems should not appear on Roblox's player leaderboard.
	local currency = player:FindFirstChild("Currency")
	if not currency then
		currency = Instance.new("Folder")
		currency.Name = "Currency"
		currency.Parent = player
	end
	ensureInt(currency, "Coins", 0)
	ensureInt(currency, "Gems", 0)

	-- Remove old leaderboard currency values if they exist from a previous version.
	for _, name in {"Coins", "Gems", "XPToNextLevel"} do
		local old = stats:FindFirstChild(name)
		if old then old:Destroy() end
	end
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	setup(player)
end
