#include <sourcemod>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

// Plugin Informaiton
#define PLUGIN_VERSION "1.00"

public Plugin myinfo =
{
  name = "Skybox Randomizer",
  author = "Invex | Byte",
  description = "Randomize the Skybox each map.",
  version = PLUGIN_VERSION,
  url = "http://www.invexgaming.com.au"
};

//Globals
ArrayList g_SkyNames;
bool g_ClientSkyboxPreference[MAXPLAYERS+1] = {true, ...};
char g_CurrentMapSkyName[64] = "";
Handle g_RandSkyboxCookie = null;

public void OnPluginStart()
{
  //Register cookie
  g_RandSkyboxCookie = RegClientCookie("skyboxrandomizer_enable", "Should the skybox be randomized for you", CookieAccess_Protected);

  //Commands
  RegConsoleCmd("sm_skybox", Command_Skybox, "Turn the randomized skybox on or off");
  RegAdminCmd("sm_changeskybox", Command_ChangeSkybox, ADMFLAG_GENERIC, "Change the current maps skybox to a random skybox");

  //Hooks
  HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
  //Refresh g_SkyNames list
  delete g_SkyNames;
  g_SkyNames = new ArrayList(64);

  //Skybox suffixes.
  static char suffix[][] = {
    "bk",
    "Bk",
    "dn",
    "Dn",
    "ft",
    "Ft",
    "lf",
    "Lf",
    "rt",
    "Rt",
    "up",
    "Up",
  };

  //Read any custom skyboxes
  DirectoryListing dl = OpenDirectory("materials/skybox");

  if (dl != null) {
    char fileName[64];
    while (dl.GetNext(fileName, sizeof(fileName))) {
      if (StrEqual(fileName, ".") || StrEqual(fileName, ".."))
        continue;

      char ext[64];
      if (GetFileExtension(fileName, ext, sizeof(ext))) {
        if (StrEqual(ext, ".vtf")) {

          //Remove suffixes and ext from the file name
          for (int i = 0; i < sizeof(suffix); ++i) {
            char suffixExt[64];
            Format(suffixExt, sizeof(suffixExt), "%s.vtf", suffix[i]);

            //Replace suffic to get base skyname
            if (ReplaceString(fileName, sizeof(fileName), suffixExt, "", false) > 0) {
              //Push skyname to array
              if (g_SkyNames.FindString(fileName) == -1)
                g_SkyNames.PushString(fileName);
              
              break;
            }
          }
        }
      }
    }

    delete dl;
  }

  //Read default skyboxes
  dl = OpenDirectory("materials/skybox", true);

  //Read valve skyboxes
  if (dl != null) {
    char fileName[64];
    while (dl.GetNext(fileName, sizeof(fileName))) {
      if (StrEqual(fileName, ".") || StrEqual(fileName, ".."))
        continue;

      char ext[64];
      if (GetFileExtension(fileName, ext, sizeof(ext))) {
        if (StrEqual(ext, ".vtf")) {

          //Remove suffixes and ext from the file name
          for (int i = 0; i < sizeof(suffix); ++i) {
            char suffixExt[64];
            Format(suffixExt, sizeof(suffixExt), "%s.vtf", suffix[i]);

            //Replace suffic to get base skyname
            if (ReplaceString(fileName, sizeof(fileName), suffixExt, "", false) > 0) {
              //Push skyname to array
              if (g_SkyNames.FindString(fileName) == -1)
                g_SkyNames.PushString(fileName);
              
              break;
            }
          }
        }
      }
    }

    delete dl;
  }

  //Pick a random skybox
  PickRandomSkyBox();
}

public void OnClientCookiesCached(int client)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return;
  
  char buffer[2];
  GetClientCookie(client, g_RandSkyboxCookie, buffer, sizeof(buffer));

  if (strlen(buffer) != 0)
    g_ClientSkyboxPreference[client] = view_as<bool>(StringToInt(buffer));

  SetSkyBox(client);
}

public void OnClientPutInServer(int client)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return;

  SetSkyBox(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  SetSkyBoxAll();
  return Plugin_Continue;
}

public Action Command_Skybox(int client, int args)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return Plugin_Handled;

  g_ClientSkyboxPreference[client] = !g_ClientSkyboxPreference[client];
  SetClientCookie(client, g_RandSkyboxCookie, g_ClientSkyboxPreference[client] ? "1" : "0");

  SetSkyBox(client);

  ReplyToCommand(client, "[SM] Randomized skyboxes have been turned %s.", g_ClientSkyboxPreference[client] ? "on" : "off");

  return Plugin_Handled;
}

public Action Command_ChangeSkybox(int client, int args)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return Plugin_Handled;

  //Pick a random skybox and update everybody
  PickRandomSkyBox();
  SetSkyBoxAll();

  PrintToChatAll("[SM] %N has changed the current maps skybox.", client);

  return Plugin_Handled;
}

void SetSkyBoxAll()
{
  for (int i = 1; i <= MaxClients; ++i)
    SetSkyBox(i);
}

void SetSkyBox(int client)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return;

  ConVar sv_skyname = FindConVar("sv_skyname");
  if (sv_skyname == null)
    return;

  //Set custom skybox or default based on client preference
  if (g_ClientSkyboxPreference[client])
    sv_skyname.ReplicateToClient(client, g_CurrentMapSkyName);
  else {
    char defaultSkyname[64];
    sv_skyname.GetString(defaultSkyname, sizeof(defaultSkyname));
    sv_skyname.ReplicateToClient(client, defaultSkyname);
  }
}

void PickRandomSkyBox()
{
  if (g_SkyNames.Length > 0) {
    //Pick random index into g_SkyNames
    int randomIndex = GetRandomInt(0, g_SkyNames.Length-1);
    char buffer[64];
    g_SkyNames.GetString(randomIndex, buffer, sizeof(buffer));
    strcopy(g_CurrentMapSkyName, sizeof(g_CurrentMapSkyName), buffer);
  }
}


//Get the extension given a file path
stock bool GetFileExtension(const char[] path, char[] ext, int maxlen)
{
  //Find first dot
  int index = FindCharInString(path, '.');
  if (index == -1) {
    return false;
  }
  
  //Everything past first dot is the extension
  Format(ext, maxlen, path[index]);
  return true;
}