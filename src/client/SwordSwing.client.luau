-- Player sword animation controller.
-- Uses the developer animation pack in Workspace.TemplateR6.AnimSaves.
-- Slash VFX uses a custom Trail on the sword blade so the animation physically draws the slash path.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")
local slashTemplate = workspace:FindFirstChild("Slash Particle") or workspace:WaitForChild("Slash Particle", 10)

local SLASH_START_DELAY = 0.04
local SLASH_ACTIVE_TIME = 0.20
local SLASH_TRAIL_NAME = "SwordSlashTrailVFX"

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
	warn("[SwordCombat] Missing animation: " .. name)
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

local function getSlashEmitterTemplate()
	if not slashTemplate then return nil end
	for _, obj in ipairs(slashTemplate:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			return obj
		end
	end
	return nil
end

local slashEmitterTemplate = getSlashEmitterTemplate()

local function getBladeTrailAttachments(handle)
	for _, obj in ipairs(handle:GetDescendants()) do
		if obj:IsA("Trail") and obj.Attachment0 and obj.Attachment1 then
			return obj.Attachment0, obj.Attachment1
		end
	end

	local attachments = {}
	for _, obj in ipairs(handle:GetDescendants()) do
		if obj:IsA("Attachment") then
			table.insert(attachments, obj)
		end
	end
	if #attachments >= 2 then
		return attachments[1], attachments[2]
	end
	return nil, nil
end

local function ensureSlashTrail(tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end

	local existing = handle:FindFirstChild(SLASH_TRAIL_NAME)
	if existing and existing:IsA("Trail") then
		return existing
	end

	local attachment0, attachment1 = getBladeTrailAttachments(handle)
	if not attachment0 or not attachment1 then
		warn("[SwordCombat] Could not find two blade attachments for slash trail")
		return nil
	end

	local trail = Instance.new("Trail")
	trail.Name = SLASH_TRAIL_NAME
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Enabled = false
	trail.Lifetime = 0.18
	trail.MinLength = 0.02
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.TextureLength = 1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.15),
		NumberSequenceKeypoint.new(0.65, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})

	if slashEmitterTemplate then
		trail.Color = slashEmitterTemplate.Color
		trail.Texture = slashEmitterTemplate.Texture
	else
		trail.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(235, 250, 255))
	end

	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.75, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = handle
	return trail
end

local function playSlashVFX(tool)
	local trail = ensureSlashTrail(tool)
	if not trail then return end

	trail.Enabled = false
	task.wait()
	trail.Enabled = true
	task.delay(SLASH_ACTIVE_TIME, function()
		if trail.Parent then
			trail.Enabled = false
		end
	end)
end

local function bindSword(tool)
	if not tool:IsA("Tool") then return end
	if not tool:GetAttribute("SlayerSword") and tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("CombatClientBound") then return end
	tool:SetAttribute("CombatClientBound", true)
	ensureSlashTrail(tool)

	local equipped = false
	local attacking = false
	local transitioning = false
	local humanoid, animator
	local idleTrack, walkTrack, unsheathTrack, sheathTrack
	local attackTracks = {}
	local runningConnection
	local sprintConnection
	local lastAttackIndex = 0
	local lastAttackTime = 0
	local equipToken = 0

	local function stopTrack(track, fade)
		if track and track.IsPlaying then track:Stop(fade or 0.14) end
	end

	local function setLocomotion(speed)
		if not equipped or attacking or transitioning then return end
		if player:GetAttribute("IsSprinting") then
			stopTrack(idleTrack, 0.16)
			stopTrack(walkTrack, 0.16)
			return
		end
		if speed > 0.5 then
			stopTrack(idleTrack, 0.18)
			if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.18) end
		else
			stopTrack(walkTrack, 0.18)
			if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.18) end
		end
	end

	local function clearTracks()
		if runningConnection then runningConnection:Disconnect() runningConnection = nil end
		if sprintConnection then sprintConnection:Disconnect() sprintConnection = nil end
		stopTrack(unsheathTrack, 0.08)
		stopTrack(sheathTrack, 0.08)
		stopTrack(idleTrack, 0.12)
		stopTrack(walkTrack, 0.12)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.08) end
		unsheathTrack, sheathTrack, idleTrack, walkTrack = nil, nil, nil, nil
		table.clear(attackTracks)
		humanoid, animator = nil, nil
	end

	local function setupTracks()
		clearTracks()
		local character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		unsheathTrack = loadTrack(animator, "UnsheathingSword", Enum.AnimationPriority.Action, false)
		sheathTrack = loadTrack(animator, "SheathingSword", Enum.AnimationPriority.Action, false)
		idleTrack = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true)
		walkTrack = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true)
		for i = 1, 5 do
			attackTracks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
		end
		runningConnection = humanoid.Running:Connect(setLocomotion)
		sprintConnection = player:GetAttributeChangedSignal("IsSprinting"):Connect(function()
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end)
	end

	local function chooseAttack()
		local choices = {}
		for i = 1, 5 do
			if i ~= lastAttackIndex and attackTracks[i] then table.insert(choices, i) end
		end
		if #choices == 0 then return nil end
		local index = choices[math.random(1, #choices)]
		lastAttackIndex = index
		return index
	end

	tool.Equipped:Connect(function()
		equipped = true
		attacking = false
		transitioning = true
		equipToken += 1
		local thisEquip = equipToken
		ensureSlashTrail(tool)
		setupTracks()
		stopTrack(idleTrack, 0)
		stopTrack(walkTrack, 0)

		if unsheathTrack then
			unsheathTrack:Play(0.12, 1, 1)
			local duration = unsheathTrack.Length > 0 and math.clamp(unsheathTrack.Length, 0.25, 2) or 0.65
			task.delay(duration, function()
				if not equipped or thisEquip ~= equipToken then return end
				transitioning = false
				if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
			end)
		else
			transitioning = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end
	end)

	tool.Unequipped:Connect(function()
		equipped = false
		attacking = false
		transitioning = true
		equipToken += 1
		local thisEquip = equipToken
		local slashTrail = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild(SLASH_TRAIL_NAME)
		if slashTrail then slashTrail.Enabled = false end
		stopTrack(idleTrack, 0.16)
		stopTrack(walkTrack, 0.16)
		stopTrack(unsheathTrack, 0.08)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.1) end

		if sheathTrack then
			sheathTrack:Play(0.14, 1, 1)
			local duration = sheathTrack.Length > 0 and math.clamp(sheathTrack.Length, 0.25, 2) or 0.6
			task.delay(duration, function()
				if equipped or thisEquip ~= equipToken then return end
				transitioning = false
				clearTracks()
			end)
		else
			transitioning = false
			clearTracks()
		end
	end)

	tool.Activated:Connect(function()
		if not equipped or attacking or transitioning or player:GetAttribute("IsSprinting") then return end
		if os.clock() - lastAttackTime < 0.42 then return end
		local character = player.Character
		if not character or tool.Parent ~= character then return end
		local index = chooseAttack()
		if not index then return end
		lastAttackTime = os.clock()
		attacking = true
		stopTrack(idleTrack, 0.1)
		stopTrack(walkTrack, 0.1)
		local track = attackTracks[index]
		if track then track:Play(0.1, 1, 1) end
		task.delay(SLASH_START_DELAY, function()
			if equipped and attacking and tool.Parent == player.Character then
				playSlashVFX(tool)
			end
		end)
		combatRemote:FireServer(index)
		local duration = track and track.Length > 0 and math.clamp(track.Length * 0.75, 0.32, 0.8) or 0.48
		task.delay(duration, function()
			if not equipped then return end
			attacking = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end)
	end)

	tool.Destroying:Connect(clearTracks)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character) watch(character) end)
if player.Character then watch(player.Character) end
