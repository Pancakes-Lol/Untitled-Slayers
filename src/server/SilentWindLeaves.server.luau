-- Replaces the noisy per-tree Math1 wind scripts with one silent controller.
-- Keeps leaf movement, but removes [WindLeaves] debug spam during play.
local RunService = game:GetService("RunService")

local trees = workspace:FindFirstChild("Trees")
if not trees then return end

-- Disable the old wind scripts. They are named Math1 in the current map.
for _, obj in ipairs(trees:GetDescendants()) do
	if obj:IsA("Script") and obj.Name == "Math1" then
		obj.Disabled = true
	end
end

local leafData = {}
local function addLeaf(part)
	if not part:IsA("BasePart") or leafData[part] then return end
	part.Anchored = true
	leafData[part] = {
		base = part.CFrame,
		offset = math.random() * 20,
		strength = math.rad(1.2 + math.random() * 1.8),
	}
end

for _, tree in ipairs(trees:GetChildren()) do
	local leaves = tree:FindFirstChild("Leaves")
	if leaves then
		for _, obj in ipairs(leaves:GetDescendants()) do
			addLeaf(obj)
		end
		leaves.DescendantAdded:Connect(addLeaf)
	end
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for part, data in pairs(leafData) do
		if not part.Parent then
			leafData[part] = nil
		else
			local sway = math.sin(t * 1.15 + data.offset) * data.strength
			local twist = math.sin(t * 0.72 + data.offset * 0.7) * data.strength * 0.45
			part.CFrame = data.base * CFrame.Angles(sway, 0, twist)
		end
	end
end)
