/mob/living/bot/miningonestar
	name = "Similacrum Robotics Bot"
	desc = "It looks like a drillbot. An ancient drillbot"
	health = 20
	maxHealth = 20
	icon = 'icons/mob/build_a_drone.dmi'
	icon_state = "drone_os"
	faction = "similacrum"
	layer = MOB_LAYER
	var/obj/item/loot
	var/attacktext = "drilled" // For reference, these verbs should be worded in plusquamperfect as they will always be preceded by "has". E.g: "[attacker] has [attacktext] [target]" or "has blocked being [attack_verb] by [attacker]"
	var/environment_smash = 1

/mob/living/bot/miningonestar/UnarmedAttack(var/atom/A, var/proximity)
	if(istype(A, /turf/simulated/floor/asteroid))
		sleep(rand(10,20))
		A:gets_dug()

/mob/living/bot/miningonestar/Destroy()
	loot = null
	. = ..()

/mob/living/bot/miningonestar/death()
	loot.forceMove(loc)
	qdel(src)

/mob/living/bot/miningonestar/resources/Initialize()
	..()
	update_icons()

	botcard = new /obj/item/card/id(src)
	botcard.access = botcard_access.Copy()

	access_scanner = new /obj(src)
	access_scanner.req_access = req_access.Copy()
	access_scanner.req_one_access = req_one_access.Copy()
	var/atom/A = pick(/obj/item/stack/material/plasma/random, /obj/item/stack/material/iron/random, /obj/item/stack/material/gold/random, /obj/item/stack/material/diamond/random, /obj/item/stack/material/uranium/random)
	loot = new A

/mob/living/bot/miningonestar/resources/agressive/Life()
	..()
	if(health <= 0)
		death()
		return
	weakened = 0
	stunned = 0
	paralysis = 0
	for(var/mob/living/carbon/human/H in view(3, src))
		if(get_dist(src, H) >= 1)
			UnarmedAttack(H)
		else
			SSmove_manager.move_to(src,H,1,5)

/mob/living/bot/miningonestar/resources/agressive/with_support/Initialize()
	..()
	update_icons()

	botcard = new /obj/item/card/id(src)
	botcard.access = botcard_access.Copy()

	access_scanner = new /obj(src)
	access_scanner.req_access = req_access.Copy()
	access_scanner.req_one_access = req_one_access.Copy()

	var/atom/A = pick(/obj/item/stack/material/plasma/random, /obj/item/stack/material/iron/random, /obj/item/stack/material/gold/random, /obj/item/stack/material/diamond/random, /obj/item/stack/material/uranium/random)
	loot = new A
	var/counter = 0
	var/counterfinish = rand(1,2)

	while(counter < counterfinish)
		counter++
		new /mob/living/bot/miningonestar/resources/agressive ( locate( get_step(src, pick(NORTH, WEST, EAST, SOUTH) ) ))

/mob/living/bot/miningonestar/resources/in_work/Life()
	..()
	if(health < 1)
		death()
		return
	weakened = 0
	stunned = 0
	paralysis = 0
	for(var/turf/simulated/floor/asteroid/AST in view(3, src))
		if(get_dist(src, AST) >= 1)
			UnarmedAttack(AST)
		else
			SSmove_manager.move_to(src,AST, 1, 5)
