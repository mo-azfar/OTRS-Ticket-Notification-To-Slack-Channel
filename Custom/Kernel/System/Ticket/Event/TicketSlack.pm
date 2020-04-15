# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
#Send a notification to Slack Channel upon ticket action. E.g: TicketQueueUpdate
#
package Kernel::System::Ticket::Event::TicketSlack;

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);

use Data::Dumper;
use Fcntl qw(:flock SEEK_END);
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::MaybeXS;
#yum install -y perl-LWP-Protocol-https
#yum install -y perl-JSON-MaybeXS

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::Log',
	'Kernel::System::Group',
	'Kernel::System::Queue',
	'Kernel::System::User',
	
);

=head1 NAME

Kernel::System::ITSMConfigItem::Event::DoHistory - Event handler that does the history

=head1 SYNOPSIS

All event handler functions for history.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DoHistoryObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::Event::DoHistory');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    
	#my $parameter = Dumper(\%Param);
    #$Kernel::OM->Get('Kernel::System::Log')->Log(
    #    Priority => 'error',
    #    Message  => $parameter,
    #);
	
	# check needed param
    if ( !$Param{TicketID} || !$Param{New}->{Text1} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID || Text1 (Param and Value) for this operation',
        );
        return;
    }

    #my $TicketID = $Param{Data}->{TicketID};  ##This one if using sysconfig ticket event
	my $TicketID = $Param{TicketID};  ##This one if using GenericAgent ticket event
	my $Text1 = $Param{New}->{'Text1'}; ##This one if using GenericAgent ticket event
    
	if ( defined $Param{New}->{'Text2'} ) { $Text1 = "$Text1. $Param{New}->{Text2}"; }
	
	my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
	
	# get ticket content
	my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID ,
		UserID        => 1,
		DynamicFields => 1,
		Extended => 0,
    );
	
	return if !%Ticket;
	
	#print "Content-type: text/plain\n\n";
	#print Dumper(\%Ticket);
	
	my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
	my $UserObject = $Kernel::OM->Get('Kernel::System::User');
	my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
	my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
	my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
	my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
	
	#Get	queue id based on ticket queue name
	my $QueueID = $QueueObject->QueueLookup( Queue => $Ticket{Queue} );
	#Get group id based on queue id 
	my $GroupID = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
	
	# prepare owner fullname based on Text1 tag
    if ( $Text1 =~ /<OTRS_OWNER_UserFullname>/ ) {
		my %OwnerPreferences = $UserObject->GetUserData(
        UserID        => $Ticket{OwnerID},
        NoOutOfOffice => 0,
    );
	
	for ( sort keys %OwnerPreferences ) {
        $Text1 =~ s/<OTRS_OWNER_UserFullname>/$OwnerPreferences{UserFullname}/g;
		}   
    }
	
	# prepare responsible fullname based on Text1 tag
    if ( $Text1 =~ /<OTRS_RESPONSIBLE_UserFullname>/ ) {
		my %ResponsiblePreferences = $UserObject->GetUserData(
        UserID        => $Ticket{ResponsibleID},
        NoOutOfOffice => 0,
    );
	
	for ( sort keys %ResponsiblePreferences ) {
        $Text1 =~ s/<OTRS_RESPONSIBLE_UserFullname>/$ResponsiblePreferences{UserFullname}/g;
		}   
    }
	
	# prepare customer fullname based on text1 tag
    if ( $Text1 =~ /<OTRS_CUSTOMER_UserFullname>/ ) {
		my $FullName = $CustomerUserObject->CustomerName( UserLogin => $Ticket{CustomerUserID} );
		$Text1 =~ s/<OTRS_CUSTOMER_UserFullname>/$FullName/g;
    };
	
	#change to < and > for text1 tag
	$Text1 =~ s/&lt;/</ig;
	$Text1 =~ s/&gt;/>/ig;	
	
	#get data based on text1 tag
	my $RecipientText1 = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent::Transport::Email')->_ReplaceTicketAttributes(
        Ticket => \%Ticket,
        Field  => $Text1,
    );
	
	my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');
	#strip all html tag 
	my $MessageText1 = $HTMLUtilsObject->ToAscii( String => $RecipientText1 );
	
	my $HttpType = $ConfigObject->Get('HttpType');
	my $FQDN = $ConfigObject->Get('FQDN');
	my $ScriptAlias = $ConfigObject->Get('ScriptAlias');
	
	my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime', ObjectParams => { String   => $Ticket{Created},});
	my $DateTimeString = $DateTimeObject->Format( Format => '%Y-%m-%d %H:%M' );
	my $ticket_link = $HttpType.'://'.$FQDN.'/'.$ScriptAlias.'index.pl?Action=AgentTicketZoom;TicketID='.$TicketID;
	
	my $SlackWebhookURL;
    my %SlackWebhookURLs = %{ $ConfigObject->Get('TicketSlack::Queue') };
	
	for my $WebHookQueue ( sort keys %SlackWebhookURLs )   
	{
		next if $Ticket{Queue} ne $WebHookQueue;
		$SlackWebhookURL = $SlackWebhookURLs{$WebHookQueue};
        # error if queue is defined but Webhook URLis empty
        if ( !$SlackWebhookURL )
        {
            $LogObject->Log(
                Priority => 'notice',
                Message  => "No WebhookURL defined for Queue $Ticket{Queue}"
            );
            return;
        }
  	    
		my $params = {
        "blocks"=> [
		{
			"type" => "section",
			"text" => {
				"type" => "mrkdwn",
				"text" => "*<$ticket_link|OTRS#$Ticket{TicketNumber}>*\n\n$MessageText1"
			}
		},
		{
			"type" => "section",
			"fields" => [
				{
					"type" => "mrkdwn",
					"text" => "*Created:*\n$DateTimeString"
				},
				{
					"type" => "mrkdwn",
					"text" => "*Queue:*\n$Ticket{Queue}"
				},
				{
					"type" => "mrkdwn",
					"text" => "*Service:*\n$Ticket{Service}"
				},
				{
					"type" => "mrkdwn",
					"text" => "*Priority:*\n$Ticket{Priority}"
				}
			]
		}
		]
		};
			
		my $ua = LWP::UserAgent->new;        
		
		my $response = $ua->request(
			POST $SlackWebhookURL,
			Content_Type    => 'application/json',
			Content         => JSON::MaybeXS::encode_json($params)
		)	;
		
		my $content  = $response->decoded_content();
		my $resCode =$response->code();
		
		my $result;
		if ($resCode eq "200")
		{
		$result="Success";
		}
		else
		{
		$result=$content;
		}
		
		## result should write to ticket history
		my $TicketHistory = $TicketObject->HistoryAdd(
        TicketID     => $TicketID,
        QueueID      => $QueueID,
        HistoryType  => 'SendAgentNotification',
        Name         => "Slack Notification to $Ticket{Queue} : $result",
        CreateUserID => 1,
		);			
				
	}

}

1;

