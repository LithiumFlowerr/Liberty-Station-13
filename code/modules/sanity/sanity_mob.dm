GLOBAL_VAR_INIT(GLOBAL_SANITY_MOD, 1)

GLOBAL_VAR_INIT(GLOBAL_INSIGHT_MOD, 1)

#define SANITY_PASSIVE_GAIN 0.2

#define SANITY_DAMAGE_MOD (0.6 * GLOB.GLOBAL_SANITY_MOD)

#define SANITY_VIEW_DAMAGE_MOD (0.4 * GLOB.GLOBAL_SANITY_MOD)

// Damage received from unpleasant stuff in view
#define SANITY_DAMAGE_VIEW(damage, wil, dist) ((damage) * SANITY_VIEW_DAMAGE_MOD * (1.2 - (wil) / STAT_LEVEL_MAX) * (1 - (dist)/15))

// Damage received from body damage
#define SANITY_DAMAGE_HURT(damage, wil) (min((damage) / 5 * SANITY_DAMAGE_MOD * (1.2 - (wil) / STAT_LEVEL_MAX), 60))

// Damage received from shock
#define SANITY_DAMAGE_SHOCK(shock, wil) ((shock) / 50 * SANITY_DAMAGE_MOD * (1.2 - (wil) / STAT_LEVEL_MAX))

// Damage received from psy effects
#define SANITY_DAMAGE_PSY(damage, wil) (damage * SANITY_DAMAGE_MOD * (2 - (wil) / STAT_LEVEL_MAX))

// Damage received from seeing someone die
#define SANITY_DAMAGE_DEATH(wil) (10 * SANITY_DAMAGE_MOD * (1 - (wil) / STAT_LEVEL_MAX))

#define SANITY_GAIN_SMOKE 0.05 // A full cig restores 300 times that
#define SANITY_GAIN_SAY 1

#define SANITY_COOLDOWN_SAY rand(30 SECONDS, 45 SECONDS)
#define SANITY_COOLDOWN_BREAKDOWN rand(7 MINUTES, 10 MINUTES)

#define SANITY_CHANGE_FADEOFF(level_change) (level_change * 0.75)

#define INSIGHT_PASSIVE_GAIN 0.05
#define INSIGHT_GAIN(level_change) (INSIGHT_PASSIVE_GAIN + level_change / 15)

#define INSIGHT_DESIRE_COUNT 2

#define INSIGHT_DESIRE_FOOD "food"
#define INSIGHT_DESIRE_ALCOHOL "alcohol"
#define INSIGHT_DESIRE_SMOKING "smoking"
#define INSIGHT_DESIRE_DRUGS "drugs"
#define INSIGHT_DESIRE_DRINK_NONALCOHOL "nonalcoholic"


#define EAT_COOLDOWN_MESSAGE 15 SECONDS
#define SANITY_MOB_DISTANCE_ACTIVATION 12

/datum/sanity
	var/flags
	var/mob/living/carbon/human/owner

	var/sanity_passive_gain_multiplier = 1
	var/sanity_invulnerability = 0
	var/level
	var/max_level = 200 //Soj change to give a bit more breathing room / from 150 to 200 let's see where this goes
	var/level_change = 0

	var/insight
	var/max_insight = INFINITY
	var/insight_passive_gain_multiplier = 0.5
	var/insight_gain_multiplier = 1
	var/insight_rest_gain_multiplier = 1
	var/insight_rest = 0
	var/max_insight_rest = 1
	var/resting = 0
	var/max_resting = INFINITY

	var/rest_timer_active = FALSE
	var/rest_timer_time

	var/list/valid_inspirations = list(/obj/item/oddity)
	var/list/desires = list()
	var/positive_prob = 20
	var/positive_prob_multiplier = 1
	var/negative_prob = 30

	var/view_damage_threshold = 20
	var/environment_cap_coeff = 1 //How much we are affected by environmental cognitohazards. Multiplies the above threshold

	var/say_time = 0
	var/breakdown_time = 0
	var/spook_time = 0

	var/death_view_multiplier = 1

	var/list/datum/breakdown/breakdowns = list()

	var/eat_time_message = 0
	var/smoking_message = 51 //Used as a cooldown, agv smoke has around 250~ puffs

	var/life_tick_modifier = 2	//How often is the onLife() triggered and by how much are the effects multiplied

/datum/sanity/New(mob/living/carbon/human/H)
	owner = H
	level = max_level
	insight = rand(0, 30)
	RegisterSignal(owner, COMSIG_MOB_LIFE, .proc/onLife)
	RegisterSignal(owner, COMSIG_HUMAN_SAY, .proc/onSay)

/datum/sanity/Destroy()
	UnregisterSignal(owner, COMSIG_MOB_LIFE)
	UnregisterSignal(owner, COMSIG_HUMAN_SAY)
	owner = null
	QDEL_LIST(breakdowns)
	return ..()

/datum/sanity/proc/give_insight(value)
	var/new_value = value
	if(value > 0)
		new_value = max(0, value * insight_gain_multiplier * GLOB.GLOBAL_INSIGHT_MOD)
	insight = min(insight + new_value, max_insight)

/datum/sanity/proc/give_resting(value)
	resting = min(resting + value, max_resting)

/datum/sanity/proc/give_insight_rest(value)
	var/new_value = value
	if(value > 0)
		new_value = max(0, value * insight_rest_gain_multiplier * GLOB.GLOBAL_INSIGHT_MOD)
	insight_rest += new_value

/datum/sanity/Topic(href, href_list)
	if(href_list["here_and_now"])
		if(rest_timer_active) //prevent any possible exploits
			rest_timer_active = FALSE
			level_up()

/datum/sanity/proc/onLife()
	handle_breakdowns()
	if(owner.stat == DEAD || owner.life_tick % life_tick_modifier || owner.in_stasis || (owner.species.lower_sanity_process && !owner.client))
		return
//	if(owner.species.reagent_tag == IS_SYNTHETIC) //erm no? We can still have synths use sanity, ERIS...
//		return
	var/affect = SANITY_PASSIVE_GAIN * sanity_passive_gain_multiplier
	if(owner.stat) //If we're unconscious
		changeLevel(affect)
		return
	if(!(owner.sdisabilities & BLIND) && !owner.blinded)
		affect += handle_area()
		affect -= handle_view()
	changeLevel(max(affect  * life_tick_modifier, min((view_damage_threshold*environment_cap_coeff) - level, 0)))
	handle_Insight()
	handle_level()
	if(rest_timer_active)
		if(rest_timer_time > 0)
			rest_timer_time -= 2 SECONDS //since OnLife() procs every 2 seconds
		else
			rest_timer_active = FALSE
			level_up()

	LEGACY_SEND_SIGNAL(owner, COMSIG_HUMAN_SANITY, level)

/datum/sanity/proc/handle_view()
	. = 0
	activate_mobs_in_range(owner, SANITY_MOB_DISTANCE_ACTIVATION)
	if(sanity_invulnerability)//Sorry, but that needed to be added here :C
		return
	var/wil = owner.stats.getStat(STAT_WIL)
	for(var/atom/A in view(owner.client ? owner.client : owner))
		if(A.sanity_damage) //If this thing is not nice to behold
			. += SANITY_DAMAGE_VIEW(A.sanity_damage, wil, get_dist(owner, A))

		if(owner.stats.getPerk(PERK_IDEALIST) && ishuman(A)) //Moralists react negatively to people in distress
			var/mob/living/carbon/human/H = A
			if(H.sanity.level < 30 || H.health < 50)
				. += SANITY_DAMAGE_VIEW(0.1, wil, get_dist(owner, A))
// Hold yourself together. Keep your Morale up.

/datum/sanity/proc/handle_area()
	var/area/my_area = get_area(owner)
	if(!my_area)
		return 0
	. = my_area.sanity.affect
	if(. < 0)
		. *= owner.stats.getStat(STAT_COG) / STAT_LEVEL_MAX //Mental state should matter more than your perception and agility

/datum/sanity/proc/handle_breakdowns()
	for(var/datum/breakdown/B in breakdowns)
		if(!B.update())
			breakdowns -= B

/datum/sanity/proc/handle_Insight()
	var/moralist_factor = 1
	//var/style_factor = owner.get_style_factor()
	if(owner.stats.getPerk(PERK_IDEALIST))
		for(var/mob/living/carbon/human/H in view(owner))
			if(H.sanity.level > 60)
				moralist_factor += 0.02
	give_insight((INSIGHT_GAIN(level_change) * insight_passive_gain_multiplier * moralist_factor * life_tick_modifier * GLOB.GLOBAL_INSIGHT_MOD))
	if(resting < max_resting && insight >= 100)
		if(!rest_timer_active)//Prevent any exploits(timer is only active for one minute tops)
			give_resting(1)
			if(owner.stats.getPerk(PERK_ARTIST))
				to_chat(owner, SPAN_NOTICE("You have gained insight.[resting ? " Now you need to make art. You cannot gain more insight before you do." : null]"))
			else
				to_chat(owner, SPAN_NOTICE("You have gained insight.[resting ? " Now you need to rest and rethink your life choices." : " Your previous insight has been discarded, shifting your desires for new ones."]"))
				pick_desires()
				insight -= 100
			owner.playsound_local(get_turf(owner), 'sound/sanity/level_up.ogg', 100)

	var/obj/screen/sanity/hud = owner.HUDneed["sanity"]
	hud?.update_icon()

/datum/sanity/proc/handle_level()
	level_change = SANITY_CHANGE_FADEOFF(level_change)

	if(level < 40 && world.time >= spook_time)
		spook_time = world.time + rand(1 MINUTES, 8 MINUTES) - (40 - level) * 1 SECONDS //Each missing sanity point below 40 decreases cooldown by a second

		var/static/list/effects_40 = list(
			.proc/effect_emote = 25,
			.proc/effect_quote = 50
		)
		var/static/list/effects_30 = effects_40 + list(
			.proc/effect_sound = 1,
			.proc/effect_quote = 25,
		)
		var/static/list/effects_20 = effects_30 + list(
			.proc/effect_hallucination = 30
		)

		call(src, pickweight(level < 30 ? level < 20 ? effects_20 : effects_30 : effects_40))()


/datum/sanity/proc/pick_desires()
	desires.Cut()
	var/list/candidates = list(
		INSIGHT_DESIRE_FOOD,
		INSIGHT_DESIRE_FOOD,
		INSIGHT_DESIRE_FOOD,
		INSIGHT_DESIRE_ALCOHOL,
		INSIGHT_DESIRE_ALCOHOL,
		INSIGHT_DESIRE_ALCOHOL,
		INSIGHT_DESIRE_SMOKING,
		INSIGHT_DESIRE_DRINK_NONALCOHOL,
		INSIGHT_DESIRE_DRINK_NONALCOHOL,
		INSIGHT_DESIRE_DRUGS,
		INSIGHT_DESIRE_DRUGS,
	)

	for(var/i in owner.metabolism_effects.addiction_list)
		if(istype(i, /datum/reagent/drug))
			if(istype(i, /datum/reagent/drug/nicotine))
				candidates.Remove(INSIGHT_DESIRE_SMOKING)
				continue
			candidates.Remove(INSIGHT_DESIRE_DRUGS)
	for(var/i = 0; i < INSIGHT_DESIRE_COUNT; i++)
		var/desire = pick_n_take(candidates)
		var/list/potential_desires = list()
		switch(desire)
			if(INSIGHT_DESIRE_FOOD)
				potential_desires = GLOB.sanity_foods.Copy()
				if(!potential_desires.len)
					potential_desires = init_sanity_foods()
			if(INSIGHT_DESIRE_ALCOHOL)
				potential_desires = GLOB.sanity_drinks.Copy()
				if(!potential_desires.len)
					potential_desires = init_sanity_drinks()
			if(INSIGHT_DESIRE_DRINK_NONALCOHOL)
				potential_desires = GLOB.sanity_non_alcoholic_drinks.Copy()
				if(!potential_desires.len)
					potential_desires = init_sanity_sanity_non_alcoholic_drinks()
			else
				desires += desire
				continue
		var/desire_count = 0
		while(desire_count < 5)
			var/candidate = pick_n_take(potential_desires)
			desires += candidate
			++desire_count
	print_desires()

/datum/sanity/proc/print_desires()
	if(!resting)
		return
	var/list/desire_names = list()
	for(var/desire in desires)
		if(ispath(desire))
			var/atom/A = desire
			desire_names += initial(A.name)
		else
			desire_names += desire
	to_chat(owner, SPAN_NOTICE("You desire [english_list(desire_names)]."))

/datum/sanity/proc/list_desires()
	if(!resting)
		return
	var/list/desire_names = list()
	for(var/desire in desires)
		if(ispath(desire))
			var/atom/A = desire
			desire_names += initial(A.name)
		else
			desire_names += desire
	return "[english_list(desire_names)]"


/datum/sanity/proc/add_rest(type, amount)
	if(!(type in desires))
		amount /= 16
	give_insight_rest(amount)
	if(insight_rest >= 100)
		insight_rest = 0
		finish_rest()

/datum/sanity/proc/finish_rest()
	desires.Cut()
	if(!rest_timer_active)
		to_chat(owner, "<font color='purple'>[owner.stats.getPerk(PERK_ARTIST) ? "You have created art." : "You have rested well."]\
					<br>Select what you wish to do with your fulfilled insight <a HREF=?src=\ref[src];here_and_now=TRUE>here and now</a> or get to safety first if you are in danger.\
					<br>The prompt will appear in one minute.</font>")
		rest_timer_active = TRUE
		rest_timer_time = 60 SECONDS
		owner.playsound_local(get_turf(owner), 'sound/sanity/rest.ogg', 100)

/datum/sanity/proc/level_up()
	rest_timer_active = FALSE
	var/rest = input(owner, "How would you like to improve your stats?", "Rest complete", null) in list(
		"Internalize your recent experiences",
		"Focus on an oddity",
		"Convert your fulfilled insight for later use"
		)

	if(rest == "Focus on an oddity")
		if(owner.stats.getPerk(PERK_ARTIST))
			to_chat(owner, SPAN_NOTICE("Your artistic mind prevents you from using an oddity."))
			rest = "Internalize your recent experiences"
		else
			var/oddity_in_posession = FALSE

			for(var/obj/item/I in owner.get_contents())
				if(is_type_in_list(I, valid_inspirations) && I.GetComponent(/datum/component/inspiration))
					oddity_in_posession = TRUE
					break

			if(!oddity_in_posession)
				to_chat(owner, SPAN_NOTICE("You do not have any oddities to use."))
				rest = "Internalize your recent experiences"

	switch(rest)

		if("Focus on an oddity")

			var/list/inspiration_items = list()
			for(var/obj/item/I in owner.get_contents()) //what oddities do we have?
				if(is_type_in_list(I, valid_inspirations) && I.GetComponent(/datum/component/inspiration))
					inspiration_items += I

			if(inspiration_items.len)//should always work, but in case of bug, there is an else
				var/obj/item/O = inspiration_items.len > 1 ? owner.client ? input(owner, "Select something to use as inspiration", "Level up") in inspiration_items : pick(inspiration_items) : inspiration_items[1]
				if(!O)
					return

				GET_COMPONENT_FROM(I, /datum/component/inspiration, O) // If it's a valid inspiration, it should have this component. If not, runtime
				var/list/L = I.calculate_statistics()
				var/resting_times = resting
				if(resting_times <= 0)
					resting_times = 1
				for(var/stat in L)
					var/stat_up = L[stat] * 2 * resting_times
					if((owner.stats.getStat(stat)) >= STAT_VALUE_MAXIMUM)
						stat_up = 0
						to_chat(owner, SPAN_NOTICE("You feel that you can't grow anymore better for today in [stat] with oddities"))
					else
						to_chat(owner, SPAN_NOTICE("Your [stat] stat goes up by [stat_up]"))
						owner.stats.changeStat_withcap(stat, stat_up)

				if(I.perk)
					if(owner.stats.addPerk(I.perk))
						I.perk = null

				resting = 0

				LEGACY_SEND_SIGNAL(O, COMSIG_ODDITY_USED)
				owner.give_health_via_stats()
				for(var/mob/living/carbon/human/H in viewers(owner))
					LEGACY_SEND_SIGNAL(H, COMSIG_HUMAN_ODDITY_LEVEL_UP, owner, O)

			else to_chat(owner, SPAN_NOTICE("Something really buggy just happened with your brain."))

		if("Convert your fulfilled insight for later use")
			owner.rest_points += 1 //yeah... that's it
			//resting = 0 //Temp commited out do to balance

		else //Cancelling or internalizing
			var/list/stat_change = list()

			var/stat_pool = resting * 15
			resting = 0
			owner.give_health_via_stats()
			while(stat_pool > 0)
				stat_pool--
				LAZYAPLUS(stat_change, pick(ALL_STATS_LEVEL), 3)

			for(var/stat in stat_change)
				if((owner.stats.getStat(stat)) >= STAT_VALUE_MAXIMUM)
					to_chat(owner, SPAN_NOTICE("You can not increase [stat] anymore with simple resting."))
				else
					to_chat(owner, SPAN_NOTICE("Your [stat] stat goes up by [stat_change[stat]]"))
					owner.stats.changeStat_withcap(stat, stat_change[stat])

	owner.pick_individual_objective()

/datum/sanity/proc/onDamage(amount)
	changeLevel(-SANITY_DAMAGE_HURT(amount, owner.stats.getStat(STAT_WIL)))

/datum/sanity/proc/onPsyDamage(amount)
	changeLevel(-SANITY_DAMAGE_PSY(amount, owner.stats.getStat(STAT_COG)))

/datum/sanity/proc/onSeeDeath(mob/M)
	var/mob/living/carbon/human/H
	if(ishuman(H))
		var/penalty = -SANITY_DAMAGE_DEATH(owner.stats.getStat(STAT_WIL))
		if(owner.stats.getPerk(PERK_NIHILIST))
			var/effect_prob = rand(1, 100)
			switch(effect_prob)
				if(1 to 25)
					M.stats.addTempStat(STAT_WIL, 5, INFINITY, "Fate Nihilist")
				if(25 to 50)
					M.stats.removeTempStat(STAT_WIL, "Fate Nihilist")
				if(50 to 75)
					penalty *= -1
				if(75 to 100)
					penalty *= 0
		if(M.stats.getPerk(PERK_TERRIBLE_FATE) && prob(100-owner.stats.getStat(STAT_WIL)))
			setLevel(0)
		else
			changeLevel(penalty*death_view_multiplier)

/datum/sanity/proc/onShock(amount)
	changeLevel(-SANITY_DAMAGE_SHOCK(amount, owner.stats.getStat(STAT_WIL)))

/datum/sanity/proc/onAlcohol(datum/reagent/ethanol/E, multiplier)
	changeLevel(E.sanity_gain_ingest * multiplier)
	if(resting)
		add_rest(E.type, 3 * multiplier)

/datum/sanity/proc/onNonAlcohol(datum/reagent/drink/D, multiplier)
	changeLevel(D.sanity_gain_ingest * multiplier)
	if(resting)
		add_rest(D.type, 3 * multiplier)

/datum/sanity/proc/onDrug(datum/reagent/drug/R, multiplier)
	changeLevel(R.sanity_gain * multiplier)
	if(resting)
		add_rest(INSIGHT_DESIRE_DRUGS, 4 * multiplier)

/datum/sanity/proc/onToxin(datum/reagent/toxin/R, multiplier)
	changeLevel(-R.sanityloss * multiplier)

/datum/sanity/proc/onReagent(datum/reagent/E, multiplier)
	var/sanity_gain = E.sanity_gain_ingest
	if(E.id == "ethanol")
		sanity_gain /= 5
	else if(istype(E, /datum/reagent/ethanol))
		var/datum/reagent/ethanol/fine_drink = E
		sanity_gain *= (40 / (fine_drink.strength + 15))
	changeLevel(sanity_gain * multiplier)

	/*if(resting && E.taste_tag.len)
		for(var/taste_tag in E.taste_tag)
			if(multiplier <= 1 )
				add_rest(taste_tag, 4 * 1/E.taste_tag.len)  //just so it got somme effect of things with small multipliers
			else
				add_rest(taste_tag, 4 * multiplier/E.taste_tag.len)*/ //We don't use taste-tag code. I'm too lazy to impliment it, and Trilby would wand major changes if this system were implimented due to its simplicity.

/datum/sanity/proc/onEat(obj/item/reagent_containers/food/snacks/snack, snack_sanity_gain, snack_sanity_message, amount_eaten)
	if(world.time > eat_time_message && snack_sanity_message)
		eat_time_message = world.time + EAT_COOLDOWN_MESSAGE
		to_chat(owner, "[snack_sanity_message]")
	changeLevel(snack_sanity_gain)
	if(resting) //snack.cooked removed do to it being quite unfun to need to eat uncooked food to level
		add_rest(snack.type, 20 * amount_eaten / snack.bitesize)
	/*if(snack.cooked && resting && snack.taste_tag.len)
		for(var/taste in snack.taste_tag)
			add_rest(taste, snack_sanity_gain * 50/snack.taste_tag.len)*/

/datum/sanity/proc/onSmoke(obj/item/clothing/mask/smokable/S)
	var/smoking_change = SANITY_GAIN_SMOKE * S.quality_multiplier
	var/smoking_allowed = FALSE
	var/smoking_no = FALSE
	for(var/obj/structure/sign/warning/nosmoking/dont in oview(owner, 7))

		smoking_no = TRUE
	for(var/obj/structure/sign/warning/smoking/undont in oview(owner, 7))
		smoking_allowed = TRUE

	if(smoking_no && !owner.stats.getPerk(PERK_CUBAN_DELIGHT))
		smoking_message += 1
		if(smoking_message >= 50)
			to_chat(owner, "Smoking in a non-smoking zone does not rest my nerves!")
			smoking_message = -1 //takes 51 puffs before we get a new warning about smoking in a non-smoker zone
		return

	if(resting)
		add_rest(INSIGHT_DESIRE_SMOKING, 0.4 * S.quality_multiplier)

	if(smoking_allowed && !smoking_no)
		changeLevel(1) //1+ for smoking in the correct area
		if(ishuman(owner))
			var/mob/living/carbon/human/H = owner
			H.learnt_tasks.attempt_add_task_mastery(/datum/task_master/task/proper_area_smoker, "PROPER_AREA_SMOKER", skill_gained = 0.1, learner = H)

	changeLevel(smoking_change)

/datum/sanity/proc/onSay()
	if(owner.stats.getPerk(PERK_SURVIVOR))
		return
	if(world.time < say_time)
		return
	say_time = world.time + SANITY_COOLDOWN_SAY
	changeLevel(SANITY_GAIN_SAY)

/datum/sanity/proc/changeLevel(amount)
	//if(owner.species.reagent_tag == IS_SYNTHETIC)
		//return
	if(sanity_invulnerability && amount < 0)
		return
	updateLevel(level + amount)

/datum/sanity/proc/setLevel(amount)
	//if(owner.species.reagent_tag == IS_SYNTHETIC)
		//return
	if(sanity_invulnerability)
		restoreLevel(amount)
		return
	updateLevel(amount)

/datum/sanity/proc/restoreLevel(amount)
	if(level <= amount)
		return
	updateLevel(amount)

/datum/sanity/proc/updateLevel(new_level)
	//if(owner.species.reagent_tag == IS_SYNTHETIC)
		//return
	new_level = CLAMP(new_level, 0, max_level)
	level_change += abs(new_level - level)
	level = new_level
	if(level == 0 && world.time >= breakdown_time)
		breakdown()
	var/obj/screen/sanity/hud = owner.HUDneed["sanity"]
	hud?.update_icon()

/datum/sanity/proc/breakdown(var/positive_breakdown = FALSE)
	breakdown_time = world.time + SANITY_COOLDOWN_BREAKDOWN

	if(owner.stats.getPerk(PERK_NJOY))
		return // No breakdowns when you're Njoying life. TODO: once Psychosis is added, reduce to 50% chance

	for(var/obj/item/device/mind_fryer/M in GLOB.active_mind_fryers)
		if(get_turf(M) in view(get_turf(owner)))
			M.reg_break(owner)

	var/list/possible_results
	if((prob(positive_prob) && positive_prob_multiplier > 0 || positive_breakdown))
		possible_results = subtypesof(/datum/breakdown/positive)
	else if(prob(negative_prob))
		possible_results = subtypesof(/datum/breakdown/negative)
	else
		possible_results = subtypesof(/datum/breakdown/common)

	for(var/datum/breakdown/B in breakdowns)
		possible_results -= B.type

	while(possible_results.len)
		var/breakdown_type = pick(possible_results)
		var/datum/breakdown/B = new breakdown_type(src)

		if(!B.can_occur())
			possible_results -= breakdown_type
			qdel(B)
			continue

		if(B.occur())
			breakdowns += B
			for(var/mob/living/carbon/human/H in viewers(owner))
				LEGACY_SEND_SIGNAL(H, COMSIG_HUMAN_BREAKDOWN, owner, B)
		return

#undef SANITY_PASSIVE_GAIN


//Soj Edit
/datum/sanity/proc/change_max_level(amount)
	max_level += amount
