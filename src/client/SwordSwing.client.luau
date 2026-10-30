-- Move the character's right arm along with the sword.
-- R6: animate the shoulder Motor6D. R15: use IKControl to move the hand.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local WINDUP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLASH = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local RECOVER = TweenInfo.new(0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function bindSword(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Novice Slayer Sword" then return end
	if tool:GetAttribute("SwingClientBound") then return end
	tool:SetAttribute("SwingClientBound", true)

	local swinging = false
	local ik, target, shoulder, defaultC0
	local function cleanup()
		if ik then ik:Destroy() ik = nil end
		if target then target:Destroy() target = nil end
		if shoulder and shoulder.Parent and defaultC0 then shoulder.C0 = defaultC0 end
		shoulder = nil
		defaultC0 = nil
	end

	local function setup(character)
		cleanup()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			local torso = character:FindFirstChild("Torso")
			shoulder = torso and torso:FindFirstChild("Right Shoulder")
			if shoulder and shoulder:IsA("Motor6D") then defaultC0 = shoulder.C0 end
		else
			local upper = character:FindFirstChild("RightUpperArm")
			local hand = character:FindFirstChild("RightHand")
			local root = character:FindFirstChild("UpperTorso")
			if not upper or not hand or not root then return end
			target = Instance.new("Part")
			target.Name = "LocalSwordSwingTarget"
			target.Size = Vector3.new(0.2,0.2,0.2)
			target.Transparency = 1
			target.Anchored = true
			target.CanCollide = false
			target.CanTouch = false
			target.CanQuery = false
			target.CFrame = hand.CFrame
			target.Parent = workspace
			ik = Instance.new("IKControl")
			ik.Name = "SwordSwingArmIK"
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = upper
			ik.EndEffector = hand
			ik.Target = target
			ik.SmoothTime = 0.08
			ik.Weight = 0
			ik.Priority = 10
			ik.Parent = humanoid
		end
	end

	local function animate(targetObject, info, properties)
		local tween = TweenService:Create(targetObject, info, properties)
		tween:Play()
		tween.Completed:Wait()
	end

	tool.Equipped:Connect(function()
		local character = player.Character
		if character then setup(character) end
	end)
	tool.Unequipped:Connect(function()
		swinging = false
		cleanup()
	end)
	tool.Activated:Connect(function()
		local character = player.Character
		if swinging or not character or tool.Parent ~= character then return end
		swinging = true
		if shoulder and defaultC0 then
			-- Shoulder movement carries the sword because it is welded to the hand.
			local back = defaultC0 * CFrame.Angles(math.rad(-35), math.rad(-10), math.rad(35))
			local forward = defaultC0 * CFrame.Angles(math.rad(40), math.rad(5), math.rad(-35))
			animate(shoulder, WINDUP, {C0=back})
			if tool.Parent == character then animate(shoulder, SLASH, {C0=forward}) end
			if shoulder.Parent then animate(shoulder, RECOVER, {C0=defaultC0}) end
		elseif ik and target and target.Parent then
			local torso = character:FindFirstChild("UpperTorso")
			if torso then
				-- Keep the hand near the shoulder instead of pulling it across the body.
				-- A torso-relative attachment avoids world-space snapping while moving.
				local rest = target.CFrame
				
				local function aim(localOffset, info)
					if not torso.Parent or not target.Parent then return end
					animate(target, info, {CFrame=torso.CFrame * CFrame.new(localOffset)})
				end
				ik.Weight = 0.75
				aim(Vector3.new(1.35, 0.65, -0.7), WINDUP)
				if tool.Parent == character then
					aim(Vector3.new(0.35, -0.6, -1.4), SLASH)
				end
				animate(target, RECOVER, {CFrame=rest})
				ik.Weight = 0

			end
		end
		swinging = false
	end)
	tool.Destroying:Connect(cleanup)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do bindSword(child) end
	container.ChildAdded:Connect(bindSword)
end
watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end
