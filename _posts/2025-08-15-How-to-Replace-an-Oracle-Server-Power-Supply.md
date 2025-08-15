---
layout: post
title: "How to Replace an Oracle Server X7-2L or X8-2L Power Supply"
excerpt: "The server's redundant power supplies support concurrent maintenance, which enables you to remove and replace a power supply without shutting down the server, provided that the other power supply is online and working."
date: 2025-08-12 10:00:00 +0800
categories: [Oracle, Database]
tags: [ODA Power Supply, X7-2L, X8-2L, power supply fails, oracle]
image: /assets/images/posts/How-to-Replace-an-Oracle-Server-Power-Supply.jpg
---

## Goal  
How to Replace an Oracle Server X7-2L or X8-2L Power Supply.  

## Solution  
DISPATCH INSTRUCTIONS  

### WHAT SKILLS ARE REQUIRED?:  
No special skills required, Customer Replaceable Unit (CRU) procedure  
TIME ESTIMATE: 15 minutes  
TASK COMPLEXITY: 0  

### REMOVAL/REPLACEMENT INSTRUCTIONS:  
PROBLEM OVERVIEW: An Oracle Server X7-2L or X8-2L Power Supply needs replacement  

### WHAT STATE SHOULD THE SYSTEM BE IN TO BE READY TO PERFORM THE RESOLUTION ACTIVITY? :  
The server's redundant power supplies support concurrent maintenance, which enables you to remove and replace a power supply without shutting down the server, provided that the other power supply is online and working.  

### WHAT ACTIONS ARE REQUIRED?:  
Caution - If a power supply fails and you do not have a replacement available, leave the failed power supply installed to ensure proper airflow in the server.  

#### 1.Confirm the Power Supply failure and it's location.  
Confirm which Power Supply is to be replaced. When looking at the server from the rear PS0 is on the bottom and PS1 is on the top.
If the specific power supply to be replaced is not yet known check the status LEDs to identify the failed Power Supply. A failed PSU should have it's amber "service required" LED lit. A working PSU will only have it's green "OK" LED lit.
If the service is to be performed while the system is up and running confirm that the second PSU is online and working properly.
If a replacement Power Supply is not yet available leave the failed supply in place to provide proper airflow within the system until the replacement is available. You may notice that the failed Power Supply's fans are still turning. This is ok and the power supply may be removed while the fans are still spinning.  

#### 2. Remove the Power Supply  
Gain access to the rear of the server where the faulty power supply is located.  
If the cable management arm (CMA) is installed, disconnect the connector D on the left-side by pressing the green release tab on the slide-rail latching bracket toward the left and slide the connector D out of the left slide-rail.  
Rotate the cable management arm out of the way so that you can access the power supply, remove velcro straps from cables if necessary to avoid removing any other cables accidentally during maintenance actions. To avoid damaging the CMA do not allow the CMA to hang under it's own weight. (If necessary extend the server approximately 20 cm (8 inches) out of the front of the rack to gain access to the power supply)  
Disconnect the power cord from the failed power supply.  
If the power supply is being replaced hot while the system is up then care should be taken to make sure that AC power to the second power supply is not interrupted during the removal of the failed unit. Check to make sure that the AC input is properly seated in the second unit and if necessary hold in it's AC cord while performing the next steps to ensure that the AC input is not interrupted while removing the failed unit.  
Grasp the power supply handle and push the power supply latch to the left.  
Pull the power supply out of the chassis and set it aside on an antistatic mat.  

#### 3. Install the replacement Power Supply  
Remove the replacement power supply from its packaging and place it on an antistatic mat.  
Align the power supply with the empty power supply bay.  
Slide the power supply into the bay until it is fully seated. (an audible click will be heard when it is fully seated)  
Reconnect the power cord to the power supply.  
Verify that the amber LED on the replaced power supply and the Service Required LEDs on the chassis are not lit.  

#### 4.Return the Server to operation  
If you pulled the server out of the rack to make it easier to remove the power supply, push the server into the rack until the slide-rail locks (on the front of the server) engage the slide-rail assemblies.  
If a cable management arm is installed and was removed to access the power supply reattach the CMA clip to the slide rail.  
Check all power and data cables to ensure that no connections were disturbed during the service.  
Verify that the Power/OK indicator led lights steady on and that system is operating properly.  
If the power supply in slot 0 has been replaced in a "hot-swap" process (ie. the PSU was replaced while the system is up and running) then the ILOM should be reset so that the system is prompted to check the TLI data containers and the psnc values can be copied over to the new supply. (if more than one part was replaced at the same time the automatic copying of psnc data may not happen so replacing multiple frus containing TLI data simultaneously should not be done). To reset the ILOM from the command line interface execute "reset /SP" as shown in the example below. (From the WebGUI go to the "ILOM Administration" - "Maintenance" window and select the "Reset SP" tab to reset the SP)  
```
 -> reset /SP
Are you sure you want to reset /SP (y/n)? y
Performing reset on /SP
```

REFERENCE INFORMATION:  
Oracle Server X7-2L Documentation:  
http://docs.oracle.com/cd/E72463_01/index.html  
Oracle Server X8-2L Documentation  
https://docs.oracle.com/cd/E93361_01/index.html  
