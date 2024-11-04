This is meant to be a simple script to make basic calls to the OpenAI API using MSL mIRC Scripting Language. It is not bulletproof. There are two versions: one will create an additional socket and open a standard server window with a chat interface and the other is just the socket and will join the specified room. Things to add would include more thorough parsing of user messages to prevent corrupting the JSON in the context_window.txt file. This includes ensuring quotes are escaped and curly braces are handled appropriately. You will also want to account for the various responses from the OpenAI API that indicate errors have happened (401 Unauthorized for example).

Other things to add could include a list of users no longer allowed to interact with the bot, throttling messages so they do not cause a flood, identifying the max-length of messages on the server and breaking up responses accordingly etc.

My hope is people will take this simple project and evolve it into unique use cases with additional features and added stability.

Another addition I have made in a separate project includes separate context windows for individual users so that private messages directly to the bot will allow the bot to have conversations relavent only to that particular user.
Another addition was the addition of a timer each time a user chats to the bot that allows subsequent conversation without having to use the bots name to continue chatting to it for a certain amount of time.

Good Luck!
