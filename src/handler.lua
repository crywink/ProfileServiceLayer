--[[
    Data Handler Object
    Author: Samuel#0440 / crywink
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Constants
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")

local ProfileService = require(ServerPackages.profileservice)
local Promise = require(Packages:WaitForChild("promise"))

-- Variables
local Handler = {
    _getCache = {};
}
Handler.__index = Handler

-- Constructor
Handler.new = function(Templates)
    local self = setmetatable({}, Handler)

    self.Templates = Templates
    self.Profiles = {}

    return self
end

-- Functions
Handler.setup = function(self)
    local load = coroutine.wrap(function(player)
        self:loadPlayerProfiles(player)
    end)

    for _, player in Players:GetPlayers() do
        load(player)
    end
    Players.PlayerAdded:Connect(load)

    Players.PlayerRemoving:Connect(function(player)
        local profile = self.Profiles[player]

        if profile then
            profile:Release()
        end
    end)

    task.spawn(function()
        while task.wait(2.5) do
            self:resolveCache()
        end
    end)
end

Handler.loadPlayerProfiles = function(self, player)
    local playerProfiles = {}

    for Name, Template in self.Templates do
        local profileStore = ProfileService.GetProfileStore(Name, Template)
        local profile = profileStore:LoadProfileAsync("plr_" .. player.Name)

        if profile == nil then
            return player:Kick("Error loading data")
        end

        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            self.Profiles[player] = nil
            player:Kick("Data was released")
        end)

        if player:IsDescendantOf(Players) then
            playerProfiles[Name] = profile
        else
            return profile:Release()
        end
    end

    if player:IsDescendantOf(Players) then
        self.Profiles[player] = playerProfiles
    end

    self:resolveCache()
end

Handler.resolveCache = function(self)
    for index, record in Handler._getCache do
        local profile = self.Profiles[record.player]

        if profile ~= nil then
            record.resolve(profile)
            table.remove(self._getCache, index)
        end
    end
end

Handler.getProfile = function(self, player)
    return Promise.new(function(resolve, reject)
        if not player:IsDescendantOf(Players) then
            return reject("invalid player")
        end

        local profile = self.Profiles[player]

        if profile then
            resolve(profile)
        else
            table.insert(Handler._getCache, {
                player = player;
                resolve = resolve;
            })
        end
    end)
end

Handler.isProfileLoaded = function(self, player)
    return self.Profiles[player] and true or false
end

return Handler
