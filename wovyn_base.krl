ruleset wovyn_base {
  meta {
    use module io.picolabs.lesson_keys
    use module sensor_profile
    use module temperature_store
    use module io.picolabs.subscription alias subscriptions
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "post", "type": "test",
                              "attrs": [ "temp", "baro" ] } ] }
  
  }
 
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      timestamp = time:now()
      gthing = event:attrs["genericThing"]
      temp = event:attrs["genericThing"]["data"]["temperature"][0]["temperatureF"].klog("temp: ");
    }
    if gthing != null then
      send_directive("success", {"results": gthing})
    
    fired {
      raise wovyn event "new_temperature_reading"
      attributes {"timestamp": timestamp, "temp" : temp}
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attrs["temp"]
      temperature_threshold = sensor_profile:threshold()["threshold"]
    }
    
    if (temp > temperature_threshold) then
    send_directive("Threshold Violation!!!", {"temp": temp})
    
    fired {
      raise wovyn event "threshold_violation"
      attributes event:attrs
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    foreach subscriptions:established("Tx_role","manager") setting (manager)
    pre {
      temp = event:attrs["temp"]
      temperature_threshold = sensor_profile:threshold()["threshold"]
      to = sensor_profile:smsNumber()["smsNumber"]
      from = "16784878093"
      message = "The current tempeture of " + temp + " is above the threshold of " + temperature_threshold + "!" 
    }
    event:send ({
      "eci" : manager{"Tx"},
      "eid" : "Temperature violation to manager",
      "domain" : "sensor",
      "type" : "threshold_violation",
      "attrs" : {
        "to" : to,
        "from" : from,
        "message" : message
      }
    })
    //twilio:send_sms(to, from, message)
  }
  
  rule generate_report {
    select when sensor build_report
    foreach subscriptions:established("Tx_role","manager") setting (manager)
    pre {
      results = temperature_store:temperatures().defaultsTo(["No Temps"])
      picoId = meta:picoId
      reportId = event:attrs["reportId"]
    }
    event:send ({
      "eci" : manager{"Tx"},
      "eid" : "Returning report",
      "domain" : "sensor",
      "type" : "report_generated",
      "attrs" : {
        "reportId" : reportId,
        "results" : results,
        "picoId" : picoId
      }
    })
    
  }
  
}