#!/bin/bash
projectname=$1
projecturl=$2
dest_dir=$3
[ $projectname == ""] && echo "Specify project name. ./prereqs.sh project_name" && exit 1
[ $projecturl == ""] && echo "Specify project url. ./prereqs.sh project_name project_url" && exit 1
[ $dest_dir == ""] && echo "Specify destination dir. ./prereqs.sh project_name project_url dest_dir" && exit 1
echo $projectname

echo "Configuring percona repo"
sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
echo "deb http://repo.percona.com/apt "$(lsb_release -sc)" main" | sudo tee /etc/apt/sources.list.d/percona.list

echo "Upgrading"
apt-get update && apt-get -y upgrade

echo "Installing required packages"
apt-get install -y build-essential supervisor nginx git-core git python-dev python-pip percona-server-server-5.5 percona-server-client-5.5 libmysqlclient-dev

echo "Upgrading pip"
pip install --upgrade pip &> /dev/null
rm /usr/bin/pip
ln -s /usr/local/bin/pip /usr/bin/pip
echo "Installing virtuanenvwrapper"
pip install virtualenvwrapper &> /dev/null

echo "Creating devteam user"
useradd -m -d /home/devteam -s /bin/bash devteam
echo ". /usr/local/bin/virtualenvwrapper.sh" >> /home/devteam/.profile
chown devteam:devteam /home/devteam/.profile
cd /home/devteam

echo "Cloning project"
sudo -u devteam git clone $projecturl $dest_dir

echo "Creating virtualenv"
sudo -u devteam mkvirtualenv $projectname
chown -R devteam /home/devteam/
cd /home/devteam/$dest_dir

echo "Configuring nginx"
echo > /etc/nginx/sites-enabled/default
echo > /etc/nginx/sites-enabled/default << EOF
upstream django {
    server unix:///tmp/${projectname}.sock;
}

server {
    listen      80;
    server_name ${projectname};
    charset     utf-8;

    access_log /var/log/nginx/${projectname}_access.log;
    error_log /var/log/nginx/${projectname}_error.log;

    client_max_body_size 1M;   # adjust to taste

    location /media {
        alias /home/devteam/${dest_dir}/media;
    }

    location /static {
        alias /home/devteam/${dest_dir}/static;
    }

    location / {
        uwsgi_pass  django;
        include uwsgi_params;
    }
}
EOF

echo "Configuring uWSGI"
echo > /home/devteam/uwsgi.conf << EOF
[uwsgi]
uid=devteam
gid=devteam

env=DJANGO_SETTINGS_MODULE=${projectname}.settings.production
env=SECRET_KEY=`openssl rand -base64 32`

vhost=true
socket=/tmp/${projectname}.sock
master=true
enable-threads=true
processes=2
harakiri=20
max-requests=5000
chmod-socket=777
vacuum=true

wsgi-file=/home/devteam/${dest_dir}/$projectname/wsgi.py
virtualenv=/home/devteam/.virtualenvs/${projectname}
chdir=/home/devteam/${projectname}
touch-reload=/dev/shm/site-reload
EOF

echo "Configuring supervisor"
mkdir /var/log/${projectname}
chown -R devteam.devteam /var/log/${projectname}
echo > /etc/supervisor/conf.d/${projectname}.conf << EOF
[program:${projectname}]
directory=/home/devteam/${projectname}
command=/home/devteam/.virtualenvs/${projectname}/bin/uwsgi --chmod-socket --ini /home/devteam/uwsgi.conf
user=devteam
stdout_logfile=/var/log/${projectname}/wsgi.log
stderr_logfile=/var/log/${projectname}/wsgi_err.log
autostart=true
autorestart=true
redirect_stderr=true
stopwaitsecs = 60
stopsignal=INT

EOF
