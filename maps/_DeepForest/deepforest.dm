#include "map/frozen_forest.dmm"
#include "map/frozen_crashsite.dmm"

//#include "map/_Deep_Forest.dmm"
//#include "map/_Beast_Cave.dmm"
//#include "map/_Similacrum_Field_Office.dmm"
//#include "map/_Prepper_Bunker.dmm"
//#include "map/_River_Forest.dmm"
//#include "map/_River_To_Colony.dmm"

/obj/map_data/frozen_forest
	name = "Frozen Forest"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 1
	digsites = "TEMPLE"

/obj/map_data/frozen_crashsight
	name = "Frozen Crashsight"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 2
	digsites = "TEMPLE"
	generate_asteroid = TRUE

/obj/map_data/nadezda_f
	name = "Deep Forest"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 2
	digsites = "TECHNICAL"

/obj/map_data/beast_cave
	name = "Beast Cave"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 1
	digsites = "TEMPLE"

/obj/map_data/similacrum_field_offices
	name = "Similacrum Field Offices"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 2

/obj/map_data/the_vault //No longer currently used
	name = "Bunker Vault"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 1

/obj/map_data/river_forest
	name = "River Forest"
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 2
	digsites = "Fossil"

/obj/map_data/river_to_colony
	name = "Scrap Haven"
	is_station_level = FALSE
	is_player_level = TRUE
	is_contact_level = FALSE
	is_accessable_level = FALSE
	is_sealed = TRUE
	height = 3
	generate_asteroid = TRUE
	digsites = "WAR"
