-- Player sword animation controller.
-- Uses the developer animation pack in Workspace.TemplateR6.AnimSaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")
local slashTemplate = workspace:WaitForChild("Slash Particle", 30)

-- Preserve one untouched copy of the Studio-authored VFX before hiding the
-- Workspace template locally. Runtime attacks clone this preserved source.
local slashSourceTemplate = nil
if slashTemplate and slashTemplate:IsA("BasePart") then
	slashSourceTemplate = slashTemplate:Clone()
	slashSourceTemplate.Name = "Slash Particle Source"
	slashTemplate.LocalTransparencyModifier = 1
	for _, obj in ipairs(slashTemplate:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
		end
	end
end

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

-- Placement/timing only. The VFX itself still comes from Workspace > Slash Particle.
local SLASH_DISTANCE = 1.35
local SLASH_HEIGHT = 0.65
local SLASH_SIDE_OFFSET = 0
local SLASH_LIFETIME = 2.4
local SLASH_DELAY = 0.09
local SLASH_EMIT_WINDOW = 0.22
local PARTICLE_LIFETIME_SCALE = 1.8

local function emitSlash(tool)
	if not slashSourceTemplate or not slashSourceTemplate:IsA("BasePart") then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or tool.Parent ~= character then return end

	-- Clone the preserved Studio asset exactly as it was authored at play start.
	local slash = slashSourceTemplate:Clone()
	slash.Name = "Player Slash Particle"
	slash.Anchored = false
	slash.Massless = true
	slash.CanCollide = false
	slash.CanTouch = false
	slash.CanQuery = false
	slash.CastShadow = false
	slash.Transparency = 1
	slash.LocalTransparencyModifier = 0

	-- Keep the slash physically attached to the player's front side. This means
	-- moving/turning during the attack cannot leave the effect behind the player.
	local localOffset = CFrame.new(SLASH_SIDE_OFFSET, SLASH_HEIGHT, -SLASH_DISTANCE)
	slash.CFrame = root.CFrame * localOffset
	slash.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Name = "SlashFrontWeld"
	weld.Part0 = root
	weld.Part1 = slash
	weld.Parent = slash

	-- Keep particles centered on the attached slash and make them last longer.
	-- Texture, color, size, transparency curve, rotation, etc. remain Studio-authored.
	for _, obj in ipairs(slash:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.EmissionDirection = Enum.NormalId.Front
			obj.SpreadAngle = Vector2.new(0, 0)
			obj.LockedToPart = true
			obj.Speed = NumberRange.new(0.01)
			obj.Drag = 1000
			obj.Acceleration = Vector3.zero
			obj.Lifetime = NumberRange.new(
				math.max(0.05, obj.Lifetime.Min * PARTICLE_LIFETIME_SCALE),
				math.max(0.05, obj.Lifetime.Max * PARTICLE_LIFETIME_SCALE)
			)

			if obj.Enabled then
				task.delay(SLASH_EMIT_WINDOW, function()
					if obj.Parent then
						obj.Enabled = false
					end
				end)
			else
				local emitCount = obj:GetAttribute("EmitCount")
				if typeof(emitCount) ~= "number" then
					emitCount = math.max(1, math.round(math.max(obj.Rate, 1) * SLASH_EMIT_WINDOW))
				end
				obj:Emit(emitCount)
			end
		end
	end

	Debris:AddItem(slash, SLASH_LIFETIME)
end

local function bindSword(tool)
	if not tool:IsA("Tool") then return end
	if not tool:GetAttribute("SlayerSword") and tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("CombatClientBound") then return end
	tool:SetAttribute("CombatClientBound", true)

	local equipped = false
	local attacking = false
	local unsheathing = false
	local humanoid, animator
	local idleTrack, walkTrack, unsheathTrack
	local attackTracks = {}
	local runningConnection
	local lastAttackIndex = 0
	local lastAttackTime = 0
	local equipToken = 0

	local function stopTrack(track, fade)
		if track and track.IsPlaying then track:Stop(fade or 0.1) end
	end

	local function setLocomotion(speed)
		if not equipped or attacking or unsheathing then return end
		if speed > 0.5 then
			stopTrack(idleTrack, 0.15)
			if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.15) end
		else
			stopTrack(walkTrack, 0.15)
			if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.15) end
		end
	end

	local function clearTracks()
		if runningConnection then runningConnection:Disconnect() runningConnection = nil end
		stopTrack(unsheathTrack, 0.05)
		stopTrack(idleTrack, 0.1)
		stopTrack(walkTrack, 0.1)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.05) end
		unsheathTrack, idleTrack, walkTrack = nil, nil, nil
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
		idleTrack = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true)
		walkTrack = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true)
		for i = 1, 5 do
			attackTracks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
		end
		runningConnection = humanoid.Running:Connect(setLocomotion)
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
		unsheathing = true
		equipToken += 1
		local thisEquip = equipToken
		setupTracks()
		stopTrack(idleTrack, 0)
		stopTrack(walkTrack, 0)

		if unsheathTrack then
			unsheathTrack:Play(0.06, 1, 1)
			local duration = 0.65
			if unsheathTrack.Length > 0 then duration = math.clamp(unsheathTrack.Length, 0.25, 2) end
			task.delay(duration, function()
				if not equipped or thisEquip ~= equipToken then return end
				unsheathing = false
				if humanoid then
					setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
				end
			end)
		else
			unsheathing = false
			if humanoid then setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed) end
		end
	end)

	tool.Unequipped:Connect(function()
		equipped = false
		attacking = false
		unsheathing = false
		equipToken += 1
		clearTracks()
	end)

	tool.Activated:Connect(function()
		if not equipped or attacking or unsheathing then return end
		if os.clock() - lastAttackTime < 0.42 then return end
		local character = player.Character
		if not character or tool.Parent ~= character then return end
		local index = chooseAttack()
		if not index then return end
		lastAttackTime = os.clock()
		attacking = true
		stopTrack(idleTrack, 0.08)
		stopTrack(walkTrack, 0.08)
		local track = attackTracks[index]
		if track then track:Play(0.06, 1, 1) end

		task.delay(SLASH_DELAY, function()
			if equipped and tool.Parent == player.Character then
				emitSlash(tool)
			end
		end)

		combatRemote:FireServer(index)
		local duration = 0.48
		if track and track.Length > 0 then duration = math.clamp(track.Length * 0.75, 0.32, 0.8) end
		task.delay(duration, function()
			if not equipped then return end
			attacking = false
			if humanoid then
				setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
			end
		end)
	end)

	tool.Destroying:Connect(clearTracks)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(character)
	watch(character)
end)
if player.Character then watch(player.Character) end
