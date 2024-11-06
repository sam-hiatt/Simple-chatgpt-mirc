/*
Important - Set an environment variable on your system called OPENAI_API_KEY
Set OPENAI_API_KEY to your OpenAI API KEY. This is to ensure you do not have
your api key in plain text in your script in case you choose to share it and to prevent
accidentally leaking it.

Once you have set your api key you may have to restart before mIRC can actually see it with
$envvar(OPENAI_API_KEY)

please see here on how to set your environment variable: https://platform.openai.com/docs/quickstart/step-2-set-up-your-api-key

The bot is set to remember as far back as the last 20 interactions. this includes responses from the bot.
setting the %context_window_size variable to a higher number will allow the bot to remember more interactions but will burn through tokens faster as the conversation grows

Version 1.213
*/

menu * {
  OpenAI Chatbot
  .Start/Restart Chatbot: gpt_sockbot
  .Reset Context Window: reset_context_window
  .Set Chatroom: set %chatroom $input(Chatroom:,eo,Chatroom,%chatroom)
  .Set Bot Nick: set %botnick $input(Bot Nick:,eo,BotNick,%botnick)
  .Set Context Window Size: set %context_window_size $input(Context Window Size:,eo,Context Window Size,%context_window_size)
  .$style(%server_mode) Enable Server Window: set %server_mode $calc(1 - %server_mode)
  .$style(%debug) Enable Debug Mode: set %debug $calc(1 - %debug) | debug_output $iif(%debug,enabled,disabled) | debug_output 4 Debug Mode: $iif(%debug,Enabled,Disabled)
}

on *:START:{
  set %chatroom #chatbot
  set %botnick BanterBot
  set %context_window_size 20
  set %server_mode 0
  set %debug 0
  window -ekh @GPT_Sockbot
  reset_system_role
}

alias reset_system_role {
  write -c $mircdir $+ system_role.txt $chr(123) $+ "role": "system","content": "You are a creative and helpful host in an IRC chatroom. You will not constantly ask if there is anything else you can help with. it gets repetitive and annoying to the users. When a chat user talks to you, you can follow the conversation and respond accordingly. When users leave the room, most of the time you say exactly this: Goodbye. Every now and then you will instead say a short but funny quippy goodbye. When a user joins the room you must greet them with something funny. You will keep track of who is currently in the room as users join and part." $+ $chr(125)
}

alias reset_context_window {
  write -c $mircdir $+ context_window.txt 
}

alias debug_output {  
    if ($1 == disabled) {
      window -h @GPT_Sockbot
    } 
    elseif ($1 == enabled) {
      noop
    }
    else {      
      if (%debug) {    
        ; If the window is hidden then show it
        if ($window(@GPT_Sockbot).state == hidden) {
          window -w3 @GPT_Sockbot
        }

        ; If the window does not exist then create it
        if (!$window(@GPT_Sockbot)) {
          window -ek @GPT_Sockbot
        }

        ; Output the message to the debug window
        echo $1 @GPT_Sockbot $2-
      }
  }
}

alias openai_api_request {
  ; Define the URL for the OpenAI API
  var %url = https://api.openai.com/v1/chat/completions

  ;append our latest request to our context window file  
  ; Clean up some of the contents
   var %content = $replace($1-, $chr(1), $null, $chr(34), \ $+ $chr(34))
  write $mircdir $+ context_window.txt $chr(123) $+ "role": "user", "content": " $+ %content $+ " $+ $chr(125)

  ; Build the context window string from the system_role.txt and context_window.txt files
  ; First we read the system_role.txt file and store the content in %context_window
  var %context_window = $read(system_role.txt,nw,*,1) 

  ; Next we verify the number of lines in the context window file.
  var %sizeof_context_window $lines("context_window.txt")

  ; If there are 50 or more lines we only load the last 50 lines and append them to the %context_window variable
  ; Otherwise we load all the lines in the file and append them to the %context_window variable

  if (%sizeof_context_window >= %context_window_size) {
    var %i = $calc(%sizeof_context_window - (%context_window_size - 1))
  }
  else {

    var %i = 1
  } 

  while (%i <= %sizeof_context_window) {
    var %context_window %context_window $+ , $+ $read("context_window.txt", nw,*,%i)
    inc %i
  }

  ;enclose the %context_window in square brackets
  %context_window = $chr(91) $+ %context_window $+ $chr(93)
  ; Define the headers in a &binvar named &headers
  bset -t &headers -1 Content-Type: application/json $+ $crlf
  bset -t &headers -1 Authorization: Bearer $envvar(OPENAI_API_KEY) $+ $crlf
  bset -t &headers -1 User-Agent: mIRC OpenAI Script 1.0 By Rift $+ $crlf
  bset -t &headers -1 Accept: */* $+ $crlf
  bset -t &headers -1 Cache-Control: no-cache $+ $crlf
  bset -t &headers -1 Host: api.openai.com $+ $crlf
  bset -t &headers -1 Accept-Encoding: gzip, deflate, br $+ $crlf
  bset -t &headers -1 Connection: keep-alive $+ $crlf $+ $crlf

  ; Define the JSON body in a &binvar
  bset -t &body 1 $chr(123)
  bset -t &body -1 "model": "gpt-4o-mini",
  bset -t &body -1 "messages": %context_window $+ ,
  bset -t &body -1 "max_tokens": 1000,
  bset -t &body -1 "top_p": 1,
  bset -t &body -1 "frequency_penalty": 2,
  bset -t &body -1 "presence_penalty": 1.0,
  bset -t &body -1 "temperature": 0.7
  bset -t &body -1 $chr(125)

  ; Make the POST request using urlget
  var %id = $urlget(%url,pb,&response,onRequestComplete,&headers,&body)

  ; Check if the call failed
  if (%id == 0) {
    debug_output 4 Error: Failed to initiate the HTTP request to the OpenAI API
  }
}

; Alias to handle the response when the request completes
alias onRequestComplete {
  var %id = $1
  if ($urlget(%id).error) {
    debug_output 4 URL Get Error: $urlget(%id).error
    return
  }
  ; Retrieve the response message from the &binvar
  debug_output 53 OpenAI API Response ->1 $bvar(&response,1-).text
  noop $regex(response_message,$bvar(&response,1-).text,/"content":\s*"(.*?)(?=",\s*"refusal":)"/i)

  ; Store the response message in a variable
  var %response_message $replace($regml(response_message,1), \", ")

  debug_output 53 OpenAI API Extracted Response ->1 %response_message

  ; Add the assistant's response to the context_window file
  write $mircdir $+ context_window.txt $chr(123) $+ "role": "assistant", "content": " $+ $replace(%response_message, ", \") $+ " $+ $chr(125)

  ; Send the response message to the chatroom
  if ($sock(sockbot)) {
    ; Parse \n to send multiple PRIVMSG messages
    %response_message = $replace(%response_message, \n, $chr(10))
    
    var %i = 1
    var %lines = $numtok(%response_message, 10)
    while (%i <= %lines) {
      var %line = $gettok(%response_message, %i, 10)
      sockwrite -tn sockbot PRIVMSG %chatroom : $+ %line
      inc %i
    }
  }
  
}


/*

Here is a basic socket bot

*/
alias gpt_sockbot {
  
  window -ek @GPT_Sockbot

  if ($sock(sockbot*)) {
    sockclose sockbot*
  }

  if (%server_mode) {
    socklisten -n sockbot.listener 7272
    server -m localhost 7272
  }
  else {
    sockopen sockbot chat.koach.com 6667
  }

}

on *:socklisten:sockbot.listener: {
  sockaccept sockbot.local  
  sockopen sockbot chat.koach.com 6667
}

on *:sockread:sockbot.local: {
  sockread -tn %data
  tokenize 32 %data
  echo @GPT_Sockbot Local Server: $1-

  if ($sock(sockbot)) {
    sockwrite -n sockbot $1-
  }
}

on *:sockopen:sockbot: {
  ; Send the NICK and USER commands to the server
  sockwrite -n $sockname NICK %botnick
  sockwrite -n $sockname USER BanterBot 0 * :BanterBot
}

on *:sockread:sockbot: {
  ; Read the incoming data from the server
  sockread -tn %data
  tokenize 32 %data

  debug_output 3 IRC Server -> %data


if (%server_mode) {

sockwrite -n sockbot.local $1-
} 
else {
    ; Respond to PING
  if ($1 == PING) {
    ; Respond to the PING command with a PONG command
    sockwrite -n $sockname PONG $2-
    debug_output 60 IRC Server <- PONG $2-
  }
}

  ; Check if the data contains the MOTD
  if ($2 == 376) {
    ; Join the channel
    sockwrite -n $sockname JOIN %chatroom
  }

  ; Check if the data contains the PRIVMSG command
  if ($2 == PRIVMSG) {
    ; Parse the message and extract the sender and content
    var %sender = $right($gettok($gettok($1,1,32),1,33),-1)
    var %content = $gettok($3-,2-,58)

    if (* $+ %botnick $+ * iswm $3-) {
      ; Send the message to the OpenAI API
      debug_output 53 Sending message to OpenAI API <- 1 %sender $+ : %content
      $openai_api_request(%sender $+ : %content)
    }
  }
}