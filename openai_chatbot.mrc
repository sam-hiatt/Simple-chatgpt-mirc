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
*/

on *:START:{
  set %chatroom #chatbot
  set %botnick BanterBot
  set %context_window_size 20
  reset_system_role
}

alias reset_system_role {
  write -c system_role.txt $chr(123) $+ "role": "system","content": "You are a creative and helpful host in an IRC chatroom. You will not constantly ask if there is anything else you can help with. it gets repetitive and annoying to the users. When a chat user talks to you, you can follow the conversation and respond accordingly. When users leave the room, most of the time you say exactly this: Goodbye. Every now and then you will instead say a short but funny quippy goodbye. When a user joins the room you must greet them with something funny. You will keep track of who is currently in the room as users join and part." $+ $chr(125)
}

alias reset_context_window {
  write -c context_window.txt 
}

alias openai_api_request {
  ; Define the URL for the OpenAI API
  var %url = https://api.openai.com/v1/chat/completions

  ;append our latest request to our context window file
  write context_window.txt $chr(123) $+ "role": "user", "content": " $+ $1- $+ " $+ $chr(125)

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
  bset -t &body -1 "frequency_penalty": 0.5,
  bset -t &body -1 "presence_penalty": 1.0,
  bset -t &body -1 "temperature": 0.7
  bset -t &body -1 $chr(125)

  ;echo -g @GPT_Sockbot 4 context being sent: $bvar(&body,1-).text
  ; Make the POST request using urlget
  var %id = $urlget(%url,pb,&response,onRequestComplete,&headers,&body)

  ; Check if the call failed
  if (%id == 0) {
    echo -a Error: Failed to initiate the HTTP request
  }
}

; Alias to handle the response when the request completes
alias onRequestComplete {
  var %id = $1
  if ($urlget(%id).error) {
    echo -a Error: $urlget(%id).error
    return
  }
  ; Retrieve the response message from the &binvar
  ;echo -ag $bvar(&response,1-).text
  noop $regex(response_message,$bvar(&response,1-).text,/"content":\s*"(.*?)"/i)

  ; Store the response message in a variable
  var %response_message $regml(response_message,1)

  ; Add the assistant's response to the context_window file
  write context_window.txt $chr(123) $+ "role": "assistant", "content": " $+ %response_message $+ " $+ $chr(125)

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
  if ($sock(sockbot)) {
    sockclose sockbot
  }
  window -ek @GPT_Sockbot
  sockopen sockbot chat.koach.com 6667
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

  echo @GPT_Sockbot IRC Server: %data


  ; Respond to PING
  if ($1 == PING) {
    ; Respond to the PING command with a PONG command
    sockwrite -n $sockname PONG $gettok(%data,2,32)
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

    ; Clean up some of the contents
    %content = $replace(%content, $chr(1), $null, $chr(34), \ $+ $chr(34))
    
    if (* $+ %botnick $+ * iswm $3-) {
      ; Send the message to the OpenAI API
      echo @GPT_Sockbot 4 Sending message to OpenAI API: %sender $+ : %content
      $openai_api_request(%sender $+ : %content)
    }
  }
}
