@echo off
rem avvia-basalt.bat — server basalt (porta 12341 e' di Strata: qui 12342, style nostro)
rem NOTA: i privilegi sepol valgono solo dopo logoff+login (vedi 00-Secpol-leggimi-Sibilla.md)
cd /d H:\basalt
bin\basalt.exe serve --config basalt_config_q2.json
