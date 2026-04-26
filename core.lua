local addonName, ns = ...
if not iAutoPassBonusRollDB then
	iAutoPassBonusRollDB = {
		difs = {},
		encounters = {},
		instances = {},
	}
end
local db = iAutoPassBonusRollDB

local addon = CreateFrame('Frame')
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function ns.ShouldAutoPassEncounter(spellID)
	local _, encounterId = GetJournalInfoForSpellConfirmation(spellID)
	return encounterId and db.encounters[tostring(encounterId)]
end

function ns.ShouldAutoPassDifficulty(difId)
	return difId and db.difs[tostring(difId)]
end

function ns.ShouldAutoPassInstance(instanceId)
	return instanceId and db.instances[tostring(instanceId)]
end

function ns.PassBonusRoll(spellId, reason)
	print(string.format('|cffffff00Reason for passing bonus roll: "%s".|r', reason))
	DeclineSpellConfirmationPrompt(spellId)
end
addon:RegisterEvent("SPELL_CONFIRMATION_PROMPT")
function addon:SPELL_CONFIRMATION_PROMPT(spellID, effectValue, message, duration, currencyTypesID, currencyCost, currentDifficulty, displayItemID, itemContext, treasureContextLevel)
	if currencyTypesID ~= 3418 then return end -- Nebulous Voidcore
	-- difficulty from the event doesnt match what we actually want, so check difficultyId from GetInstanceInfo instead
	local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
	if ns.ShouldAutoPassDifficulty(difficultyID) then
		ns.PassBonusRoll(spellID, "DifficultyId")
		return
	end
	if ns.ShouldAutoPassInstance(instanceID) then
		ns.PassBonusRoll(spellID, "InstanceId")
		return
	end
	if ns.ShouldAutoPassEncounter(spellID) then
		ns.PassBonusRoll(spellID, "EncounterId")
		return
	end
	--DevTools_Dump({spellID, effectValue, message, duration, currencyTypesID, currencyCost, currentDifficulty, displayItemID, itemContext, treasureContextLevel})
	--DevTools_Dump({GetJournalInfoForSpellConfirmation(spellID)})
end

do -- Options
	local config, configLayout = Settings.RegisterVerticalLayoutCategory(addonName)
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(	"All of these settings are character specific.\nIf any of these match, bonus roll will automatically be passed."))
	Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, "0", "0", db.difs, "boolean", BUG_CATEGORY2)) -- Outdoor Zones
	for _, id in ipairs({
		208, -- Delves
		24, -- Dungeon Timewalking
		1, -- Normal dungeon
		2, -- Heroic dungeon
		23, -- Mythic 0
		8, -- Mythic+
		33, -- Raid Timewalking
		17, -- LFR
		14, -- Raid Normal
		15, -- Raid Heroic
		16, -- Raid Mythic
		}) do
		local difName, difType = GetDifficultyInfo(id)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(id), tostring(id), db.difs, "boolean", string.format("%s (%s)", difName, difType)))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(GUILD_NEWS_FILTER3)) -- Raid encounters
	--Settings.CreateSectionHeader(config, GUILD_NEWS_FILTER3) -- Raid encounters
	for _, d in ipairs({
		-- Voidspire
		{ejId = 2733, eId = 3176, jiId = 1307}, -- Imperator Averzian
		{ejId = 2734, eId = 3177, jiId = 1307}, -- Vorasius
		{ejId = 2736, eId = 3179, jiId = 1307}, -- Salhadaar
		{ejId = 2735, eId = 3178, jiId = 1307}, -- Vaelgor & Ezzorak
		{ejId = 2737, eId = 3180, jiId = 1307}, -- Lightblinded Vanguard
		{ejId = 2738, eId = 3181, jiId = 1307}, -- Crown of the Cosmos
		-- Dreamrift
		{ejId = 2795, eId = 3306, jiId = 1314}, -- Chimearus
		-- March
		{ejId = 2739, eId = 3182, jiId = 1308}, -- Belo'ren
		{ejId = 2740, eId = 3183, jiId = 1308}, -- Midnight falls

	}) do
		local encounterName = EJ_GetEncounterInfo(d.ejId)
		if not encounterName then
			EJ_SelectInstance(d.jiId)
			encounterName = EJ_GetEncounterInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.eId)
		end
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.eId), tostring(d.eId), db.encounters, "boolean", encounterName))
	end
	configLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer(DUNGEONS)) -- M+ dungeons
	--Settings.CreateSectionHeader(config, DUNGEONS) -- M+ dungeons
	for _, d in ipairs({
		{ejId = 1201, instanceId = 2526}, -- Algeth'ar Academy
		{ejId = 1300, instanceId = 2811}, -- Magisters' Terrace
		{ejId = 1315, instanceId = 2874}, -- Maisara Caverns
		{ejId = 1316, instanceId = 2915}, -- Nexus-Point Xenas
		{ejId = 278, instanceId = 658}, -- Pit of Saron
		{ejId = 945, instanceId = 1753}, -- Seat of the Triumvirate
		{ejId = 476, instanceId = 1209}, -- Skyreach
		{ejId = 1299, instanceId = 2805}, -- Windrunner Spire
	}) do
		local instanceName = EJ_GetInstanceInfo(d.ejId) or string.format("%s (%s)", UNKNOWN, d.instanceId)
		Settings.CreateCheckbox(config, Settings.RegisterAddOnSetting(config, tostring(d.instanceId), tostring(d.instanceId), db.instances, "boolean", instanceName))
	end
	Settings.RegisterAddOnCategory(config)
end