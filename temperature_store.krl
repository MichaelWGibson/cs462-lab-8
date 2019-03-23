ruleset temperature_store {
  meta {
    
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provide temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "post", "type": "test",
                              "attrs": [ "temp", "baro" ] } ] }
                              
    temperatures  = function() {
      ent:temps.defaultsTo("No Temps")
    }
    
    threshold_violations  = function() {
      ent:violations
    }
    
    inrange_temperatures = function() {
      ent:temps.difference(ent:violations)
    }
    
  }
 
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      timestamp = event:attrs["timestamp"]
      temp = event:attrs["temp"]
    }
    
    always {
      ent:temps := ent:temps.defaultsTo([]).append({"timestamp": timestamp, "temp" : temp})
    }
  }
  
  rule collect_threshold_violations  {
    select when wovyn threshold_violation
    pre {
      timestamp = event:attrs["timestamp"]
      temp = event:attrs["temp"]
    }
    
    always {
      ent:violations := ent:violations.defaultsTo([]).append({"timestamp": timestamp, "temp" : temp})
    }
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    always {
      ent:violations := [];
      ent:temps := [];
    }
  }
  
}