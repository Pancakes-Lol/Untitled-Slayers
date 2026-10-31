-- Adds the Follow Brick's +5% strength bonus to player sword hits.
-- Base sword damage is currently 20 in CombatSystem, so the permanent bonus adds 1 damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatRemote = ReplicatedStorage:WaitForChild("SwordCombat")
local BONUS_DAMAGE = 1
local ATTACK_COOLDOWN = 0.42
local lastAttack = {}

local function findTarget(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not root or not humanoid or humanoid.Health <= 0 or not tool or not tool:GetAttribute("SlayerSword") then
		return nil
	end

	local bestHumanoid
	local bestDistance
	local liveEnemies = workspace:FindFirstChild("LiveEnemies")
	if liveEnemies then
		for _, model in ipairs(liveEnemies:GetChildren()) do
			local enemyHumanoid = model:FindFirstChildOfClass("Humanoid")
			local enemyRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if enemyHumanoid and enemyRoot and enemyHumanoid.Health > 0 then
				local offset = enemyRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= 7.5 and distance > 0.01 and root.CFrame.LookVector:Dot(offset.Unit) > -0.15 then
					if not bestDistance or distance < bestDistance then
						bestHumanoid = enemyHumanoid
						bestDistance = distance
					end
				end
			end
		end
	end

	local dummy = workspace:FindFirstChild("Slayer Training Enemy")
	if dummy and dummy:IsA("Model") then
		local enemyHumanoid = dummy:FindFirstChildOfClass("Humanoid")
		local enemyRoot = dummy:FindFirstChild("HumanoidRootPart") or dummy.PrimaryPart
		if enemyHumanoid and enemyRoot and enemyHumanoid.Health > 0 then
			local offset = enemyRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= 7.5 and distance > 0.01 and root.CFrame.LookVector:Dot(offset.Unit) > -0.15 then
				if not bestDistance or distance < bestDistance then
					bestHumanoid = enemyHumanoid
				end
			end
		end
	end

	return bestHumanoid
end

combatRemote.OnServerEvent:Connect(function(player)
	if player:GetAttribute("FollowBrickUnlocked") ~= true then return end
	local now = os.clock()
	if now - (lastAttack[player] or 0) < ATTACK_COOLDOWN then return end
	lastAttack[player] = now

	local target = findTarget(player)
	if target and target.Health > 0 then
		target:SetAttribute("LastHitUserId", player.UserId)
		target:TakeDamage(BONUS_DAMAGE)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
