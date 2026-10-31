-- Currency/XP rewards for enemies. Currency lives outside leaderstats so it does not clutter the Roblox leaderboard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function xpNeededForLevel(level)
	return 100 + math.max(0, level - 1) * 50
end

local function getConfig()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local configs = assets:FindFirstChild("Configs")
	local module = configs and configs:FindFirstChild("EnemyConfig")
	if not module then
		local shared = ReplicatedStorage:WaitForChild("GameShared")
		module = shared:WaitForChild("EnemyConfig")
	end
	return require(module)
end

local EnemyConfig = getConfig()
local liveEnemies = workspace:WaitForChild("LiveEnemies")

local function randomReward(range)
	if type(range) ~= "table" then return 0 end
	local minimum = tonumber(range.Min) or 0
	local maximum = tonumber(range.Max) or minimum
	if maximum < minimum then minimum, maximum = maximum, minimum end
	return math.random(math.floor(minimum), math.floor(maximum))
end

local function award(player, config)
	local stats = player:FindFirstChild("leaderstats")
	local currency = player:FindFirstChild("Currency")
	if not stats or not currency then return end

	local level = stats:FindFirstChild("Level")
	local xp = stats:FindFirstChild("XP")
	local coins = currency:FindFirstChild("Coins")
	if not level or not xp or not coins then return end

	xp.Value += randomReward(config.XPReward)
	local coinConfig = config.PossibleRewards and config.PossibleRewards.Coins
	coins.Value += randomReward(coinConfig)

	while xp.Value >= xpNeededForLevel(level.Value) do
		local needed = xpNeededForLevel(level.Value)
		xp.Value -= needed
		level.Value += 1
	end
end

local function bindEnemy(model)
	if not model:IsA("Model") or model:GetAttribute("CurrencyRewardBound") then return end
	local enemyType = model:GetAttribute("SpawnEnemyType")
	local config = enemyType and EnemyConfig[enemyType]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not config or not humanoid then return end

	model:SetAttribute("CurrencyRewardBound", true)
	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastHitUserId")
		local player = userId and Players:GetPlayerByUserId(userId)
		if player then award(player, config) end
	end)
end

for _, model in ipairs(liveEnemies:GetChildren()) do bindEnemy(model) end
liveEnemies.ChildAdded:Connect(function(model)
	task.defer(bindEnemy, model)
end)
