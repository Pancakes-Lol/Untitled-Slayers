-- Keeps the Studio-authored Slash Particle available as a hidden effect template.
-- Player clients clone and emit it during sword attacks; NPCs never use this effect.
local template = workspace:WaitForChild("Slash Particle", 30)
if not template or not template:IsA("BasePart") then
	warn("[SwordCombat] Workspace/Slash Particle was not found.")
	return
end

template.Anchored = true
template.CanCollide = false
template.CanTouch = false
template.CanQuery = false
template.Transparency = 1

for _, obj in ipairs(template:GetDescendants()) do
	if obj:IsA("ParticleEmitter") then
		obj.Enabled = false
	end
end
