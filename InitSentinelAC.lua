local SentinelAC = require(script:WaitForChild("SentinelAC"):WaitForChild("SentinelAC"))
local sentinel = SentinelAC.getInstance()

local WHITELISTED_USERS = {
}

local config = {
	-- overrides only, defaults are in SentinelAC
	maxStrikes = 20,
	enableTeleportCheck = false,
	whitelistedUserIds = WHITELISTED_USERS,
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

print("[SentinelAC] Setup complete! All systems operational.")
