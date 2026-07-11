local ESX = nil
local PlayerData = {}
local isDead = false
local passedGateEntry = false
local lastGateEntryTime = 0
local spawnedNPCs = {}
local spawnedVehicles = {}
local lastFineTime = 0
local fineCooldown = 30000

-- Zone notification tracking
local militaryNotified = false
local prisonNotified = false
local trafficNotified = false
local airportNotified = false
local metroNotified = false
local airportWeaponWarning = false
local metroWeaponWarning = false

-- Airport and Metro specific
local airportGuards = {}
local metroGuards = {}
local currentAirportZone = nil
local currentMetroStation = nil
local lastWeaponCheck = 0

-- Initialize ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(10)
    end
    
    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

-- ===== UTILITY FUNCTIONS =====

-- Check if player has safe job
function IsSafeJob()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    for _, job in ipairs(Config.SafeJobs) do
        if string.lower(PlayerData.job.name) == string.lower(job) then
            return true
        end
    end
    return false
end

-- Check if player has weapon drawn
function HasWeaponDrawn()
    local playerPed = PlayerPedId()
    local weapon = GetSelectedPedWeapon(playerPed)
    
    if weapon and weapon ~= GetHashKey("WEAPON_UNARMED") then
        for _, restrictedWeapon in ipairs(Config.Airport.weaponDetection.restrictedWeapons) do
            if weapon == GetHashKey(restrictedWeapon) then
                return true, weapon, restrictedWeapon
            end
        end
    end
    
    return false, nil, nil
end

-- Check if weapon is aggressive
function IsAggressiveWeapon(weaponHash)
    for _, aggressiveWeapon in ipairs(Config.Airport.weaponDetection.aggressiveWeapons) do
        if weaponHash == GetHashKey(aggressiveWeapon) then
            return true
        end
    end
    return false
end

-- Check if player is prisoner
function IsPlayerPrisoner()
    if Config.Prison.prisonerDetection.checkPedModel then
        local playerPed = PlayerPedId()
        local playerModel = GetEntityModel(playerPed)
        
        for _, model in ipairs(Config.Prison.prisonerDetection.prisonerModels) do
            if playerModel == GetHashKey(model) then
                return true
            end
        end
    end
    
    if Config.Prison.prisonerDetection.checkJob and PlayerData and PlayerData.job then
        local jobName = string.lower(PlayerData.job.name)
        for _, prisonerJob in ipairs(Config.Prison.prisonerDetection.prisonerJobs) do
            if jobName == string.lower(prisonerJob) then
                return true
            end
        end
    end
    
    if Config.Prison.prisonerDetection.checkClothing then
        local playerPed = PlayerPedId()
        local torsoDrawable = GetPedDrawableVariation(playerPed, 3)
        local legsDrawable = GetPedDrawableVariation(playerPed, 4)
        if (torsoDrawable >= 49 and torsoDrawable <= 53) or (legsDrawable >= 54 and legsDrawable <= 58) then
            return true
        end
    end
    
    return false
end

-- Send notification using Native ESX function
function SendNotification(title, subject, msg, icon, iconType, flash)
    if ESX and ESX.ShowAdvancedNotification then
        ESX.ShowAdvancedNotification(title, subject, msg, icon, iconType or 1, flash or false)
    end
end

-- Zone notification wrapper
function SendZoneNotification(notification)
    if not notification then return end
    
    SendNotification(
        notification.title or "",
        notification.subject or "",
        notification.msg or "",
        notification.icon or "CHAR_DEFAULT",
        notification.iconType or 1,
        notification.flash or false
    )
end

-- ===== ZONE DETECTION FUNCTIONS =====

function HasEnteredMilitaryGate()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local inVehicle = IsPedInAnyVehicle(playerPed, false)
    
    for _, entryPoint in ipairs(Config.MilitaryBase.entryPoints) do
        local distance = #(playerCoords - entryPoint.coords)
        local heightDiff = math.abs(playerCoords.z - entryPoint.coords.z)
        local isAtEntry = distance <= entryPoint.radius and heightDiff < 10.0
        
        if entryPoint.checkVehicle and not inVehicle then
            isAtEntry = false
        end
        
        if isAtEntry then
            return true, entryPoint.coords
        end
    end
    
    return false, nil
end

function IsInsideMilitaryBase()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.MilitaryBase.internalZones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true
        end
    end
    
    return false
end

function IsInPrisonZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.Prison.zones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true
        end
    end
    
    return false
end

function IsInAirportZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.Airport.zones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true, zone
        end
    end
    
    return false, nil
end

function IsInMetroStation()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, station in ipairs(Config.Metro.stations) do
        local distance = #(playerCoords - station.coords)
        if station.underground then
            local zDiff = math.abs(playerCoords.z - station.coords.z)
            if distance <= station.radius and zDiff <= 10.0 then
                return true, station
            end
        elseif distance <= station.radius then
            return true, station
        end
    end
    
    return false, nil
end

-- ===== NPC SPAWNING FUNCTIONS =====

function SpawnNPC(model, coords, weapon, accuracy, friendly)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Citizen.Wait(10)
    end
    
    local ped = CreatePed(4, GetHashKey(model), coords.x, coords.y, coords.z, 0.0, true, false)
    
    if DoesEntityExist(ped) then
        if not friendly then
            SetPedAsCop(ped, true)
            SetPedFleeAttributes(ped, 0, 0)
            SetPedCombatAttributes(ped, 46, true)
            SetPedCombatRange(ped, 2)
            SetPedCombatMovement(ped, 3)
        else
            SetPedFleeAttributes(ped, 0, 0)
            SetPedCombatAttributes(ped, 0, true)
            SetPedCombatRange(ped, 0)
            SetPedSeeingRange(ped, 50.0)
            SetPedHearingRange(ped, 50.0)
            SetPedAlertness(ped, 3)
        end
        
        SetPedAccuracy(ped, accuracy or 50)
        
        if weapon and not friendly then
            GiveWeaponToPed(ped, GetHashKey(weapon), 999, false, true)
            SetCurrentPedWeapon(ped, GetHashKey(weapon), true)
        end
        
        if friendly then
            GiveWeaponToPed(ped, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        end
        
        SetPedRelationshipGroupHash(ped, GetHashKey("SECURITY_GUARD"))
        
        table.insert(spawnedNPCs, ped)
    end
    
    return ped
end

function SpawnVehicleWithCrew(model, coords, heading, hasWeapon, isAircraft)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Citizen.Wait(10)
    end
    
    local veh = CreateVehicle(GetHashKey(model), coords.x, coords.y, coords.z, heading or 0.0, true, false)
    
    if DoesEntityExist(veh) then
        SetVehicleOnGroundProperly(veh)
        SetVehicleEngineOn(veh, true, true, false)
        
        if isAircraft then
            SetVehicleEngineHealth(veh, 1000.0)
            SetHeliBladesFullSpeed(veh)
        end
        
        local driverModel = "s_m_m_marine_01"
        if Config.Airport then
            driverModel = Config.Airport.npcs.security.models[1]
        end
        
        local driver = CreatePedInsideVehicle(veh, 4, GetHashKey(driverModel), -1, true, false)
        
        if hasWeapon and not isAircraft then
            local passenger = CreatePedInsideVehicle(veh, 4, GetHashKey(driverModel), 0, true, false)
            GiveWeaponToPed(passenger, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
        end
        
        table.insert(spawnedVehicles, veh)
    end
    
    return veh
end

function CleanUpSpawns()
    for _, ped in ipairs(spawnedNPCs) do
        if DoesEntityExist(ped) then
            SetPedAsNoLongerNeeded(ped)
            DeleteEntity(ped)
        end
    end
    
    for _, veh in ipairs(spawnedVehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsNoLongerNeeded(veh)
            DeleteEntity(veh)
        end
    end
    
    spawnedNPCs = {}
    spawnedVehicles = {}
    airportGuards = {}
    metroGuards = {}
end

-- ===== AIRPORT SECURITY SYSTEM =====

local airportGuardsSpawned = false

function HandleAirportSecurity()
    local playerPed = PlayerPedId()
    
    if not Config.Airport.enabled or IsPedDeadOrDying(playerPed, true) then
        if airportGuardsSpawned then
            CleanUpAirportGuards()
            airportGuardsSpawned = false
            airportWeaponWarning = false
        end
        return
    end
    
    local inAirport, zone = IsInAirportZone()
    
    if inAirport then
        if not airportNotified then
            SendZoneNotification(Config.Airport.notification.friendly)
            airportNotified = true
        end
        
        if not airportGuardsSpawned then
            SpawnAirportGuards(zone)
            airportGuardsSpawned = true
        end
        
        if Config.Airport.weaponDetection.enabled then
            local currentTime = GetGameTimer()
            if currentTime - lastWeaponCheck >= Config.Airport.weaponDetection.checkInterval then
                lastWeaponCheck = currentTime
                CheckAirportWeapons(zone)
            end
        end
    else
        if airportGuardsSpawned then
            airportNotified = false
            airportWeaponWarning = false
            CleanUpAirportGuards()
            airportGuardsSpawned = false
        end
    end
end

function SpawnAirportGuards(zone)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local guardCount = Config.Airport.npcs.security.guardsPerZone[zone.type] or 4
    
    if #airportGuards >= Config.Airport.npcs.security.maxGuards then
        return
    end
    
    local guardsToSpawn = math.min(guardCount, Config.Airport.npcs.security.maxGuards - #airportGuards)
    local patrolPoints = Config.Airport.npcs.security.patrolPoints[zone.type]
    
    for i = 1, guardsToSpawn do
        local spawnPos
        if patrolPoints and #patrolPoints > 0 then
            local patrolPoint = patrolPoints[math.random(1, #patrolPoints)]
            spawnPos = vector3(
                patrolPoint.x + math.random(-10, 10),
                patrolPoint.y + math.random(-10, 10),
                patrolPoint.z
            )
        else
            local angle = (360 / guardsToSpawn) * i
            local radius = math.random(30, 60)
            spawnPos = vector3(
                playerCoords.x + math.cos(math.rad(angle)) * radius,
                playerCoords.y + math.sin(math.rad(angle)) * radius,
                playerCoords.z
            )
        end
        
        local model = Config.Airport.npcs.security.models[math.random(1, #Config.Airport.npcs.security.models)]
        local guard = SpawnNPC(model, spawnPos, nil, Config.Airport.npcs.security.accuracy, true)
        
        if DoesEntityExist(guard) then
            TaskGuardStand(guard, spawnPos, 10.0, 10.0, 3)
            table.insert(airportGuards, guard)
        end
    end
    
    for _, vehicleData in ipairs(Config.Airport.npcs.vehicles) do
        if vehicleData.patrol then
            for i = 1, (vehicleData.count or 1) do
                local angle = math.random(0, 360)
                local radius = math.random(80, 120)
                local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
                local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
                
                SpawnVehicleWithCrew(vehicleData.model, vector3(spawnX, spawnY, playerCoords.z), angle, false, false)
            end
        end
    end
end

function CheckAirportWeapons(zone)
    local playerPed = PlayerPedId()
    local hasWeapon, weaponHash, weaponName = HasWeaponDrawn()
    
    if hasWeapon then
        if not airportWeaponWarning then
            SendZoneNotification(Config.Airport.notification.weaponWarning)
            airportWeaponWarning = true
        end
        
        local playerCoords = GetEntityCoords(playerPed)
        local isAggressive = IsAggressiveWeapon(weaponHash)
        
        for _, guard in ipairs(airportGuards) do
            if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then
                local guardCoords = GetEntityCoords(guard)
                local distance = #(playerCoords - guardCoords)
                
                if distance <= Config.Airport.weaponDetection.alertRadius then
                    local guardWeapon = isAggressive and "WEAPON_PUMPSHOTGUN" or "WEAPON_COMBATPISTOL"
                    GiveWeaponToPed(guard, GetHashKey(guardWeapon), 999, false, true)
                    SetCurrentPedWeapon(guard, GetHashKey(guardWeapon), true)
                    
                    SetPedCombatAttributes(guard, 46, true)
                    SetPedCombatRange(guard, 2)
                    TaskCombatPed(guard, playerPed, 0, 16)
                    
                    for _, otherGuard in ipairs(airportGuards) do
                        if DoesEntityExist(otherGuard) and not IsPedDeadOrDying(otherGuard, true) then
                            local otherDistance = #(guardCoords - GetEntityCoords(otherGuard))
                            if otherDistance <= 100.0 then
                                GiveWeaponToPed(otherGuard, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
                                TaskCombatPed(otherGuard, playerPed, 0, 16)
              end
