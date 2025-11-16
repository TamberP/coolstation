/obj/machinery/atmospherics/unary/furnace
	name = "enormous furnace"
	desc = "...did someone just cut a hole into a tanker car and use it as a burn barrel?"
	icon = 'icons/obj/large/furnace.dmi'
	icon_state = "hellburn-barrel" // also, hellburn-barrel-door, and hellburn-barrel-flame
	anchored = ANCHORED
	density = 1
//	layer = DECAL_LAYER // I dunno what to pick that'll make it cover lights, but not effects n stuff?
	pixel_x = -16
	var/max_efficiency = 0.99 // How much of our energy goes into the pipework vs goes into the room air
	var/efficiency
	var/pipe_dir = SOUTH
	var/active
	var/last_active
	var/doorstate
	var/last_doorstate
	var/datum/light/light

	var/fuel
	var/fuel_heat_mult = 1.0 // 1.0 is equivalent to charcoal. some stuff can burn hotter, some stuff can burn colder
	var/maxfuel = 800

	var/current_temp = T20C
	var/current_heat_cap = 5000 // Totally arbitrary. Tweak as necessary.
	var/datum/digital_filter/exponential_moving_average/heat_filter = new

	New()
		..()
		initialize_directions = pipe_dir
		heat_filter.init_basic(0.25)
		src.efficiency = max_efficiency
		light = new /datum/light/point
		light.attach(src)
		light.set_color(0.98, 0.61, 0.41)

	initialize()
		if(node) return
		var/node_connect = pipe_dir
		for(var/obj/machinery/atmospherics/target in get_step(src, node_connect))
			if(target.initialize_directions & get_dir(target,src))
				node = target
				break

		update_icon()

	process()
		var/air_heat_cap = HEAT_CAPACITY(air_contents)
		var/combo_heat_cap = current_heat_cap + air_heat_cap
		var/datum/gas_mixture/ambient = src.loc?.return_air()
		var/amb_heat_cap = HEAT_CAPACITY(ambient)
		var/combo_energy = (current_temp * current_heat_cap)+(air_heat_cap * air_contents.temperature)

		if(src.active)
			src.fuel--

			if(src.fuel <= 0)
				src.visible_message("<span class='alert'>[src] runs out of fuel and burns out!</span>")
				src.active = FALSE

				update_icon()
				return

			if(combo_heat_cap > 0)
				var/additional_heat = 0
				// lifted from the TEG thermo furnace
				if(active)
					var/fuel_fuel_ratio = src.fuel/src.maxfuel
					var/fuel_burn_scale = (-0.48 * fuel_fuel_ratio) * ((3*fuel_fuel_ratio)-5) + (current_temp / 200) // Our burn gets better the higher temp we get
					additional_heat = fuel_burn_scale * (3000) * fuel_heat_mult // Charcoal hi-temp is 2500C

					src.current_temp += additional_heat / combo_heat_cap // warm up




				// ~~Put [efficiency]% of our heat energy into the air_contents~~
				air_contents.temperature += (combo_energy * src.efficiency)/combo_heat_cap

				// Put some heat energy into the ambient air
				ambient.temperature += (combo_energy * (1 - efficiency)/amb_heat_cap)/10

		else
			// slowly reducing our temp to that of either ambient, or our pipe network, whichever is warmer
			var/tmp_hi = air_contents.temperature
			if(tmp_hi < ambient.temperature)
				tmp_hi = ambient.temperature

			var/delta_temp = src.current_temp - tmp_hi
			if(delta_temp)
				src.current_temp -= delta_temp / combo_heat_cap


	update_icon()
		if(src.active)
			var/image/I = GetOverlayImage("fiyah")
			if(!I) I = image('icons/obj/large/furnace.dmi', "hellburn-barrel-flame")
			UpdateOverlays(I, "fiyah")
			src.light.enable()
		else
			UpdateOverlays(null, "fiyah", 0, 1)
			src.light.disable()

		if(src.doorstate) // door closed
			var/image/I = GetOverlayImage("door_closed")
			if(!I) I = image('icons/obj/large/furnace.dmi', "hellburn-barrel-door-closed")
			UpdateOverlays(I, "door_closed")
			UpdateOverlays(null, "door_opened", 0, 1)
			if(src.active)
				src.light.set_brightness(0.4)
		else
			var/image/I = GetOverlayImage("door_opened")
			if(!I) I = image('icons/obj/large/furnace.dmi', "hellburn-barrel-door-open")
			UpdateOverlays(null, "door_closed", 0, 1)
			if(src.active)
				src.light.set_brightness(1.2)


	attack_hand(var/mob/user as mob)
		if(src.doorstate)
			src.doorstate = FALSE
			src.efficiency = src.max_efficiency / 2 // Lettin' all the heat out!
			user.visible_message("You open the door of the [src]")
			if(src.active && src.current_temp > (2 * T100C))
				// lmao, fireball to the face
				game_stats.Increment("workplacesafety")
				var/turf/T = get_turf(src)
				src.visible_message("<span class='alert'>[src] belches a ball of flame!</span>")
				fireflash(T, 2)
		else
			src.doorstate = TRUE
			src.efficiency = src.max_efficiency
			user.visible_message("You close the door of the [src]")

		update_icon()

	attackby(obj/item/W as obj, mob/user as mob)
		if(istype(W, /obj/item/grab))
			var/obj/item/grab/grab = W
			var/mob/target = grab.affecting
			if(target?.buckled || target?.anchored)
				user.visible_message("<span class='alert'>[target] is stuck to something, and can't be shoved into the furnace!</span>")
				return
			user.visible_message("<span class='alert'>[user] starts to shove [target] into the furnace!</span>")
			logTheThing("combat", user, target, "attempted to force [constructTarget(target, "combat")] into a hellburn-barrel at [log_loc(src)].")
			message_admins("[key_name(user)] is trying to force [key_name(target)] into a hellburn-barrel at [log_loc(src)]")
			src.add_fingerprint(user)
			sleep(5 SECONDS)
			if(grab?.affecting && in_interact_range(src, user))
				var/mob/M = grab.affecting
				user.visible_message("<span class='alert'>[user] stuffs [M] into the furnace!</span>")
				logTheThing("combat", user, M, "forced [constructTarget(M, "combat")] into a hellburn-barrel at [log_loc(src)].")
				message_admins("[key_name(user)] forced [key_name(M)] into a furnace at [log_loc(src)].")
				// Slam door
				// Figure out whether they're just trapped there for a bit, or whether they're burning to death.
				return
		else if(!src.active)
			if(isweldingtool(W) && W:try_weld(user, 0, -1, 0, 0))
				// we light
				user.visible_message("<span class='alert'><b>[user] casually lights [src] with [W], what a badass.</b></span>")
				src.light()
				return
			else if (istype(W, /obj/item/clothing/head/cakehat) && W:on)
				// ...woh
				user.visible_message("<span class='alert'><b>Did [user] just light \The [src] with [W]? Holy shit.</b></span>")
				src.light()
				return
			else if (istype(W, /obj/item/device/igniter))
				// okay, nice
				user.visible_message("<span class='alert'>[user] fumbles around with [W]; a small flame erupts from [src].</span>")
				src.light()
				return
			else if (istype(W, /obj/item/device/light/zippo) && W:on)
				// classy
				user.visible_message("<span class='alert'><b>With a single flick of [his_or_her(user)] wrist, [user] smoothly lights [src] with [W]. Damn they're cool.</b></span>")
				src.light()
				return
			else if (istype(W, /obj/item/match))
				var/obj/item/match/match = W
				switch(match.on)
					if(-1) // broken
						user.visible_message("[user] stares at [match] for a while, then gives up and throw it into [src].", "\The [match] confuses you, so you throw it into [src]")
						return
					if(0) // unlit
						user.visible_message("<span class='alert'><b>With a swift motion, [user] strikes [match] on [src] and lights both simultaneously! Damn, they're slick!</span>")
						src.light()
						return
					if(1) // lit
						user.visible_message("<span class='alert'>[user] lights [src] with [match].</span>")
						src.light()
						return
			else if (istype(W, /obj/item/device/light/candle) && W:on)
				user.visible_message("<span class='alert'>[user] lights [src] with [W].</span>")
				src.light()
				return
			else if (W.burning)
				user.visible_message("<span class='alert'><b>[user] lights [src] with [W]. Goddamn.</b></span>")
				src.light()
				return
		else if(load_into_furnace(W, 1, user) == 0)
			..()
			return

	proc/light()
		if(!src.active && src.fuel > 1)
			src.active = TRUE
			update_icon()

			if((src.fuel / src.maxfuel) > 0.6 && src.current_temp > (1.5 * T100C))
				// Hot restart!
				game_stats.Increment("workplacesafety")
				var/turf/T = get_turf(src)
				src.visible_message("<span class='alert'>[src] belches a ball of flame!</span>")
				fireflash(T, 2)

	MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
		if(get_dist(src, user) > 1)
			boutput(user, "<span class='alert'>You are too far away to do that.</span>")
			return

		if(get_dist(src, O) > 1)
			boutput(user, "<span class='alert'>[O] is too far away to do that.</span>")
			return

		// Just about everything burns eventually, right?
		// if(istype(O, /obj/storage/crate/))
		// 	var/obj/storage/crate/C = O
		// 	if(C.spawn_contents && C.make_my_stuff())
		// 		C.spawn_contents = null


	proc/load_into_furnace(obj/item/W as obj, var/original, mob/user as mob)
		return
