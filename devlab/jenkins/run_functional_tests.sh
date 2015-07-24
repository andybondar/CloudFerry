#!/bin/bash
set -e
set -x

export WORKSPACE="${WORKSPACE:-$( cd $( dirname "$0" ) && cd ../../../ && pwd)}"
export CF_DIR=$WORKSPACE/cloudferry
export JOB_NAME="${JOB_NAME:-cloudferry-functional-tests}"

trap 'clean_exit $LINENO $BASH_COMMAND; exit' SIGHUP SIGINT SIGQUIT SIGTERM EXIT
clean_exit()
{
    pushd ${CF_DIR}/devlab
    vboxmanage list vms
    vagrant destroy --force
    popd
}

echo "Preparing environment"

pushd $CF_DIR

if [ "$JOB_NAME" = "cloudferry-functional-tests" ]; then
    git checkout devel
    git remote update
    # cloudferry source dir is not deleted after job finish, so if
    # pull request cannot be automatically rebased, we must abort it explicitly and
    # exit with failure. In case rebase succeeded, functional test should # move on.
    git pull --rebase origin devel || ( git rebase --abort && exit 1 )
elif  [ "$JOB_NAME" = "cloudferry-release-builder"]; then
    echo "Job ${JOB_NAME} is running, 'git remote update' and 'git pull --rebase origin devel' was performed previously"
else
    echo "JOB_NAME defined incorrectly"
    exit 1
fi

virtualenv --clear .venv
source .venv/bin/activate
pip install pip==6.1.1
pip install --allow-all-external -r requirements.txt -r test-requirements.txt

echo "Preparing lab"
echo "kill VBoxHeadless processes"
for n in `vboxmanage list vms | awk -F"{" '{print $2}' | awk -F"}" '{print $1}'`; do ps aux | grep $n | grep VBoxHeadless | awk '{print $2}' | xargs -I {} kill -9 {}; done
echo 'then unregister VMs...'
vboxmanage list vms | awk -F"{" '{print $2}' | awk -F"}" '{print $1}' | xargs -I {} vboxmanage unregistervm --delete {}
list=$(vboxmanage list vms); if [[ -n $list ]]; then echo "Need to clean VMs"; exit 1; fi

echo 'Removing old hostinerfaces...'
vboxmanage list hostonlyifs | awk 'BEGIN { RS="\n\n" } $0 ~ /192.168.1.1/ {print $0}' | awk '$0 ~ /^Name:/ {print $2}'
vboxmanage list hostonlyifs | awk 'BEGIN { RS="\n\n" } $0 ~ /192.168.1.1/ {print $0}' | awk '$0 ~ /^Name:/ {print $2}' | xargs -I {} vboxmanage hostonlyif remove {}

pushd devlab
echo 'Booting new VMs...'
vagrant box update
vagrant up grizzly icehouse

pushd tests
source openrc.example

echo 'Running test load cleaning...'
pushd $CF_DIR
bash ${CF_DIR}/devlab/utils/os_cli.sh clean dst
popd
python generate_load.py --clean --env DST
python generate_load.py --clean --env DST
python generate_load.py --clean --env SRC
python generate_load.py --clean --env SRC

echo 'Running test load generation...'
python generate_load.py
echo 'Openstack resources for source cloud successfully created.'
popd

popd

echo "Preparing configuration for CloudFerry"
devlab/provision/generate_config.sh --cloudferry-path "$CF_DIR"

fab migrate:configuration.ini,debug=True

pushd devlab/tests
echo 'Running tests'
nosetests -d -v --with-xunit
popd

popd
