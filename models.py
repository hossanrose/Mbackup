#import settings
from sqlalchemy import Column, Integer, String, ForeignKey, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, sessionmaker
from conf import SQLALCHEMY_DATABASE_URI

Base = declarative_base()
engine = create_engine(SQLALCHEMY_DATABASE_URI, echo=True)

class Awskeys(Base):
    __tablename__ = 'awskeys'
    aws_profile = Column(String(20), primary_key=True)
    aws_key = Column(String(300), nullable=False)
    aws_secret = Column(String(300), nullable=False)

class Backdata(Base):
    __tablename__ = 'backdata'
    slno = Column(Integer, primary_key=True, nullable=False)
    serv_name = Column(String(50), unique=True)
    remote_user = Column(String(20), nullable=False)
    remote_port = Column(String(20), nullable=False)
    dir_bkp = Column(String(100), nullable=False)
    bkp_hour = Column(Integer, nullable=False)
    rt_hour = Column(Integer, nullable=False)
    bkp_day = Column(Integer, nullable=False)
    rt_day = Column(Integer, nullable=False)
    bkp_week = Column(Integer, nullable=False)
    rt_week = Column(Integer, nullable=False)
    bkp_month = Column(Integer, nullable=False)
    rt_month = Column(Integer, nullable=False)
    aws_profile = Column(String(20), ForeignKey('awskeys.aws_profile'), nullable=False)

    def __init__(self, serv_name, remote_user, remote_port ,dir_bkp,bkp_hour,rt_hour,bkp_day,rt_day,bkp_week,rt_week,bkp_month,rt_month,aws_profile):
        self.serv_name = serv_name
        self.remote_user = remote_user
        self.remote_port = remote_port
        self.dir_bkp=dir_bkp
        self.bkp_hour=bkp_hour
        self.rt_hour=rt_hour
        self.bkp_day=bkp_day
        self.rt_day=rt_day
        self.bkp_week=bkp_week
        self.rt_week=rt_week
        self.bkp_month=bkp_month
        self.rt_month=rt_month
        self.aws_profile=aws_profile
        self.aws_key=aws_key
        self.aws_secret=aws_secret

    def __repr__(self):
        return '<Backdata %r>' % self.rt_week

Base.metadata.create_all(engine)

Session = sessionmaker()
Session.configure(bind=engine)
dbsession = Session()

