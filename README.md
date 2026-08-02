<p align="center">
  <img src="assets/hero.svg" alt="Keystone" width="256">
</p>

<p align="center">
  Reliable, session-locked data persistence for Roblox.
</p>

<p align="center">
  <a href="https://wally.run/package/ordac/keystone">
    <img src="https://img.shields.io/badge/Install-Wally-CE5C4B?style=for-the-badge" />
  </a>
  <!-- <a href="https://github.com/ordac/keystone/wiki">
    <img src="https://img.shields.io/badge/Documentation-4F7CFF?style=for-the-badge" />
  </a> -->
</p>

<p align="center">
    <img src="https://img.shields.io/github/license/ordac/keystone?style=flat-square">
    <!-- <img src="https://img.shields.io/github/v/release/ordac/keystone?style=flat-square"> -->
    <img src="https://img.shields.io/github/stars/ordac/keystone?style=flat-square">
    <img src="https://img.shields.io/badge/Luau-Roblox-blue?style=flat-square">
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
