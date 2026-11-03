-- Tetsu onboarding + data-driven early quests with persistent quest state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local npc = workspace:WaitForChild("Tetsu", 30)
if not npc then warn("[Tetsu] Workspace/Tetsu missing") return end
local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("HumanoidRootPart")
if not torso or not torso:IsA("BasePart") then warn("[Tetsu] Missing torso") return end

local assets = ReplicatedStorage:WaitForChild("Assets")
local configs = assets:WaitForChild("Configs")
local swordsFolder = assets:WaitForChild("Swords")
local QuestConfig = require(configs:WaitForChild("QuestConfig"))

local SwordsConfig = {}
do
	local module = configs:FindFirstChild("SwordsConfig")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			SwordsConfig = result
		else
			warn("[Tetsu] Could not require Assets.Configs.SwordsConfig: " .. tostring(result))
		end
	else
		warn("[Tetsu] Assets.Configs.SwordsConfig is missing; tutorial sword will use the katana Tool fallback.")
	end
end

local remote = ReplicatedStorage:FindFirstChild("TetsuDialogue") or Instance.new("RemoteEvent")
remote.Name = "TetsuDialogue"
remote.Parent = ReplicatedStorage

local questRemote = ReplicatedStorage:FindFirstChild("QuestUpdate") or Instance.new("RemoteEvent")
questRemote.Name = "QuestUpdate"
questRemote.Parent = ReplicatedStorage

local prompt = torso:FindFirstChild("TetsuTalkPrompt") or Instance.new("ProximityPrompt")
prompt.Name = "TetsuTalkPrompt"
prompt.ActionText = "Talk"
prompt.ObjectText = "Tetsu"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = torso

local QUEST_ORDER = {"AshenPup", "WolfScout"}
local state = {}
local dummy
local DUMMY_DISTANCE = 19

local function send(player, kind, data)
	remote:FireClient(player, kind, data or {})
end

local function nearby(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - torso.Position).Magnitude <= 18
end

local function xpNeededForLevel(level)
	return 100 + math.max(0, level - 1) * 50
end

local function applyRewardMultiplier(player, amount, attributeName)
	local multiplier = tonumber(player:GetAttribute(attributeName)) or 1
	return math.floor((tonumber(amount) or 0) * multiplier + 0.5)
end

local function ensureMaterialsFolder(player)
	local folder = player:FindFirstChild("Materials")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Materials"
		folder.Parent = player
	end
	return folder
end

local function awardQuest(player, quest)
	local stats = player:FindFirstChild("leaderstats")
	local currency = player:FindFirstChild("Currency")
	if not stats or not currency then return end
	local level = stats:FindFirstChild("Level")
	local xp = stats:FindFirstChild("XP")
	local coins = currency:FindFirstChild("Coins")
	if not level or not xp or not coins then return end

	local rewards = quest.Rewards or {}
	xp.Value += applyRewardMultiplier(player, rewards.XP or 0, "XPMultiplier")
	coins.Value += applyRewardMultiplier(player, rewards.Cash or 0, "MoneyMultiplier")

	if type(rewards.Materials) == "table" then
		local materials = ensureMaterialsFolder(player)
		for materialName, amount in pairs(rewards.Materials) do
			if type(materialName) == "string" and tonumber(amount) and amount > 0 then
				local value = materials:FindFirstChild(materialName)
				if not value then
					value = Instance.new("IntValue")
					value.Name = materialName
					value.Parent = materials
				end
				value.Value += math.floor(amount)
			end
		end
	end

	while xp.Value >= xpNeededForLevel(level.Value) do
		local needed = xpNeededForLevel(level.Value)
		xp.Value -= needed
		level.Value += 1
	end
end

local function fireTracker(player, questId, progress, complete)
	local quest = questId and QuestConfig[questId]
	if not quest then
		questRemote:FireClient(player, {Visible = false})
		return
	end
	questRemote:FireClient(player, {
		Visible = true,
		QuestId = questId,
		Title = quest.Title or questId,
		Description = quest.QuestDescription or quest.QuestDescriptiom or ("Defeat " .. tostring(quest.AmountOfEnemy) .. " " .. tostring(quest.Enemy)),
		Progress = progress or 0,
		Amount = quest.AmountOfEnemy or 0,
		Rewards = quest.Rewards or {},
		Complete = complete == true,
	})
end

local function syncTracker(player, s)
	if not s then
		questRemote:FireClient(player, {Visible = false})
		return
	end

	if s.stage == "hunt" then
		questRemote:FireClient(player, {
			Visible = true,
			Title = "Tutorial",
			Description = "Defeat the training enemy, then return to Tetsu.",
			Progress = 0,
			Amount = 1,
			Rewards = {},
			Complete = false,
		})
		return
	end

	if s.stage == "return" then
		questRemote:FireClient(player, {
			Visible = true,
			Title = "Tutorial",
			Description = "Defeat the training enemy, then return to Tetsu.",
			Progress = 1,
			Amount = 1,
			Rewards = {},
			Complete = true,
		})
		return
	end

	if s.activeQuest then
		local quest = QuestConfig[s.activeQuest]
		local amount = quest and (tonumber(quest.AmountOfEnemy) or 0) or 0
		fireTracker(player, s.activeQuest, s.questKills or 0, (s.questKills or 0) >= amount)
		return
	end

	questRemote:FireClient(player, {Visible = false})
end

local function playerLevel(player)
	local stats = player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	return level and level.Value or 1
end

local function applyRegularName(player)
	player:SetAttribute("SlayerName", player.DisplayName)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayName = player.DisplayName end
end

local function tutorialSwordDefinition()
	local bestKey, bestDefinition
	for key, definition in pairs(SwordsConfig) do
		if type(definition) == "table" then
			local combined = string.lower(tostring(key) .. " " .. tostring(definition.Name or "") .. " " .. tostring(definition.DisplayName or ""))
			if definition.Tutorial == true or definition.Starter == true or string.find(combined, "katana", 1, true) then
				bestKey, bestDefinition = tostring(key), definition
				if definition.Tutorial == true or definition.Starter == true then break end
			end
		end
	end
	return bestKey, bestDefinition
end

local function configuredTutorialSwordTemplate()
	local configKey, definition = tutorialSwordDefinition()
	local candidates = {}
	if definition then
		for _, field in ipairs({"ToolName", "AssetName", "ModelName", "SwordName", "Name"}) do
			local value = definition[field]
			if type(value) == "string" and value ~= "" then table.insert(candidates, value) end
		end
	end
	if configKey then table.insert(candidates, configKey) end
	table.insert(candidates, "Katana")
	table.insert(candidates, "Sword")

	for _, name in ipairs(candidates) do
		local found = swordsFolder:FindFirstChild(name, true)
		if found and found:IsA("Tool") then return found, configKey end
	end
	for _, obj in ipairs(swordsFolder:GetDescendants()) do
		if obj:IsA("Tool") and string.find(string.lower(obj.Name), "katana", 1, true) then return obj, configKey end
	end
	for _, obj in ipairs(swordsFolder:GetDescendants()) do
		if obj:IsA("Tool") then return obj, configKey end
	end
	return nil, configKey
end

local function hasSlayerSword(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({backpack, player.Character}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and (child:GetAttribute("TutorialSword") or child:GetAttribute("SlayerSword")) then return true end
			end
		end
	end
	return false
end

local function grantSword(player)
	local s = state[player]
	if not s or (s.stage ~= "hunt" and s.stage ~= "return" and s.stage ~= "done") then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or hasSlayerSword(player) then return end

	local template, configKey = configuredTutorialSwordTemplate()
	if not template then
		warn("[Tetsu] No tutorial katana Tool found in ReplicatedStorage.Assets.Swords")
		return
	end
	local tool = template:Clone()
	if tool.Name == "Sword" then tool.Name = "Novice Slayer Sword" end
	tool.CanBeDropped = false
	tool:SetAttribute("SlayerSword", true)
	tool:SetAttribute("DeveloperSword", true)
	tool:SetAttribute("TutorialSword", true)
	if configKey then tool:SetAttribute("SwordConfigId", configKey) end
	tool.Parent = backpack
end

local function spawnDummy()
	if dummy and dummy.Parent then dummy:Destroy() end
	local model = Instance.new("Model")
	model.Name = "Slayer Training Enemy"
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(3, 4, 2)
	body.Anchored = true
	body.Color = Color3.fromRGB(127, 78, 58)
	body.Material = Enum.Material.Wood
	body.CFrame = torso.CFrame * CFrame.new(0, 0, -DUMMY_DISTANCE)
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Color3.fromRGB(154, 108, 79)
	head.CFrame = body.CFrame * CFrame.new(0, 3, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model
	model.PrimaryPart = body
	model.Parent = workspace
	dummy = model

	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastHitUserId")
		local player = userId and Players:GetPlayerByUserId(userId)
		local s = player and state[player]
		if s and s.stage == "hunt" then
			s.stage = "return"
			syncTracker(player, s)
		end
		task.delay(5, function()
			if dummy == model then spawnDummy() end
		end)
	end)
end
spawnDummy()

local function nextQuestId(s)
	return QUEST_ORDER[s.questIndex]
end

local function offerNextQuest(player, s)
	local questId = nextQuestId(s)
	local quest = questId and QuestConfig[questId]
	if not quest then
		s.pendingQuest = nil
		send(player, "Story", {text = "You've handled every job I have for now. Keep training.", button = "Goodbye"})
		return
	end
	local requiredLevel = tonumber(quest.LevelRequired) or 1
	if playerLevel(player) < requiredLevel then
		s.pendingQuest = nil
		send(player, "Story", {
			text = string.format("Come back at level %d for your next quest.", requiredLevel),
			button = "Got it",
		})
		return
	end
	s.pendingQuest = questId
	local rewards = quest.Rewards or {}
	send(player, "Story", {
		text = string.format("%s Reward: %d cash and %d XP.", quest.QuestDescription or quest.QuestDescriptiom or "I have a hunt for you.", rewards.Cash or 0, rewards.XP or 0),
		button = "Accept quest",
	})
end

local function talk(player)
	local s = state[player]
	if not s or not nearby(player) then return end

	if s.stage == "math" then
		send(player, "Question", {
			question = "Welcome, " .. player.DisplayName .. ". One quick test: what's 9 + 10?",
			answers = {"19", "21", "910"},
		})
	elseif s.stage == "offer" then
		send(player, "Story", {
			text = "You have potential. Take this katana and defeat the training enemy to begin your slayer journey.",
			button = "Accept sword & quest",
		})
	elseif s.stage == "hunt" then
		grantSword(player)
		send(player, "Story", {text = "Equip your katana and defeat the training enemy near me.", button = "Let's go"})
	elseif s.stage == "return" then
		s.stage = "done"
		syncTracker(player, s)
		send(player, "Story", {
			text = "Well done! You defeated your first enemy. Your slayer journey has officially begun.",
			button = "Thank you!",
		})
	elseif s.activeQuest then
		local quest = QuestConfig[s.activeQuest]
		local amount = quest and (tonumber(quest.AmountOfEnemy) or 0) or 0
		if quest and s.questKills >= amount then
			local completedId = s.activeQuest
			awardQuest(player, quest)
			s.completedQuests[completedId] = true
			s.activeQuest = nil
			s.questKills = 0
			s.questIndex += 1
			syncTracker(player, s)
			local rewards = quest.Rewards or {}
			send(player, "Story", {
				text = string.format("Good work. %s complete! You earned %d cash and %d XP.", quest.Title or completedId, rewards.Cash or 0, rewards.XP or 0),
				button = "Collect reward",
			})
		else
			fireTracker(player, s.activeQuest, s.questKills, false)
			send(player, "Story", {
				text = string.format("%s progress: %d/%d. Keep hunting.", quest and (quest.Title or s.activeQuest) or s.activeQuest, s.questKills, amount),
				button = "Back to hunting",
			})
		end
	else
		offerNextQuest(player, s)
	end
end
prompt.Triggered:Connect(talk)

remote.OnServerEvent:Connect(function(player, action, value)
	local s = state[player]
	if not s then return end
	if action == "Close" then return end
	if not nearby(player) then return end

	if action == "Choose" and s.stage == "math" and type(value) == "number" and value % 1 == 0 and value >= 1 and value <= 3 then
		s.stage = "offer"
		send(player, "Story", {
			text = (value == 2 and "21?! Ha! I like your confidence. " or value == 1 and "Correct! " or "That's... creative. ") .. "Now let's begin your slayer journey.",
			button = "Continue",
		})
	elseif action == "Continue" and s.stage == "offer" then
		talk(player)
	elseif action == "Accept" and s.stage == "offer" then
		s.stage = "hunt"
		grantSword(player)
		syncTracker(player, s)
		talk(player)
	elseif action == "Continue" and s.stage == "done" and s.pendingQuest then
		local questId = s.pendingQuest
		local quest = QuestConfig[questId]
		s.pendingQuest = nil
		if quest and playerLevel(player) >= (tonumber(quest.LevelRequired) or 1) then
			s.activeQuest = questId
			s.questKills = 0
			fireTracker(player, questId, 0, false)
		end
		send(player, "Close")
	elseif action == "Continue" then
		send(player, "Close")
	end
end)

local function bindEnemy(model)
	if not model:IsA("Model") or model:GetAttribute("TetsuQuestBound") then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local enemyType = model:GetAttribute("SpawnEnemyType")
	if not humanoid or not enemyType then return end
	model:SetAttribute("TetsuQuestBound", true)
	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastHitUserId")
		local player = userId and Players:GetPlayerByUserId(userId)
		local s = player and state[player]
		if not s or s.stage ~= "done" or not s.activeQuest then return end
		local quest = QuestConfig[s.activeQuest]
		if not quest or quest.Enemy ~= enemyType then return end
		local amount = tonumber(quest.AmountOfEnemy) or 0
		s.questKills = math.min((s.questKills or 0) + 1, amount)
		fireTracker(player, s.activeQuest, s.questKills, s.questKills >= amount)
	end)
end

local function watchLiveEnemies()
	local liveEnemies = workspace:WaitForChild("LiveEnemies")
	for _, model in ipairs(liveEnemies:GetChildren()) do task.defer(bindEnemy, model) end
	liveEnemies.ChildAdded:Connect(function(model) task.defer(bindEnemy, model) end)
end
task.spawn(watchLiveEnemies)

local function setupPlayer(player)
	local profile = PlayerData.LoadPlayer(player)
	local savedQuest = profile and profile.Quest
	if not savedQuest then return end

	savedQuest.stage = type(savedQuest.stage) == "string" and savedQuest.stage or "math"
	savedQuest.questIndex = math.max(1, math.floor(tonumber(savedQuest.questIndex) or 1))
	savedQuest.questKills = math.max(0, math.floor(tonumber(savedQuest.questKills) or 0))
	savedQuest.completedQuests = type(savedQuest.completedQuests) == "table" and savedQuest.completedQuests or {}
	state[player] = savedQuest

	applyRegularName(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.6)
		local s = state[player]
		if not s then return end
		applyRegularName(player)
		grantSword(player)
		syncTracker(player, s)
	end)

	if player.Character then
		task.delay(0.6, function()
			if not state[player] then return end
			grantSword(player)
			syncTracker(player, state[player])
		end)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
