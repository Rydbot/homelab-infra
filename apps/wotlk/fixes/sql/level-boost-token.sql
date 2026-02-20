-- This item will drop from bosses in Classic, TBC and WotLK raids, and can be used to boost a character to level 60.

USE acore_world;

-- Configure the boost token item ID.
SET @BOOST_TOKEN_ITEM_ID :=90004;

-- UPDATE: Switched from dungeon exclusion lists to an explicit raid whitelist.
-- These IDs are instance_encounters.lastEncounterDungeon values verified in your live DB.
SET @RAID_WHITELIST_DUNGEON_IDS := '42,46,48,50,159,160,161,175,176,177,193,194,195,196,197,198,199,201,223,224,227,237,238,239,240,241,243,244,246,247,248,250,257,279,280,293,294';

-- Add the item into the Database, and update it if it already exists.
INSERT IGNORE INTO item_template 
  (entry, class, subclass, name, displayid, Quality, bonding, stackable, maxcount, BuyPrice, SellPrice, description)
   
VALUES
  -- UPDATE: Removed trailing comma to keep INSERT syntax valid.
  -- UPDATE: Set bonding = 0 so the item is not soulbound and is tradeable.
  (@BOOST_TOKEN_ITEM_ID, 10, 0, 'Sands of Infinite Wisdom', 29735, 5, 0, 1000, 2, 0, 0, 'The power emanating from the sands is almost overwhelming.');


UPDATE item_template
  -- UPDATE: Enforce bonding = 0 so reruns do not rebind the item.
  SET bonding = 0, SellPrice = 0, BuyPrice = 0, stackable = 1000
  WHERE entry = @BOOST_TOKEN_ITEM_ID;


-- Getting the item to drop from raid bosses in Classic, TBC and WotLK raids.

INSERT INTO creature_loot_template 
  (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    
SELECT DISTINCT 
  ie.creditEntry AS boss_entry,
  @BOOST_TOKEN_ITEM_ID,
  0,
  0.01,
  0,
  1,
  0,
  1,
  1,
  'Sands of Infinite Wisdom'
-- Please check this entire section to make sure that it is dropping correctly and excluded from dungeons
-- UPDATE: Fixed table name from instance_id -> instance_encounters.
FROM instance_encounters ie
JOIN creature_template ct ON ct.entry = ie.creditEntry
WHERE ie.lastEncounterDungeon != 0
  AND ie.creditType = 0
  -- UPDATE: Keep only raid end encounters by explicit whitelist.
  AND FIND_IN_SET(CAST(ie.lastEncounterDungeon AS CHAR), @RAID_WHITELIST_DUNGEON_IDS) > 0
ON DUPLICATE KEY UPDATE
  -- UPDATE: Moved ON DUPLICATE KEY UPDATE into same statement (removed premature semicolon above).
  Chance = VALUES(Chance),
  QuestRequired = VALUES(QuestRequired),
  LootMode = VALUES(LootMode),
  GroupId = VALUES(GroupId),
  MinCount = VALUES(MinCount),
  MaxCount = VALUES(MaxCount),
  Comment = VALUES(Comment);
  
-- Sanity check: ensure the item exists.
SELECT 'boost_token_item' AS k, COUNT(*) AS v 
FROM item_template 
-- UPDATE: Added missing statement terminator.
WHERE entry = @BOOST_TOKEN_ITEM_ID;
