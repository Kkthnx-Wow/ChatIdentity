local _, namespace = ...

local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local tostring = tostring

local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumGuildMembers = GetNumGuildMembers
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace
local UnitSex = UnitSex

-- Static table to store member data (race, gender, class, and level)
local memberData = {}
local debugMode = false
local lastGuildRosterUpdate = 0

-- Access settings dynamically
local function GetOption(optionKey)
	return namespace:GetOption(optionKey)
end

-- Debugging function
local function DebugPrint(msg)
	if debugMode then
		namespace:Print(msg)
	end
end

-- Mapping for special race names
local raceAtlasMap = { -- I think this is still broken? Bleh :|
	["highmountaintauren"] = "highmountain",
	["lightforgeddraenei"] = "lightforged",
	["scourge"] = "undead",
	["zandalaritroll"] = "zandalari",
	["earthendwarf"] = "earthen",
}

-- Function to dynamically generate race icons using Atlas
local function GetRaceIcon(race, gender)
	if not GetOption("enableRaceIcon") then
		return nil
	end
	if not race or not gender then
		DebugPrint("Missing race or gender for atlas icon generation")
		return nil
	end

	-- Debugging raw race input
	DebugPrint("Raw race input: " .. race)

	-- Apply mapping and sanitize
	local sanitizedRace = raceAtlasMap[string_lower(race)] or string_gsub(string_lower(race), "%s+", "")
	DebugPrint("Sanitized race: " .. sanitizedRace)

	local genderString = (gender == 2) and "male" or (gender == 3) and "female"
	local atlasName = "raceicon-" .. sanitizedRace .. "-" .. genderString

	local iconSize = GetOption("iconSize") or 18

	if not C_Texture.GetAtlasInfo(atlasName) then
		DebugPrint("Atlas not found for: " .. atlasName .. ", using fallback.")
		return "|TInterface\\Icons\\INV_Misc_QuestionMark:" .. iconSize .. "|t"
	end

	DebugPrint("Atlas found: " .. atlasName)
	return CreateAtlasMarkup(atlasName, iconSize, iconSize)
end

-- Function to dynamically generate class icons
local function GetClassIcon(class)
	if not GetOption("enableClassIcon") then
		return nil
	end
	local sanitizedClass = string_gsub(string_lower(class), "%s+", "")
	local iconSize = GetOption("iconSize") or 18
	return "|TInterface\\Icons\\ClassIcon_" .. sanitizedClass .. ":" .. iconSize .. "|t"
end

-- Generate difficulty color for levels
local function GetLevelColor(level)
	local color = GetQuestDifficultyColor(level)
	return string_format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Generate level string with difficulty color
local function GetLevelString(playerLevel, targetLevel)
	if not GetOption("showLevel") then
		return nil
	end
	if GetOption("onlyShowLevelDifference") and playerLevel == targetLevel then
		return nil
	end
	return GetLevelColor(targetLevel) .. "[" .. targetLevel .. "]|r"
end

-- Utility function to split strings
local function SplitString(input, delimiter)
	local result = {}
	for match in (input .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end

-- Initialize player's own data on login
local function InitializePlayerData()
	local playerRace = UnitRace("player")
	local playerClass = UnitClass("player")
	local playerLevel = UnitLevel("player")
	local playerSex = UnitSex("player")
	local playerName = UnitName("player")

	if playerRace and playerSex and playerClass and playerLevel and playerName then
		memberData[playerName] = { race = playerRace, class = playerClass, level = playerLevel, sex = playerSex }
		DebugPrint("Player data initialized: " .. playerName .. " - " .. playerRace .. " - " .. playerClass .. " - Level " .. playerLevel)
	end
end

-- Detect race, gender, class, and level from visible units
local function DetectPlayerData(sender)
	namespace:Defer(function()
		DebugPrint("Attempting to detect player data for: " .. tostring(sender))
		if not sender or memberData[sender] then
			DebugPrint("Skipping detection: No sender or data already exists for " .. tostring(sender))
			return
		end

		local unitIds = { "player", "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }
		for _, unitId in ipairs(unitIds) do
			if UnitExists(unitId) and UnitName(unitId) == sender then
				local race = UnitRace(unitId)
				local class = UnitClass(unitId)
				local level = UnitLevel(unitId)
				local sex = UnitSex(unitId)

				if race and sex and class and level then
					memberData[sender] = { race = race, class = class, level = level, sex = sex }
					DebugPrint("Detected player data: " .. sender .. " - Race: " .. race .. ", Class: " .. class .. ", Level: " .. level .. ", Gender: " .. (sex == 2 and "Male" or "Female"))
					return
				else
					DebugPrint("Incomplete player data for " .. sender .. ": Race=" .. tostring(race) .. ", Class=" .. tostring(class) .. ", Level=" .. tostring(level) .. ", Gender=" .. tostring(sex))
				end
			end
		end
		DebugPrint("No unit data found for: " .. sender)
	end)
end

-- Add race icon, class icon, and level to chat messages
local function AddRaceIconToChat(_, _, message, sender, ...)
	DebugPrint("Processing chat message from: " .. tostring(sender))
	local playerName = Ambiguate(sender, "short")
	local playerData = memberData[playerName]

	if playerData then
		DebugPrint("Player data found for: " .. playerName .. " - Race: " .. playerData.race .. ", Gender: " .. playerData.sex)
		local raceIcon = GetRaceIcon(playerData.race, playerData.sex)
		local classIcon = GetClassIcon(playerData.class)
		local levelString = GetLevelString(UnitLevel("player"), playerData.level)

		if not raceIcon then
			DebugPrint("No race icon generated for: " .. playerName)
		end
		if not classIcon then
			DebugPrint("No class icon generated for: " .. playerName)
		end

		local prefix = ""
		local order = SplitString(GetOption("displayOrder"), ",")
		for _, element in ipairs(order) do
			if element == "race" and raceIcon then
				prefix = prefix .. raceIcon .. " "
			elseif element == "class" and classIcon then
				prefix = prefix .. classIcon .. " "
			elseif element == "level" and levelString then
				prefix = prefix .. levelString .. " "
			end
		end

		local modifiedMessage = prefix .. message
		DebugPrint("Modified message: " .. modifiedMessage)
		return false, modifiedMessage, sender, ...
	else
		DebugPrint("No data found for sender: " .. sender)
	end

	return false, message, sender, ...
end

namespace:RegisterEvent("PLAYER_LOGIN", function()
	InitializePlayerData()
	namespace:Print("ChatIdentity loaded and ready!")
end)

namespace:RegisterEvent("CHAT_MSG_GUILD", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY_LEADER", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("GUILD_ROSTER_UPDATE", function()
	namespace:Defer(function()
		-- Exit early if the player is not in a guild
		if not IsInGuild() then
			DebugPrint("Player is not in a guild. Exiting GUILD_ROSTER_UPDATE handler.")
			return
		end

		local now = GetTime()
		if now - lastGuildRosterUpdate >= 10 then
			C_GuildInfo.GuildRoster()
			lastGuildRosterUpdate = now

			-- Get the total and online guild members
			local numTotalGuildMembers, numOnlineGuildMembers = GetNumGuildMembers()
			DebugPrint(string_format("Guild Roster: Total Members = %d, Online Members = %d", numTotalGuildMembers, numOnlineGuildMembers))

			-- Exit early if the player is the only guild member online
			if numOnlineGuildMembers == 1 then
				local firstOnlineMemberName = Ambiguate(GetGuildRosterInfo(1), "short") -- Assuming the first member is the player
				if firstOnlineMemberName == UnitName("player") then
					DebugPrint("Player is the only guild member online. Exiting GUILD_ROSTER_UPDATE handler.")
					return
				end
			end

			-- Process guild members
			for i = 1, numTotalGuildMembers do
				local fullName, _, _, level, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
				local playerName = Ambiguate(fullName, "short") -- Strip realm name

				if guid then
					local localizedClass, _, localizedRace, _, sex = GetPlayerInfoByGUID(guid)
					if localizedRace and sex then
						memberData[playerName] = {
							race = localizedRace, -- Localized race name
							class = localizedClass, -- Localized class name
							level = level,
							sex = sex,
						}
						DebugPrint(string_format("Guild member: %s - Race: %s - Class: %s - Level: %s - Gender: %s", playerName, localizedRace, localizedClass, level, (sex == 2 and "Male" or "Female")))
					else
						DebugPrint("Failed to retrieve race or gender for GUID: " .. guid)
					end
				else
					DebugPrint("Missing GUID for guild member: " .. tostring(playerName))
				end
			end
		end
	end)
end)

namespace:RegisterEvent("UNIT_LEVEL", function(_, unit)
	if not unit or not UnitExists(unit) then
		DebugPrint("UNIT_LEVEL event fired, but unit does not exist.")
		return
	end

	namespace:Defer(function()
		-- Only process if the unit is part of the player's party
		if UnitInParty(unit) then
			local name = UnitName(unit)
			local level = UnitLevel(unit)

			if name and level then
				DebugPrint("UNIT_LEVEL fired for party member: " .. name .. ", Level: " .. level)
				-- Update level in memberData if it has changed
				if memberData[name] and memberData[name].level ~= level then
					memberData[name].level = level
					DebugPrint("Updated level for " .. name .. ": " .. level)
				else
					DebugPrint("No changes required for " .. name)
				end
			else
				DebugPrint("UNIT_LEVEL fired but no valid name or level for unit.")
			end
		else
			DebugPrint("UNIT_LEVEL ignored for unit not in party: " .. tostring(UnitName(unit)))
		end
	end)
end)

namespace:RegisterEvent("PLAYER_LEVEL_UP", function(_, level, healthDelta, powerDelta)
	DebugPrint(string_format("PLAYER_LEVEL_UP fired! New Level: %d, Health Gained: %d, Power Gained: %d", level, healthDelta, powerDelta))

	-- Update the player's level in memberData
	local playerName = UnitName("player")
	if memberData[playerName] then
		memberData[playerName].level = level
		DebugPrint("Updated player's level: " .. playerName .. " to Level: " .. level)
	else
		DebugPrint("Player data not found in memberData; initializing.")
		memberData[playerName] = {
			race = UnitRace("player"),
			class = UnitClass("player"),
			level = level,
			sex = UnitSex("player"),
		}
	end

	-- Optional: Perform additional updates or display messages
	namespace:Print("Congratulations on reaching level " .. level .. "!")
end)

-- Handle PLAYER_LEVEL_CHANGED
namespace:RegisterEvent("PLAYER_LEVEL_CHANGED", function(_, oldLevel, newLevel, real)
	local playerName = UnitName("player")
	if playerName and memberData[playerName] then
		-- Update player's level in memberData
		memberData[playerName].level = newLevel

		-- Debugging output
		DebugPrint(string_format("Player level changed: %s - Old Level: %d, New Level: %d, Real: %s", playerName, oldLevel, newLevel, tostring(real)))
	else
		DebugPrint("PLAYER_LEVEL_CHANGED fired, but player data is not found.")
	end
end)

namespace:RegisterEvent("GROUP_ROSTER_UPDATE", function()
	namespace:Defer(function()
		-- Exit early if the player is not in a group or is in a raid
		if not IsInGroup() or IsInRaid() then
			DebugPrint("Player is either not in a group or is in a raid. Exiting GROUP_ROSTER_UPDATE handler.")
			return
		end

		DebugPrint("Group roster updated")
		local numGroupMembers = GetNumGroupMembers()
		for i = 1, numGroupMembers do
			local unit = "party" .. i
			if UnitExists(unit) then
				local name = UnitName(unit)
				local race = UnitRace(unit)
				local class = UnitClass(unit)
				local level = UnitLevel(unit)
				local sex = UnitSex(unit)

				if name and race and class and level and sex then
					memberData[name] = { race = race, class = class, level = level, sex = sex }
					DebugPrint("Updated data for group member: " .. name)
				end
			end
		end
	end)
end)

ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", AddRaceIconToChat)
