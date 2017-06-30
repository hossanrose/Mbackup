#!/bin/bash
#Version: 0.5
#Author: Hossan Rose
#Purpose: Perform DB / File Backups

#VARS
SITE=( "$@" )
TMPDIR="/backup/hourly"
BACKUPDIR="/backup"
REMOTE_BKP="s3://nixwindcom/managed"
BACKUPNAME="nixback"
LOG="/var/log/backup.log"
DATE=`/bin/date '+%Y%d%m'`
WEEKNO="0`echo $((($(/bin/date +%d)-1)/7+1))`"
MONNO=`/bin/date '+%m'`
DAYNO_WEEK=`date '+%u'`
DAYNO_MONTH=`date '+%d'`
HOURNO_DAY=`/bin/date '+%H'`
#On which day of week weekly backup must run. Values 1 to 7 where 1 is Monday
BACK_WEEK_DAY='7' 
#On which day of Month monthly backup must run. Values 1 to 31
BACK_MON_DAY='01' 
#On which hour of the day daily backup must be done
BACK_DAY_HOUR='00'
MYSQL_BIN='/usr/bin/mysql'
PSQL_BIN='/usr/bin/psql'

initialize () {
echo "================== `date` ==================" >> $LOG
mkdir -p $BACKUPDIR $TMPDIR 2>> $LOG
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "FAILED. Unable to create directory"
  exit 1
else
  echo "Able to create directory"
fi
echo ${#SITE[@]}
if [[ "${#SITE[@]}" -le 10 ]] ; then
	echo "Arguments not sufficient! << Usage: $0 directory_to_backup BACKUP_HOURLY BACKUP_DAILY BACKUP_WEEKLY BACKUP_MONTHLY RETENSION_HOURLY RETENSION_DAILY RETENSION_WEEKLY RETENSION_MONTHLY AWS_KEY AWS_SECRET>>"
	exit 111
fi

#SET the passed variables
DIR=${SITE[0]}
BKP_HOUR=${SITE[1]}
BKP_DAY=${SITE[2]}
BKP_WEEK=${SITE[3]}
BKP_MON=${SITE[4]}
RT_HOUR=${SITE[5]}
RT_DAY=${SITE[6]}
RT_WEEK=${SITE[7]}
RT_MON=${SITE[8]}
export AWS_ACCESS_KEY_ID=${SITE[9]}
export AWS_SECRET_ACCESS_KEY=${SITE[10]}
}

purge_back(){
BACKUP="$BACKUPNAME-$1"
BKP_TYPE=`echo $1| cut -d\- -f1`
RETENTION_HOURS=$2
echo "Backup description : $BACKUP"
OLD_BACKUPS=($(find $BACKUPDIR -type f -name "$BACKUPNAME-$BKP_TYPE*" -mmin +$(($RETENTION_HOURS * 60)) -printf "%f\n"))
echo "Oldbackups to remove" >> $LOG
echo "$OLD_BACKUPS" >> $LOG
for old_backup in "${OLD_BACKUPS[@]}"; do
	if [[ $old_backup =~ $BACKUPNAME-$BKP_TYPE-[0-9]{1,2}-[0-9]{8}.tar.gz  ]] ; then
		echo "Deleting old backup: $old_backup"
		rm -vf $BACKUPDIR/$old_backup 2>> $LOG
		if [ ${PIPESTATUS[0]} -ne 0 ]; then
			echo "FAILED. Unable to remove $old_backup"
			exit 1
		else
        		echo "Able to remove $old_backup"
		fi
	fi
done
}

create_back() {
BACKUP="$BACKUPNAME-$1"
backup_data
backup_db
compress_backup $BACKUP
clean_up
}

backup_data () {
cp -rpf $DIR $TMPDIR/ 2>> $LOG                                        # sitefiles
if [ ${PIPESTATUS[0]} -ne 0 ]; then
	echo "FAILED. Unable to copy data from $i"
	exit 1
else
	echo "Able to copy data from $i"
fi
}

mysql_bkp(){
if [[ -x $1 ]]; then
	MYSQL_RUN='mysql -sN'
	$MYSQL_RUN -e "SELECT version();" 2>> $LOG
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
        	echo "FAILED. Unable to connect to mysql server"
        	exit 1
	else
        	echo "Able to connect to mysql server"
	fi
	$MYSQL_RUN -e "show databases;" | egrep -v 'information_schema|mysql|performance_schema' > database_list
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
        	echo "FAILED. Database list not created"
        	exit 1
	else
        	echo "Database list created"
	fi
	for i in `cat database_list`;do
        	mysqldump  $i > $TMPDIR/$i.sqli 2>>$LOG
        	if [ ${PIPESTATUS[0]} -ne 0 ]; then
                	echo "FAILED. Unable to backup $i Database "
                	exit 1
        	else
                	echo "Database backup of $i done"
        	fi
	done
else
	echo "Mysql binary not found at $1"
fi
}

psql_bkp(){

if [[ -x $1 ]]; then
	PSQL_RUN='sudo -H  -u postgres bash'
	$PSQL_RUN -c 'psql -c "SELECT version();"'
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
        	echo "FAILED. Unable to connect to postgres server"
        	exit 1
	else
        	echo "Able to connect to postgres server"
	fi
	$PSQL_RUN -c "psql -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'|egrep -v 'template0|template1'" > database_list
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
	        echo "FAILED. Database list not created"
        	exit 1
	else
        	echo "Database list created"
	fi
	for i in `cat database_list`;do
		$PSQL_RUN -c "pg_dump -Fc $i" | sudo tee $TMPDIR/$i.sql 2>>$LOG 1>/dev/null
        	if [ ${PIPESTATUS[0]} -ne 0 ]; then
                	echo "FAILED. Unable to backup $i Database "
                	exit 1
        	else
                	echo "Database backup of $i done"
        	fi
	done
else 
	echo "Postgres binary not found at $1"

fi
}

backup_db () {
mysql_bkp $MYSQL_BIN
psql_bkp  $PSQL_BIN
}

compress_backup () {
BACKUP=$1
cd $BACKUPDIR
tar -zcf  $BACKUPDIR/$BACKUP-$DATE.tar.gz  hourly      2>> $LOG #
if [ ${PIPESTATUS[0]} -ne 0 ]; then
	echo "FAILED. Failed creating the archive $BACKUP-$DATE.tar.gz"
	exit 1
else
	echo "Able to create $BACKUP-$DATE.tar.gz"
	BKP_NAME="$BACKUP-$DATE.tar.gz"
fi
}

transfer_back () {
BKP_TYPE=$1
aws s3 cp $BACKUPDIR/$BKP_NAME $REMOTE_BKP/$(hostname)/$1/$BKP_NAME
if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "FAILED. Failed to transfer the backup to remote"
        exit 1
else
        echo "Able to transfer the $BACKUP-$DATE.tar.gz"
fi
}

clean_up () {
rm -rf $TMPDIR 2>> $LOG
if [ ${PIPESTATUS[0]} -ne 0 ]; then
	echo "FAILED. Failed removing the $TMPDIR"
	exit 1
else
	echo "Able to remove $TMPDIR"
fi
}

# Main program
initialize

# Run monthly backups
if [[ $BACK_MON_DAY = $DAYNO_MONTH &&  $BACK_DAY_HOUR = $HOURNO_DAY ]]; then
        if [[ $BKP_MON = 0 ]];then
                echo "Sorry no Monthly backup set"
        elif [[ $BKP_MON = 1 ]]; then
		echo "Running Monthly backup for mon : $MONNO"
                purge_back "MON-${MONNO}" $(($RT_MON * 31 * 24)) 
		create_back "MON-${MONNO}"  
		transfer_back MON 
        else
                echo "Not a valid monthly option"
        fi
fi

# Run Weekly backups
if [[ $BACK_WEEK_DAY = $DAYNO_WEEK &&  $BACK_DAY_HOUR = $HOURNO_DAY  ]]; then
	if [[ $BKP_WEEK = 0 ]]; then
		echo "Sorry no weekly backup set"
	elif [[ $BKP_WEEK = 1 ]]; then
		echo "Running Weekly backup for week : $WEEKNO"
		purge_back "WEEK-${WEEKNO}" $(($RT_WEEK * 7 * 24))
		create_back "WEEK-${WEEKNO}" 
		transfer_back WEEK 
	elif [[ $BKP_WEEK = 2  &&  $(( $WEEKNO % 2 )) != "0"  ]] ; then
		echo "Running Weekly backup for week : $WEEKNO"
		purge_back "WEEK-${WEEKNO}" $(($RT_WEEK * 7 * 24))
		create_back "WEEK-${WEEKNO}" 
		transfer_back WEEK 
	else
		echo "Not a valid weekly option"
	fi
fi

# Run daily backups
if [[ $BACK_DAY_HOUR = $HOURNO_DAY ]]; then
	if [[ $BKP_DAY = 0 ]];then  
		echo "Sorry no backup"
	elif [[ $BKP_DAY = 1 ]]; then
		purge_back "DAY-$DAYNO_WEEK" $(($RT_DAY * 24))
		create_back "DAY-$DAYNO_WEEK"
		transfer_back DAY 
	elif [[ $BKP_DAY = 2 &&  $(( $DAYNO_WEEK % 2 )) != "0"  ]] ; then
		purge_back "DAY-$DAYNO_WEEK" $(($RT_DAY * 24))
		create_back "DAY-$DAYNO_WEEK"
		transfer_back DAY 
	else
		echo "Not a valid daily option"
	fi
fi

# Run hourly backups
if [[ $BKP_HOUR = 0 ]];then  
        echo "Sorry no backup"
elif [[ $BKP_HOUR = 1 ]]; then
        purge_back "HOUR-$HOURNO_DAY" $(($RT_HOUR ))
        create_back "HOUR-$HOURNO_DAY"
elif [[ $BKP_DAY = 2 &&  $(( $HOURNO_DAY % 2 )) != "0"  ]] ; then
        purge_back "HOUR-$HOURNO_DAY" $(($RT_HOUR))
        create_back "HOUR-$HOURNO_DAY"
else    
        echo "Not a valid daily option"
fi
