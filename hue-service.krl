ruleset hue-service {
  meta {
    name "Hue Light Service"
    description <<
Hue Light Service
    >>
    author "Phil Windley"

    logging off

    provides turn_bulb_on, turn_bulb_off, control_bulb, flash_bulb, set_bulb_hsl, control_group, all_on_in_group, all_off_in_group

    use module a169x676 alias pds
    use module a169x701 alias CloudRain
  
  }

  dispatch { 
  }

  global {

    get_config_value = function (name) {
      pds:get_setting_data_value("a16x165", name);
    };

    get_base_url = function() {
        hub_ip_addr = get_config_value("hub_ip_addr") || '127.0.0.1';
    	hub_port = get_config_value("hub_port") || '80';
	app_key = get_config_value("app_key") || 'no_api_key_found';
        "http://"+hub_ip_addr+ ":" + hub_port +"/api/"+app_key;
    }	

    control_bulb = defaction(bulb_id, command) {
      bulb_url = get_base_url() + "/lights/#{bulb_id}/state";
      //bulb_url = "http://requestb.in/s1qagus1";
      http:put(bulb_url) with
       body = command and 
       headers = {"content-type": "application/json"}
    }

    turn_bulb_on = defaction(bulb_id) {
      action = {"on" : true};
      control_bulb(bulb_id, action);       
    }

    turn_bulb_off = defaction(bulb_id) {
      action = {"on" : false};
      control_bulb(bulb_id, action);       
    }

    flash_bulb = defaction(bulb_id) {
      action = {"alert" : "select"};
      control_bulb(bulb_id, action);       
    }
    
    // h is hue value between 0 and 360
    // s is saturation 0..1
    // l is light 0..1
    set_bulb_hsl = defaction(bulb_id, h, s, l) {
      settings = {
         "bri": math:floor(l * 255),
         "hue": (h % 360) * 182,
         "sat": math:floor(s * 255),
         "on": true
       };
       control_bulb(bulb_id, settings);		
     }

    // cs is color temperature 0..500
    // l is light 0..1
    set_bulb_white = defaction(bulb_id, ct, l) {
      settings = {
         "bri": math:floor(l * 255),
         "ct": ct,
         "on": true
       };
       control_bulb(bulb_id, settings);		
     }

//------------- group actions -------------------

    control_group = defaction(group_id, command) {
       bulb_url = get_base_url() + "/groups/#{group_id}/action";
       //bulb_url = "http://requestb.in/s1qagus1";
       http:put(bulb_url) with
        body = command and 
	headers = {"content-type": "application/json"}
     }

     all_on_in_group = defaction(group_id) {
       control_group(group_id, {"on": true});
     }

     all_off_in_group = defaction(group_id) {
       control_group(group_id, {"on": false});
     }


  }


  // ----------------------------------- experiment ------------------------------------------------
  rule lights {
    select when explicit office_lights
    pre {
      state = event:attr("state") eq "on" => true | false;
      group_id = 0;
    }
    control_group(group_id, {"on": state});
  }



  // ----------------------------------- configuration setup ---------------------------------------
  rule load_app_config_settings {
    select when web sessionLoaded
    pre {
      schema = [
        {
          "name"     : "hub_ip_addr",
          "label"    : "Hue Hub IP Address",
          "dtype"    : "text"
        },
        {
          "name"     : "hub_port",
          "label"    : "Hue Hub IP Port",
          "dtype"    : "text"
        },
        {
          "name"     : "app_key",
          "label"    : "Hue Hub App Key",
          "dtype"    : "text"
        }
      ];
      data = {
        "hub_ip"  : "127.0.0.1",
	"hub_port" : "",
	"app_key" : "none"
      };
    }
    always {
      raise pds event new_settings_schema
        with setName   = meta:rulesetName()
        and  setRID    = meta:rid()
        and  setSchema = schema
        and  setData   = data
        and  _api = "sky";
    }
  }
}