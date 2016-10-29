#Mbackup
Backup Manager for local / remote AWS backups

##Installation

### Pre-requisites 
`virtualenv -p python3 env`
`./env/bin/pip3 install -r requirments`

### Configuration
Configuration conf-sample.py must changed and copied as conf.py

Front end made with flask which act managment WebUI : Run it with

`./backup.py`

Backend that should be scheduled hourly : Schedule it as below in cron

`01 * * * * cd /root/scripts/nixback && ./backup_controller.py >/dev/null 2>&1`

##Features
- Linux local / Remote AWS S3 backups
- File and Database backups
- Hourly / Daily / Weekly / Monthly Backup scheduling
- Flexible retension settings
- WebUI based managment 
