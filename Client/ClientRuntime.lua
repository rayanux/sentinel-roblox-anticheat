-- obfuscation
local _G = getfenv()
script.Parent = nil
script.Name = string.char(0)

-- get communication remote
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- wait for server remote
local remote
local attempts = 0
repeat
	local tagged = CollectionService:GetTagged("SentinelAC_Comm")
	if #tagged > 0 then
		remote = tagged[1]
	end
	attempts = attempts + 1
	task.wait(0.1)
until remote or attempts > 50

if not remote then
	warn("SentinelAC: Failed to initialize client protection")
	return
end

-- remove tag to prevent detection
remote:RemoveTag("SentinelAC_Comm")

-- studio safety check
local isStudio = RunService:IsStudio()
local rng = Random.new()

-- security functions
local function getRandomString(length)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local result = ""
	for i = 1, length do
		local idx = rng:NextInteger(1, #chars)
		result = result .. string.sub(chars, idx, idx)
	end
	return result
end

-- get C function signature
local function getCFunction(func)
	local success, result = pcall(function()
		return debug.info(func, "f")
	end)
	return success and result or nil
end

-- crash exploiter client
local function pipebomb()
	if isStudio then
		warn("[SentinelAC] Client detection triggered in Studio")
		return
	end

	task.spawn(function()
		while true do
			task.spawn(pipebomb)
			task.spawn(function()
				while true do
					Instance.new("Sky", workspace)
					Instance.new("BloomEffect", workspace)
				end
			end)
		end
	end)
end

-- alert server of detection
local function alertServer()
	pcall(function()
		remote:FireServer(2)
	end)
	pipebomb()
end

-- heartbeat system
task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			remote:FireServer(1)
		end)
	end
end)

-- service access monitoring
task.spawn(function()
	if isStudio then
		return
	end

	local forbiddenServices = {
		"UGCValidationService",
	}

	while task.wait(1) do
		for _, serviceName in ipairs(forbiddenServices) do
			if game:FindService(serviceName) then
				alertServer()
				break
			end
		end
	end
end)

-- C function integrity monitoring
task.spawn(function()
	local baselineFunctions = {
		index = getCFunction(function()
			return workspace[getRandomString(50)]
		end),

		namecall = getCFunction(function()
			workspace:__________()
		end),

		newindex = getCFunction(function()
			game.__________ = nil
		end),
	}

	while task.wait(0.2) do
		-- Check index
		local currentIndex = getCFunction(function()
			return workspace[getRandomString(50)]
		end)

		if currentIndex ~= baselineFunctions.index then
			alertServer()
		end

		local currentNamecall = getCFunction(function()
			workspace:__________()
		end)

		if currentNamecall ~= baselineFunctions.namecall then
			alertServer()
		end

		local currentNewindex = getCFunction(function()
			game.__________ = nil
		end)

		if currentNewindex ~= baselineFunctions.newindex then
			alertServer()
		end
	end
end)

-- integrity monitoring
task.spawn(function()
	local criticalFunctions = {
		table.clone,
		string.format,
		math.random,
	}

	local baselines = {}

	for _, func in ipairs(criticalFunctions) do
		baselines[func] = {
			tostring(debug.info(func, "s")),
			tostring(debug.info(func, "l")),
			tostring(debug.info(func, "n")),
			tostring(debug.info(func, "a")),
			tostring(debug.info(func, "f")),
		}
	end

	while task.wait(0.3) do
		for _, func in ipairs(criticalFunctions) do
			local current = {
				tostring(debug.info(func, "s")),
				tostring(debug.info(func, "l")),
				tostring(debug.info(func, "n")),
				tostring(debug.info(func, "a")),
				tostring(debug.info(func, "f")),
			}

			local baseline = baselines[func]

			for i, v in ipairs(current) do
				if v ~= baseline[i] then
					alertServer()
					break
				end
			end
		end
	end
end)

-- environment monitoring
task.spawn(function()
	if isStudio then
		return
	end

	local suspiciousGlobals = {
		"hookmetamethod",
		"getnamecallmethod",
		"hookfunction",
		"replaceclosure",
		"newcclosure",
	}

	while task.wait(0.5) do
		for _, globalName in ipairs(suspiciousGlobals) do
			if _G[globalName] or getfenv()[globalName] then
				alertServer()
				break
			end
		end
	end
end)

-- remote monitoring
task.spawn(function()
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer

	if not localPlayer then
		return
	end

	local fireCount = 0
	local lastReset = tick()

	local oldFireServer = remote.FireServer
	remote.FireServer = function(self, ...)
		fireCount = fireCount + 1

		local currentTime = tick()
		if currentTime - lastReset > 1 then
			if fireCount > 100 then
				alertServer()
			end
			fireCount = 0
			lastReset = currentTime
		end

		return oldFireServer(self, ...)
	end
end)

-- script monitoring
task.spawn(function()
	if isStudio then
		return
	end

	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer

	if not localPlayer then
		return
	end

	local function checkDescendants(parent)
		for _, descendant in ipairs(parent:GetDescendants()) do
			if descendant:IsA("LocalScript") and descendant ~= script then
				local source = ""
				local success = pcall(function()
					source = descendant.Source
				end)

				if success and source:find("require") and 
					(source:find("game:HttpGet") or source:find("loadstring")) then
					alertServer()
				end
			end
		end
	end

	if localPlayer:FindFirstChild("PlayerGui") then
		checkDescendants(localPlayer.PlayerGui)
	end

	game.DescendantAdded:Connect(function(descendant)
		task.wait(0.1)
		if descendant:IsA("LocalScript") and descendant ~= script then
			checkDescendants(descendant.Parent)
		end
	end)
end)
