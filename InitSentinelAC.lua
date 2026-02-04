local SentinelAC = require(script:WaitForChild("SentinelAC"):WaitForChild("SentinelAC"))
local sentinel = SentinelAC.getInstance()

local config = {
	-- strike system
	maxStrikes = 10,              -- kicks at 10 strikes
	strikeCooldown = 30,          -- decay every 30 seconds
	strikeDecayRate = 1,          -- remove 1 strike per decay

	-- client protection
	enableClientChecks = true,
	clientHeartbeatTimeout = 10,

	-- detection toggles
	enableVelocityCheck = true,   -- speed hacks
	enableRotationCheck = true,   -- spin bots
	enableStateCheck = true,      -- invalid states
	enableToolCheck = true,       -- multi tool exploits
	enablePhysicsCheck = true,    -- fly and noclip
	enableTeleportCheck = true,   -- teleportation

	-- performance
	checkInterval = 0.1,
	maxPlayersPerFrame = 5,

	-- logging
	verboseLogging = true,
	logToConsole = true,

	-- kick settings
	kickMessage = "Suspicious activity detected. Code: {reason}",
	autoKick = true,

	-- discord webhook
	webhookUrl = nil, -- "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"
}

print("[SentinelAC] Initializing...")
local success = sentinel:initialize(config)

if success then
	print("[SentinelAC] Successfully initialized!")
	print("[SentinelAC] Monitoring all players for suspicious activity")
else
	warn("[SentinelAC] Failed to initialize!")
	return
end

sentinel:on("onPlayerFlagged", function(player, reason, totalStrikes)
	print(string.format("[FLAG] %s - %s (%d strikes)", player.Name, reason, totalStrikes))

	if totalStrikes == 5 then
		warn(player.Name .. " is at 5 strikes!")
	end
end)

sentinel:on("onPlayerKicked", function(player, reason, totalStrikes)
	warn(string.format("[KICK] %s - %s (%d total strikes)", player.Name, reason, totalStrikes))

	-- log ban in your database
end)

sentinel:on("onStrikeAdded", function(player, reason, strikeCount, totalStrikes)
	print(string.format("[STRIKE] %s +%d for %s (Total: %d)", 
		player.Name, strikeCount, reason, totalStrikes))
end)

local WHITELISTED_USERS = {
}

game.Players.PlayerAdded:Connect(function(player)
	if table.find(WHITELISTED_USERS, player.UserId) then
		task.wait(1) -- wait for tracking to intialize
		sentinel:whitelistPlayer(player)
		print("[SentinelAC] Whitelisted:", player.Name)
	end
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		sentinel:whitelistPlayer(player)

		task.wait(2)

		sentinel:unwhitelistPlayer(player)
	end)
end)

print("[SentinelAC] Setup complete! All systems operational.")