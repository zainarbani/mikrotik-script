#!rsc by RouterOS
# RouterOS script: Twilio Whatsapp API
# version: v0.1-2022-12-22
# authors: zainarbani

##########################VARIABLE##########################

# TWILIO API SID
:local TWILIOAPISID "AAAAAAAAAAAAAAAAAAAAAAA";

# TWILIO API TOKEN
:local TWILIOAPITOKEN "BBBBBBBBBBBBBBBBBBBBBBB";

# TWILIO API Endpoint
:local TWILIOAPIURL ("https://api.twilio.com/2010-04-01/Accounts/$TWILIOAPISID/Messages.json");

# From number, default +14155238886
:local TWILIOAPIFROMNUMBER "+14155238886";

# To number
:local TWILIOAPITONUMBER "+00000000000";

# Messages, complex text/url may require proper encoding
# https://www.urlencoder.org/
:local MESSAGE "Mikrotik: *ISP 1* Down!";

# Messages Logo, complex text/url may require proper encoding
# https://www.urlencoder.org/
:local LOGO "https://img.freepik.com/premium-vector/illustration-smart-robot-working-laptop_188898-171.jpg";

############################################################

# Basic URL encoder
:local urlEncoder do={
 :local urlEncoded;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:pick $1 $i]
  :if ($char = ":") do={:set $char "%3A"}
  :if ($char = "+") do={:set $char "%2B"}
  :set urlEncoded ($urlEncoded . $char)
 }
 :return $urlEncoded;
}

:local payloads [$urlEncoder ("To=whatsapp:$TWILIOAPITONUMBER&From=whatsapp:$TWILIOAPIFROMNUMBER&Body=$MESSAGE&MediaUrl=$LOGO")];
/tool fetch http-method=post http-data=$payloads url=$TWILIOAPIURL user=$TWILIOAPISID password=$TWILIOAPITOKEN output=none;
