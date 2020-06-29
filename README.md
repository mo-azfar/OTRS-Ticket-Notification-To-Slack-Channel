# OTRS-Ticket-Notification-To-Slack-Channel
- Built for OTRS CE v 6.0.x
- Send a notification to Slack Channel upon ticket action. E.g: TicketQueueUpdate  
- **Require [CustomMessage](https://github.com/mo-azfar/OTRS-CustomMessage-API) API**

1. Create incoming webhook (app) and get the Webhook URL for each channel. Reference: https://api.slack.com/messaging/webhooks#getting_started  

2. Update the Webhook Url at System Configuration > TicketSlack::Queue

Queue 1 Name => Slack Channel Webhook 1  
Queue 2 Name => Slack Channel Webhook 2  
Queue 3 Name => Slack Channel Webhook 3  
Misc => https://hooks.slack.com/services/TDdsfL09K/B011Xxxxxxxxxxxxxx  
and so on..

3. Admin must create a new Generic Agent (GA) with option to execute custom module.

Execute Custom Module => Module => Kernel::System::Ticket::Event::TicketSlack
	
[MANDATORY PARAM]

Param 1 Key => Text1  
Param 1 Value => *Text body to be sent to the channel.  
#Also support OTRS ticket TAG only.  
#Also support <OTRS_OWNER_UserFullname>, <OTRS_RESPONSIBLE_UserFullname> and <OTRS_CUSTOMER_UserFullname> tag.  
					 
[OPTIONAL PARAM]
	
Param 2 Key => Text2  
Param 2 Value => *Additional text to be sent to the channel.  
#Also support OTRS ticket TAG only. bold, newline must be in HTML code.  
#Also support <OTRS_NOTIFICATION_RECIPIENT_UserFullname>, <OTRS_OWNER_UserFullname>, <OTRS_RESPONSIBLE_UserFullname> and <OTRS_CUSTOMER_UserFullname> tag.


[![download.png](https://i.postimg.cc/KvPLgkSG/download.png)](https://postimg.cc/56tjht2T)
