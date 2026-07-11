Config = {}

-- Safe Jobs (won't be attacked)
Config.SafeJobs = {
    'police',
    'sheriff',
    'ambulance',
    'ems',
    'offpolice',
    'offambulance',
    'offems',
    'fib',
    'army',
    'soldier',
    'security',
    'prisonguard',
    'corrections',
    'doj',
    'government',
    'state',
    'fbi'
}

-- Military Base Settings
Config.MilitaryBase = {
    enabled = true,
    zoneName = "Fort Zancudo Military Base",
    entryPoints = {
        -- Main gate entrance
        {
            coords = vector3(-1605.0, 2798.0, 16.0),
            radius = 25.0,
            checkVehicle = true
        },
        -- Back gate entrance
        {
            coords = vector3(-2360.0, 3235.0, 32.0),
            radius = 25.0,
            checkVehicle = true
        },
        -- Side entrance
        {
            coords = vector3(-2115.0, 3160.0, 32.0),
            radius = 25.0,
            checkVehicle = true
        }
    },
    internalZones = {
        {
            coords = vector3(-2150.0, 3200.0, 32.0),
            radius = 300.0
        }
    },
    chaseSettings = {
        maxChaseDistance = 500.0,    -- How far they'll chase outside
        chaseTimeout = 45000,        -- 45 seconds max chase
        chaseSpeed = 35.0,          -- Vehicle chase speed
        returnAfterChase = true     -- Return to base after chase
    },
    npcs = {
        soldiers = {
            models = {
                "s_m_m_marine_01",
                "s_m_m_marine_02",
                "s_m_y_marine_01"
            },
            weapons = {
                "WEAPON_CARBINERIFLE",
                "WEAPON_COMBATMG",
                "WEAPON_SPECIALCARBINE",
                "WEAPON_HEAVYSNIPER"
            },
            accuracy = 65,
            count = 10
        },
        vehicles = {
            {model = "crusader", weapon = false, count = 2},
            {model = "barracks", weapon = true, count = 1},
            {model = "buzzard2", weapon = true, count = 1, airVehicle = true}
        }
    },
    notification = {
        title = "RESTRICTED AREA",
        subject = "Fort Zancudo",
        msg = "You have entered a restricted military zone! Military forces have been deployed!",
        icon = "CHAR_ARMY",
        iconType = 1,
        flash = true
    }
}

-- Prison Area Settings
Config.Prison = {
    enabled = true,
    zoneName = "Bolingbroke Penitentiary",
    zones = {
        -- Outer perimeter
        {
            coords = vector3(1840.0, 2590.0, 45.0),
            radius = 200.0,
            type = "outer"
        },
        -- Inner prison area
        {
            coords = vector3(1750.0, 2570.0, 45.0),
            radius = 150.0,
            type = "inner"
        }
    },
    prisonerDetection = {
        checkJob = true,
        checkClothing = true,
        checkPedModel = true,
        prisonerJobs = {
            'prisoner',
            'inmate',
            'jail'
        },
        prisonerModels = {
            "mp_m_prisoner",
            "mp_f_prisoner",
            "s_m_m_prisoner_01"
        }
    },
    npcs = {
        guards = {
            models = {
                "s_m_m_prisguard_01",
                "s_m_y_prismuscl_01"
            },
            weapons = {
                "WEAPON_PUMPSHOTGUN",
                "WEAPON_COMBATPISTOL",
                "WEAPON_ASSAULTSHOTGUN"
            },
            accuracy = 55,
            count = 12,
            attackPrisoners = false
        },
        vehicles = {
            {model = "pbus", weapon = false, count = 2},
            {model = "policeb", weapon = false, count = 2},
            {model = "riot", weapon = false, count = 1}
        }
    },
    notification = {
        title = "RESTRICTED AREA",
        subject = "Bolingbroke Penitentiary",
        msg = "Unauthorized access to correctional facility! Prison guards are responding!",
        icon = "CHAR_BLOCKED",
        iconType = 1,
        flash = true
    }
}

-- Airport Security Settings
Config.Airport = {
    enabled = true,
    zoneName = "Los Santos International Airport",
    zones = {
        -- Main terminal area
        {
            coords = vector3(-1050.0, -2700.0, 13.0),
            radius = 800.0,
            type = "terminal"
        },
        -- Runway and hangar area
        {
            coords = vector3(-1200.0, -2900.0, 13.0),
            radius = 600.0,
            type = "tarmac"
        },
        -- Cargo area
        {
            coords = vector3(-900.0, -2850.0, 13.0),
            radius = 400.0,
            type = "cargo"
        }
    },
    npcs = {
        security = {
            models = {
                "s_m_m_ciasec_01",
                "s_m_m_highsec_01",
                "s_m_y_airworker",
                "s_m_m_security_01"
            },
            weapons = {
                "WEAPON_COMBATPISTOL",
                "WEAPON_PUMPSHOTGUN",
                "WEAPON_SMG"
            },
            accuracy = 55,
            guardsPerZone = {
                terminal = 8,
                tarmac = 6,
                cargo = 4
            },
            maxGuards = 15,
            friendly = true,
            reactToWeapon = true,
            spawnDistance = 100.0,
            patrolPoints = {
                terminal = {
                    vector3(-1040.0, -2720.0, 13.0),
                    vector3(-1060.0, -2680.0, 13.0),
                    vector3(-1080.0, -2740.0, 13.0),
                    vector3(-1020.0, -2760.0, 13.0)
                },
                tarmac = {
                    vector3(-1150.0, -2850.0, 13.0),
                    vector3(-1250.0, -2900.0, 13.0),
                    vector3(-1200.0, -2950.0, 13.0),
                    vector3(-1300.0, -2850.0, 13.0)
                },
                cargo = {
                    vector3(-920.0, -2830.0, 13.0),
                    vector3(-880.0, -2870.0, 13.0),
                    vector3(-910.0, -2900.0, 13.0)
                }
            }
        },
        vehicles = {
            {model = "airtug", weapon = false, count = 2, patrol = true},
            {model = "rentalbus", weapon = false, count = 1, patrol = true}
        }
    },
    weaponDetection = {
        enabled = true,
        checkInterval = 2000,
        alertRadius = 50.0,
        aggressiveWeapons = {
            "WEAPON_RPG",
            "WEAPON_GRENADE",
            "WEAPON_MINIGUN",
            "WEAPON_RAILGUN",
            "WEAPON_STICKYBOMB",
            "WEAPON_COMPACTLAUNCHER",
            "WEAPON_HOMINGLAUNCHER",
            "WEAPON_PROXMINE"
        },
        restrictedWeapons = {
            "WEAPON_KNIFE",
            "WEAPON_BAT",
            "WEAPON_PISTOL",
            "WEAPON_COMBATPISTOL",
            "WEAPON_APPISTOL",
            "WEAPON_PISTOL50",
            "WEAPON_SMG",
            "WEAPON_ASSAULTSMG",
            "WEAPON_MICROSMG",
            "WEAPON_ASSAULTRIFLE",
            "WEAPON_CARBINERIFLE",
            "WEAPON_ADVANCEDRIFLE",
            "WEAPON_SPECIALCARBINE",
            "WEAPON_BULLPUPRIFLE",
            "WEAPON_PUMPSHOTGUN",
            "WEAPON_SAWNOFFSHOTGUN",
            "WEAPON_ASSAULTSHOTGUN",
            "WEAPON_HEAVYSHOTGUN",
            "WEAPON_STUNGUN",
            "WEAPON_SNIPERRIFLE",
            "WEAPON_HEAVYSNIPER",
            "WEAPON_MARKSMANRIFLE",
            "WEAPON_GRENADELAUNCHER",
            "WEAPON_GRENADELAUNCHER_SMOKE",
            "WEAPON_RPG",
            "WEAPON_MINIGUN",
            "WEAPON_GRENADE",
            "WEAPON_STICKYBOMB",
            "WEAPON_SMOKEGRENADE",
            "WEAPON_BZGAS",
            "WEAPON_MOLOTOV",
            "WEAPON_FIREEXTINGUISHER",
            "WEAPON_PETROLCAN",
            "WEAPON_FLARE",
            "WEAPON_MACHETE",
            "WEAPON_HATCHET",
            "WEAPON_SWITCHBLADE",
            "WEAPON_BATTLEAXE",
            "WEAPON_POOLCUE",
            "WEAPON_WRENCH"
        }
    },
    notification = {
        friendly = {
            title = "AIRPORT SECURITY",
            subject = "Los Santos International",
            msg = "Welcome to LSIA. Security personnel are present. Keep weapons holstered.",
            icon = "CHAR_FLY",
            iconType = 1,
            flash = false
        },
        weaponWarning = {
            title = "WARNING",
            subject = "Airport Security",
            msg = "Weapons are prohibited! Holster your weapon immediately or security will engage!",
            icon = "CHAR_BLOCKED",
            iconType = 1,
            flash = true
        }
    }
}

-- Metro Station Security Settings
Config.Metro = {
    enabled = true,
    zoneName = "Los Santos Metro System",
    stations = {
        {
            name = "Pillbox Hill Station",
            coords = vector3(50.0, -850.0, 28.0),
            radius = 80.0,
            underground = true
        },
        {
            name = "Davis Ave Station",
            coords = vector3(140.0, -1600.0, 29.0),
            radius = 80.0,
            underground = false
        },
        {
            name = "Little Seoul Station",
            coords = vector3(-500.0, -700.0, 25.0),
            radius = 80.0,
            underground = true
        },
        {
            name = "Del Perro Station",
            coords = vector3(-1300.0, -500.0, 28.0),
            radius = 80.0,
            underground = false
        },
        {
            name = "Downtown Station",
            coords = vector3(-150.0, -600.0, 28.0),
            radius = 80.0,
            underground = true
        },
        {
            name = "Vinewood Station",
            coords = vector3(350.0, 50.0, 95.0),
            radius = 80.0,
            underground = false
        }
    },
    npcs = {
        security = {
            models = {
                "s_m_m_security_01",
                "s_m_y_cop_01",
                "s_m_m_highsec_02",
                "s_m_y_blackops_01"
            },
            weapons = {
                "WEAPON_COMBATPISTOL",
                "WEAPON_STUNGUN",
                "WEAPON_NIGHTSTICK"
            },
            accuracy = 50,
            guardsPerStation = 4,
            maxGuards = 20,
            friendly = true,
            reactToWeapon = true,
            spawnDistance = 80.0,
            patrolBehavior = "stationary",
            patrolRadius = 30.0
        },
        vehicles = {}
    },
    weaponDetection = {
        enabled = true,
        checkInterval = 2000,
        alertRadius = 40.0,
        aggressiveWeapons = {
            "WEAPON_RPG",
            "WEAPON_GRENADE",
            "WEAPON_MINIGUN",
            "WEAPON_RAILGUN",
            "WEAPON_STICKYBOMB",
            "WEAPON_COMPACTLAUNCHER",
            "WEAPON_HOMINGLAUNCHER",
            "WEAPON_PROXMINE"
        },
        restrictedWeapons = {
            "WEAPON_KNIFE",
            "WEAPON_BAT",
            "WEAPON_PISTOL",
            "WEAPON_COMBATPISTOL",
            "WEAPON_APPISTOL",
            "WEAPON_PISTOL50",
            "WEAPON_SMG",
            "WEAPON_ASSAULTSMG",
            "WEAPON_MICROSMG",
            "WEAPON_ASSAULTRIFLE",
            "WEAPON_CARBINERIFLE",
            "WEAPON_ADVANCEDRIFLE",
            "WEAPON_SPECIALCARBINE",
            "WEAPON_BULLPUPRIFLE",
            "WEAPON_PUMPSHOTGUN",
            "WEAPON_SAWNOFFSHOTGUN",
            "WEAPON_ASSAULTSHOTGUN",
            "WEAPON_HEAVYSHOTGUN",
            "WEAPON_STUNGUN",
            "WEAPON_SNIPERRIFLE",
            "WEAPON_HEAVYSNIPER",
            "WEAPON_MARKSMANRIFLE",
            "WEAPON_GRENADELAUNCHER",
            "WEAPON_RPG",
            "WEAPON_MINIGUN",
            "WEAPON_GRENADE",
            "WEAPON_STICKYBOMB",
            "WEAPON_SMOKEGRENADE",
            "WEAPON_BZGAS",
            "WEAPON_MOLOTOV",
            "WEAPON_FIREEXTINGUISHER",
            "WEAPON_PETROLCAN",
            "WEAPON_MACHETE",
            "WEAPON_HATCHET",
            "WEAPON_SWITCHBLADE",
            "WEAPON_BATTLEAXE",
            "WEAPON_POOLCUE",
            "WEAPON_WRENCH"
        }
    },
    notification = {
        friendly = {
            title = "METRO SECURITY",
            subject = "Transit Authority",
            msg = "Welcome to LS Metro. Transit security is present. Keep weapons holstered.",
            icon = "CHAR_TRAIN",
            iconType = 1,
            flash = false
        },
        weaponWarning = {
            title = "WARNING",
            subject = "Metro Security",
            msg = "Weapons are prohibited in metro stations! Holster your weapon immediately!",
            icon = "CHAR_BLOCKED",
            iconType = 1,
            flash = true
        }
    }
}

-- Traffic Police Settings
Config.TrafficPolice = {
    enabled = true,
    zones = {
        {
            name = "Downtown Los Santos",
            coords = vector3(200.0, -900.0, 30.0),
            radius = 1500.0
        },
        {
            name = "Vinewood Hills",
            coords = vector3(600.0, 200.0, 90.0),
            radius = 800.0
        },
        {
            name = "Del Perro",
            coords = vector3(-1500.0, -300.0, 40.0),
            radius = 600.0
        }
    },
    fines = {
        enabled = true,
        bankDeduction = true,
        notifyPlayer = true,
        minorSpeeding = {
            min = 500,
            max = 1000,
            label = "Minor Speeding"
        },
        majorSpeeding = {
            min = 1500,
            max = 3000,
            label = "Excessive Speeding"
        },
        recklessDriving = {
            min = 2000,
            max = 5000,
            label = "Reckless Driving"
        },
        hitAndRun = {
            min = 5000,
            max = 10000,
            label = "Hit and Run"
        },
        runningRedLight = {
            min = 750,
            max = 1500,
            label = "Running Red Light"
        }
    },
    violations = {
        speedLimit = 120.0,
        minorSpeedingThreshold = 10.0,
        majorSpeedingThreshold = 40.0,
        checkRedLights = true,
        checkAggressive = true,
        checkHitAndRun = true,
        speedCheckInterval = 5000
    },
    npcs = {
        officers = {
            models = {
                "s_m_y_cop_01",
                "s_f_y_cop_01"
            },
            weapons = {
                "WEAPON_COMBATPISTOL",
                "WEAPON_STUNGUN"
            },
            accuracy = 45,
            count = 4
        },
        vehicles = {
            {model = "police", count = 2},
            {model = "police2", count = 1},
            {model = "police3", count = 1}
        }
    },
    notification = {
        title = "TRAFFIC ENFORCEMENT",
        subject = "Police Patrol Zone",
        msg = "You are in a police-patrolled area. Obey traffic laws to avoid fines!",
        icon = "CHAR_LSPD",
        iconType = 1,
        flash = false
    }
}

-- General Settings
Config.General = {
    updateInterval = 2000,      -- Main check interval (ms)
    debug = false,              -- Enable debug display
    performanceMode = true      -- Optimize for performance
}
