#define GAS_GEN_Q 2000
#define GAS_GEN_G 0.8

/obj/machinery/atmospherics/engine
	name = "engine"
	desc = "Turns fuel and air into smoke and noise, and rotates a coupling as a byproduct"
	icon = 'icons/obj/machines/infernal_combustion.dmi'
	icon_state = "engine"

	var/datum/gas_mixture/air_in
	var/datum/gas_mixture/fuel_in
	var/datum/gas_mixture/chamber
	var/datum/gas_mixture/exhaust_out

	var/obj/machinery/atmospherics/node_air_inlet
	var/obj/machinery/atmospherics/node_fuel_inlet
	var/obj/machinery/atmospherics/node_exhaust

	var/datum/pipe_network/network_air_inlet
	var/datum/pipe_network/network_fuel_inlet
	var/datum/pipe_network/network_exhaust

	var/ignition = 0
	var/displacement = 200
	var/current_speed = 0
	var/stall_speed = 300
	var/redline = 3600
	var/throttle = 0
	var/mixture = 50 // 50/50
	var/efficiency = 0.25 // 25 percent. Zow-ee momma! That's the Otto cycle for you!
	var/last_work_done = 0

/obj/machinery/atmospherics/engine/network_disposing(datum/pipe_network/reference)
	if(network_air_inlet == reference)
		network_air_inlet = null
		return
	if(network_fuel_inlet == reference)
		network_fuel_inlet = null
		return
	if(network_exhaust == reference)
		network_exhaust = null

/obj/machinery/atmospherics/engine/New(loc)
	..()

	air_in  = new()
	fuel_in = new()
	chamber = new()
	exhaust_out = new()

	air_in.volume = displacement
	fuel_in.volume = displacement
	chamber.volume = displacement
	exhaust_out.volume = (displacement * 1.5)

/obj/machinery/atmospherics/engine/disposing()
	if(network_air_inlet)
		network_air_inlet.air_disposing_hook(air_in, fuel_in, chamber, exhaust_out)
	if(network_fuel_inlet)
		network_fuel_inlet.air_disposing_hook(air_in, fuel_in, chamber, exhaust_out)
	if(network_exhaust)
		network_exhaust.air_disposing_hook(air_in, fuel_in, chamber, exhaust_out)

	if(node_air_inlet)
		node_air_inlet.disconnect(src)
		if(network_air_inlet)
			network_air_inlet.dispose()
	if(node_fuel_inlet)
		node_fuel_inlet.disconnect(src)
		if(network_fuel_inlet)
			network_fuel_inlet.dispose()
	if(node_exhaust)
		node_exhaust.disconnect(src)
		if(network_exhaust)
			network_exhaust.dispose()

	node_air_inlet = null
	node_fuel_inlet = null
	node_exhaust = null
	network_air_inlet = null
	network_fuel_inlet = null
	network_exhaust = null

	if(air_in)
		qdel(air_in)
	if(fuel_in)
		qdel(fuel_in)
	if(chamber)
		qdel(chamber)
	if(exhaust_out)
		qdel(exhaust_out)

	air_in  = null
	fuel_in = null
	chamber = null
	exhaust_out = null
	..()

/obj/machinery/atmospherics/engine/process()
	..()

	if(status & BROKEN)
		return

	if(!ignition)
		if(current_speed > 0)
			src.visible_message("<span class='alert'>The [src] lurches and stops.</span>")
			src.last_work_done = 0
			src.current_speed = 0
			update_icon()
		return

	if(current_speed < stall_speed)
		if(last_work_done > 0)
			src.visible_message("<span class='alert'>The [src] lurches ominously and stalls.</span>")
			src.last_work_done = 0
			src.current_speed = 0
			update_icon()
		return

	if(current_speed > redline)
		if(prob((current_speed %% redline)/10))
			// Kaboom
			src.visible_message("<span class='alert'>The [src] fails violently, scattering parts in all directions!</span>")
			explosion(src, src, 1, 2, 2, 4)
			src.current_speed = 0
			src.last_work_done = 0
			src.status |= BROKEN
			update_icon()
			return

	var/transfer_ratio = max(1, ((displacement/src.air_in.volume) * (100 - src.mixture) * (src.throttle+1)))
	src.chamber = src.air_in.remove_ratio(transfer_ratio)

	transfer_ratio = max(1, ((displacement/src.fuel_in.volume) * src.mixture * (src.throttle+1)))
	src.chamber.merge(src.fuel_in.remove_ratio(transfer_ratio))

	src.air_in?.update = 1
	src.fuel_in?.update = 1

	var/charge_temp_pre = chamber.temperature
	var/charge_pressure_pre = MIXTURE_PRESSURE(src.chamber)

	src.chamber.temperature += 150 // *spark*
	src.chamber.react()

	// (Burn baby burn)
	var/temp_delta = (charge_temp_pre - cylinders.temperature)
	var/pressure_delta = (charge_pressure_pre - MIXTURE_PRESSURE(src.chamber))

	var/work_done = (pressure_delta * ((charge_pressure_pre * displacement) / (R_IDEAL_GAS_EQUATION * charge_temp_pre)) * (current_speed / 60)) * efficiency
	src.cylinder.temperature =* (1-efficiency)

	src.current_speed += (work_done - last_work_done) * 0.10
	src.current_speed = max(0, current_speed)

	src.last_work_done = work_done
	src.exhaust_out.merge(cylinder)
	update_icon()

/obj/machinery/atmospherics/engine/proc/update_icon()
	if(status & BROKEN)
		src.icon_state = "[initial(src.icon_state)]_broken"
		return
	if(src.current_speed > src.stall_speed)
		src.icon_state = "[initial(src.icon_state)]_running"
	else
		src.icon_state = initial(src.icon_state)


/obj/machinery/atmospherics/engine/proc/Start()
	if(src.current_speed > 0 || (status & BROKEN))
		src.visible_message("<span class='alert'>The engine makes a horrible noise as the starter grinds!</span>">
		// Todo: Crunchy noise
		elecflash(src)
		return

	src.visible_message("<span class='notice'>The starter grumbles as it rotates the engine</span>")
	// Todo: Starter noise
	if(ignition)
		SPAWN_DBG(1.5 SECOND)
			src.current_speed = 350
			src.visible_message("<span class='notice'>The engine coughs into life</span>")

/obj/machinery/atmospherics/engine/attack_hand(mob/usr)
	if(status & BROKEN)
		return

	usr << browse(return_text(), "window=computer;can_close=1")
	src.add_dialog(usr)
	onclose(usr, "computer")

/obj/machinery/atmospherics/engine/proc/return_text()
	var/engine_html = ""

	engine_html += "<b>Status</b>: Ignition [src.ignition ? "On":"Off"] Engine: [src.current_speed < src.stall_speed ? "Stalled" : "Running"]<br>"
	engine_html += "<u><a href='?src=\ref[src];ign'>Ignition</a></u> | <u><a href='?src=\ref[src];crank'>Starter</a></u><br>"
	engine_html += "<hr><br>"

	engine_html += "<b>Current Speed</b>: [src.current_speed] rpm<br>"
	engine_html += "<b>Current Output</b>: [src.last_work_done] Nm<br>"

	engine_html += "<hr><br>"

	engine_html += "<b>Mixture</b>: <a href='?src=\ref[src];mix_dn'>&lt;</a> [src.mixture]&percent; <a href='?src=\ref[src];mix_up'>&gt;</a><br>"
	engine_html += "<b>Throttle</b>: <a href='?src=\ref[src];throttle_dn'>&lt;</a> [src.throttle]&percent; <a href='?src=\ref[src];throttle_up'>&gt;</a>"
	return engine_html

/obj/machinery/atmospherics/engine/Topic(href, href_list)
	if(..())
		return

	if(href_list["ign"])
		src.ignition != src.ignition
	if(href_list["crank"])
		src.add_fingerprint(usr)
		src.Start()
	if(href_list["throttle_up"])
		if(src.throttle < 100)
			src.throttle = min(100, src.throttle+10)
	if(href_list["throttle_dn"])
		if(src.throttle > 0)
			src.throttle = max(0, src.throttle-10)
	if(href_list["mix_up"])
		if(src.mixture < 100)
			src.mixture = min(100, src.mixture+10)
	if(href_list["mix_dn"])
		if(src.mixture > 0)
			src.mixture = max(0, src.mixture-10)
