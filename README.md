<p align="center">
  <img src="assets/hero-light.svg#gh-light-mode-only" alt="Keystone" width="256">
  <img src="assets/hero-dark.svg#gh-dark-mode-only" alt="Keystone" width="256">
</p>

<p align="center">
  Reliable, session-locked data persistence for Roblox.
</p>

<p align="center">
  <a href="https://wally.run/package/ordac/keystone">
    <img src="assets/wally_button.svg" alt="Wally" height="32">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-007ACC?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Luau-Roblox-00A2FF?style=flat-square" alt="Luau">
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

## Why Keystone?

Keystone provides a simple, reliable data persistence API for Roblox while handling many obstacles that normally come with DataStore development.

- Session locking
- Automatic saving
- Deep template reconciliation
- Automatic retry handling
- Safe shutdown support
- Reactive change signals

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

> **More examples coming soon.**
>
> This guide currently covers the basics of getting started with Keystone. Additional examples and API documentation will be added in future updates.