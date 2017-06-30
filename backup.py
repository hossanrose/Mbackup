#!./env/bin/python
#Version: 1
#Author : Hossan Rose
#Purpose: Backup manager

from flask import Flask, request, session, redirect, url_for, abort, render_template, flash
from models import Base, Backdata, dbsession
from conf import log_location

# create our little application :)
app = Flask(__name__)
app.config.from_pyfile('conf.py')

@app.route('/')
def show_entries(): 
    if not session.get('logged_in'):
         #abort(401)
         return redirect(url_for('login'))
    entries = dbsession.query(Backdata).all()
    return render_template('show_entries.html', entries=entries)

@app.route('/server/<no>')
def show_article(no): 
    server = dbsession.query(Backdata).filter_by(slno=no).first()
    LOG=open(log_location +'/'+server.serv_name +".txt", 'r')
    return render_template('single_entries.html', entry=server, log=LOG)

@app.route('/add', methods=['GET','POST'])
def add_entry():
    if not session.get('logged_in'):
         #abort(401)
         return redirect(url_for('login'))
    if request.method == 'GET':
         return render_template('add_entries.html')
    else:
         server=Backdata(serv_name=request.form['serv_name'], remote_user=request.form['remote_user'],remote_port=request.form['remote_port'],dir_bkp=request.form['dir_bkp'],bkp_hour=request.form['bkp_hour'],rt_hour=request.form['rt_hour'],bkp_day=request.form['bkp_day'],rt_day=request.form['rt_day'],bkp_week=request.form['bkp_week'],rt_week=request.form['rt_week'],bkp_month=request.form['bkp_month'],rt_month=request.form['rt_month'],aws_profile=request.form['aws_profile'])
         dbsession.add(server)
         dbsession.commit()
         flash('New entry was successfully posted')
         return redirect(url_for('show_entries'))

@app.route('/edit/<no>', methods=['GET','POST'])
def edit_entry(no):
    if not session.get('logged_in'):
         #abort(401)
         return redirect(url_for('login'))
    if request.method == 'GET':
         entries = dbsession.query(Backdata).filter_by(slno=no)
         return render_template('edit_entries.html', entries=entries)
    else:
         server=dbsession.query(Backdata).filter_by(slno=no).first()
         server.serv_name=request.form['serv_name']
         server.remote_user=request.form['remote_user']
         server.remote_port=request.form['remote_port']
         server.dir_bkp=request.form['dir_bkp']
         server.bkp_hour=request.form['bkp_hour']
         server.rt_hour=request.form['rt_hour']
         server.bkp_day=request.form['bkp_day']
         server.rt_day=request.form['rt_day']
         server.bkp_week=request.form['bkp_week']
         server.rt_week=request.form['rt_week']
         server.bkp_month=request.form['bkp_month']
         server.rt_month=request.form['rt_month']
         server.aws_profile=request.form['aws_profile']
#         db.session.merge(server)
         dbsession.commit()
         flash('Edit was successfull')
         return redirect(url_for('show_entries'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
         if request.form['username'] != app.config['USERNAME']:
            error = 'Invalid username'
         elif request.form['password'] != app.config['PASSWORD']:
            error = 'Invalid password'
         else:
            session['logged_in'] = True
            flash('You are logged in')
            return redirect(url_for('show_entries'))
    return render_template('login.html', error=error)

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    flash('You were logged out')
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(host='0.0.0.0')
