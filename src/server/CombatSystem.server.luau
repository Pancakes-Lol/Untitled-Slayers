-- Shared sword combat + Dawnreach enemy spawner.
-- Primary enemy tuning: ReplicatedStorage.Assets.Configs.EnemyConfig
-- Fallback tuning: ReplicatedStorage.GameShared.EnemyConfig
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Create the remote immediately so the client never hangs, even if config loading has a problem.
local combatRemote = ReplicatedStorage:FindFirstChild("SwordCombat") or Instance.new("RemoteEvent")
combatRemote.Name = "SwordCombat"
combatRemote.Parent = ReplicatedStorage

local assets = ReplicatedStorage:WaitForChild("Assets")
local swordsFolder = assets:WaitForChild("Swords")
local swordTemplate = swordsFolder:WaitForChild("Sword")

local function resolveEnemyConfig()
	local configsFolder = assets:FindFirstChild("Configs")
	local primary = configsFolder and configsFolder:FindFirstChild("EnemyConfig")
	if primary and primary:IsA("ModuleScript") then
		local ok, result = pcall(require, primary)
		if ok then return result end
		warn("[CombatSystem] Could not require Assets.Configs.EnemyConfig: " .. tostring(result))
	end

	local gameShared = ReplicatedStorage:FindFirstChild("GameShared")
	local fallback = gameShared and gameShared:FindFirstChild("EnemyConfig")
	if fallback and fallback:IsA("ModuleScript") then
		warn("[CombatSystem] Using GameShared.EnemyConfig fallback. Restart Rojo to load Assets.Configs.EnemyConfig.")
		return require(fallback)
	end

	error("[CombatSystem] EnemyConfig missing from both Assets.Configs and GameShared")
end

local EnemyConfig = resolveEnemyConfig()
local spawnRoot = workspace:WaitForChild("EnemieSpawnPoints"):WaitForChild("Dawnreach")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")

local enemyFolder = workspace:FindFirstChild("LiveEnemies") or Instance.new("Folder")
enemyFolder.Name = "LiveEnemies"
enemyFolder.Parent = workspace

local PLAYER_ATTACK_COOLDOWN = 0.42
local PLAYER_DAMAGE = 20

local templateFolder = ServerStorage:FindFirstChild("EnemyTemplates") or Instance.new("Folder")
templateFolder.Name = "EnemyTemplates"
templateFolder.Parent = ServerStorage

local function xpNeededForLevel(level)
	return 100 + math.max(0, level - 1) * 50
end

local function awardPlayer(player, xpAmount, coinAmount)
	local stats = player and player:FindFirstChild("leaderstats")
	if not stats then return end
	local level = stats:FindFirstChild("Level")
	local xp = stats:FindFirstChild("XP")
	local xpToNext = stats:FindFirstChild("XPToNextLevel")
	local coins = stats:FindFirstChild("Coins")
	if not level or not xp or not xpToNext or not coins then return end

	coins.Value += coinAmount
	xp.Value += xpAmount
	while xp.Value >= xpNeededForLevel(level.Value) do
		local needed = xpNeededForLevel(level.Value)
		xp.Value -= needed
		level.Value += 1
	end
	xpToNext.Value = xpNeededForLevel(level.Value)
end

local function randomReward(range, fallback)
	if type(range) ~= "table" then return fallback or 0 end
	local minValue = tonumber(range.Min) or fallback or 0
	local maxValue = tonumber(range.Max) or minValue
	if maxValue < minValue then minValue, maxValue = maxValue, minValue end
	return math.random(math.floor(minValue), math.floor(maxValue))
end

local function takeTemplate(name)
	local stored = templateFolder:FindFirstChild(name)
	if stored then return stored end
	local model = workspace:FindFirstChild(name)
	if not model or not model:IsA("Model") then
		warn("[CombatSystem] Missing Workspace." .. name .. " enemy model")
		return nil
	end
	model.Archivable = true
	model.Parent = templateFolder
	return model
end

local templates = {}
for enemyName, config in pairs(EnemyConfig) do
	templates[enemyName] = takeTemplate(config.ModelName or enemyName)
end

local function cloneDevSword(displayName)
	local tool = swordTemplate:Clone()
	tool.Name = displayName or "Novice Slayer Sword"
	tool.CanBeDropped = false
	tool:SetAttribute("SlayerSword", true)
	tool:SetAttribute("DeveloperSword", true)
	return tool
end

local function replaceOldSword(container)
	if not container then return end
	local old = container:FindFirstChild("Novice Slayer Sword")
	if not old or not old:IsA("Tool") or old:GetAttribute("DeveloperSword") then return end
	local replacement = cloneDevSword("Novice Slayer Sword")
	old:Destroy()
	replacement.Parent = container
end

local function watchPlayer(player)
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Novice Slayer Sword" and not child:GetAttribute("DeveloperSword") then
			task.defer(replaceOldSword, backpack)
		end
	end)
	replaceOldSword(backpack)

	player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == "Novice Slayer Sword" and not child:GetAttribute("DeveloperSword") then
				task.defer(replaceOldSword, character)
			end
		end)
		task.defer(replaceOldSword, character)
	end)
end
for _, player in ipairs(Players:GetPlayers()) do task.spawn(watchPlayer, player) end
Players.PlayerAdded:Connect(watchPlayer)

local animationCache = {}
local function resolveAnimation(name)
	if animationCache[name] then return animationCache[name] end

	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("Animation") and obj.Name == name and obj.AnimationId ~= "" then
			animationCache[name] = obj
			return obj
		end
	end

	local sequence = animSaves:FindFirstChild(name)
	if sequence and sequence:IsA("KeyframeSequence") then
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end)
		if ok and id then
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = id
			animationCache[name] = anim
			return anim
		end
	end

	warn("[CombatSystem] Animation not available: " .. name)
	return nil
end

local function loadTrack(animator, name, priority, looped)
	local anim = resolveAnimation(name)
	if not anim then return nil end
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok then return nil end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function setupNpcAnimations(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {
		idle = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true),
		walk = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true),
		attacks = {},
	}
	for i = 1, 5 do
		tracks.attacks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
	end
	return tracks
end

local function setMoving(tracks, moving)
	if moving then
		if tracks.idle and tracks.idle.IsPlaying then tracks.idle:Stop(0.15) end
		if tracks.walk and not tracks.walk.IsPlaying then tracks.walk:Play(0.15) end
	else
		if tracks.walk and tracks.walk.IsPlaying then tracks.walk:Stop(0.15) end
		if tracks.idle and not tracks.idle.IsPlaying then tracks.idle:Play(0.15) end
	end
end

local function playDifferentAttack(tracks, lastIndex)
	local choices = {}
	for i = 1, 5 do
		if i ~= lastIndex and tracks.attacks[i] then table.insert(choices, i) end
	end
	if #choices == 0 then return lastIndex end
	local index = choices[math.random(1, #choices)]
	tracks.attacks[index]:Play(0.08, 1, 1)
	return index
end

local function nearestPlayer(position, aggroDistance)
	local bestPlayer, bestRoot, bestHum, bestDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance <= aggroDistance and (not bestDistance or distance < bestDistance) then
				bestPlayer, bestRoot, bestHum, bestDistance = player, root, hum, distance
			end
		end
	end
	return bestPlayer, bestRoot, bestHum, bestDistance
end

local function equipNpcSword(model, humanoid)
	local tool = cloneDevSword("Sword")
	tool.Parent = model
	pcall(function() humanoid:EquipTool(tool) end)
end

local function spawnEnemy(enemyName, point)
	local config = EnemyConfig[enemyName]
	local template = templates[enemyName]
	if not config or not template or not point:IsA("BasePart") then return end

	local model = template:Clone()
	model.Name = config.ModelName or enemyName
	model:SetAttribute("EnemyNPC", true)
	model:SetAttribute("SpawnEnemyType", enemyName)
	model.Parent = enemyFolder

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not humanoid or not root or not root:IsA("BasePart") then
		warn("[CombatSystem] " .. enemyName .. " needs a Humanoid and HumanoidRootPart")
		model:Destroy()
		return
	end

	model.PrimaryPart = root
	model:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			pcall(function() part:SetNetworkOwner(nil) end)
		end
	end

	humanoid.MaxHealth = config.Health
	humanoid.Health = config.Health
	humanoid.WalkSpeed = config.WalkSpeed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	local home = root.Position
	local tracks = setupNpcAnimations(humanoid)
	equipNpcSword(model, humanoid)
	setMoving(tracks, false)

	local alive = true
	local lastAttackTime = 0
	local lastAttackIndex = 0

	humanoid.Died:Connect(function()
		alive = false
		local userId = humanoid:GetAttribute("LastHitUserId")
		local killer = userId and Players:GetPlayerByUserId(userId)
		if killer then
			local xpReward = randomReward(config.XPReward, 0)
			local coinsConfig = config.PossibleRewards and config.PossibleRewards.Coins
			local coinReward = randomReward(coinsConfig, 0)
			awardPlayer(killer, xpReward, coinReward)
		end

		task.delay(config.RespawnTime, function()
			if point.Parent then spawnEnemy(enemyName, point) end
		end)
		task.delay(2, function()
			if model.Parent then model:Destroy() end
		end)
	end)

	task.spawn(function()
		while alive and model.Parent and humanoid.Health > 0 do
			local leashDistance = config.LeashDistance
			local attackRange = config.AttackRange
			local homeDistance = (root.Position - home).Magnitude
			local _, targetRoot, targetHum, targetDistance = nearestPlayer(root.Position, config.AggroRange)

			if homeDistance > leashDistance + 0.75 then
				humanoid:MoveTo(home)
				setMoving(tracks, true)
			elseif targetRoot and targetHum and targetDistance then
				local targetFromHome = targetRoot.Position - home
				if targetFromHome.Magnitude > leashDistance + attackRange then
					humanoid:MoveTo(home)
					setMoving(tracks, homeDistance > 1.5)
				elseif targetDistance <= attackRange then
					humanoid:MoveTo(root.Position)
					setMoving(tracks, false)
					if os.clock() - lastAttackTime >= config.AttackCooldown then
						lastAttackTime = os.clock()
						lastAttackIndex = playDifferentAttack(tracks, lastAttackIndex)
						task.delay(0.22, function()
							if alive and targetHum.Parent and targetHum.Health > 0 and (targetRoot.Position - root.Position).Magnitude <= attackRange + 1 then
								targetHum:TakeDamage(config.AttackDamage)
							end
						end)
					end
				else
					local desired = targetRoot.Position
					local fromHome = desired - home
					if fromHome.Magnitude > leashDistance then
						desired = home + fromHome.Unit * leashDistance
					end
					humanoid:MoveTo(desired)
					setMoving(tracks, true)
				end
			else
				if homeDistance > 1.5 then
					humanoid:MoveTo(home)
					setMoving(tracks, true)
				else
					setMoving(tracks, false)
				end
			end
			task.wait(0.15)
		end
	end)
end

for enemyName, config in pairs(EnemyConfig) do
	local folder = spawnRoot:FindFirstChild(config.SpawnFolder or enemyName)
	if folder then
		for _, point in ipairs(folder:GetChildren()) do
			if point:IsA("BasePart") then spawnEnemy(enemyName, point) end
		end
	else
		warn("[CombatSystem] Missing spawn folder for " .. enemyName)
	end
end

local lastPlayerAttack = {}
combatRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastPlayerAttack[player] or 0) < PLAYER_ATTACK_COOLDOWN then return end
	lastPlayerAttack[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not root or not hum or hum.Health <= 0 or not tool or not tool:GetAttribute("SlayerSword") then return end

	local bestHum, bestDistance
	for _, model in ipairs(enemyFolder:GetChildren()) do
		local enemyHum = model:FindFirstChildOfClass("Humanoid")
		local enemyRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if enemyHum and enemyRoot and enemyHum.Health > 0 then
			local offset = enemyRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= 7.5 and distance > 0.01 and root.CFrame.LookVector:Dot(offset.Unit) > -0.15 and (not bestDistance or distance < bestDistance) then
				bestHum, bestDistance = enemyHum, distance
			end
		end
	end

	local dummy = workspace:FindFirstChild("Slayer Training Enemy")
	if dummy and dummy:IsA("Model") then
		local enemyHum = dummy:FindFirstChildOfClass("Humanoid")
		local enemyRoot = dummy:FindFirstChild("HumanoidRootPart") or dummy.PrimaryPart
		if enemyHum and enemyRoot and enemyHum.Health > 0 then
			local offset = enemyRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= 7.5 and distance > 0.01 and root.CFrame.LookVector:Dot(offset.Unit) > -0.15 and (not bestDistance or distance < bestDistance) then
				bestHum, bestDistance = enemyHum, distance
			end
		end
	end

	if bestHum then
		bestHum:SetAttribute("LastHitUserId", player.UserId)
		bestHum:TakeDamage(PLAYER_DAMAGE)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastPlayerAttack[player] = nil
end)
