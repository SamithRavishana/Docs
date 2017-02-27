# K-8 Engines
# ------------
# Authors: David Bastien and Alexis Bory

# TODO: - Protect engine from overtemp, overpressure and stall
#       - motor @ IDLE for manual start
#       - Ignition effect if n2 > 15 && collector_tk != 0 && !ats_valve
#       - Take care of throttle cut OFF position

# ATS Valve : Air Turbine Start Valve.

	var LeftEngine  = nil;
	var ab1 = 0;
	var as_count = 0;
    var time_out_as = 0;
	var T_OUT = 60;
    var md = 0;
	var i_itt = 20*rand() + 25;
    var n1g = (30-28)*rand() + 28;
    var n2g = (60-38)*rand() + 38;
	var itt_c = 0;
	var itt_c_v = 0;
	var ign_on = 0;
	var itt_set = 0;
	var ab_n1 = 0;
	var ab_n2 = 0;
	var kn1t = 5;
	var kn2t = 5;
	var AbMsg = {
	  new: func(s=0)
	  {
		var width=500;
		var height=160;
		var m = {
		  parents: [AbMsg],
		  _dlg: canvas.Window.new([width, height], "dialog")
							 .set("title", "K-8 Simulator")
							 .set("resize", 1),
		};

		m._dlg.getCanvas(1)
			  .set("background", canvas.style.getColor("bg_color"));
		m._dlg.align = "center-center";
		m._root = m._dlg.getCanvas().createGroup();
	 
		var myText = m._root.createChild("text")
		  .setFontSize(25, 0.9)          # font size (in texels) and font aspect ratio
		  .setTranslation(200, 80);     # where to place the text
		  
		if(s==1){
		  myText.setText("K-8 Mission Successful");
		  myText.setColor(0,0,1,1);             # blue, fully opaque
		  myText.setAlignment("center-center"); # how the text is aligned to where you place it

		}else{
		  myText.setText("K-8 Mission Failed");
		  myText.setColor(1,0,0,1);             # red, fully opaque
		  myText.setAlignment("center-center"); # how the text is aligned to where you place it
		}
		
		return m;
	  },
	};

	var initialize = func {
		# Engines ("name", number)
		LeftEngine  = Engine.new( "Left Engine", 0);
		setprop("engines/engine/itt-norm",1);
		setprop("controls/electric/generator",1);
	}




#############################################################################
var update_loop = func( n ) {

	var e       = LeftEngine;
	if (n) e 	= LeftEngine;
	
	var eng_serviceable 	= e.get_serviceable();
	var eng_switch_pos 		= e.get_switch_pos();
	var eng_throttle_pos 	= e.get_throttle_pos();
	var eng_n1 				= e.get_n1();
	var eng_n2				= e.get_n2();
	var eng_n1_yasim		= e.get_n1_yasim();
	var eng_n2_yasim 		= e.get_n2_yasim();
	e.eng_n1_goal 			= 0;
	e.eng_n2_goal 			= 0;
	
	#e.oilp_norm		= 0;
	#e.oilt_norm 	= 0;
	
	var ats_valve 			= e.get_ats_valve();
	#var ats_valve_oth 		= other_e.get_ats_valve();
	#var ats_valve_oth 		= e.get_ats_valve();  #add by me
	var eng_collector_tank 	= e.get_collector_tk();
	var eng_out_of_fuel 	= 0;
	var time_now 			= getprop("sim/time/elapsed-sec");
	var throttle_value = 0;
	
	e.set_alt_throttle_pos( eng_throttle_pos );

	
	var hydr_press = 0;
	if(e.get_hydraulic_pump_serviceable() and e.get_hyd_res()>40){
		if(eng_n2 >= 60 ){
			hydr_press=(10.78431*eng_n2 + 2250);
		}
		else {
			hydr_press = 50 * eng_n2;
		}
	}
	e.set_hyd_psi(hydr_press);

		
	if(ab1 == 0){
	if(eng_serviceable ){
	throttle_value = getprop("sim/model/K-8/controls/engines/engine/throttle");
	if(ign_on==1 & throttle_value >=0.03){

	        if(eng_n2<=20){
			e.eng_n1_goal = 0;
			}else{
			e.eng_n1_goal = throttle_value == 0.03? n1g: (100 - n1g)*(throttle_value - 0.03)/0.97 + n1g;
			}
			e.eng_n2_goal = throttle_value == 0.03? n2g: (100 - n2g)*(throttle_value - 0.03)/0.97 + n2g;

	}
			
	}
	}else{
	    e.eng_n1_goal = ab_n1;
		e.eng_n2_goal = ab_n2;
	}
	
	if ( getprop("sim/deec_buc") ) {
	# Calculate the core engine speed
		print("throtle.....");
		print(throttle_value);
		var gain = 1.72;
		var tm = 0.2;
		var thau = 1.2;
		var delta_n1 = e.eng_n1_goal - eng_n1;
		eng_n1 += ( delta_n1 * gain * math.exp( -tm / K8.UPDATE_PERIOD ) ) / ( 1 + ( thau / K8.UPDATE_PERIOD ) );
		if ( eng_n1 < 0 ) { eng_n1 = 0; }
		var delta_n2 = e.eng_n2_goal - eng_n2;
		eng_n2 += ( delta_n2 * gain * math.exp( -tm / K8.UPDATE_PERIOD ) ) / ( 1 + ( thau / K8.UPDATE_PERIOD ) );
		if ( eng_n2 < 0 ) { eng_n2 = 0; }
	}	
	
	e.set_out_of_fuel( eng_out_of_fuel );
	
	e.set_n1( eng_n1 );         #set N1 engine RPM
	e.set_n2( eng_n2 );         #set N2 engine RPM

	
	#ignition step
		
	var bat_on = getprop("controls/electric/battery-switch");   # enine ingition only when battery switch is on
    var start_sw = getprop("sim/model/K-8/controls/engines/engine[0]/starter-switch-position");
	
	if(start_sw == 2 and bat_on == 1 ){
	    ign_on = 1;      # engine iginition given
	}
		
	if(ab1 == 0){
    if(ign_on == 1){	
	if(throttle_value <= 0.03){
		 itt_set = 110;
	}else{
		 itt_set = (850 - 110)*(throttle_value - 0.03)/0.97 + 110;
	   }
	   
	   if(throttle_value == 0){             # engine cut off when thottle is to 0 when igintion is on and ignition is also set to zero for off
	        ign_on = 0; 
	   }
	   
    }
	}	
	
	    var gain = 0.05;
		var tm = 0.2;
		var thau = 1.2;
		var delta_itt = itt_set - itt_c_v;
		itt_c_v += delta_itt * gain ;

	    setprop("engines/engine/itt-norm_val",itt_c_v);
		#setprop("engines/engine[0]/oilp-norm",20);
		#print(getprop("engines/engine[0]/oilp-norm"));

	
	# Abnormal Start
		
	if(ab1 == 200){   # Abnormal Senario Number 1, Refer doc for information
	
		print(getprop("light/fire-warning"));
		var c1 = (getprop("sim/model/K-8/controls/engines/engine[0]/throttle")==0); 
		var c2 = (getprop("controls/APU/off-start-switch")==1); 
		var c3 = (getprop("controls/eng-pwr-sw")==0);
		var c4 = getprop("controls/fuel/fuel-pump-sw")==0;

		if(time_out_as != 1){			
			if(getprop("controls/APU/off-start-switch")==1){
				if(!getprop("sim/model/K-8/controls/engines/engine[0]/throttle")==0){
					var demo = AbMsg.new();
					print("invalid one");
					ab1 = 0;
				}		
			}
			if(getprop("controls/eng-pwr-sw")==0){
				if(!(getprop("controls/APU/off-start-switch")==0))
					var demo = AbMsg.new();
					print("invalid two");
					ab1 = 0;
			}
			if(getprop("controls/fuel/fuel-pump-sw")==0 ){
				if(!(getprop("controls/eng-pwr-sw")==0)){
					var demo = AbMsg.new();
					print("invalid three");
					ab1 = 0;
				}				
			}	
			 
			
			if(getprop("sim/model/K-8/controls/engines/engine[0]/throttle")==0){
				if(getprop("controls/APU/off-start-switch")==1){
					if(getprop("controls/eng-pwr-sw")==0){
						if(getprop("controls/fuel/fuel-pump-sw")==0){
							var demo = AbMsg.new(1);  
							print("success");

							ab1 = 0;
						}
					}
				}
				
			}
				
		}
		
	}

			
	if(ab1 == 1){   # Abnormal Senario Number 1, Refer doc for information
				      #  print(""Abort start");

		if(time_out_as != 1){		
		
		    if(getprop("controls/APU/off-start-switch")==1){
				if(!getprop("sim/model/K-8/controls/engines/engine[0]/throttle")==0){
					var demo = AbMsg.new();
					print("invalid one");
					ab1 = 0;
				}		
			}
			
			if(getprop("sim/model/K-8/controls/engines/engine[0]/throttle")==0){
				if(getprop("controls/APU/off-start-switch")==1){
				
                    var demo = AbMsg.new(1);  # successful message
					print("success");
					ab1 = 0;				
					
				}		
			}
					
		}
	}
		
	
	# Abnormal End
	
	K8engines.true_speed();		#ayomi coded 2013.08.21
}
############################################################end of " update_loop "

#ayomi coded 2013.08.21

	var true_speed = func(){
		var ias = getprop("instrumentation/airspeed-indicator/indicated-speed-kt");	
		var altitude = getprop("instrumentation/altimeter/indicated-altitude-ft");
		var tas1 = (ias*0.00002*altitude);
		var tas21 = (altitude*0.0018);
		var tas2 = (30-tas21);
		var tas3 = (tas1 + tas2 + ias);
		#print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&", tas1);
		#print("||||||||||||||||||||||||||||||", tas2);
		#print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@", tas3);
		#setprop("instrumentation/airspeed-indicator/true-speed1",tas1);
		#setprop("instrumentation/airspeed-indicator/true-speed2",tas2);
		setprop("instrumentation/airspeed-indicator/true-speed",tas3);
	}
	
#end

# Controls ################
	var eng_oper_switch_move = func(n, s) {
		# 3 positions 'ENG OPER' switch.
		var e = LeftEngine;
		
		var switch_pos = e.get_switch_pos();
		if ( switch_pos < 2 and s == 1 ) {
			switch_pos += 1;
		} elsif ( s == 0 and switch_pos > 0 ) {
			switch_pos -= 1;
		}
		e.set_switch_pos(switch_pos);
	}
	var throttle_cutoff_mov = func(n) {
		# Throttle from OFF to IDLE
		
		var e = LeftEngine;
		
		if ( e.get_cutoff() ) {	
			e.set_cutoff( 0 );		
			e.set_throttle_pos( 0.03 );				
			
		} elsif ( e.get_throttle_pos() < 0.06 ) {	
			e.set_cutoff(1);
			e.set_throttle_pos( 0 );
		}
	}

	#coded by ayomi on 12th augest 2013
    var eng_autostart = func() {
		# Fast engines autostart.
		setprop ("controls/electric/battery-switch",1);
		setprop ("controls/electric/battery-switch",0);	
		setprop("controls/apu",1);
		setprop ("controls/electric/battery-switch",1);	
		setprop("systems/electrical/volts",29);	
		setprop ("controls/electric/generator",2);
		setprop("controls/electric/power-system-switch",1);
		setprop("controls/APU/fire-switch",1);
		setprop("controls/electric/anti-collision",1);
		
		setprop("K-8-circuit_brake/hydraulic_system_power_switch",1);
		setprop("K-8-circuit_brake/Landing_gear_control_power_switch",1);
		setprop("K-8-circuit_brake/Aileron_trim_tabs_power_switch",1);
		setprop("K-8-circuit_brake/Engine_instument_power_switch",1);
		setprop("K-8-circuit_brake/DEEC_power_switch",1);
		setprop("K-8-circuit_brake/Intercom_power_switch",1);
		setprop("K-8-circuit_brake/MFD_power_switch",1);
		setprop("K-8-circuit_brake/Fuel_system_power_switch",1);
		setprop("K-8-circuit_brake/Integrated_warning_power_switch",1);
		
		setprop("controls/fuel/fuel-pump-sw",1);
		
		#setprop("mfd_border/S_1",1);
		setprop("controls/eng-pwr-sw",1);
		setprop("sim/deec_buc",1);
		setprop("engines/engine/eng_running",1);
		setprop("controls/electric/avionics-switch",1);
		
		setprop("canopy/position-norm",0);
		
		setprop("Radio/transer_switch",1);
		setprop("Radio/transer_switch_2",1);
		setprop("K-8-circuit_brake/Radio_set_power_switch",1);
		
	}

	#####START___HERE
	
	var as_timeout = func(){
		time_out_as = 1;
		print("timeout");
	}
	
	var abrt_strt = func() {
		var er = getprop("engines/engine/eng_running");
		if(er == 1){
			ab1 = 1;			
			#
			ab_n1 = 15*rand()+10;
		    ab_n2 = 45*rand()+10;
            itt_set = 125*rand() + 175;
			#print(e.eng_n1_goal);
			#print(e.eng_n2_goal);
			#print(itt_set);
			settimer(as_timeout, T_OUT); # time out for scenario fail
	    }
	}
	
	var eng_hang = func() {
		var er = getprop("engines/engine/eng_running");
		if(er == 1){
			ab1 = 2;
			var rv = rand();
			if(rv > 0.5){
				itt_set = 0;
			}else{
				itt_set = 890;
			}
						setprop("light/fire-warning",1);
						        print("engine hangup");

			settimer(as_timeout, T_OUT); # time out for scenario fail
			
	    }
		        print("engine hangup");
		settimer(eng_hang, 0.5);
	}	
	
	var fire_on_start = func() {
		var er = getprop("engines/engine/eng_running");
		if(er == 1){
		ab1 = 3;
		
		# indications code come here
		
		
		# indication before this
		
		settimer(as_timeout, T_OUT); # time out for scenario fail
	    }
	}
	
	var cold_run = func() {
		var er = getprop("engines/engine/eng_running");
		if(er == 1){
		ab1 = 4;
		
		# indications code come here
		
		
		# indication before this
		
		settimer(as_timeout, T_OUT); # time out for scenario fail
	    }
	}
	
	#####END___HERE

# Classes ################

# Engine
Engine = {
	new : func (name, number) {
		var obj = { parents : [Engine],
			eng_n1_goal    : 0,
			eng_n2_goal    : 0,
			eng_ignit_time : 0,
			ats_valve_time : 0,
			ign_selected   : 0,
		};
		obj.prop               = props.globals.getNode("engines").getChild("engine", number , 1);
		obj.name               = obj.prop.getNode("name", 1);
		obj.prop.getChild("name", 0, 1).setValue(name);
		obj.n1_yasim           = obj.prop.getNode("n1", 1);
		obj.n2_yasim           = obj.prop.getNode("n2", 1);
		obj.out_of_fuel        = obj.prop.getNode("out-of-fuel", 1);
		obj.fuel_flow_gph      = obj.prop.getNode("fuel-flow-gph", 1);
		obj.fuel_flow_pph      = obj.prop.getNode("fuel-flow-pph", 1);
		obj.fuel_consumed_lbs  = obj.prop.getNode("fuel-consumed-lbs", 1);
		obj.collector_tk       = obj.prop.getNode("collector-tank", 1);

		obj.control_prop       = props.globals.getNode("controls/engines").getChild("engine", number , 1);
		obj.throttle_pos       = obj.control_prop.getNode("throttle", 1);
		obj.cutoff             = obj.control_prop.getNode("cutoff", 1);
		obj.control_fault_prop = obj.control_prop.getNode("faults", 1);
		obj.ignitors_0         = obj.control_prop.getNode("engines-ignitors[0]", 1);
		#obj.ignitors_1         = obj.control_prop.getNode("engines-ignitors[1]", 1);
		obj.control_prop.getChild("engines-ignitors", 0, 1).setBoolValue(0);
		#obj.control_prop.getChild("engines-ignitors", 1, 1).setBoolValue(0);
		obj.serviceable        = obj.control_fault_prop.getNode("serviceable", 1);
		obj.hydraulic_pump_serviceable = obj.control_fault_prop.getNode("hydraulic-pump-serviceable", 1);

		obj.alt_prop           = props.globals.getNode("sim/model/K-8/engines").getChild("engine", number , 1);
		obj.n1                 = obj.alt_prop.getNode("n1", 1);
		obj.n2                 = obj.alt_prop.getNode("n2", 1);

		obj.alt_control_prop   = props.globals.getNode("sim/model/K-8/controls/engines").getChild("engine", number , 1);
		obj.switch_pos         = obj.alt_control_prop.getNode("starter-switch-position", 1);
		obj.alt_throttle_pos   = obj.alt_control_prop.getNode("throttle", 1);

		obj.elec_outputs       = props.globals.getNode("systems/electrical/outputs").getChild("engine", number , 1);
		obj.ignitors_0_volts   = obj.elec_outputs.getNode("engines-ignitors[0]", 1);
		obj.ignitors_1_volts   = obj.elec_outputs.getNode("engines-ignitors[1]", 1);

		obj.ats_valve         = props.globals.getNode("systems/bleed-air").getChild("ats-valve", number , 1);
		obj.hyd_res           = props.globals.getNode("systems/K-8-hydraulics").getChild("hyd-res", number ,1);
		obj.hyd_psi           = props.globals.getNode("systems/K-8-hydraulics").getChild("hyd-psi", number ,1);
		
		obj.ITTlimit	= 8.7;
		obj.itt			= obj.prop.getNode("itt-norm");
		obj.itt_c		= obj.prop.getNode("itt-celcius",1);
		
		
		append(Engine.list, obj);
		return obj;
	},
	
	get_name : func () {
		return me.name.getValue();
	},
	get_index : func () {
		return me.prop.getIndex();
	},
	get_n1_yasim : func () {
		return me.n1_yasim.getValue();
	},
	get_n2_yasim : func () {
		return me.n2_yasim.getValue();
	},
	get_out_of_fuel : func () {
		return me.out_of_fuel.getBoolValue();
	},
	set_out_of_fuel : func (n) {
		me.out_of_fuel.setBoolValue(n);
	},
	get_fuel_flow_gph : func () {
		return me.fuel_flow_gph.getValue();
	},
	set_fuel_flow_pph : func (n) {
		me.fuel_flow_pph.setValue(n);
	},
	get_fuel_consumed_lbs : func () {
		return me.fuel_consumed_lbs.getValue();
	},
	set_fuel_consumed_lbs : func (n) {
		me.fuel_consumed_lbs.setValue(n);
	},
	get_collector_tk : func () {
		return me.collector_tk.getValue();
	},
	set_collector_tk : func (n) {
		me.collector_tk.setValue(n);
	},

	get_throttle_pos : func () {
		return me.throttle_pos.getValue();
	},
	set_throttle_pos : func (n) {
		me.throttle_pos.setValue(n);
	},
	get_cutoff : func () {
		return me.cutoff.getBoolValue();
	},
	set_cutoff : func (n) {
		me.cutoff.setBoolValue(n);
	},
	get_ignitors_0 : func () {
		return me.ignitors_0.getBoolValue();
	},
	set_ignitors_0 : func (n) {
		me.ignitors_0.setBoolValue(n);
	},
	get_ignitors_1 : func () {
		return me.ignitors_1.getBoolValue();
	},
	set_ignitors_1 : func (n) {
		me.ignitors_1.setValue(n);
	},
	get_serviceable : func () {
		return me.serviceable.getBoolValue();
	},
	get_hydraulic_pump_serviceable : func () {
		return me.hydraulic_pump_serviceable.getBoolValue();
	},

	get_n1 : func () {
		return me.n1.getValue();
	},
	set_n1 : func (n) {
		me.n1.setValue(n);
	},
	get_n2 : func () {
		return me.n2.getValue();
	},
	set_n2 : func (n) {
		me.n2.setValue(n);
	},

	get_switch_pos : func () {
		return me.switch_pos.getValue();
	},
	set_switch_pos : func (n) {
		me.switch_pos.setValue(n);
	},
	get_alt_throttle_pos : func () {
		return me.alt_throttle_pos.getValue();
	},
	set_alt_throttle_pos : func (n) {
		me.alt_throttle_pos.setValue(n);
	},

	get_ignitors_0_volts : func () {
		return me.ignitors_0_volts.getValue();
	},
	get_ignitors_1_volts : func () {
		return me.ignitors_1_volts.getValue();
	},

	get_ats_valve : func () {
		return me.ats_valve.getBoolValue();
	},
	set_ats_valve : func (n) {
		me.ats_valve.setBoolValue(n);
	},
	get_hyd_res : func () {
		me.hyd_res.getValue();
	},
	get_hyd_psi : func () {
		return me.hyd_psi.getValue();
	},
	set_hyd_psi : func (n) {
		me.hyd_psi.setValue(n);
	},

	list : [],
};

var as_timeout = func(){
	print("hjsnhfui");
	setprop("controls/emg-light",0);
	as_count = 1;
}
	
setlistener("K-8-circuit_brake/Fuel_system_power_switch", func {
    if (getprop("K-8-circuit_brake/Fuel_system_power_switch")==1){
		setprop("controls/emg-light",1);
		settimer(as_timeout, 2); 
	} else{
		setprop("controls/emg-light",0);
	}     
}, 1, 0);
