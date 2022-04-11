# queue parent
:local qparent "CLIENT";

# skip user, (non remotable)
:local skipuser "queue1,queue2,john,doe";

:log warning "Starting diagnostic..."
:foreach i in=[/queue simple find where parent=$qparent] do={
 :local ipa [:tostr [/queue simple get $i target]];
 :local ipad [:pick $ipa 0 ([:len $ipa]-3)];
 :local usern [/queue simple get $i name];
 :local rcvd 0;
 :local avgrtt 0;
 :local maxrtt 0;
 :if ([:find (" $skipuser") $usern]) do={
  :log warning ("Skip user $usern");
 } else={
  /tool flood-ping $ipad size=38 count=3 do={
   :set $rcvd $"received";
   :set $avgrtt $"avg-rtt";
   :set $maxrtt $"max-rtt";
  }
  :if ($rcvd = 0) do={
   :log error ("Unable to ping user $usern, IP: $ipad");
  } else={
   :log warning ("User $usern is up, ping avg: $($avgrtt)ms max: $($maxrtt)ms");
  }
 }
 delay 1s;
}
:log warning "Diagnostic complete"
