local spawnedNPCs = {}
local spawnedVehicles = {}
local isInZone = false
local currentZone = nil
local isJailed = false
local playerJob = nil
local playerJobLabel = nil
local ESX = nil
local isBeingChased = false
local lastWeaponCheck = 0
local playerHasWeapon = false

-- Notification tracking
local notificationShown = false
local lastNotificationMessage = ""

-- Initialize ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Get player's job from ESX
function GetPlayerJob()
    if ESX then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.job then
            return playerData.job.name, playerData.job.label
        end
    end
    return nil, nil
end

-- Check if player has safe job
function HasSafeJob()
    if not playerJob then
        playerJob, playerJobLabel = GetPlayerJob()
    end
    
    if not playerJob then
        return false
    end
    
    for _, safeJob in ipairs(Config.SafeJobs) do
        if playerJob:lower() == safeJob:lower() then
            return true
        end
    end
    
    return false
end

-- Check if player has any weapon
function CheckPlayerWeapon()
    local playerPed = PlayerPedId()
    local weapon = GetSelectedPedWeapon(playerPed)
    
    if weapon ~= GetHashKey('WEAPON_UNARMED') then
        return true
    end
    return false
end

-- Check if player is aiming at NPCs
function IsPlayerAimingAtNPC(zoneName)
    local playerPed = PlayerPedId()
    
    if not IsPlayerFreeAiming(playerPed) then
        return false
    end
    
    local aimPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 0.0, 0.0)
    local aimDir = GetEntityForwardVector(playerPed)
    local rayHandle = StartShapeTestRay(aimPos.x, aimPos.y, aimPos.z, 
                                        aimPos.x + aimDir.x * 100.0, 
                                        aimPos.y + aimDir.y * 100.0, 
                                        aimPos.z + aimDir.z * 100.0, 
                                        -1, playerPed, 0)
    
    local _, hit, hitCoords, hitEntity = GetShapeTestResult(rayHandle)
    
    if hit and DoesEntityExist(hitEntity) then
        for _, npc in pairs(spawnedNPCs) do
            if npc.zone == zoneName and npc.ped == hitEntity then
                return true
            end
        end
    end
    
    return false
end

-- Check if player is in jail
function CheckIfJailed()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, jailPos in ipairs(Config.Jail.jail_positions) do
        local distance = #(playerCoords - jailPos)
        if distance < 50.0 then
            return true
        end
    end
    
    return false
end

-- Check if position is inside base boundaries
function IsInsideBase(zoneName, coords)
    local boundaries = Config.BaseBoundaries[zoneName]
    if not boundaries then
        return true
    end
    
    if coords.x >= boundaries.minX and coords.x <= boundaries.maxX and
       coords.y >= boundaries.minY and coords.y <= boundaries.maxY then
        return true
    end
    return false
end

-- Check if NPC should attack player
function ShouldAttackPlayer(zoneName)
    local zoneData = Config.Zones[zoneName]
    
    if zoneData.ignore_jail and isJailed then
        return false
    end
    
    if HasSafeJob() then
        return false
    end
    
    if zoneData.faction == 'military' and zoneData.check_weapon then
        if CheckPlayerWeapon() then
            return true
        end
        return false
    end
    
    if zoneData.faction == 'police' and zoneData.check_aiming then
        if IsPlayerAimingAtNPC(zoneName) then
            return true
        end
        if zoneData.check_weapon and CheckPlayerWeapon() then
            return true
        end
        return false
    end
    
    if zoneData.check_weapon and CheckPlayerWeapon() then
        return true
    end
    
    return false
end

-- Spawn military vehicles
function SpawnMilitaryVehicles(zoneName, zoneData)
    if not zoneData.use_vehicles then
        return
    end
    
    local vehicleCount = 0
    
    for _, spawnPoint in ipairs(zoneData.vehicle_spawn_points) do
        if vehicleCount >= zoneData.max_vehicles then
            break
        end
        
        RequestModel(GetHashKey(zoneData.vehicle_model))
        while not HasModelLoaded(GetHashKey(zoneData.vehicle_model)) do
            Wait(10)
        end
        
        local vehicle = CreateVehicle(GetHashKey(zoneData.vehicle_model), 
            spawnPoint.x, spawnPoint.y, spawnPoint.z, 
            math.random(0, 360), true, false)
        
        SetVehicleNumberPlateText(vehicle, "ARMY" .. math.random(100, 999))
        SetVehicleColours(vehicle, 0, 0)
        SetVehicleDirtLevel(vehicle, 0.0)
        SetVehicleEngineOn(vehicle, true, true, false)
        
        -- Spawn NPC driver
        local driverModel = 's_m_y_marine_01'
        RequestModel(GetHashKey(driverModel))
        while not HasModelLoaded(GetHashKey(driverModel)) do
            Wait(10)
        end
        
        local driver = CreatePedInsideVehicle(vehicle, 4, GetHashKey(driverModel), -1, true, false)
        SetPedRelationshipGroupHash(driver, GetHashKey('CIVMALE'))
        SetPedCombatAttributes(driver, 46, true)
        SetPedCombatAttributes(driver, 1, true)
        SetPedCombatAbility(driver, 2)
        SetPedAccuracy(driver, Config.NPC.accuracy * 100)
        SetEntityHealth(driver, Config.NPC.health)
        SetEntityMaxHealth(driver, Config.NPC.health)
        SetPedArmour(driver, 100)
        SetPedFleeAttributes(driver, 0, false)
        
        GiveWeaponToPed(driver, GetHashKey(zoneData.vehicle_weapon), 999, false, true)
        SetCurrentPedWeapon(driver, GetHashKey(zoneData.vehicle_weapon), true)
        
        -- Spawn passenger NPCs
        local passengerCount = math.random(1, 3)
        for i = 1, passengerCount do
            local passenger = CreatePedInsideVehicle(vehicle, 4, GetHashKey(driverModel), i, true, false)
            SetPedRelationshipGroupHash(passenger, GetHashKey('CIVMALE'))
            SetPedCombatAttributes(passenger, 46, true)
            SetPedCombatAttributes(passenger, 1, true)
            SetPedCombatAbility(passenger, 2)
            SetPedAccuracy(passenger, Config.NPC.accuracy * 100)
            SetEntityHealth(passenger, Config.NPC.health)
            SetEntityMaxHealth(passenger, Config.NPC.health)
            SetPedArmour(passenger, 100)
            SetPedFleeAttributes(passenger, 0, false)
            
            GiveWeaponToPed(passenger, GetHashKey(zoneData.vehicle_weapon), 999, false, true)
            SetCurrentPedWeapon(passenger, GetHashKey(zoneData.vehicle_weapon), true)
            
            table.insert(spawnedNPCs, {
                ped = passenger,
                zone = zoneName,
                isInVehicle = true,
                vehicle = vehicle
            })
        end
        
        table.insert(spawnedVehicles, {
            vehicle = vehicle,
            zone = zoneName,
            driver = driver,
            spawnPoint = spawnPoint,
            isChasing = false
        })
        
        table.insert(spawnedNPCs, {
            ped = driver,
            zone = zoneName,
            isInVehicle = true,
            vehicle = vehicle
        })
        
        vehicleCount = vehicleCount + 1
        Wait(100)
    end
end

-- Create NPCs for a zone
function CreateZoneNPCs(zoneName, zoneData)
    local npcCount = Config.NPC.max_guards_per_zone
    
    for i = 1, npcCount do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(5, zoneData.radius - 10)
        local x = zoneData.coords.x + math.cos(angle) * distance
        local y = zoneData.coords.y + math.sin(angle) * distance
        local z = zoneData.coords.z
        
        local groundZ = z
        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z, true)
        if foundGround then
            z = groundZ
        end
        
        RequestModel(GetHashKey(zoneData.npc_model))
        while not HasModelLoaded(GetHashKey(zoneData.npc_model)) do
            Wait(10)
        end
        
        local ped = CreatePed(4, GetHashKey(zoneData.npc_model), x, y, z, math.random(0, 360), false, true)
        
        SetPedRelationshipGroupHash(ped, GetHashKey('CIVMALE'))
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 1, true)
        SetPedCombatAbility(ped, 2)
        SetPedAccuracy(ped, Config.NPC.accuracy * 100)
        SetEntityHealth(ped, Config.NPC.health)
        SetEntityMaxHealth(ped, Config.NPC.health)
        SetPedArmour(ped, 100)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatRange(ped, 2)
        
        GiveWeaponToPed(ped, GetHashKey(zoneData.weapon), 999, false, true)
        SetCurrentPedWeapon(ped, GetHashKey(zoneData.weapon), true)
        
        SetEntityAsMissionEntity(ped, true, true)
        FreezeEntityPosition(ped, false)
        
        table.insert(spawnedNPCs, {
            ped = ped,
            zone = zoneName,
            coords = vector3(x, y, z),
            originalPos = vector3(x, y, z),
            isDead = false,
            isChasing = false,
            targetCoords = nil,
            isInVehicle = false,
            vehicle = nil
        })
        
        Wait(100)
    end
    
    if zoneData.use_vehicles then
        SpawnMilitaryVehicles(zoneName, zoneData)
    end
end

-- Spawn all zone NPCs
function SpawnAllNPCs()
    for zoneName, zoneData in pairs(Config.Zones) do
        CreateZoneNPCs(zoneName, zoneData)
    end
end

-- Chase with vehicles
function ChaseWithVehicles(zoneName, playerCoords)
    local zoneData = Config.Zones[zoneName]
    
    if not zoneData.use_vehicles then
        return
    end
    
    for _, vehicleData in pairs(spawnedVehicles) do
        if vehicleData.zone == zoneName and DoesEntityExist(vehicleData.vehicle) then
            local vehicleCoords = GetEntityCoords(vehicleData.vehicle)
            local distance = #(vehicleCoords - playerCoords)
            local driver = vehicleData.driver
            
            if not IsInsideBase(zoneName, playerCoords) then
                TaskVehicleDriveToCoord(driver, vehicleData.vehicle, 
                    vehicleData.spawnPoint.x, vehicleData.spawnPoint.y, vehicleData.spawnPoint.z, 
                    5.0, 0, 0, 0, 0, 0)
                vehicleData.isChasing = false
                return
            end
            
            if distance <= zoneData.chase_range and ShouldAttackPlayer(zoneName) then
                TaskVehicleDriveToCoord(driver, vehicleData.vehicle, 
                    playerCoords.x, playerCoords.y, playerCoords.z, 
                    Config.NPC.vehicle_chase_speed, 0, 0, 0, 0, 0)
                vehicleData.isChasing = true
                
                for _, npc in pairs(spawnedNPCs) do
                    if npc.vehicle == vehicleData.vehicle and npc.ped ~= driver then
                        if DoesEntityExist(npc.ped) and distance <= zoneData.attack_range then
                            TaskCombatPed(npc.ped, PlayerPedId(), 0, 16)
                            SetCurrentPedWeapon(npc.ped, GetHashKey(zoneData.vehicle_weapon), true)
                        end
                    end
                end
            else
                if not vehicleData.isChasing then
                    TaskVehicleDriveToCoord(driver, vehicleData.vehicle, 
                        vehicleData.spawnPoint.x, vehicleData.spawnPoint.y, vehicleData.spawnPoint.z, 
                        5.0, 0, 0, 0, 0, 0)
                end
                vehicleData.isChasing = false
            end
        end
    end
end

-- Chase and kill player
function ChaseAndKill(zoneName)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local zoneData = Config.Zones[zoneName]
    local shouldAttack = ShouldAttackPlayer(zoneName)
    
    local insideBase = IsInsideBase(zoneName, playerCoords)
    
    for _, npc in pairs(spawnedNPCs) do
        if npc.zone == zoneName and DoesEntityExist(npc.ped) and not IsPedDeadOrDying(npc.ped, true) and not npc.isInVehicle then
            
            if shouldAttack and insideBase then
                local npcCoords = GetEntityCoords(npc.ped)
                local distance = #(npcCoords - playerCoords)
                
                SetPedRelationshipGroupHash(npc.ped, GetHashKey('CIVMALE'))
                SetRelationshipBetweenGroups(5, GetHashKey('CIVMALE'), GetHashKey('PLAYER'))
                SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('CIVMALE'))
                
                if distance <= zoneData.attack_range then
                    TaskCombatPed(npc.ped, playerPed, 0, 16)
                    SetCurrentPedWeapon(npc.ped, GetHashKey(zoneData.weapon), true)
                    npc.isChasing = false
                elseif distance <= zoneData.chase_range then
                    TaskGoToCoordAnyMeans(npc.ped, playerCoords.x, playerCoords.y, playerCoords.z, 
                                        Config.NPC.chase_speed, 0, 0, 786603, 0xbf800000)
                    npc.isChasing = true
                    npc.targetCoords = playerCoords
                    
                    if distance <= zoneData.attack_range + 20 then
                        TaskCombatPed(npc.ped, playerPed, 0, 16)
                    end
                else
                    if distance > zoneData.chase_range then
                        TaskGoToCoordAnyMeans(npc.ped, npc.originalPos.x, npc.originalPos.y, npc.originalPos.z, 
                                            1.0, 0, 0, 786603, 0xbf800000)
                        npc.isChasing = false
                    end
                end
            else
                ClearPedTasks(npc.ped)
                SetRelationshipBetweenGroups(0, GetHashKey('CIVMALE'), GetHashKey('PLAYER'))
                SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('CIVMALE'))
                
                if not npc.isChasing then
                    local patrolDist = math.random(5, 20)
                    local angle = math.random() * 2 * math.pi
                    local destX = npc.originalPos.x + math.cos(angle) * patrolDist
                    local destY = npc.originalPos.y + math.sin(angle) * patrolDist
                    
                    TaskGoToCoordAnyMeans(npc.ped, destX, destY, npc.originalPos.z, 1.0, 0, 0, 786603, 0xbf800000)
                end
                npc.isChasing = false
            end
        end
    end
    
    if zoneData.use_vehicles then
        ChaseWithVehicles(zoneName, playerCoords)
    end
end

-- Check if player is in any zone
function CheckZones()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    isJailed = CheckIfJailed()
    playerJob, playerJobLabel = GetPlayerJob()
    playerHasWeapon = CheckPlayerWeapon()
    
    for zoneName, zoneData in pairs(Config.Zones) do
        local distance = #(playerCoords - zoneData.coords)
        
        if distance <= zoneData.radius + zoneData.chase_range then
            if not isInZone or currentZone ~= zoneName then
                isInZone = true
                currentZone = zoneName
                TriggerServerEvent('npc:playerEnteredZone', zoneName)
            end
            return true
        end
    end
    
    if isInZone then
        isInZone = false
        currentZone = nil
        TriggerServerEvent('npc:playerLeftZone')
    end
    return false
end

-- Respawn dead NPCs
function RespawnDeadNPCs()
    for _, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc.ped) then
            if IsPedDeadOrDying(npc.ped, true) then
                DeleteEntity(npc.ped)
                
                Citizen.SetTimeout(Config.Zones[npc.zone].respawn_time, function()
                    local zoneData = Config.Zones[npc.zone]
                    RequestModel(GetHashKey(zoneData.npc_model))
                    while not HasModelLoaded(GetHashKey(zoneData.npc_model)) do
                        Wait(10)
                    end
                    
                    local ped = CreatePed(4, GetHashKey(zoneData.npc_model), 
                        npc.originalPos.x, npc.originalPos.y, npc.originalPos.z, 
                        math.random(0, 360), false, true)
                    
                    SetPedRelationshipGroupHash(ped, GetHashKey('CIVMALE'))
                    SetPedCombatAttributes(ped, 46, true)
                    SetPedCombatAttributes(ped, 1, true)
                    SetPedCombatAbility(ped, 2)
                    SetPedAccuracy(ped, Config.NPC.accuracy * 100)
                    SetEntityHealth(ped, Config.NPC.health)
                    SetEntityMaxHealth(ped, Config.NPC.health)
                    SetPedArmour(ped, 100)
                    SetPedFleeAttributes(ped, 0, false)
                    
                    GiveWeaponToPed(ped, GetHashKey(zoneData.weapon), 999, false, true)
                    SetCurrentPedWeapon(ped, GetHashKey(zoneData.weapon), true)
                    
                    SetEntityAsMissionEntity(ped, true, true)
                    
                    npc.ped = ped
                    npc.isDead = false
                    npc.isChasing = false
                end)
            end
        end
    end
end

-- Show notification (ONE TIME)
function ShowNotification(message, type)
    if message == lastNotificationMessage then
        return
    end
    
    lastNotificationMessage = message
    
    if Config.UseESXNotification and ESX then
        if type == 'error' then
            ESX.ShowNotification('~r~' .. message)
        elseif type == 'success' then
            ESX.ShowNotification('~g~' .. message)
        elseif type == 'warning' then
            ESX.ShowNotification('~y~' .. message)
        else
            ESX.ShowNotification(message)
        end
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

-- Reset notification when leaving zone
function ResetNotifications()
    lastNotificationMessage = ""
    notificationShown = false
end

-- Main loop
Citizen.CreateThread(function()
    SpawnAllNPCs()
    local wasInZone = false
    
    while true do
        Wait(500)
        
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            Wait(2000)
        end
        
        local inZone = CheckZones()
        
        if inZone and currentZone then
            local zoneData = Config.Zones[currentZone]
            local shouldAttack = ShouldAttackPlayer(currentZone)
            
            ChaseAndKill(currentZone)
            
            if not wasInZone then
                wasInZone = true
                
                if shouldAttack then
                    local jobStatus = ""
                    if playerJob and not HasSafeJob() then
                        jobStatus = " (Job: " .. playerJobLabel .. ")"
                    end
                    
                    if zoneData.faction == 'military' then
                        ShowNotification("MILITARY FORCE DETECTED! They are attacking with VEHICLES!" .. jobStatus, 'error')
                    elseif zoneData.faction == 'police' then
                        if IsPlayerAimingAtNPC(currentZone) then
                            ShowNotification("POLICE: Stop aiming! They are returning fire!", 'error')
                        else
                            ShowNotification("POLICE: Weapon detected! They are engaging!", 'error')
                        end
                    end
                else
                    if HasSafeJob() then
                        ShowNotification(playerJobLabel .. " recognized. Authorized personnel.", 'success')
                    elseif isJailed and zoneData.ignore_jail then
                        ShowNotification("Jailed prisoner. NPCs are ignoring you.", 'success')
                    else
                        ShowNotification("Restricted zone. No weapons detected.", 'warning')
                    end
                end
            end
        else
            if wasInZone then
                wasInZone = false
                ResetNotifications()
                
                ShowNotification("You have left the restricted zone.", 'warning')
                
                for zoneName, _ in pairs(Config.Zones) do
                    for _, npc in pairs(spawnedNPCs) do
                        if npc.zone == zoneName and DoesEntityExist(npc.ped) then
                            ClearPedTasks(npc.ped)
                            SetRelationshipBetweenGroups(0, GetHashKey('CIVMALE'), GetHashKey('PLAYER'))
                            SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('CIVMALE'))
                            npc.isChasing = false
                        end
                    end
                end
            end
        end
    end
end)

-- Respawn NPCs
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        RespawnDeadNPCs()
    end
end)

-- Cleanup on resource stop
Citizen.CreateThread(function()
    while true do
        Wait(100)
        if not GetResourceState('npc_reactions') or GetResourceState('npc_reactions') == 'stopped' then
            for _, npc in pairs(spawnedNPCs) do
                if DoesEntityExist(npc.ped) then
                    DeleteEntity(npc.ped)
                end
            end
            for _, vehicleData in pairs(spawnedVehicles) do
                if DoesEntityExist(vehicleData.vehicle) then
                    DeleteEntity(vehicleData.vehicle)
                end
            end
            break
        end
    end
end)

-- Events
RegisterNetEvent('npc:setJailStatus')
AddEventHandler('npc:setJailStatus', function(jailed)
    isJailed = jailed
end)

RegisterNetEvent('npc:updateJob')
AddEventHandler('npc:updateJob', function(job, jobLabel)
    playerJob = job
    playerJobLabel = jobLabel
end)

-- Get player job
function GetPlayerJobInfo()
    return playerJob, playerJobLabel
end

exports('GetPlayerJobInfo', GetPlayerJobInfo)

-- Debug zone boundaries
local debugEnabled = false
RegisterCommand('npcdebug', function()
    debugEnabled = not debugEnabled
    ShowNotification("Debug mode: " .. (debugEnabled and "ON" or "OFF"), 'info')
end, false)

-- Draw debug zones
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if debugEnabled then
            for zoneName, zoneData in pairs(Config.Zones) do
                DrawMarker(1, zoneData.coords.x, zoneData.coords.y, zoneData.coords.z - 1, 
                    0, 0, 0, 0, 0, 0, 
                    zoneData.radius * 2, zoneData.radius * 2, 2.0, 
                    255, 0, 0, 100, false, false, 2, false, false, false, false)
                
                DrawMarker(1, zoneData.coords.x, zoneData.coords.y, zoneData.coords.z - 1, 
                    0, 0, 0, 0, 0, 0, 
                    zoneData.chase_range * 2, zoneData.chase_range * 2, 1.0, 
                    0, 255, 0, 50, false, false, 2, false, false, false, false)
                
                if zoneData.faction == 'military' then
                    local boundaries = Config.BaseBoundaries[zoneName]
                    if boundaries then
                        local centerX = (boundaries.minX + boundaries.maxX) / 2
                        local centerY = (boundaries.minY + boundaries.maxY) / 2
                        local width = boundaries.maxX - boundaries.minX
                        local height = boundaries.maxY - boundaries.minY
                        
                        DrawMarker(1, centerX, centerY, zoneData.coords.z - 1, 
                            0, 0, 0, 0, 0, 0, 
                            width, height, 1.0, 
                            0, 0, 255, 50, false, false, 2, false, false, false, false)
                    end
                end
            end
        end
    end
end)

-- Emergency stop command for admins
RegisterCommand('stopnpcs', function(source, args, rawCommand)
    if source == 0 then return end
    for _, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc.ped) then
            ClearPedTasks(npc.ped)
            DeleteEntity(npc.ped)
        end
    end
    for _, vehicleData in pairs(spawnedVehicles) do
        if DoesEntityExist(vehicleData.vehicle) then
            DeleteEntity(vehicleData.vehicle)
        end
    end
    spawnedNPCs = {}
    spawnedVehicles = {}
    ShowNotification("All NPCs and vehicles removed!", 'success')
    Citizen.SetTimeout(5000, function()
        SpawnAllNPCs()
        ShowNotification("NPCs and vehicles respawned!", 'success')
    end)
end, true)
