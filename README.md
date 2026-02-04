# SentinelAC

SentinelAC is a server-authoritative anti-cheat system for Roblox games. It focuses on detecting common exploit behaviors while remaining performant and configurable for live production servers.

## Features
* Server-side validation with optional client integrity checks
* Speed, fly, noclip, teleport, and rotation detection
* Tool, humanoid state, and physics abuse checks
* Client tampering / executor behavior detection
* Progressive strike-based enforcement with decay
* Whitelist support for admins and trusted players
* Event-driven API for custom moderation logic
* Optional Discord webhook logging
* Studio-safe (client checks auto-disabled)

## Installation
Place the system inside `ServerScriptService`:

```
ServerScriptService/
├── InitSentinelAC (Script)
└── SentinelAC/
    ├── SentinelAC (ModuleScript)
    ├── Core/
    ├── Player/
    ├── Checks/
    └── Client/
```

## Usage

```
local SentinelAC = require(script.Parent.SentinelAC)
local sentinel = SentinelAC.getInstance()

sentinel:initialize()
```
The system will automatically begin tracking players once initialized.

## Configuration

```
sentinel:initialize({
    maxStrikes = 10,
    strikeCooldown = 30,
    strikeDecayRate = 1,

    enableClientChecks = true,
    clientHeartbeatTimeout = 10,

    enableVelocityCheck = true,
    enableTeleportCheck = true,
    enablePhysicsCheck = true,

    checkInterval = 0.1,
    maxPlayersPerFrame = 5,

    autoKick = true,
    kickMessage = "Detected: {reason}",
    webhookUrl = nil,
})
```
All checks can be enabled or disabled individually.

## API

```
sentinel:whitelistPlayer(player)
sentinel:unwhitelistPlayer(player)

sentinel:flagPlayer(player, "Reason", 3)
sentinel:pardonPlayer(player, "Reason", 2)

sentinel:on("onPlayerFlagged", function(player, reason, strikes) end)
sentinel:on("onPlayerKicked", function(player, reason, strikes) end)
```

## Strike Model

* Players start at 0 strikes
* Violations add strikes based on severity
* Strikes decay over time
* Players are kicked when the maximum is reached

This reduces false positives from latency and physics edge cases.

## Performance

* <1% server CPU usage (≈100 players)
* ~2 MB memory usage
* Default: 10 checks/sec per player

For large servers:

```
sentinel:initialize({
    checkInterval = 0.2,
    maxPlayersPerFrame = 3,
})
```

## Notes

* Client checks are disabled automatically in Studio
* Whitelist admins and scripted movement systems
* Test with conservative settings before deployment
