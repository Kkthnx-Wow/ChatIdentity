local _, namespace = ...

-- Define and register settings
namespace:RegisterSettings("ChatIdentityDB", {
	{
		key = "enableClassIcon",
		type = "toggle",
		title = "Enable Class Icons",
		tooltip = "Toggle whether to display class icons in chat messages.",
		default = true,
	},
	{
		key = "enableRaceIcon",
		type = "toggle",
		title = "Enable Race Icons",
		tooltip = "Toggle whether to display race icons in chat messages.",
		default = true,
	},
	{
		key = "showLevel",
		type = "toggle",
		title = "Show Player Level",
		tooltip = "Toggle whether to display player levels in chat messages.",
		default = true,
	},
	{
		key = "onlyShowLevelDifference",
		type = "toggle",
		title = "Show Level Difference Only",
		tooltip = "Only show level differences when the player level differs from yours.",
		default = false,
	},
	{
		key = "displayOrder",
		type = "menu",
		title = "Display Order",
		tooltip = "Choose the display order of Race, Class, and Level in chat messages.",
		default = "race,class,level",
		options = {
			{ value = "race,class,level", label = "Race, Class, Level" },
			{ value = "class,race,level", label = "Class, Race, Level" },
			{ value = "level,race,class", label = "Level, Race, Class" },
			{ value = "class,level,race", label = "Class, Level, Race" },
		},
	},
	{
		key = "iconSize",
		type = "slider",
		title = "Icon Size",
		tooltip = "Set the size of the icons displayed in chat messages.",
		default = 18,
		minValue = 10,
		maxValue = 32,
		valueStep = 1,
		valueFormat = "%.0f", -- Display integer values
	},
})

-- Hook slash command to open settings
namespace:RegisterSettingsSlash("/chatidentity", "/ci")
