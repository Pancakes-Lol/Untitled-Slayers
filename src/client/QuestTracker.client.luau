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
local questName = questFrame:WaitForChild("QuestName")
local questAmount = questFrame:WaitForChild("QuestAmount")

local latestData = {Visible = false}
questFrame.Visible = false

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

	questName.Text = tostring(data.Title or "Quest")

	if data.Complete then
		questAmount.Text = "Complete - Return to Tetsu"
	else
		questAmount.Text = string.format("%d / %d", tonumber(data.Progress) or 0, tonumber(data.Amount) or 0)
	end

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
