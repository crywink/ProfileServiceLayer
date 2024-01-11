--[[
    init.lua
    Author(s): Sam Kalish
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Constants
local ProfileService = require(ServerScriptService.serverPackages.profileService)
local Promise = require(ReplicatedStorage.packages.promise)
local Profile = require(script.profile)

local DEFAULT_PROFILE_KEY = "__default__1"

-- Variables
local Data = {
    profileTypes = {};
    profiles = {};
}
local profiles = Data.profiles

-- Main
function Data.init()
    -- Load / Unload data

    local function playerAdded(player: Player)
        profiles[player] = {}

        for scope, template in Data.profileTypes do
            local store = ProfileService.GetProfileStore(scope, template)
            local rawProfile = store:LoadProfileAsync("Player_" .. player.UserId)
            local profile = Profile.new(rawProfile, player)

            profiles[player][scope] = profile
        end
    end

    local function playerRemoving(player: Player)
        for _, profile in profiles[player] do
            profile:release()
        end

        profiles[player] = nil
    end

    Players.PlayerAdded:Connect(playerAdded)
    Players.PlayerRemoving:Connect(playerRemoving)

    game:BindToClose(function()
        for _, v in Players:GetPlayers() do
            task.spawn(playerRemoving, v)
        end
    end)

    for _, v in Players:GetPlayers() do
        task.spawn(playerAdded, v)
    end
end

function Data.bindToRelease(callback: (player: Player, profile: Profile.Profile) -> ())
    Profile.bindToReleaseAll(callback)
end

function Data.addProfileType(data: { string: any }, scope: string?)
    local key = scope or DEFAULT_PROFILE_KEY
    assert(Data.profileTypes[key] == nil, "Profile type already exists")

    Data.profileTypes[key] = table.clone(data)
end

function Data.getProfile(player: Player, scope: string?): Promise.TypedPromise<Profile.Profile>
    local key = scope or DEFAULT_PROFILE_KEY
    assert(Data.profileTypes[key], `Profile type {key} does not exist`)

    return Promise.new(function(resolve, reject)
        local profile
        local playerProfiles = profiles[player]
        if playerProfiles then
            profile = playerProfiles[key]
        end

        if profile then
            resolve(profile)
        else
            for _ = 1, 30 do
                playerProfiles = profiles[player]
                if playerProfiles then
                    profile = playerProfiles[key]
                end

                if profile then
                    resolve(profile)
                else
                    task.wait(1)
                end
            end

            reject("Profile request timed out")
        end
    end)
end

return Data