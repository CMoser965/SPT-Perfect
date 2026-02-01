# Script Instructions

## Basic SPT + Fika Installation

1. Create Folder
2. Copy Tarkov game dir into new folder
3. Patcher [Download](https://spt-legacy.modd.in/Patcher_1.0.1.1.42751_to_16.1.3.35392.7z) + extract + run patcher.exe 
4. [Download SPT](https://github.com/sp-tarkov/build/releases/download/3.11.4/SPT-3.11.4-35392-96e5b73.7z), extract into root
5. [Download and Copy Fika installer](https://github.com/project-fika/Fika-Installer/releases/download/1.1.3/Fika-Installer.exe) to directory root
6. Run installer, choose option 1
7. Run the SPT.Server file, close it after the server finishes importing the database files and is good to go
8. JSON edit for IPConfig, get IP from prompt for user, paste in <FOLDER_DIRECTORY_ROOT>\user\mods\fika-server\assets\configs\fika.jsonc
7. https://wiki.project-fika.com/joining-a-fika-server/join-using-direct-connection
9. Run SPT.Launcher and create account
10. Login to main screen and close

## Mod Installation Instructions

1. Download mods.7z from GDrive
2. Extract into root installation directory
3. Copy configs from this repository 
    - configs/questing_bots_config/config.json -> user/mods/DanW-SPTQuestingBots/config/config.json
    - configs/realism_config/config.json -> user/mods/SPT-Realism/config/config.json
    - configs/sain_config/* -> BepinEx/plugins/SAIN/
    - configs/svm_config/MainProfile.json -> user/mods/[SVM] Server Value Modifier/Presets/MainProfile.json
