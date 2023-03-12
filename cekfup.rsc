#!rsc by RouterOS
# RouterOS script: Cek FUP IndiHome
# version: v0.1-2023-3-12-release
# authors: zainarbani
#

# =============================

# No IndiHome
:local inetNumber "1234567890";

# API Token
# Generated using: https://github.com/zainarbani/indiapi
:local refreshToken "xxxxxxxx";

# =============================


# JSON to Array
:local jsonArr do={
 :local jsChar;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:pick $1 $i];
  :if (([:pick $1 ($i-1)]~"[a-z|A-Z]" != true)\
  && ([:pick $1 ($i+1)]~"[a-z|A-Z|:|/]" != true)\
  || ([:pick $1 ($i-4) $i] = true)\
  || ([:pick $1 ($i+1) ($i+5)] = true)\
  || ([:pick $1 ($i-5) $i] = false)\
  || ([:pick $1 ($i+1) ($i+6)] = false)) do={
   :local conv {":"="=";","=";";"["="{";"]"="}"};
   :foreach oc,nc in=$conv do={
    :if ($char = $oc) do={
     :set char $nc;
    }
   }
  }
  :set jsChar ($jsChar . $char);
 }
 :local jsArr [[:parse ":local jsRet $jsChar; :return \$jsRet"]];
 :return $jsArr;
}


# API
:local datetime ([/sys clock get time] . " " . [/sys clock get date]);
:local telkomGw "https://apigw.telkom.co.id:7777/gateway";
:local tokEndpoint "/telkom-myihxmbe-identityserver/1.0/user/token";
:local fupEndpoint "/telkom-myihxmbe-productinfosubscription/1.0/product-subscription/packages/usage/$inetNumber";
:local XGw "070bb926-44d4-449e-9f88-b96c87392964";
:local XAuth "Basic bXlJbmRpaG9tZVg6Nkw3MUxPdWlubGloOWJuWkhBSUtKMjFIc3Qxcg==";

:local hdrs "X-Gateway-APIKey: $XGw, Authorization: $XAuth, content-type: application/json";
:local pyld "{\"refreshToken\":\"$refreshToken\"}";
:local tokRes ([/tool fetch http-header-field=$hdrs http-method=post url="$telkomGw$tokEndpoint" http-data=$pyld output=user as-value]->"data");
:local sesTok ([$jsonArr $tokRes]->"data"->"token");

:set hdrs "X-Gateway-APIKey: $XGw, Authorization: Bearer $sesTok, content-type: application/json";
:local fupRes ([/tool fetch http-header-field=$hdrs http-method=get url="$telkomGw$fupEndpoint" output=user as-value]->"data");
:local jsRes [$jsonArr $fupRes];

:local remainingQ ($jsRes->"data"->"dataUsage"->"usage"->"remainingQuota");
:local usedQ ($jsRes->"data"->"dataUsage"->"usage"->"usedQuata");
:local unitQ ($jsRes->"data"->"dataUsage"->"usage"->"unit");

:local msg "InpoInpo\r\n\r\nSisa Kuoata IndiHome: $remainingQ $unitQ\r\nKuota Terpakai: $usedQ $unitQ\r\n\r\nLast Check: $datetime";
/system note set show-at-login=yes note=$msg;
