-- Tetsu slayer onboarding + early hunt quests.
-- Quest progress is session-only for now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npc = workspace:WaitForChild("Tetsu", 30)
if not npc then warn("[Tetsu] Workspace/Tetsu missing") return end
local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("HumanoidRootPart")
if not torso or not torso:IsA("BasePart") then warn("[Tetsu] Missing torso") return end

local assets = ReplicatedStorage:WaitForChild("Assets")
local swordTemplate = assets:WaitForChild("Swords"):WaitForChild("Sword")

local remote = ReplicatedStorage:FindFirstChild("TetsuDialogue") or Instance.new("RemoteEvent")
remote.Name = "TetsuDialogue"
remote.Parent = ReplicatedStorage

local prompt = torso:FindFirstChild("TetsuTalkPrompt") or Instance.new("ProximityPrompt")
prompt.Name = "TetsuTalkPrompt"
prompt.ActionText = "Talk"
prompt.ObjectText = "Tetsu"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = torso

local state = {}
local dummy
local DUMMY_DISTANCE = 19

local QUESTS = {
	AshenPup = {
		title = "AshenPup Hunt",
		enemyType = "AshenPup",
		required = 6,
		coins = 100,
		xp = 75,
	},
	WolfScout = {
		title = "Wolf Hunt",
		enemyType = "WolfScout",
		required = 6,
		coins = 150,
		xp = 100,
	},
}

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
	return math.floor(amount * multiplier + 0.5)
end

local function awardQuest(player, quest)
	local stats = player:FindFirstChild("leaderstats")
	local currency = player:FindFirstChild("Currency")
	if not stats or not currency then return end

	local level = stats:FindFirstChild("Level")
	local xp = stats:FindFirstChild("XP")
	local coins = currency:FindFirstChild("Coins")
	if not level or not xp or not coins then return end

	local xpReward = applyRewardMultiplier(player, quest.xp, "XPMultiplier")
	local coinReward = applyRewardMultiplier(player, quest.coins, "MoneyMultiplier")
	coins.Value += coinReward
	xp.Value += xpReward

	while xp.Value >= xpNeededForLevel(level.Value) do
		local needed = xpNeededForLevel(level.Value)
		xp.Value -= needed
		level.Value += 1
	end
end

local function applyRegularName(player)
	local s = state[player]
	if not s then return end
	s.name = player.DisplayName
	player:SetAttribute("SlayerName", player.DisplayName)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayName = player.DisplayName end
end

local function grantSword(player)
	local s = state[player]
	if not s or (s.stage ~= "hunt" and s.stage ~= "return" and s.stage ~= "done") then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild("Novice Slayer Sword") or (player.Character and player.Character:FindFirstChild("Novice Slayer Sword")) then return end

	local tool = swordTemplate:Clone()
	tool.Name = "Novice Slayer Sword"
	tool.ToolTip = "Your first slayer sword."
	tool.CanBeDropped = false
	tool:SetAttribute("SlayerSword", true)
	tool:SetAttribute("DeveloperSword", true)
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
			send(player, "Quest", {text = "Training enemy defeated! Return to Tetsu to finish your first quest."})
		end
		task.delay(5, function()
			if dummy == model then spawnDummy() end
		end)
	end)
end
spawnDummy()

local function activeQuestInfo(s)
	if s.ashenAccepted and not s.ashenCompleted then
		return QUESTS.AshenPup, "ashenKills", "ashenCompleted"
	end
	if s.wolfAccepted and not s.wolfCompleted then
		return QUESTS.WolfScout, "wolfKills", "wolfCompleted"
	end
	return nil
end

local function offerQuest(player, s, questKey)
	local quest = QUESTS[questKey]
	s.pendingQuest = questKey
	send(player, "Story", {
		text = string.format("I have another job for you. Defeat %d %s%s. Reward: %d coins and %d XP.", quest.required, questKey == "AshenPup" and "AshenPup" or "WolfScout", quest.required == 1 and "" or "s", quest.coins, quest.xp),
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
			text = "You have potential, " .. player.DisplayName .. ". Take this sword and defeat the training enemy to begin your slayer journey.",
			button = "Accept sword & quest",
		})
	elseif s.stage == "hunt" then
		grantSword(player)
		send(player, "Story", {
			text = "Equip your Novice Slayer Sword and defeat the training enemy near me. Click or tap to attack!",
			button = "Let's go",
		})
	elseif s.stage == "return" then
		s.stage = "done"
		send(player, "Story", {
			text = "Well done, " .. player.DisplayName .. "! You defeated your first enemy. Your slayer journey has officially begun! Come talk to me again when you're ready for real work.",
			button = "Thank you!",
		})
	else
		local quest, killsField, completedField = activeQuestInfo(s)
		if quest then
			local kills = s[killsField] or 0
			if kills >= quest.required then
				s[completedField] = true
				awardQuest(player, quest)
				s.pendingQuest = nil
				send(player, "Story", {
					text = string.format("Good work. %s complete! You earned %d coins and %d XP.", quest.title, quest.coins, quest.xp),
					button = "Collect reward",
				})
			else
				send(player, "Story", {
					text = string.format("%s progress: %d/%d. Keep hunting and come back when the job is finished.", quest.title, kills, quest.required),
					button = "Back to hunting",
				})
			end
		elseif not s.ashenCompleted then
			offerQuest(player, s, "AshenPup")
		elseif not s.wolfCompleted then
			offerQuest(player, s, "WolfScout")
		else
			send(player, "Story", {
				text = "You've handled both hunts well, " .. player.DisplayName .. ". Keep training. I'll have tougher work for you soon.",
				button = "Goodbye",
			})
		end
	end
end
prompt.Triggered:Connect(talk)

remote.OnServerEvent:Connect(function(player, action, value)
	local s = state[player]
	if not s or not nearby(player) then return end
	if action == "Close" then return end

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
		talk(player)
	elseif action == "Continue" and s.stage == "done" and s.pendingQuest then
		if s.pendingQuest == "AshenPup" and not s.ashenCompleted then
			s.ashenAccepted = true
			s.ashenKills = 0
		elseif s.pendingQuest == "WolfScout" and s.ashenCompleted and not s.wolfCompleted then
			s.wolfAccepted = true
			s.wolfKills = 0
		end
		local accepted = s.pendingQuest
		s.pendingQuest = nil
		local quest = QUESTS[accepted]
		if quest then
			send(player, "Quest", {text = string.format("Quest accepted: %s — defeat %d targets.", quest.title, quest.required)})
		else
			send(player, "Close")
		end
	elseif action == "Continue" then
		send(player, "Close")
	end
end)

local function bindEnemy(model)
	if not model:IsA("Model") or model:GetAttribute("TetsuQuestBound") then return end
	local enemyType = model:GetAttribute("SpawnEnemyType")
	if enemyType ~= "AshenPup" and enemyType ~= "WolfScout" then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	model:SetAttribute("TetsuQuestBound", true)
	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastHitUserId")
		local player = userId and Players:GetPlayerByUserId(userId)
		local s = player and state[player]
		if not s or s.stage ~= "done" then return end

		if enemyType == "AshenPup" and s.ashenAccepted and not s.ashenCompleted then
			s.ashenKills = math.min((s.ashenKills or 0) + 1, QUESTS.AshenPup.required)
			if s.ashenKills >= QUESTS.AshenPup.required then
				send(player, "Quest", {text = "AshenPup Hunt complete! Return to Tetsu for your reward."})
			end
		elseif enemyType == "WolfScout" and s.wolfAccepted and not s.wolfCompleted then
			s.wolfKills = math.min((s.wolfKills or 0) + 1, QUESTS.WolfScout.required)
			if s.wolfKills >= QUESTS.WolfScout.required then
				send(player, "Quest", {text = "Wolf Hunt complete! Return to Tetsu for your reward."})
			end
		end
	end)
end

local function watchLiveEnemies()
	local liveEnemies = workspace:WaitForChild("LiveEnemies")
	for _, model in ipairs(liveEnemies:GetChildren()) do
		task.defer(bindEnemy, model)
	end
	liveEnemies.ChildAdded:Connect(function(model)
		task.defer(bindEnemy, model)
	end)
end
task.spawn(watchLiveEnemies)

local function setupPlayer(player)
	state[player] = {
		stage = "math",
		name = player.DisplayName,
		ashenAccepted = false,
		ashenKills = 0,
		ashenCompleted = false,
		wolfAccepted = false,
		wolfKills = 0,
		wolfCompleted = false,
		pendingQuest = nil,
	}
	player:SetAttribute("SlayerName", player.DisplayName)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if not state[player] then return end
		applyRegularName(player)
		grantSword(player)
	end)
	if player.Character then
		task.defer(function()
			applyRegularName(player)
			grantSword(player)
		end)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do setupPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
