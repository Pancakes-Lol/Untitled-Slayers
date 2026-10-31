-- Tetsu slayer onboarding.
-- Session-only for now: no DataStore saving and no custom name selection.
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

local function send(player, kind, data)
	remote:FireClient(player, kind, data or {})
end

local function nearby(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - torso.Position).Magnitude <= 18
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
			text = "Well done, " .. player.DisplayName .. "! You defeated your first enemy. Your slayer journey has officially begun!",
			button = "Thank you!",
		})
	else
		send(player, "Story", {
			text = "Welcome back, " .. player.DisplayName .. ". Keep training. Your greatest battles are still ahead!",
			button = "Goodbye",
		})
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
	elseif action == "Continue" then
		send(player, "Close")
	end
end)

local function setupPlayer(player)
	-- Every server session starts fresh until persistence is intentionally re-added.
	state[player] = {stage = "math", name = player.DisplayName}
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
