-- Shared persistent player profile service for Untitled Slayers.
-- Saves progression, currency, materials, stats, and Tetsu/quest progress in one DataStore.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "UntitledSlayers_PlayerData_v1"
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 3
local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerData = {}
local profiles = {}
local loading = {}
local writable = {}

local DEFAULT_PROFILE = {
	Version = 1,
	Level = 1,
	XP = 0,
	Coins = 0,
	Gems = 0,
	StatPoints = 0,
	Stats = {
		Stat1 = 0,
		Stat2 = 0,
		Stat3 = 0,
	},
	Materials = {},
	Quest = {
		stage = "math",
		questIndex = 1,
		questKills = 0,
		questCooldownUntil = 0,
		completedQuests = {},
	},
}

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function reconcile(data, defaults)
	if type(data) ~= "table" then
		return deepCopy(defaults)
	end
	for key, defaultValue in pairs(defaults) do
		if data[key] == nil then
			data[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" then
			data[key] = reconcile(data[key], defaultValue)
		end
	end
	return data
end

local function clampInteger(value, minimum)
	value = tonumber(value) or minimum
	value = math.floor(value)
	return math.max(minimum, value)
end

local function sanitizeProfile(profile)
	profile = reconcile(profile, DEFAULT_PROFILE)
	profile.Version = 1
	profile.Level = clampInteger(profile.Level, 1)
	profile.XP = clampInteger(profile.XP, 0)
	profile.Coins = clampInteger(profile.Coins, 0)
	profile.Gems = clampInteger(profile.Gems, 0)
	profile.StatPoints = clampInteger(profile.StatPoints, 0)
	profile.Stats = type(profile.Stats) == "table" and profile.Stats or {}
	for statId, defaultValue in pairs(DEFAULT_PROFILE.Stats) do
		profile.Stats[statId] = clampInteger(profile.Stats[statId], defaultValue)
	end
	profile.Materials = type(profile.Materials) == "table" and profile.Materials or {}

	local quest = profile.Quest
	quest.stage = type(quest.stage) == "string" and quest.stage or "math"
	quest.questIndex = clampInteger(quest.questIndex, 1)
	quest.questKills = clampInteger(quest.questKills, 0)
	quest.questCooldownUntil = clampInteger(quest.questCooldownUntil, 0)
	quest.pendingQuest = type(quest.pendingQuest) == "string" and quest.pendingQuest or nil
	quest.activeQuest = type(quest.activeQuest) == "string" and quest.activeQuest or nil
	quest.completedQuests = type(quest.completedQuests) == "table" and quest.completedQuests or {}
	return profile
end

local function ensureInt(folder, name, value)
	local object = folder:FindFirstChild(name)
	if not object or not object:IsA("IntValue") then
		if object then object:Destroy() end
		object = Instance.new("IntValue")
		object.Name = name
		object.Parent = folder
	end
	object.Value = clampInteger(value, 0)
	return object
end

local function applyProfileToPlayer(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	ensureInt(stats, "Level", profile.Level).Value = math.max(1, profile.Level)
	ensureInt(stats, "XP", profile.XP)

	for _, name in ipairs({"Coins", "Gems", "XPToNextLevel"}) do
		local old = stats:FindFirstChild(name)
		if old then old:Destroy() end
	end

	local currency = player:FindFirstChild("Currency")
	if not currency then
		currency = Instance.new("Folder")
		currency.Name = "Currency"
		currency.Parent = player
	end
	ensureInt(currency, "Coins", profile.Coins)
	ensureInt(currency, "Gems", profile.Gems)

	local upgradeStats = player:FindFirstChild("Stats")
	if not upgradeStats then
		upgradeStats = Instance.new("Folder")
		upgradeStats.Name = "Stats"
		upgradeStats.Parent = player
	end
	ensureInt(upgradeStats, "StatPoints", profile.StatPoints)
	for statId, amount in pairs(profile.Stats) do
		if type(statId) == "string" and tonumber(amount) then
			ensureInt(upgradeStats, statId, amount)
		end
	end

	local materials = player:FindFirstChild("Materials")
	if not materials then
		materials = Instance.new("Folder")
		materials.Name = "Materials"
		materials.Parent = player
	end
	for _, child in ipairs(materials:GetChildren()) do
		if child:IsA("IntValue") and profile.Materials[child.Name] == nil then
			child:Destroy()
		end
	end
	for materialName, amount in pairs(profile.Materials) do
		if type(materialName) == "string" and tonumber(amount) then
			ensureInt(materials, materialName, amount)
		end
	end

	player:SetAttribute("PlayerDataLoaded", true)
end

local function capturePlayerValues(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	local currency = player:FindFirstChild("Currency")
	local upgradeStats = player:FindFirstChild("Stats")
	local materials = player:FindFirstChild("Materials")

	local level = stats and stats:FindFirstChild("Level")
	local xp = stats and stats:FindFirstChild("XP")
	local coins = currency and currency:FindFirstChild("Coins")
	local gems = currency and currency:FindFirstChild("Gems")

	if level and level:IsA("IntValue") then profile.Level = math.max(1, level.Value) end
	if xp and xp:IsA("IntValue") then profile.XP = math.max(0, xp.Value) end
	if coins and coins:IsA("IntValue") then profile.Coins = math.max(0, coins.Value) end
	if gems and gems:IsA("IntValue") then profile.Gems = math.max(0, gems.Value) end

	if upgradeStats then
		local points = upgradeStats:FindFirstChild("StatPoints")
		if points and points:IsA("IntValue") then
			profile.StatPoints = math.max(0, points.Value)
		end
		local statData = {}
		for statId in pairs(DEFAULT_PROFILE.Stats) do
			local value = upgradeStats:FindFirstChild(statId)
			statData[statId] = value and value:IsA("IntValue") and math.max(0, value.Value) or 0
		end
		profile.Stats = statData
	end

	local materialData = {}
	if materials then
		for _, child in ipairs(materials:GetChildren()) do
			if child:IsA("IntValue") and child.Value > 0 then
				materialData[child.Name] = child.Value
			end
		end
	end
	profile.Materials = materialData
end

local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

function PlayerData.LoadPlayer(player)
	if profiles[player] then return profiles[player] end
	while loading[player] do
		task.wait()
		if profiles[player] then return profiles[player] end
	end

	loading[player] = true
	local loadedData
	local loadSucceeded = false
	local lastError

	for attempt = 1, LOAD_ATTEMPTS do
		local success, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if success then
			loadedData = result
			loadSucceeded = true
			break
		end
		lastError = result
		if attempt < LOAD_ATTEMPTS then
			task.wait(attempt)
		end
	end

	if not loadSucceeded then
		warn("[PlayerData] Load failed for " .. player.Name .. " after retries: " .. tostring(lastError))
	end

	local profile = sanitizeProfile(loadedData)
	profiles[player] = profile
	writable[player] = loadSucceeded
	loading[player] = nil

	if player.Parent == Players then
		applyProfileToPlayer(player, profile)
		player:SetAttribute("PlayerDataPersistent", loadSucceeded)
	end
	return profile
end

function PlayerData.GetProfile(player)
	return profiles[player] or PlayerData.LoadPlayer(player)
end

function PlayerData.GetQuestState(player)
	local profile = PlayerData.GetProfile(player)
	return profile and profile.Quest or nil
end

function PlayerData.SavePlayer(player)
	local profile = profiles[player]
	if not profile then return false end
	-- Never overwrite a real save with defaults when GetAsync failed.
	if writable[player] ~= true then return false end

	capturePlayerValues(player, profile)
	profile = sanitizeProfile(profile)
	local payload = deepCopy(profile)

	local success, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)
	if not success then
		warn("[PlayerData] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

function PlayerData.ReleasePlayer(player)
	PlayerData.SavePlayer(player)
	profiles[player] = nil
	loading[player] = nil
	writable[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.ReleasePlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(PlayerData.SavePlayer, player)
		end
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	local remaining = #players
	if remaining == 0 then return end

	local finished = Instance.new("BindableEvent")
	for _, player in ipairs(players) do
		task.spawn(function()
			PlayerData.SavePlayer(player)
			remaining -= 1
			if remaining <= 0 then finished:Fire() end
		end)
	end
	if remaining > 0 then
		finished.Event:Wait()
	end
	finished:Destroy()
end)

return PlayerData
