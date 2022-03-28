# queue parent
:local qparent "CLIENT";

# old max limit, UP/DOWN
:local oldlimit "1M/1200k";

# new max limit, UP/DOWN
:local newlimit "1M/1M";

:log warning "Starting bulk queue changer";
:log warning ("Old limit: $oldlimit, New limit: $newlimit");
:local numchanged 0;
:foreach i in=[/queue simple find where parent=$qparent] do={
 :if ([/queue simple get $i max-limit] = $oldlimit) do={
  /queue simple set $i max-limit=$newlimit
  :set $numchanged ($numchanged + 1);
 }
}
:log warning ("$numchanged queue successfully changed");
