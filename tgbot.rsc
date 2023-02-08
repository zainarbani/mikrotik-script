#!rsc by RouterOS
# RouterOS script: Telegram Bot
# version: v0.1-2023-2-8-release
# authors: zainarbani
#

# TG Bot Token
:global TGBotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";

# TG Trusted Users ID
:global TGTrusted "1234567890|1234567890"; 

:local logTopic "TGBot:";

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

:local jsonArr do={
 :local jsChar;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:tostr [:pick $1 $i]];
  :if (([:pick $1 ($i-1)]~"[a-z|A-Z]" != true)\
  && ([:pick $1 ($i+1)]~"[a-z|A-Z|/|:]" != true)\
  && ([:pick $1 ($i-1) ($i+1)] != "\"]")\
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
   :set char "linkVar";
  }
  :set jsChar ($jsChar . $char);
 }
 :local jsArr [[:parse ":local jsRet $jsChar; :return \$jsRet"]];
 :local textMsg ($jsArr->"result"->0->"message"->"text");
 :local isVar [:find $textMsg "linkVar"];
 :while ($isVar > 0) do={
  :local textRep ([:pick $textMsg 0 $isVar] . "\$");
  :set textRep ($textRep . [:pick $textMsg ($isVar + 7) [:len $textMsg]]);
  :set textMsg $textRep;
  :set isVar [:find $textMsg "linkVar"];
 }
 :set ($jsArr->"result"->0->"message"->"text") $textMsg;
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
 :local resDat;
 do {
  :set resDat ([/tool fetch url="$TelegramAPI$TGBotToken/$1\?$2" output=user as-value]->"data");
 } on-error={
  :log warning "$logTopic fetch: $1 failed";
 }
 :return $resDat;
}

:local getUpdate [$tgFetch "getUpdates" ("limit=1&offset=$TGLastOffset")];
:if ([:len $getUpdate] > 23) do={
 :local tgSuccess false;
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
  :log warning "$logTopic Receiving command:\n$textCmd";
  :if ($fromId~$TGTrusted) do={
   :local textMsg;
   :if ($textCmd~"/start|/help") do={
    :set textMsg [$urlEnc ("Example:\n/interface print")];
   } else={
    :local excOut [$execMsg $textCmd];
    :set textMsg [$urlEnc ("```\n$excOut\n```")];
   }
   :local payLd ("chat_id=$chatId&reply_to_message_id=$msgId&text=$textMsg&parse_mode=markdown");
   :local sendMsg [$tgFetch "sendMessage" $payLd];
   :local sendRep [$jsonArr [$sendMsg $payLd]];
   :if ($sendRep->"ok") do={
    :set tgSuccess true;
    :log warning "$logTopic Trusted user @$fromUser, command executed!";
   }
  } else={
   :local textMsg [$urlEnc ("Sorry, you are not allowed to access this router.")];
   :local payLd ("chat_id=$chatId&reply_to_message_id=$msgId&text=$textMsg&parse_mode=markdown");
   :local sendMsg [$tgFetch "sendMessage" $payLd];
   :local sendRep [$jsonArr [$sendMsg $payLd]];
   :if ($sendRep->"ok") do={
    :set tgSuccess true;
    :log warning "$logTopic Untrusted user @$fromUser, command ignored!";
   }
  }
  :if ($tgSuccess) do={
   :set TGLastOffset ($updId + 1);
  } else={
   :set TGLastOffset $updId;
  }
 } else={
  :set TGLastOffset ($updId + 1);
 }
}
:set $TGBotBusy false;
