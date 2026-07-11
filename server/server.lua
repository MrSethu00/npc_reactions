local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Process fine payment
RegisterNetEvent('npc_reactions:processFine')
AddEventHandler('npc_reactions:processFine', function(amount, reason)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer then
        local currentMoney = xPlayer.getMoney()
        local bankMoney = xPlayer.getAccount('bank').money
        
        -- Try bank first, then cash
        if Config.TrafficPolice.fines.bankDeduction and bankMoney >= amount then
            xPlayer.removeAccountMoney('bank', amount)
            
            TriggerClientEvent('npc_reactions:finePaid', source, {
                success = true,
                amount = amount,
                reason = reason,
                method = 'bank'
            })
        elseif currentMoney >= amount then
            xPlayer.removeMoney(amount)
            
            TriggerClientEvent('npc_reactions:finePaid', source, {
                success = true,
                amount = amount,
                reason = reason,
                method = 'cash'
            })
        else
            TriggerClientEvent('npc_reactions:fineFailed', source, {
                success = false,
                amount = amount,
                reason = reason,
                missing = amount - (currentMoney + bankMoney)
            })
            
            print(string.format("[TRAFFIC_FINE] Player %s (%s) couldn't pay fine of $%d for %s. Missing: $%d", 
                xPlayer.name, xPlayer.identifier, amount, reason, amount - (currentMoney + bankMoney)))
        end
        
        -- Log fine
        TriggerEvent('npc_reactions:logFine', xPlayer.identifier, amount, reason)
    end
end)

-- Log fine event
RegisterNetEvent('npc_reactions:logFine')
AddEventHandler('npc_reactions:logFine', function(identifier, amount, reason)
    print(string.format("[FINE_LOG] %s fined $%d for %s", identifier, amount, reason))
end)

-- Zone violation logging
RegisterNetEvent('npc_reactions:logZoneViolation')
AddEventHandler('npc_reactions:logZoneViolation', function(zoneType, zoneName, playerCoords)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer then
        local logMessage = string.format(
            "[NPC_REACTIONS] Player %s (ID: %s, Job: %s) entered %s zone: %s at coords (%.1f, %.1f, %.1f)",
            xPlayer.name,
            xPlayer.identifier,
            xPlayer.job.name,
            zoneType,
            zoneName,
            playerCoords.x,
            playerCoords.y,
            playerCoords.z
        )
        
        print(logMessage)
        
        -- Trigger custom event for external scripts
        TriggerEvent('npc_reactions:onZoneViolation', xPlayer, zoneType, zoneName, playerCoords)
    end
end)

print('^2[NPC_REACTIONS] ^7Server script initialized successfully')
print('^2[NPC_REACTIONS] ^7Fine system active')
