-- Tetsu dialogue NPC: server owns questions, correct answers and interaction range.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npc = workspace:WaitForChild("Tetsu", 30)
if not npc then warn("[Tetsu] Model missing from Workspace") return end
local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("HumanoidRootPart")
if not torso or not torso:IsA("BasePart") then warn("[Tetsu] No torso found") return end

local remote = ReplicatedStorage:FindFirstChild("TetsuDialogue")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "TetsuDialogue"
	remote.Parent = ReplicatedStorage
end

local prompt = torso:FindFirstChild("TetsuTalkPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TetsuTalkPrompt"
	prompt.Parent = torso
end
prompt.ActionText = "Talk"
prompt.ObjectText = "Tetsu"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false

local rng = Random.new()
local active = {}
local questions = {
	{question="What is the best way to get stronger?", answers={"Train every day", "Eat 900 donuts", "Sleep for 100 years"}, correct=1, right="Exactly. Consistency builds strength!", wrong="Ha! Maybe try training instead."},
	{question="Which weapon would you take into battle?", answers={"A legendary sword", "A rubber chicken", "A spoon"}, correct=1, right="A warrior's choice. I respect it.", wrong="Bold choice. You might surprise someone!"},
	{question="What should you do when an enemy is too strong?", answers={"Rush in without thinking", "Learn their moves and improve", "Ask the enemy for snacks"}, correct=2, right="A clever fighter survives to grow stronger.", wrong="That could work... but I wouldn't bet on it."},
	{question="What's the most important thing a warrior needs?", answers={"Determination", "Fancy shoes", "A pet potato"}, correct=1, right="Well said. Never lose your determination.", wrong="Interesting answer. I was thinking determination!"},
	{question="What would you do with a mysterious treasure chest?", answers={"Open it carefully", "Kick it off a cliff", "Use it as a chair"}, correct=1, right="Smart. Some treasures come with surprises.", wrong="Ha! You have a unique style."},
	{question="How many sides does a triangle have?", answers={"Four", "Three", "Seven"}, correct=2, right="Correct. Your mind is sharp too.", wrong="Not quite! A triangle has three sides."},
	{question="What is 7 + 5?", answers={"12", "75", "10"}, correct=1, right="Right! Quick thinking.", wrong="Not quite. The answer is 12."},
	{question="If you could have one power, which would you choose?", answers={"Super speed", "Talk to sandwiches", "Turn invisible"}, correct=1, right="Speed is a dangerous advantage!", wrong="That's a fun choice. Everyone fights differently."},
}

local function nearby(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - torso.Position).Magnitude <= 17
end

local function newQuestion(player)
	local index = rng:NextInteger(1, #questions + 1)
	if active[player] and active[player].index == index then index = index % (#questions + 1) + 1 end
	local q
	if index == #questions + 1 then
		local actual = player.DisplayName
		q = {question="Tell me, what's your name?", answers={"Captain Noodles", actual, "Shadow McFluffy"}, correct=2,
			right="Of course! Nice to meet you, " .. actual .. ".", wrong="Haha, you almost had me! You're " .. actual .. "."}
	else
		q = questions[index]
	end
	active[player] = {index=index, question=q, opened=os.clock()}
	remote:FireClient(player, "Question", {speaker="Tetsu", question=q.question, answers=q.answers})
end

prompt.Triggered:Connect(function(player)
	if nearby(player) then newQuestion(player) end
end)

remote.OnServerEvent:Connect(function(player, action, choice)
	if not nearby(player) then active[player] = nil remote:FireClient(player, "Close") return end
	local session = active[player]
	if action == "Close" then active[player] = nil return end
	if not session then return end
	if action == "Answer" then
		if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 1 or choice > 3 then return end
		if session.answered then return end
		session.answered = true
		local q = session.question
		remote:FireClient(player, "Response", {text=choice == q.correct and q.right or q.wrong})
	elseif action == "Next" and session.answered then
		if os.clock() - session.opened < 0.15 then return end
		newQuestion(player)
	end
end)

Players.PlayerRemoving:Connect(function(player) active[player] = nil end)
