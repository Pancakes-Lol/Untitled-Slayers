-- Quest tracking UI using the Studio-authored MainUI QuestTrackerFrame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")
local dialogGui = playerGui:FindFirstChild("DialogUI") or playerGui:WaitForChild("DialogUI", 10)

local mainUI = playerGui:WaitForChild("MainUI")
local mainFrame = mainUI:WaitForChild("MainFrame")
local questFrame = mainFrame:WaitForChild("QuestTrackerFrame")

local function findText(root, names)
	for _, name in ipairs(names) do
		local obj = root:FindFirstChild(name, true)
		if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
			return obj
		end
	end
	return nil
end

local titleLabel = findText(questFrame, {"QuestTitle", "Title", "QuestName"})
local descriptionLabel = findText(questFrame, {"QuestDescription", "Description", "QuestText"})
local progressLabel = findText(questFrame, {"QuestProgress", "Progress", "Amount"})
local rewardsLabel = findText(questFrame, {"QuestRewards", "Rewards", "RewardText"})

if not titleLabel then warn("[QuestTracker] Missing title label in MainUI.MainFrame.QuestTrackerFrame") end
if not descriptionLabel then warn("[QuestTracker] Missing description label in MainUI.MainFrame.QuestTrackerFrame") end
if not progressLabel then warn("[QuestTracker] Missing progress label in MainUI.MainFrame.QuestTrackerFrame") end
if not rewardsLabel then warn("[QuestTracker] Missing rewards label in MainUI.MainFrame.QuestTrackerFrame") end

local latestData = {Visible = false}
questFrame.Visible = false

local function rewardText(rewards)
	if type(rewards) ~= "table" then return "" end
	local pieces = {}
	if tonumber(rewards.XP) and rewards.XP > 0 then
		table.insert(pieces, tostring(rewards.XP) .. " XP")
	end
	if tonumber(rewards.Cash) and rewards.Cash > 0 then
		table.insert(pieces, "$" .. tostring(rewards.Cash))
	end
	if type(rewards.Materials) == "table" then
		for material, amount in pairs(rewards.Materials) do
			if tonumber(amount) and amount > 0 then
				table.insert(pieces, tostring(amount) .. "x " .. tostring(material))
			end
		end
	end
	return table.concat(pieces, "  •  ")
end

local function setText(label, value)
	if label then
		label.Text = tostring(value or "")
	end
end

local function render(data)
	data = data or {}
	if dialogGui and dialogGui.Enabled then
		questFrame.Visible = false
		return
	end

	if data.Visible == false then
		questFrame.Visible = false
		return
	end

	setText(titleLabel, data.Title or "Quest")
	setText(descriptionLabel, data.Description or "")
	if data.Complete then
		setText(progressLabel, "Complete — return to Tetsu")
	else
		setText(progressLabel, string.format("%d / %d", tonumber(data.Progress) or 0, tonumber(data.Amount) or 0))
	end
	setText(rewardsLabel, rewardText(data.Rewards))

	mainUI.Enabled = true
	mainFrame.Visible = true
	questFrame.Visible = true
end

remote.OnClientEvent:Connect(function(data)
	latestData = data or {Visible = false}
	render(latestData)
end)

if dialogGui then
	dialogGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if dialogGui.Enabled then
			questFrame.Visible = false
		else
			render(latestData)
		end
	end)
end
