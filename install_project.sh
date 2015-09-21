#!/bin/bash
projectname=$1
projecturl=$2
dest_dir=$3
[ $projectname == ""] && echo "Specify project name. ./prereqs.sh project_name" && exit 1
[ $projecturl == ""] && echo "Specify project url. ./prereqs.sh project_name project_url" && exit 1
[ $dest_dir == ""] && echo "Specify destination dir. ./prereqs.sh project_name project_url dest_dir" && exit 1

echo "Cloning project"
git clone $projecturl $dest_dir

echo "Creating virtualenv"
mkvirtualenv $projectname

cd /home/devteam/$dest_dir
pip install -r requirements.txt
export DJANGO_SETTINGS_MODULE=${projectname}.settings.production
./manage.py collectstatic --noinput
./manage.py migrate
