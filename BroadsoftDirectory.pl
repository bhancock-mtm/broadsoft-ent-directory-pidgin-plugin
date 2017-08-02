use Purple;
#use '/usr/lib/purple-2/perl/Purple.pm';

my $SignOnTimeStamp = 0;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "Broadsoft Directory Plugin",
    version => "0.1.2",
    summary => "Plugin to alias buddies based on their Broadsoft directory name.",
    description => "Plugin to alias buddies based on their Broadsoft directory name.",
    author => "Bob Hancock <bobhancock205\@gmail.com>",
    url => "http://pidgin.im",
    load => "plugin_load",
    unload => "plugin_unload"
);

sub SetVars {
  Purple::Debug::info("BS Dir Plugin", "Entering SetVars sub.\n");
  ####################
  #User Specific Vars#
  ####################
  #Please edit these to reflect your information
  #Your Broadsoft Username in the format of <phone_number>@mymtm.us
  $UN = '5555551234\@provider.com';
  #Your Broadsoft password. This will be used to login to the directory service.
  $PW = "password";
  #Broadsoft directory server FQDN
  $Server = "my.xspserver.com";
  #Your Broadsoft IM ID (impId) with a trailing /
  $EnabledAccountName = '5555551234@im.provider.com/';
  #Toggle look up buddy info at buddy-sign-on. This may slow down logging in to you IM account
  $LookUpBuddyAtSignOn = 1;
  #Time in seconds after an account is logged in to supress the look up of joining buddies.
  #This is to prevent having to look up all buddies when an account logs in creting a delay
  $SignOnDelay = 5;
  #Toggle tagging the looked up name with a (d) for debugging purposes
  $DebugFlag = 0;
  ########################
  #End User Specific Vars#
  ########################
  Purple::Debug::info("BS Dir Plugin", "Completing SetVars. Exiting sub.\n");
}

sub plugin_init {
    return %PLUGIN_INFO;
}

sub plugin_load {
    my $plugin = shift;
    Purple::Debug::info("BS Dir Plugin", "plugin_load() - Broadsoft Directory Plugin Loading Begun.\n");
    Purple::Debug::info("BS Dir Plugin", "Loading vars.\n");
    SetVars();
    $data = "";
    # A pointer to the handle to which the signal belongs needed by the callback function
    Purple::Debug::info("BS Dir Plugin", "Getting accounts handle.\n");
    $accounts_handle = Purple::Accounts::get_handle();
    Purple::Debug::info("BS Dir Plugin", ($accounts_handle ? "ok." : "fail.") . "\n");
    #Purple::Debug::info("BS Dir Plugin", "Account log = " . $accounts_handle->get_log . "\n");
    #Purple::Debug::info("BS Dir Plugin", "Account user info = " . $accounts_handle->get_user_info . "\n");
    Purple::Debug::info("BS Dir Plugin", "Getting connections handle.\n");
    $connections_handle = Purple::Connections::get_handle();
    Purple::Debug::info("BS Dir Plugin", ($connections_handle ? "ok." : "fail.") . "\n");
    Purple::Debug::info("BS Dir Plugin", "Getting conversations handle.\n");
    $conversations_handle  = Purple::Conversations::get_handle();
    Purple::Debug::info("BS Dir Plugin", ($conversations_handle ? "ok." : "fail.") . "\n");
    Purple::Debug::info("BS Dir Plugin", "Getting buddylist handle.\n");
    $blist_handle = Purple::BuddyList::get_handle();
    Purple::Debug::info("BS Dir Plugin", ($blist_handle ? "ok." : "fail.") . "\n");
    
    if ($LookUpBuddyAtSignOn == 1) {
      Purple::Debug::info("BS Dir Plugin", "Connecting to signal - buddylist buddy-sign-on.\n");
      Purple::Signal::connect($blist_handle, "buddy-signed-on", $plugin, \&SigBuddy, $data);
    }
    
    Purple::Debug::info("BS Dir Plugin", "Connecting to signal - buddylist buddy-added.\n");
    Purple::Signal::connect($blist_handle, "buddy-added", $plugin, \&SigBuddy, $data);
    
    Purple::Debug::info("BS Dir Plugin", "Connecting to signal - conversation conversation-created.\n");
    Purple::Signal::connect($conversations_handle, "conversation-created", $plugin, \&SigNewConvo, $data);
    
    #Purple::Debug::info("BS Dir Plugin", "Connecting to signal - account account-connecting.\n");
    #Purple::Signal::connect($accounts_handle, "account-connecting", $plugin, \&SigAcctConnecting, $data);
    
    Purple::Debug::info("BS Dir Plugin", "Connecting to signal - account account-signed-on.\n");
    Purple::Signal::connect($accounts_handle, "account-signed-on", $plugin, \&SigAcctSignedOn, $data);
    
    Purple::Debug::info("BS Dir Plugin", "plugin_load() - Broadsoft Directory Plugin Load Complete.\n");
}

sub plugin_unload {
    my $plugin = shift;
    Purple::Debug::info("BS Dir Plugin", "plugin_unload() - Broadsoft Directory Plugin Unloaded.\n");
    $account_name = '2059786027@im.mymtm.us/';
    $protocol = Purple::Account::get_protocol_id($account_name);
    $protocol = 'prpl-jabber';
    Purple::Debug::info("BS Dir Plugin", "plugin_load() - $account_name - $protocol - Test Plugin Loaded.\n");
    $account = Purple::Accounts::find($account_name, $protocol);
    Purple::Debug::info("BS Dir Plugin", ($account ? "ok." : "fail.") . "\n");
    $accounts_handle = Purple::Accounts::get_handle();
    $connections_handle = Purple::Connections::get_handle();
    $conversations_handle  = Purple::Conversations::get_handle();
    $blist_handle = Purple::BuddyList::get_handle();
    Purple::Debug::info("BS Dir Plugin", "plugin_unload() - Completed.\n");
}

sub SigAcctSignedOn {
  Purple::Debug::info("BS Dir Plugin", "Starting SigAcctSignedOn sub.\n");
  $SignOnTimeStamp = time();
  Purple::Debug::info("BS Dir Plugin", "Set SignOnTimeStamp to $SignOnTimeStamp.\n");
  Purple::Debug::info("BS Dir Plugin", "Ending SigAcctSignedOn sub.\n");
}

sub SigBuddy {
  # The signal data and the user data come in as arguments
  Purple::Debug::info("BS Dir Plugin", "Signal caught for buddy-added or buddy-sign-on entering sub SigBuddy\n");
  Purple::Debug::info("BS Dir Plugin", "Calling Sub to set vars.\n");
  my ($buddy) = @_;
  SetVars();
  $now = time();
  Purple::Debug::info("BS Dir Plugin", "Checking supression timing. ". ($now - $SignOnDelay) ." > ".$SignOnTimeStamp."\n");
  if (($now - $SignOnDelay) > $SignOnTimeStamp) {
    Purple::Debug::info("BS Dir Plugin", "Enabled account is $EnabledAccountName\n");
    Purple::Debug::info("BS Dir Plugin", "Getting buddy data.\n");
    $account = $buddy->get_account();
    Purple::Debug::info("BS Dir Plugin", "Buddy Account Name " . $account->get_username() . "\n");
    if ($account->get_username eq $EnabledAccountName) {
        Purple::Debug::info("BS Dir Plugin", "Plugin is active for this account\n");
        my $Info = GetInfoFromDirectory($buddy->get_name(),$Server,$UN,$PW);
        if (!$Info) {
            return 1;
        }
        else {
            Purple::Debug::info("BS Dir Plugin", "Getting buddy handle\n");
            $buddy_handle = Purple::Find::buddy($account,$buddy->get_name());
            Purple::Debug::info("BS Dir Plugin", ($buddy_handle ? "ok." : "fail.") . "\n");
            Purple::Debug::info("BS Dir Plugin", "Setting buddy alias to ".$Info->{"Name"}."\n");
            #$buddy_handle->alias_buddy($Info->{"Name"});
            Purple::BuddyList::alias_buddy($buddy_handle,$Info->{"Name"});
        }
    }
    else {
        Purple::Debug::info("BS Dir Plugin", "Plugin not enabled for this account. Exiting sub.\n");
        return 1;
    }
  }  
  else {
        Purple::Debug::info("BS Dir Plugin", "Lookup for buddy join supressed base on delay time of $SignOnDelay\n");
  }
}

sub SigNewConvo {
  # The signal data and the user data come in as arguments
  Purple::Debug::info("BS Dir Plugin", "Signal caught for conversation-created entering sub SigNewConvo\n");
  Purple::Debug::info("BS Dir Plugin", "Calling Sub to set vars.\n");
  SetVars();
  Purple::Debug::info("BS Dir Plugin", "Enabled account is $EnabledAccountName\n");
  my ($convo) = @_;
  Purple::Debug::info("BS Dir Plugin", "Getting conversation data.\n");
  Purple::Debug::info("BS Dir Plugin", "Conversation Title " . $convo->get_title() . "\n");
  Purple::Debug::info("BS Dir Plugin", "Conversation Name " . $convo->get_name() . "\n");
   Purple::Debug::info("BS Dir Plugin", "Fetching account for conversation " . $convo->get_account() . "\n");
  Purple::Debug::info("BS Dir Plugin", "Fetching name from directory for " . $convo->get_name() . "\n");
  $account = $convo->get_account();
  Purple::Debug::info("BS Dir Plugin", "Buddy Account Name " . $account->get_username() . "\n");
  if ($account->get_username eq $EnabledAccountName) {
    Purple::Debug::info("BS Dir Plugin", "Plugin is active for this account\n");
    Purple::Debug::info("BS Dir Plugin", "Call GetInfo with params - (".$convo->get_name().",$Server,$UN,$PW)\n");
    my $Info = GetInfoFromDirectory($convo->get_name(),$Server,$UN,$PW);
    Purple::Debug::info("BS Dir Plugin", "Directory look up for " . $convo->get_name() . " returned name - " . $Info->{"Name"} . " number - " .$Info->{"Number"}. "\n");
    if (!$Info) {
      $convo->update;
    }
    else {
      Purple::Debug::info("BS Dir Plugin", "Getting buddy handle\n");
      $buddy_handle = Purple::Find::buddy($account,$convo->get_name());
      Purple::BuddyList::alias_buddy($buddy_handle,$Info->{"Name"});
      Purple::Debug::info("BS Dir Plugin", "Calling seet convo title to " . $Info->{"Name"} . "\n");
	  if (eval{$buddy_handle->get_local_alias()}) {
        Purple::Debug::info("BS Dir Plugin", "I think this user is in the buddy list. Settting title with name only\n");
        $convo->set_title($Info->{"Name"});
	  }
	  else {
        Purple::Debug::info("BS Dir Plugin", "I don't think this user is in the buddy list. Setttint title with name and number\n");
        $convo->set_title($Info->{"Name"} ." (". $Info->{"Number"} .")");
	  }
    }
  }
  else {
    Purple::Debug::info("BS Dir Plugin", "Plugin not enabled for this account - " .$account->get_username(). ". Enabled for account - " .$EnabledAccountName. ". Exiting sub.\n");
    return 1;
  }
}

sub GetInfoFromDirectory {
  Purple::Debug::info("BS Dir Plugin", "Inside GetNameFromDirectory sub\n");
  my ($UserID, $Server, $UN, $PW) = @_;
  Purple::Debug::info("BS Dir Plugin", "UserID was passed as $UserID. Let's make sure it's clean.\n");
  my @id;
  if ($UserID =~ m/\//) {
    @id = split(/\//,$UserID);
    Purple::Debug::info("BS Dir Plugin", "ID0 is @id[0]\n");
    Purple::Debug::info("BS Dir Plugin", "ID1 is @id[1]\n");
    $UserID = @id[0];
    Purple::Debug::info("BS Dir Plugin", "UserID was bad. We cleaned it up to $UserID\n");
  }
  else {
    Purple::Debug::info("BS Dir Plugin", "UserID was clean as passed in.\n");
  }
  my $URL = "https://" .$Server. "/com.broadsoft.xsi-actions/v2.0/user/" .$UN. "/directories/Enterprise?impId=" . $UserID;
  Purple::Debug::info("BS Dir Plugin", "Query Dir - $URL\n");
  Purple::Debug::info("BS Dir Plugin", "Trying command: curl -u $UN:$PW $URL\n");
  my $xml = `curl -s --connect-timeout 2 -m 5 -u $UN:$PW $URL` || return 0;
  Purple::Debug::info("BS Dir Plugin", "Curl command completed\n");
  if ($xml eq '') {
    Purple::Debug::info("BS Dir Plugin", "Directory query came back empty. Exiting sub.\n");
    return 0;
  }
  my @numrec = split("<numberOfRecords>",$xml);
  my @fname = split("<firstName>",$xml);
  my @lname = split("<lastName>",$xml);
  my @number = split("<number>",$xml);
  my @extension = split("<extension>",$xml);
  my @numre = split("</numberOfRecords>",@numrec[1]);
  my @fnam = split("</firstName>",@fname[1]);
  my @lnam = split("</lastName>",@lname[1]);
  my @num = split("</number>",@number[1]);
  my @exi = split("</extension>",@extension[1]);
  Purple::Debug::info("BS Dir Plugin", "Records returned by query - @numre[0].\n");
  my $numberofrecords = @numre[0];
  if ($numberofrecords < 1) {
    Purple::Debug::info("BS Dir Plugin", "Less than 1 record returned - $numberofrecords . Exiting sub.\n");
    return 0;
  }
  my $firstName = @fnam[0];
  my $lastName = @lnam[0];
  my $number = @num[0];
  my $extension = @ext[0];
  my $return;
  if ($DebugFlag == 1) {
    Purple::Debug::info("BS Dir Plugin", "Debug flag not set. Setting name to " . $firstName . " " . $lastName . " (d)\n");
    $return->{"Name"} = $firstName . " " . $lastName . " (d)"; 
  }
  else {
    Purple::Debug::info("BS Dir Plugin", "Debug flag not set. Setting name to " .$firstName . " " . $lastName . "\n");
    $return->{"Name"} = $firstName . " " . $lastName; 
  } 
  $return->{"Number"} = $number;
  $return->{"Extension"} = $extension;
  Purple::Debug::info("BS Dir Plugin", "Completed directory fetch. Exiting sub and returning info.\n");
  return $return;
}
