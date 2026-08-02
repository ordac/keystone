<p align="center">
  <img src="assets/hero.svg" alt="Keystone" width="256">
</p>

<p align="center">
  Reliable, session-locked data persistence for Roblox.
</p>

<p align="center">
  <a href="https://wally.run/package/ordac/keystone">
    <img src="https://img.shields.io/badge/Install-Wally-AD4646?style=for-the-badge" />
  </a>
  <!-- <a href="https://github.com/ordac/keystone/wiki">
    <img src="https://img.shields.io/badge/Documentation-4F7CFF?style=for-the-badge" />
  </a> -->
</p>

<p align="center">
  <a href="https://github.com/ordac/keystone/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-007ACC?style=flat-square" alt="MIT License">
  </a>

  <a href="https://create.roblox.com/docs/luau">
    <img src="https://img.shields.io/badge/Luau-Roblox-00A2FF?style=flat-square" alt="Luau">
  </a>
</p>

## Features

- Session locking
- Autosaving
- Deep reconciliation
- BindToClose support
- Automatic retries
- Reactive change signals
- Client snapshots
- Save queue

## Installation

Install Keystone with Wally:

```toml
[dependencies]
Keystone = "ordac/keystone@0.1.2"
```

## Quick Start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Keystone = require(ReplicatedStorage.Packages.Keystone)

local Store = Keystone.create({
    Name = "PlayerData",

    Template = {
        Coins = 0,
        Level = 1,
    }
})

Store:Start()
```
