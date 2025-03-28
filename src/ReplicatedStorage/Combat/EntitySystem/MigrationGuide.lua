--[[
    Entity System Migration Guide
    
    This document outlines the steps to migrate from the current Player/NPC split
    condition system to the unified entity-based approach.
    
    OVERVIEW:
    
    The refactoring introduces an entity abstraction layer that wraps both Players
    and NPCs with a consistent API. The ConditionManager has been modified to use
    this abstraction, providing unified condition management for all entity types.
    
    MIGRATION STEPS:
    
    1. ENTITY SYSTEM SETUP
       - Four new files have been created in ReplicatedStorage/Combat/EntitySystem:
         * Entity.lua - Base abstraction and factory function
         * PlayerEntity.lua - Player wrapper implementation
         * NPCEntity.lua - NPC wrapper implementation
         * EntityRegistry.lua - Caching system for entity instances
         * EntityStateLock.lua - Thread safety mechanism
    
    2. CONDITION MANAGER CHANGES
       - Combat_ConditionManager_Modified.lua - Main manager with entity support
       - Combat_ConditionManager_Application_Modified.lua - Application logic
       - Combat_ConditionManager_TimerHandlers_Modified.lua - Timer management
    
    3. IMPLEMENTATION STRATEGY
       
       PHASE 1: PREPARATION
       - Review the new entity abstraction files and understand the approach
       - Test the modified files in a development environment first
       
       PHASE 2: CORE UPDATE
       - Back up existing ConditionManager files
       - Rename modified files to their original names
       - Update imports in affected modules
       
       PHASE 3: COMPATIBILITY
       - Add the global NPC adapter reference in NPC_ServerSetup.server.lua:
         _G.NPC_COMBAT_ADAPTER = npcAdapter
       - Add the global UI adapter reference in NPC_ServerSetup.server.lua:
         _G.NPC_ENTITY_UI_ADAPTER = NPC_EntityUIAdapter
       
       PHASE 4: TESTING
       - Test basic condition application on Players
       - Test basic condition application on NPCs
       - Test condition stacking behavior
       - Test condition expiration
       - Test damage over time effects
    
    ENTITY API OVERVIEW:
    
    Entity.from(target) - Creates appropriate entity wrapper
    entity:getId() - Get unique identifier
    entity:getType() - Get entity type (PLAYER or NPC)
    entity:getModel() - Get underlying instance
    entity:notifyConditionApplied() - Handle condition visualization
    
    COMPATIBILITY NOTES:
    
    - The refactored ConditionManager maintains backward compatibility
      with existing code that expects player-specific methods
    - Legacy methods like GetPlayerConditions() now delegate to entity versions
    - The NPC_ConditionManager extension is no longer required but kept for compatibility
    - NPC conditions are now stored centrally in ConditionManager instead of each NPC_Entity
    
    TROUBLESHOOTING:
    
    - If NPCs aren't showing conditions properly, check that _G.NPC_ENTITY_UI_ADAPTER is set
    - If condition application fails, verify entity wrappers are created correctly
    - For thread safety issues, check EntityStateLock implementation
    
    FUTURE IMPROVEMENTS:
    
    - Fully migrate NPC_Entity condition tracking to the central system
    - Update all condition consumers to use the entity abstraction directly
    - Remove the compatibility layer once all systems are migrated
]]