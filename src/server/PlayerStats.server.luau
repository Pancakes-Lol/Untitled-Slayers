-- Player combat-stat progression.
-- Each level awards 2 stat points and 5 gems.
-- Each stat upgrade costs 1 point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local upgradeRemote = ReplicatedStorage:FindFirstChild("UpgradeStat") or Instance.new("RemoteEvent")
upgradeRemote.Name = "UpgradeStat"
upgradeRemote.Parent = ReplicatedStorage

local POINTS_PER_LEVEL = 2
local GEMS_PER_LEVEL = 5

local BASE_WALK_SPEED = 16
local AGILITY_SPEED_PER_POINT = 0.5
local BASE_MAX_HEALTH = 100
local HEALTH_PER_DEFENSE = 10
local BASE_SWORD_DAMAGE = 20
local DAMAGE_PER_ATTACK = 2

local VALID_STATS = {
	Agility = true,
	Defense = true,
	Attack = true,
}

local function statObjects(player)
	local folder = player:FindFirstChild("Stats")
	if not folder then return end
	return folder,
		folder:FindFirstChild("StatPoints"),
		folder:FindFirstChild("Agility"),
		folder:FindFirstChild("Defense"),
		folder:FindFirstChild("Attack")
end

local function applyCharacterStats(player, fullHeal)
	local _, _, agilityValue, defenseValue, attackValue = statObjects(player)
	if not agilityValue or not defenseValue or not attackValue then return end

	local agility = math.max(0, agilityValue.Value)
	local defense = math.max(0, defenseValue.Value)
	local attack = math.max(0, attackValue.Value)

	local walkSpeed = BASE_WALK_SPEED + (agility * AGILITY_SPEED_PER_POINT)
	local sprintSpeed = walkSpeed * 2
	local maxHealth = BASE_MAX_HEALTH + (defense * HEALTH_PER_DEFENSE)
	local swordDamage = BASE_SWORD_DAMAGE + (attack * DAMAGE_PER_ATTACK)

	player:SetAttribute("BaseWalkSpeed", walkSpeed)
	player:SetAttribute("SprintWalkSpeed", sprintSpeed)
	player:SetAttribute("MaxHealth", maxHealth)
	player:SetAttribute("SwordDamage", swordDamage)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local oldMax = humanoid.MaxHealth
		humanoid.MaxHealth = maxHealth
		if fullHeal then
			humanoid.Health = maxHealth
		elseif maxHealth > oldMax then
			humanoid.Health = math.min(maxHealth, humanoid.Health + (maxHealth - oldMax))
		else
			humanoid.Health = math.min(humanoid.Health, maxHealth)
		end
		humanoid.WalkSpeed = player:GetAttribute("SprintEnabled") and sprintSpeed or walkSpeed
	end
end

local function grantPendingLevelRewards(player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local currency = player:FindFirstChild("Currency")
	local statsFolder, points = statObjects(player)
	if not leaderstats or not currency or not statsFolder or not points then return end

	local level = leaderstats:FindFirstChild("Level")
	local gems = currency:FindFirstChild("Gems")
	if not level or not gems then return end

	local rewardedThrough = math.max(1, math.floor(tonumber(profile.LevelRewardsThrough) or 1))
	local currentLevel = math.max(1, level.Value)
	if currentLevel <= rewardedThrough then return end

	local gainedLevels = currentLevel - rewardedThrough
	profile.LevelRewardsThrough = currentLevel
	points.Value += gainedLevels * POINTS_PER_LEVEL
	gems.Value += gainedLevels * GEMS_PER_LEVEL

	task.spawn(PlayerData.SavePlayer, player)
end

local function setupPlayer(player)
	local profile = PlayerData.LoadPlayer(player)
	if not profile or player.Parent ~= Players then return end

	local statsFolder, points, agility, defense, attack = statObjects(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	if not statsFolder or not points or not agility or not defense or not attack or not level then
		warn("[PlayerStats] Missing loaded stat objects for " .. player.Name)
		return
	end

	-- If this system is being introduced to an already-leveled save, grant the
	-- level rewards once and remember the highest rewarded level in PlayerData.
	grantPendingLevelRewards(player, profile)
	applyCharacterStats(player, true)

	level:GetPropertyChangedSignal("Value"):Connect(function()
		grantPendingLevelRewards(player, profile)
	end)

	agility:GetPropertyChangedSignal("Value"):Connect(function()
		applyCharacterStats(player, false)
	end)
	defense:GetPropertyChangedSignal("Value"):Connect(function()
		applyCharacterStats(player, false)
	end)
	attack:GetPropertyChangedSignal("Value"):Connect(function()
		applyCharacterStats(player, false)
	end)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.defer(applyCharacterStats, player, true)
		end
	end)
end

upgradeRemote.OnServerEvent:Connect(function(player, statName)
	if type(statName) ~= "string" or not VALID_STATS[statName] then return end
	local statsFolder, points = statObjects(player)
	if not statsFolder or not points or points.Value < 1 then return end

	local stat = statsFolder:FindFirstChild(statName)
	if not stat or not stat:IsA("IntValue") then return end

	points.Value -= 1
	stat.Value += 1
	applyCharacterStats(player, false)
	task.spawn(PlayerData.SavePlayer, player)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end
