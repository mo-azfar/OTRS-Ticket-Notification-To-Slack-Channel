# OTRS-Ticket-Notification-To-Slack-Channel
- Built for OTRS CE v 6.0.x
- Send a notification to Slack Channel upon ticket action. E.g: TicketQueueUpdate  

		Used CPAN Module:
		
		JSON::MaybeXS; #yum install -y perl-JSON-MaybeXS
		LWP::UserAgent;  #yum install -y perl-LWP-Protocol-https
		HTTP::Request::Common;	
  
    
1. Create incoming webhook (app) and get the Webhook URL for each channel for each ticket queue. Reference: https://api.slack.com/messaging/webhooks#getting_started  

2. Update the Webhook Url at System Configuration > TicketSlack::Queue

		Queue 1 Name => Slack Channel Webhook 1  
		Queue 2 Name => Slack Channel Webhook 2  
		Queue 3 Name => Slack Channel Webhook 3  
		
		Example:  
		Misc => https://hooks.slack.com/services/TDdsfL09K/B011Xxxxxxxxxxxxxx  
		and so on..

  
3. Admin must create a new Generic Agent (GA) with option to execute custom module.

		[Mandatory][Name]: Up to you.
		[Mandatory][Event Based Execution] : Mandatory. Up to you. Example, TicketQueueUpdate for moving ticket to another queue
		[Optional][Select Ticket]: Optional. Up to you.
		[Mandatory][Execute Custom Module] : Module => Kernel::System::Ticket::Event::TicketSlack
	
		[Mandatory][Param 1 Key] : Text1  
		[Mandatory][Param 1 Value] : Text to be sent to the channel.
		[Optional][Param 2 Key] : Text2  
		[Optional][Param 2 Value] : Additional text to be sent to the channel.

  
[![download.png](https://i.postimg.cc/KvPLgkSG/download.png)](https://postimg.cc/56tjht2T)
