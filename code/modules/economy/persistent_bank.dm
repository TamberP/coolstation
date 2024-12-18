// Persistent Banking: Welcome to the Debt Hoal
// -={ This ain't your grandma's spacebux. }=-

// See also:
// - gameticker.dm: Digging deeper into the debt hoal on round-end

/chui/window/roundend_debthoal
	name = "Financial Statement"
	windowSize = "300x600"

	var/wage_base
	var/interest
	var/equipment_fee
	var/cloaning_fee
	var/biomass_surcharge
	var/retrieval_fee
	var/current_balance

	GetBody()
		var/ret

		ret = "<p style=\"text-align:left;\">Shift-start credit advance .... <span style=\"float:right;\"><b>[wage_base]</b></span></p><br>"
		ret += "<p style=\"text-align:left;\">Interest ....<span style=\"float:right;\"><b>[interest]</b></span></p><br>"
		if(equipment_fee)
			ret += "<p style=\"text-align:left;\">Equipment replacement fee .... <span style=\"float:right;\"><b>[equipment_fee]</b></span></p><br>"
		if(cloaning_fee)
			ret += "<p style=\"text-align:left;\">Cloning fee .... <span style=\"float:right;\"><b>[cloaning_fee]</b></span></p><br>"
			if(biomass_surcharge)
				ret += "<p style=\"float:right;\"><b>BIOMASS SURCHARGE ADDED</b></p><br>"
		if(retrieval_fee)
			ret += "<p style=\"text-align:left;\">Retrieval fee .... <span style=\"float:right;\"><b>[retrieval_fee]</b></span></p><br>"

		ret += "<hr>"

		var/total = wage_base + interest + equipment_fee + cloaning_fee + retrieval_fee
		ret += "<p style=\"text-align:left;\"><b>Total</b> .... <span style=\"float:right;\"><b>[total]</b></span></p><br>"
		ret += "<p style=\"text-align:center;\">This will be deducted from your account automatically.</p><br><br>"
		ret += "<p style=\"text-align:left;\">Your current account balance is: <span style=\"float:right;\"><b>[current_balance]</b></span></p><br>"
		ret += "<p style=\"text-align:left;\">Account balance after deductions: <span style=\"float:right;\"><b>[current_balance - total]</b></span></p><br>"

		return ret

