Config = {}

-- Define your zones
Config.Zones = {
    -- Military Base (Fort Zancudo) - WITH VEHICLES
    military = {
        coords = vector3(-2350.0, 3250.0, 32.0),
        radius = 200.0,
        npc_model = 's_m_y_marine_01',
        weapon = 'WEAPON_CARBINERIFLE',
        faction = 'military',
        attack_range = 150.0,
        respawn_time = 30000,
        ignore_jail = false,
        debug = false,
        check_weapon = true,
        chase_range = 300.0,
        kill_on_sight = true,
        -- VEHICLE SETTINGS
        use_vehicles = true,
        vehicle_model = 'BARRACKS',
        vehicle_weapon = 'WEAPON_CARBINERIFLE',
        max_vehicles = 2,
        vehicle_spawn_points = {
            vector3(-2340.0, 3260.0, 32.0),
            vector3(-2360.0, 3240.0, 32.0),
            vector3(-2330.0, 3280.0, 32.0)
        }
    },
    
    -- Military Entrance
    military_entrance = {
        coords = vector3(-2320.0, 3180.0, 32.0),
        radius = 100.0,
        npc_model = 's_m_y_marine_01',
        weapon = 'WEAPON_CARBINERIFLE',
        faction = 'military',
        attack_range = 120.0,
        respawn_time = 30000,
        ignore_jail = false,
        debug = false,
        check_weapon = true,
        chase_range = 250.0,
        kill_on_sight = true,
        use_vehicles = true,
        vehicle_model = 'BARRACKS',
        vehicle_weapon = 'WEAPON_CARBINERIFLE',
        max_vehicles = 1,
        vehicle_spawn_points = {
            vector3(-2310.0, 3190.0, 32.0)
        }
    },
    
    -- Police Station (Mission Row) - NO VEHICLES
    police_station = {
        coords = vector3(440.0, -980.0, 30.0),
        radius = 80.0,
        npc_model = 's_m_y_cop_01',
        weapon = 'WEAPON_PISTOL',
        faction = 'police',
        attack_range = 60.0,
        respawn_time = 20000,
        ignore_jail = true,
        debug = false,
        check_weapon = false,
        chase_range = 150.0,
        kill_on_sight = false,
        check_aiming = true,
        use_vehicles = false
    },
    
    -- Police Station (Vespucci)
    vespucci_police = {
        coords = vector3(-1100.0, -850.0, 19.0),
        radius = 60.0,
        npc_model = 's_m_y_cop_01',
        weapon = 'WEAPON_PISTOL',
        faction = 'police',
        attack_range = 50.0,
        respawn_time = 20000,
        ignore_jail = true,
        debug = false,
        check_weapon = false,
        chase_range = 120.0,
        kill_on_sight = false,
        check_aiming = true,
        use_vehicles = false
    },
    
    -- Prison (Bolingbroke)
    prison = {
        coords = vector3(1840.0, 2600.0, 45.0),
        radius = 120.0,
        npc_model = 's_m_y_prisoner_01',
        weapon = 'WEAPON_PUMPSHOTGUN',
        faction = 'police',
        attack_range = 80.0,
        respawn_time = 25000,
        ignore_jail = true,
        debug = false,
        check_weapon = true,
        chase_range = 200.0,
        kill_on_sight = true,
        check_aiming = false,
        use_vehicles = false
    },
    
    -- FIB Building
    fib = {
        coords = vector3(120.0, -750.0, 45.0),
        radius = 60.0,
        npc_model = 's_m_y_fib_01',
        weapon = 'WEAPON_PISTOL',
        faction = 'police',
        attack_range = 50.0,
        respawn_time = 20000,
        ignore_jail = true,
        debug = false,
        check_weapon = true,
        chase_range = 150.0,
        kill_on_sight = true,
        check_aiming = false,
        use_vehicles = false
    }
}

-- Faction relationships
Config.Factions = {
    military = {
        friendly = {},
        hostile = {'player'}
    },
    police = {
        friendly = {},
        hostile = {'player'}
    }
}

-- NPC settings
Config.NPC = {
    max_guards_per_zone = 4,
    health = 200,
    accuracy = 0.6,
    aggression = 1.0,
    detection_range = 200.0,
    chase_speed = 3.0,
    shoot_rate = 300,
    vehicle_chase_speed = 8.0
}

-- Safe Jobs (NPCs will NEVER attack these jobs)
Config.SafeJobs = {
    'police',
    'ambulance',
    'firefighter',
    'government',
    'fib',
    'sheriff',
    'statepolice',
    'doctor',
    'mechanic',
    'military'
}

-- Jail system integration
Config.Jail = {
    enabled = true,
    jail_positions = {
        vector3(1840.0, 2600.0, 45.0),
        vector3(1830.0, 2610.0, 45.0),
        vector3(1850.0, 2590.0, 45.0)
    }
}

-- Framework settings
Config.Framework = 'esx'
Config.UseESXNotification = true

-- Base boundaries (Army won't go outside these)
Config.BaseBoundaries = {
    military = {
        minX = -2500.0,
        maxX = -2200.0,
        minY = 3100.0,
        maxY = 3400.0
    },
    military_entrance = {
        minX = -2400.0,
        maxX = -2250.0,
        minY = 3150.0,
        maxY = 3250.0
    }
}
