/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Cleaner"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>
#include <vh-logs>

/*****************************/
//Globals

const LOG = 0;
const SML = 1;
const DEM = 2;
const SPR = 3;
const MAX = 4;

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnConfigsExecuted()
{
	for (int i; i < MAX; i++)
		CleanServer(i);
}

bool CleanServer(int type)
{	
	int Time32 = GetTime() / 3600 - 168;
	
	char filename[256];
	char dir[PLATFORM_MAX_PATH];
	
	switch (type)
	{
		case LOG:
			FindConVar("sv_logsdir").GetString(dir, sizeof(dir));
		case SML:
			BuildPath(Path_SM, dir, sizeof(dir), "logs");
		case DEM:
			strcopy(dir, sizeof(dir), "./demos");
		case SPR:
			strcopy(dir, sizeof(dir), "downloads");
	}
	
	Handle h_dir;
	
	int strLength;
	
	if (type == SPR)
	{
		if (DirExists(dir))
		{
			h_dir = OpenDirectory(dir);
			while (ReadDirEntry(h_dir, filename, sizeof(filename)))
			{
				if (StrEqual(filename, ".") || StrEqual(filename, ".."))
					continue;
					
				strLength = strlen(filename);
				
				if (StrContains(filename, ".dat", false) == strLength-4 || StrContains(filename, ".ztmp", false) == strLength-5)
				{
					CanDelete(Time32, dir, filename, type);
					continue;
				} 
			}
			
			delete h_dir;
		}
			
		FormatEx(dir, sizeof(dir), "download/user_custom");
		
		if (DirExists(dir))
		{
			h_dir = OpenDirectory(dir);
			char subdir[PLATFORM_MAX_PATH];
			char fullpath[PLATFORM_MAX_PATH]; 
			Handle h_subdir;
			
			while (ReadDirEntry(h_dir, subdir, sizeof(subdir)))
			{
				if (StrEqual(subdir, ".") || StrEqual(subdir, ".."))
					continue;
					
				FormatEx(fullpath, sizeof(fullpath), "%s/%s", dir, subdir);
				
				if (DirExists(fullpath))
				{
					h_subdir = OpenDirectory(fullpath);
					bool emptyfolder = true;
					while (ReadDirEntry(h_subdir, filename, sizeof(filename)))
					{
						if (StrEqual(filename, ".") || StrEqual(filename, ".."))
							continue;
							
						emptyfolder = false;
						strLength = strlen(filename);
						
						if (StrContains(filename, ".dat", false) == strLength-4 || StrContains(filename, ".ztmp", false) == strLength-5)
						{
							CanDelete(Time32, fullpath, filename, type);
							continue;
						}
					}
					
					delete h_subdir;
					
					if (emptyfolder)
						CanDelete(Time32, dir, subdir, type, true, true);
				}
				
			}
			
			delete h_dir;
		}
	}
	else
	{
		if (strlen(dir) > 0 && DirExists(dir))
		{
			h_dir = OpenDirectory(dir);
			
			while (ReadDirEntry(h_dir, filename, sizeof(filename)))
			{
				if (StrEqual(filename, ".") || StrEqual(filename, ".."))
					continue;
				
				strLength = strlen(filename);
				
				if (type == LOG)
				{
					if (StrContains(filename, ".log", false) == strLength - 4)
					{
						CanDelete(Time32, dir, filename, type);
						continue;
					}
				}
				else if (type == SML)
				{
					if (StrContains(filename, ".log", false) == strLength - 4)
					{
						CanDelete(Time32, dir, filename, type);
						continue;
					}
				}
				else if (type == DEM)
				{
					if (StrContains(filename, "auto-", false) == 0 && StrContains(filename, ".dem", false) == strLength - 4)
					{
						CanDelete(Time32, dir, filename, type);
						continue;
					} 
				}
			}
			
			delete h_dir;
		}
	}
	
	return true;
}

void CanDelete(int Time32, const char[] dir, const char[] filename, int type, bool force = false, bool folder = false)
{
	int TimeStamp;
	
	char file[PLATFORM_MAX_PATH];
	FormatEx(file, sizeof(file), "%s/%s", dir, filename);
	
	if (type == SPR)
	{
		TimeStamp = GetFileTime(file, FileTime_LastAccess);
		
		if (TimeStamp == -1)
			TimeStamp = GetFileTime(file, FileTime_LastChange);
	}
	else
		TimeStamp = GetFileTime(file, FileTime_LastChange);
	
	TimeStamp /= 3600;
	
	if (TimeStamp == -1)
		VH_SystemLog("Fatal error reading timestamp for \"%s\".", file);
	
	if (Time32 > TimeStamp || force)
	{
		if (folder ? !RemoveDir(file) : !DeleteFile(file))
			VH_SystemLog("Unable to delete \"%s\", please check permissions.", file);
	}
}