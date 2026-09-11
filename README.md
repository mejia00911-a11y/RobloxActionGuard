# RobloxActionGuard

A lightweight, server-side validation toolkit for Roblox RemoteEvents and RemoteFunctions.

It helps Roblox developers protect gameplay actions from spam and invalid client requests without using polling loops.

## Features

- Per-player cooldowns
- Sliding-window rate limits
- Distance validation
- Character/alive checks
- Custom validators
- Automatic player cleanup
- No `while true do` loops
- No duplicated listeners
- Server-authoritative by design

## Installation

Copy `src/ActionGuard.lua` into `ServerScriptService` or a shared package location that only the server requires.

Recommended structure:

```text
ServerScriptService
└── Packages
    └── ActionGuard
```

## Quick Start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionGuard = require(script.Parent.Packages.ActionGuard)

local AttackRemote = ReplicatedStorage.Remotes.Attack

local attackGuard = ActionGuard.new({
	Cooldown = 0.45,
	RateLimit = {
		MaxCalls = 8,
		Window = 3,
	},
	RequireAlive = true,
})

AttackRemote.OnServerEvent:Connect(function(player, targetPart)
	local allowed, reason = attackGuard:Validate(player)

	if not allowed then
		return
	end

	if typeof(targetPart) ~= "Instance" or not targetPart:IsA("BasePart") then
		return
	end

	-- Server-authoritative attack logic here.
end)
```

## Distance Validation

```lua
local allowed = ActionGuard.WithinDistance(player, targetPart, 20)

if not allowed then
	return
end
```

## Custom Validators

```lua
local guard = ActionGuard.new({
	Cooldown = 1,
	Validators = {
		function(player)
			local character = player.Character
			local stunned = character and character:GetAttribute("Stunned")

			if stunned then
				return false, "Player is stunned"
			end

			return true
		end,
	},
})
```

## API

### `ActionGuard.new(config)`

Creates a guard.

Supported config fields:

```lua
{
	Cooldown = number?,
	RequireAlive = boolean?,
	RateLimit = {
		MaxCalls = number,
		Window = number,
	}?,
	Validators = { (Player) -> (boolean, string?) }?,
}
```

### `guard:Validate(player)`

Returns:

```lua
(boolean, string?)
```

### `guard:Reset(player)`

Clears cooldown and rate-limit state for one player.

### `guard:Destroy()`

Cleans all internal state and disconnects the player cleanup connection.

### `ActionGuard.WithinDistance(player, target, maxDistance)`

Checks the distance from the player's `HumanoidRootPart` to a `BasePart` or `Model`.

## Design Goals

This package intentionally avoids:

- client-authoritative validation
- polling loops
- repeated object creation
- duplicate event connections
- hidden global state

The goal is to provide small reusable building blocks that can be added to an existing Roblox system without replacing working gameplay code.

## License

MIT
