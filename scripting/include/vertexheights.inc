#if defined __vertexheights_included
	#endinput
#endif
#define __vertexheights_included

#define TAG "[Vertex]"
#define CHAT_TAG "{darkorchid}[{honeydew}Vertex{darkorchid}]{whitesmoke}"

stock void Vertex_SendPrint(int client, const char[] format, any ...)
{
	char sBuffer[255];
	VFormat(sBuffer, sizeof(sBuffer), format, 3);

	if (client == 0)
	{
		Format(sBuffer, sizeof(sBuffer), "%s %s", TAG, sBuffer);
		ReplaceString(sBuffer, sizeof(sBuffer), "[H]", "");
		ReplaceString(sBuffer, sizeof(sBuffer), "[D]", "");
		PrintToServer(sBuffer);
		return;
	}
	
	Format(sBuffer, sizeof(sBuffer), "%s %s", CHAT_TAG, sBuffer);
	
	ReplaceString(sBuffer, sizeof(sBuffer), "[H]", "{chartreuse}");
	ReplaceString(sBuffer, sizeof(sBuffer), "[D]", "{whitesmoke}");
	
	CPrintToChat(client, sBuffer);
}

stock void Vertex_SendPrintToAll(const char[] format, any ...)
{
	char sBuffer[255];
	VFormat(sBuffer, sizeof(sBuffer), format, 2);
	
	Format(sBuffer, sizeof(sBuffer), "%s %s", CHAT_TAG, sBuffer);
	
	ReplaceString(sBuffer, sizeof(sBuffer), "[H]", "{chartreuse}");
	ReplaceString(sBuffer, sizeof(sBuffer), "[D]", "{whitesmoke}");
	
	CPrintToChatAll(sBuffer);
}