-- Player sword animation controller.
-- Uses the developer animation pack in Workspace.TemplateR6.AnimSaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local animSaves = workspace:WaitForChild("TemplateR6"):WaitForChild("AnimSaves")

local animationCache = {}
local function resolveAnimation(name)
	if animationCache[name] then return animationCache[name] end
	-- Prefer uploaded Animation objects if they exist.
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("Animation") and obj.Name == name and obj.AnimationId ~= "" then
			animationCache[name] = obj
			return obj
		end
	end
	-- Studio preview fallback for the KeyframeSequences the dev added.
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

local function bindSword(tool)
	if not tool:IsA("Tool") then return end
	if not tool:GetAttribute("SlayerSword") and tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("CombatClientBound") then return end
	tool:SetAttribute("CombatClientBound", true)

	local equipped = false
	local attacking = false
	local humanoid, animator
	local idleTrack, walkTrack
	local attackTracks = {}
	local runningConnection
	local lastAttackIndex = 0
	local lastAttackTime = 0

	local function stopTrack(track, fade)
		if track and track.IsPlaying then track:Stop(fade or 0.1) end
	end

	local function setLocomotion(speed)
		if not equipped or attacking then return end
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
		stopTrack(idleTrack, 0.1)
		stopTrack(walkTrack, 0.1)
		for _, track in pairs(attackTracks) do stopTrack(track, 0.05) end
		idleTrack, walkTrack = nil, nil
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
		idleTrack = loadTrack(animator, "Sword Idle", Enum.AnimationPriority.Idle, true)
		walkTrack = loadTrack(animator, "Sword Walk", Enum.AnimationPriority.Movement, true)
		for i = 1, 5 do
			attackTracks[i] = loadTrack(animator, "Attack" .. i, Enum.AnimationPriority.Action, false)
		end
		runningConnection = humanoid.Running:Connect(setLocomotion)
		setLocomotion(humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed)
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
		setupTracks()
	end)

	tool.Unequipped:Connect(function()
		equipped = false
		attacking = false
		clearTracks()
	end)

	tool.Activated:Connect(function()
		if not equipped or attacking then return end
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
