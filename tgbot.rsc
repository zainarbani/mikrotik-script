#!rsc by RouterOS
# RouterOS script: Telegram Bot
# version: v0.2-2023-2-10-release
# authors: zainarbani
#

# TG Bot Token
:global TGBotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";

# TG Trusted Users ID
:global TGTrusted "1234567890|1234567890"; 

:global TGBotBusy;
:if ($TGBotBusy) do={
 :quit;
} else={
 :set $TGBotBusy true;
}

:global TGLastOffset;
:if ($TGLastOffset < 0) do={
 :set TGLastOffset 0;
}

:local urlEnc do={
 :local urlencoded;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:pick $1 $i];
  :local conv {"%0A"="\n";"%0D"="\r";"%20"=" "};
  :foreach nc,oc in=$conv do={
   :if ($char = $oc) do={
    :set char $nc;
   }
  }
  :set urlencoded ($urlencoded . $char);
 }
 :return $urlencoded;
}

:local strSplit do={
 :local pl ($1 . $2);
 :local rslt [{}];
 :local pos [{}];
 :local lpost 0;
 :for i from=0 to=([:len $pl] - 1) do={
  :local char [:pick $pl $i];
  :if ($char = $2) do={
   :set ($pos->[:len $pos]) $i;
  }
 }
 :foreach i in=$pos do={
  :local dat [:pick $pl $lpost $i];
  :set ($rslt->[:len $rslt]) $dat;
  :set lpost ($i+1);
 }
 :if ([:len $pos] = 0) do={
  :return $1;
 } else={
  :return $rslt;
 }
}

:local strCase do={
 :local retStr;
 :local uCase [:toarr "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"];
 :local lCase [:toarr "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"];
 :for i from=0 to=([:len $2] - 1) do={
  :local char [:pick $2 $i];
  :if ($1 = "toup") do={
   :foreach i,x in=$lCase do={
    :if ($x = $char) do={:set char ($uCase->$i)}
   }
  }
  :if ($1 = "tolow") do={
   :foreach i,x in=$uCase do={
    :if ($x = $char) do={:set char ($lCase->$i)}
   }
  }
  :set retStr ($retStr . $char);
 }
 :return $retStr;
}

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
  :if ($char = "\$") do={
   :set char "\\\$";
  }
  :set jsChar ($jsChar . $char);
 }
 :local jsArr [[:parse ":local jsRet $jsChar; :return \$jsRet"]];
 :return $jsArr;
}

:local execMsg do={
 :global TGExecRun true;
 :exec file=exout.txt ("do {$1} on-error={:put \"Unknown command!\"}; :set TGExecRun false");
 :while ($TGExecRun) do={}
 :while ([:file find where name=exout.txt] = "") do={}
 :if ([:file get exout.txt size] < 4096) do={
  :local excRet [:file get exout.txt contents];
  :file remove exout.txt;
  :if ([:len $excRet] = 0) do={
   :return "Command executed.";
  } else={
   :return $excRet;
  }
 } else={
  :file remove exout.txt;
  :return "Command output is too large."
 }
}

:local tgFetch do={
 :global TGBotToken;
 :local TelegramAPI "https://api.telegram.org/bot";
 :local hdr "content-type: application/json";
 :local resDat;
 :local frmDat $2;
 :if ($1 = "get") do={
  :set frmDat "$2\?$3"
 }
 do {
  :set resDat ([/tool fetch http-header-field=$hdr http-method=$1 url="$TelegramAPI$TGBotToken/$frmDat" http-data="$3" output=user as-value]->"data");
 } on-error={
  :log warning "TGBot: fetch: $2 failed";
 }
 :return $resDat;
}

:local tgVoucher do={
 :if ([:len $1] != 0) do={
  :local hsaddr [/ip/hotspot/profile get [find where default] hotspot-address];
  :local rnduser [:pick ([/certificate/scep-server/otp generate minutes-valid=0 as-value]->"password") 0 5];
  /ip/hotspot/user add name=$rnduser password=$rnduser comment="user-$rnduser" server="all" limit-uptime=$1 limit-bytes-total=$2 profile=default;
  :local vcLogin "*VOUCHER*: ```$rnduser```\n\n*LOGIN*: http://$hsaddr\n\n*VALID*: $1\n*QUOTA*: $2";
  :local qrLogin "https://api.qrserver.com/v1/create-qr-code\?data=http://$hsaddr/login\?username$rnduser%26password=$rnduser&bgcolor=CCD1D1";
  :return {$vcLogin;$qrLogin};
 } else={
  :return "Usage: /vouchergen (duration) (quota)\nEx: /vouchergen 1d 2g";
 }
}

:local getUpdate [$tgFetch "get" "getUpdates" ("limit=1&offset=$TGLastOffset")];
:if ([:len $getUpdate] > 23) do={
 :local textMsg;
 :local pictMsg;
 :local payLd;
 :local sendMsg;
 :local cmdLog;
 :local fetchMethod "get";
 :local sendType "sendMessage";
 :local customCmd "/start|/help|/vouchergen|/reservedcmd";
 :local updRes [$jsonArr $getUpdate];
 :local updDat ($updRes->"result"->0);
 :local updId ($updDat->"update_id");
 :local msgId ($updDat->"message"->"message_id");
 :local fromId ($updDat->"message"->"from"->"id");
 :local chatId ($updDat->"message"->"chat"->"id");
 :local fromUser ($updDat->"message"->"from"->"username");
 :local msgType ($updDat->"message"->"entities"->0->"type");
 :local textCmd ($updDat->"message"->"text");
 :if (($msgType~"bot_command") || ([:pick $textCmd 0] = ":")) do={
  :log warning "TGBot: Receiving command:\n$textCmd";
  :if ($fromId~$TGTrusted) do={
   :if ($textCmd~$customCmd) do={
    :if ($textCmd~"/start") do={
     :set textMsg [$urlEnc ("Hi, I'm Alive!")];
    }
    :if ($textCmd~"/help") do={
     :set textMsg [$urlEnc ("Example:\n/interface print")];
    }
    :if ($textCmd~"/vouchergen") do={
     :set textCmd [$strSplit $textCmd " "];
     :local ltime [$strCase "tolow" ($textCmd->1)];
     :local lbyte [$strCase "toup" ($textCmd->2)];
     :local rslt [$tgVoucher $ltime $lbyte];
     :if ([:typeof $rslt] = "array") do={
      :set textMsg ($rslt->0);
      :set pictMsg ($rslt->1);
      :set sendType "sendPhoto";
      :set fetchMethod "post";
     } else={
      :set textMsg [$urlEnc $rslt];
     }
    }
    :if ($textCmd~"/reservedcmd") do={
     :set textMsg "reservedcmd";
    }
    :set payLd ("chat_id=$chatId&reply_to_message_id=$msgId&text=$textMsg");
    :if ($sendType = "sendPhoto") do={
     :set payLd ("{\"chat_id\":$chatId,\"reply_to_message_id\":$msgId,\"photo\":\"$pictMsg\",\"caption\":\"$textMsg\",\"parse_mode\":\"markdown\"}");
    }
    :set sendMsg [$tgFetch $fetchMethod $sendType $payLd];
   } else={
    :local excOut [$execMsg $textCmd];
    :set textMsg [$urlEnc ("```\n$excOut\n```")];
    :set payLd ("chat_id=$chatId&reply_to_message_id=$msgId&text=$textMsg&parse_mode=markdown");
    :set sendMsg [$tgFetch $fetchMethod $sendType $payLd];
   }
   :set cmdLog "TGBot: Trusted user @$fromUser, command executed!";
  } else={
   :set textMsg [$urlEnc ("Sorry, you are not allowed to access this router.")];
   :set payLd ("chat_id=$chatId&reply_to_message_id=$msgId&text=$textMsg");
   :set sendMsg [$tgFetch $fetchMethod $sendType $payLd];
   :set cmdLog "TGBot: Untrusted user @$fromUser, command ignored!";
  }
  :local sendRep [$jsonArr [$sendMsg $payLd]];
  :if ($sendRep->"ok") do={
   :set TGLastOffset ($updId + 1);
   :log warning $cmdLog;
  } else={
   :set TGLastOffset $updId;
  }
 } else={
  :set TGLastOffset ($updId + 1);
 }
}
:set $TGBotBusy false;
