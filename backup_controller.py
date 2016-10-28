#!./env/bin/python3
#Version: 1
#Author	: Hossan Rose
#Purpose: Backup script that schedules the remote backup run

from models import Backdata, Awskeys, dbsession 
import subprocess
import sys

#vars
bkp_script='backup-local.sh'
run_location='/tmp/'

#Local script transfer function
def transfer( server ): 
	print ( server.serv_name)
	transfer_command = ['scp', '-P'+ server.remote_port , bkp_script , server.remote_user + '@' + server.serv_name + ':' + run_location ]
	transfer_out = subprocess.Popen(transfer_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	transfer_out.wait()
	if transfer_out.returncode != 0:
		error = transfer_out.stderr.readlines()
		print ("ERROR: %s" % error, sys.stderr)
	else:
		print ("Transfer Successful")

#Backup script run
def backup( server, key ):
	backup_command = ['ssh', '-t', '-t', '-p' + server.remote_port , server.remote_user +'@' + server.serv_name, 'sudo ' + run_location + bkp_script +' '+ server.dir_bkp + ' ' + str(server.bkp_hour) + ' ' + str(server.bkp_day) + ' ' + str(server.bkp_week) + ' ' + str(server.bkp_month) + ' ' + str(server.rt_hour) + ' ' + str(server.rt_day) + ' ' + str(server.rt_week) + ' ' + str(server.rt_month) + ' ' + key.aws_key + ' ' + key.aws_secret]
	backup_out = subprocess.Popen(backup_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	result = backup_out.stdout.readlines()
	if result == []:
		error = backup_out.stderr.readlines()
		print ("ERROR: %s" % error, sys.stderr)
	else:
		for line in result:
			print (line.strip())

#Main program
for server in dbsession.query(Backdata):
	for key in dbsession.query(Awskeys).filter(Awskeys.aws_profile==server.aws_profile):
		transfer(server)
		backup(server, key)


