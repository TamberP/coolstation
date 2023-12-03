#define GAS_GEN_G 0.8

/obj/machinery/atmospherics/engine
	name = "engine"
	desc = "Turns fuel and air into smoke and noise, and rotates a coupling as a byproduct"
	icon = 'icons/obj/machines/infernal_combustion.dmi'
	icon_state = "engine"
	dir = 1
	density = 1

	var/ignition      = 0
	var/displacement  = 200
	var/current_speed = 0
	var/stall_speed   = 300
	var/max_speed     = 3600

	var/throttle      = 0
	var/mixture       = 50 // 50/50
	var/efficiency    = 0.25 // 25 percent! Zow-ee momma! That's the Otto cycle for you!
	var/last_work     = 0

	var/datum/gas_mixture/air_in
	var/datum/gas_mixture/fuel_in
	var/datum/gas_mixture/chamber
	var/datum/gas_mixture/exhaust

	var/obj/machinery/atmospherics/node_air
	var/obj/machinery/atmospherics/node_fuel
	var/obj/machinery/atmospherics/node_exhaust

	var/datum/pipe_network/network_air
	var/datum/pipe_network/network_fuel
	var/datum/pipe_network/network_exhaust

	New()
		..()
		initialize_directions = NORTH|SOUTH|WEST

		air_in  = new()
		fuel_in = new()
		chamber = new()
		exhaust = new()

		air_in.volume  = displacement
		fuel_in.volume = displacement
		chamber.volume = displacement
		exhaust.volume = displacement

	disposing()
		if(network_air)
			network_air.air_disposing_hook(network_air, network_fuel, network_exhaust)
		if(network_fuel)
			network_fuel.air_disposing_hook(network_air, network_fuel, network_exhaust)
		if(network_exhaust)
			network_exhaust.air_disposing_hook(network_air, network_fuel, network_exhaust)

		if(node_exhaust)
			node_exhaust.disconnect(src)
			if(network_exhaust)
				network_exhaust.dispose()
		if(node_fuel)
			node_fuel.disconnect(src)
			if(network_fuel)
				network_fuel.dispose()

		if(node_air)
			node_air.disconnect(src)
			if(network_air)
				network_air.dispose()

		node_exhaust = null
		node_fuel    = null
		node_air     = null

		network_exhaust = null
		network_fuel    = null
		network_air     = null

		if(air_in)
			qdel(air_in)
		if(fuel_in)
			qdel(fuel_in)
		if(chamber)
			qdel(chamber)
		if(exhaust)
			qdel(exhaust)

		air_in  = null
		fuel_in = null
		chamber = null
		exhaust = null

		..()

	network_disposing(datum/pipe_network/reference)
		if(network_air == reference)
			network_air     = null
		if(network_fuel == reference)
			network_fuel    = null
		if(network_exhaust == reference)
			network_exhaust = null

	update_icon()
		if(status & BROKEN)
			src.icon_state = "[initial(src.icon_state)]-broken"
			return
		if(src.current_speed > src.stall_speed)
			src.icon_state = "[initial(src.icon_state)]-running"
		else
			src.icon_state = initial(src.icon_state)

	process()
		..()
		if(status & BROKEN)
			return

		if(!air_in || !fuel_in || !chamber || !exhaust)
			return

		if(!ignition)
			if(current_speed > 0)
				src.visible_message("<span class='alert'>The [src] lurches and stops.</span>")
				src.current_speed = 0
				src.last_work = 0
				update_icon()
			return

		if(current_speed < stall_speed)
			if(last_work > 0)
				src.visible_message("<span class='alert'>The [src] lurches ominously and stops.</span>")
				src.last_work = 0
				src.current_speed = 0
				update_icon()
			return

		if(last_work <= 0)
			src.visible_message("<span class='notice'>The [src] coughs into life</span>")

		if(current_speed > max_speed)
			if(prob((current_speed % max_speed)/10))
				// Kaboom
				src.visible_message("<span class='alert'>The [src] fails violently, scattering parts in all directions!</span>")
				explosion(src, src, 0, 1, 1, 2)
				src.current_speed  = 0
				src.last_work = 0
				src.status |= BROKEN
				update_icon()
				return
			else
				if(prob(40))
					src.visible_message("<span class='alert'>The [src] makes an ominous clattering noise!</span>")

		update_icon()
		SPAWN_DBG(doTheDo())
		return

	proc/doTheDo()
		var/transfer_amount = (displacement * max(0.1, throttle) * (100 - src.mixture))
		src.chamber = src.air_in.remove(transfer_amount)

		transfer_amount = (displacement * max(0.1, throttle) * src.mixture)
		src.chamber.merge(src.fuel_in.remove(transfer_amount))

		var/charge_temp_pre = chamber.temperature
		var/charge_pressure_pre = MIXTURE_PRESSURE(src.chamber)

		src.chamber.temperature += 150 // *spark*
		src.chamber.react()

		sleep(0.1 SECOND)
		// (Burn baby burn)
		// var/temp_delta = (chamber.temperature - charge_temp_pre)
		var/pressure_delta = (MIXTURE_PRESSURE(src.chamber) - charge_pressure_pre)

		var/work_done = (pressure_delta * ((charge_pressure_pre * displacement) / (R_IDEAL_GAS_EQUATION * charge_temp_pre)) * (current_speed / 60)) * efficiency
		src.chamber.temperature = src.chamber.temperature * (1-efficiency)
		src.current_speed += work_done * GAS_GEN_G

		src.last_work = work_done
		src.exhaust.merge(chamber)
		// todo: engine noise

	proc/Start()
		if(src.current_speed > 0 || (status & BROKEN))
			src.visible_message("<span class='alert'>The [src] makes a horrible crunchy noise!</span>")
			// todo: crunchy noise
			elecflash(src)
			return

		src.visible_message("<span class='notice'>The starter grumbles as it rotates the [src]</span>")
		// todo: starter noise
		if(ignition)
			SPAWN_DBG(1.5 SECOND)
			src.current_speed = (stall_speed + 25)

	attack_hand(mob/usr)
		if(status & BROKEN)
			return
		show_window(usr)

	proc/show_window(var/mob/user as mob)
		var/engine_html = "<b>Status</b><hr><br><table>"
		engine_html += "<tr><th>Ignition</th><td>[src.ignition ? "On":"Off"]</td></tr>"
		engine_html += "<tr><th>Engine</th><td>[src.current_speed<src.stall_speed ? "Stalled" : "Running"]</td></tr>"
		engine_html += "<tr><td colspan='4'><hr></td></tr>"
		engine_html += "<tr><th colspan='2'><a href='?src=\ref[src]&ui_action=ign'>Ignition</a></th><th colspan='2'><a href='?src=\ref[src]&ui_action=crank'>Starter</a></th></tr>"
		engine_html +="</table><hr><br><table>"

		engine_html += "<tr><th>Current Speed</th><td>[round(src.current_speed)] rpm</td></tr>"
		// the 'work done' thing isn't really torque output, but it looks less bad if I just put a unit there
		engine_html += "<tr><th>Current Output</th><td>[round(src.last_work, 0.1)] Nm</td></tr></table><br><hr>"
		engine_html += "<b>Mixture</b>: <a href='?src=\ref[src]&ui_action=mix_dn'>&lt;</a> [src.mixture]% <a href='?src=\ref[src]&ui_action=mix_up'>&gt;</a><br>"
		engine_html += "<b>Throttle</b>: <a href='?src=\ref[src]&ui_action=throttle_dn'>&lt;</a> [src.throttle]% <a href='?src=\ref[src]&ui_action=throttle_up'>&gt;</a>"
		engine_html += "<br><br><br><a href='?src=\ref[src]'>Refresh</a>"

		usr << browse(engine_html, "window=engine")
		src.add_dialog(usr)
		onclose(usr, "engine")

	Topic(href, href_list)
		if(..())
			return

		if(href_list["ui_action"] == "ign")
			src.add_fingerprint(usr)
			src.ignition = !src.ignition
		if(href_list["ui_action"] == "crank")
			src.add_fingerprint(usr)
			src.Start()
		if(href_list["ui_action"] == "throttle_up")
			if(src.throttle < 100)
				src.throttle = min(100, src.throttle+10)
		if(href_list["ui_action"] == "throttle_dn")
			if(src.throttle > 0)
				src.throttle = max(0, src.throttle-10)
		if(href_list["ui_action"] == "mix_up")
			if(src.mixture < 100)
				src.mixture = min(100, src.mixture+10)
		if(href_list["ui_action"] == "mix_dn")
			if(src.mixture > 0)
				src.mixture = max(0, src.mixture-10)

		show_window(usr)

	initialize()
		if(node_air && node_fuel && node_exhaust) return

		node_exhaust = connect(turn(dir, 180))
		node_fuel    = connect(turn(dir, -90))
		node_air     = connect(dir)

		update_icon()

	// Pipework housekeeping stuff.

	build_network()
		if(!network_exhaust && node_exhaust)
			network_exhaust = new /datum/pipe_network()
			network_exhaust.normal_members += src
			network_exhaust.build_network(node_exhaust, src)
		if(!network_fuel && node_fuel)
			network_fuel = new /datum/pipe_network()
			network_fuel.normal_members += src
			network_fuel.build_network(node_fuel, src)
		if(!network_air && node_air)
			network_air = new /datum/pipe_network()
			network_air.normal_members += src
			network_air.build_network(node_air, src)

	network_expand(datum/pipe_network/new_network, obj/machinery/atmospherics/pipe/reference)
		if(reference == node_exhaust)
			network_exhaust = new_network
		else if(reference == node_fuel)
			network_fuel    = new_network
		else if(reference == node_air)
			network_air     = new_network

		if(src in new_network.normal_members)
			return 0

		new_network.normal_members += src
		return null

	return_network(obj/machinery/atmospherics/reference)
		build_network()

		if(reference == node_exhaust)
			return network_exhaust
		if(reference == node_fuel)
			return network_fuel
		if(reference == node_air)
			return network_air

		return null

	reassign_network(datum/pipe_network/old_network, datum/pipe_network/new_network)
		if(network_exhaust == old_network)
			network_exhaust = new_network
		if(network_air == old_network)
			network_air = new_network
		if(network_fuel == old_network)
			network_fuel = new_network
		return 1

	return_network_air(datum/pipe_network/reference)
		var/list/results = list()

		if(network_exhaust == reference)
			results += exhaust
		if(network_fuel == reference)
			results += fuel_in
		if(network_air == reference)
			results += air_in

		return results

	disconnect(obj/machinery/atmospherics/reference)
		if(reference == node_exhaust)
			if(network_exhaust)
				network_exhaust.dispose()
				network_exhaust = null
			node_exhaust = null
		if(reference == node_air)
			if(network_air)
				network_air.dispose()
				network_air = null
			node_air = null
		if(reference == node_fuel)
			if(network_fuel)
				network_fuel.dispose()
				network_fuel = null
			node_fuel = null
		return null

	sync_node_connections()
		if(node_air)
			node_air.sync_connect(src)
		if(node_fuel)
			node_fuel.sync_connect(src)
		if(node_exhaust)
			node_exhaust.sync_connect(src)

	sync_connect(obj/machinery/atmospherics/reference)
		if(reference in list(node_air, node_fuel, node_exhaust))
			return
		var/refdir = get_dir(src, reference)
		if(!node_air && refdir == dir) // node_in
			node_air = reference
		else if(!node_fuel && refdir == turn(dir, -90)) // out1
			node_fuel = reference
		else if(!node_exhaust && refdir == turn(dir, 180)) // out2
			node_exhaust = reference

		update_icon()
