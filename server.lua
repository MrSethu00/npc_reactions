local ESX = nil
local playersInZones = {}
local jailedPlayers = {}
local playerJobs = {}

-- Initialize ESX
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Player entered zone
RegisterNetEvent('npc:playerEnteredZone')
AddEventHandler('npc:playerEnteredZone', function(zoneName)
    local src = source
    playersInZones[src] = zoneName
    print('Player ' .. src .. ' entered zone: ' .. zoneName)
end)

-- Player left zone
RegisterNetEvent('npc:playerLeftZone')
AddEventHandler('npc:playerLeftZone', function()
    local src = source
    playersInZones[src] = nil
    print('Player ' .. src .. ' left zone')
end)

-- Jail functions
function JailPlayer(playerId)
    if not playerId then return end
    jailedPlayers[playerId] = true
    TriggerClientEvent('npc:setJailStatus', playerId, true)
    print('Player ' .. playerId .. ' jailed')
end

function ReleasePlayer(playerId)
    if not playerId then return end
    jailedPlayers[playerId] = nil
    TriggerClientEvent('npc:setJailStatus', playerId, false)
    print('Player ' .. playerId .. ' released')
end

-- Update player job - FIXED
function UpdatePlayerJob(playerId, job, jobLabel)
    if not playerId then return end
    
    local jobName = 'unemployed'
    local jobLabelText = 'Unemployed'
    
    if type(job) == 'table' then
        jobName = job.name or 'unemployed'
        jobLabelText = job.label or jobName
    elseif type(job) == 'string' then
        jobName = job
        jobLabelText = jobLabel or job
    end
    
    playerJobs[playerId] = {
        name = jobName,
        label = jobLabelText
    }
    
    TriggerClientEvent('npc:updateJob', playerId, jobName, jobLabelText)
    print('Player ' .. playerId .. ' job: ' .. jobName)
end

-- ESX job event - FIXED
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job, lastJob)
    local src = source
    UpdatePlayerJob(src, job)
end)

-- Player loaded event
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerData)
    local src = source
    if playerData and playerData.job then
        UpdatePlayerJob(src, playerData.job)
    end
end)

-- AUTO UPDATE - Checks every 10 seconds
Citizen.CreateThread(function()
    while true do
        Wait(10000)
        if ESX then
            for _, playerId in ipairs(GetPlayers()) do
                local xPlayer = ESX.GetPlayerFromId(playerId)
                if xPlayer and xPlayer.job then
                    local job = xPlayer.job
                    local jobName = type(job) == 'table' and job.name or job
                    
                    if not playerJobs[playerId] or playerJobs[playerId].name ~= jobName then
                        UpdatePlayerJob(playerId, job)
                    end
                end
            end
        end
    end
end)

-- Cleanup
AddEventHandler('playerDropped', function()
    local src = source
    playersInZones[src] = nil
    jailedPlayers[src] = nil
    playerJobs[src] = nil
end)

-- Commands for testing
RegisterCommand('jailme', function(source, args, rawCommand)
    if source > 0 then
        JailPlayer(source)
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'SYSTEM', 'You have been jailed!' },
            color = { 255, 0, 0 }
        })
    end
end, false)

RegisterCommand('release', function(source, args, rawCommand)
    if source > 0 then
        ReleasePlayer(source)
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'SYSTEM', 'You have been released!' },
            color = { 0, 255, 0 }
        })
    end
end, false)

-- Manual job update command
RegisterCommand('updatejob', function(source, args, rawCommand)
    if source > 0 then
        local jobName = args[1] or 'unemployed'
        local jobLabel = args[2] or jobName
        UpdatePlayerJob(source, jobName, jobLabel)
        
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'SYSTEM', 'Job updated to: ' .. jobLabel },
            color = { 0, 255, 0 }
        })
    end
end, false)

-- Exports
exports('GetPlayerJob', function(playerId)
    return playerJobs[playerId]
end)

exports('JailPlayer', JailPlayer)
exports('ReleasePlayer', ReleasePlayer)
exports('UpdatePlayerJob', UpdatePlayerJob)
