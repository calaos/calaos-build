#/bin/env bash

set -e

export build_dir="/src"
export signing_available=0

#Usage: get_version /path/to/repo
function get_version()
{
    repo=$1
    pushd $repo > /dev/null
    git describe --tags --abbrev=0
    popd > /dev/null
}

function beginsWith()
{
    case $2 in "$1"*) true;; *) false;; esac;
}

function endsWith()
{
    case $2 in *"$1") true;; *) false;; esac;
}

#Usage: sync_repo $SRCDIR http://github.com/group/project.git master
function sync_repo()
{
    echo "Syncing repository $2"

    dir=$1
    gitrepo=$2
    branch=$3
    
    if [ -e ${dir}/.build_ignore_git ] ; then
    	echo "Git clone ignored."
		return 0
    fi

    if ! [ -e ${dir} ] ; then
        git clone $gitrepo $dir
        ( cd $dir; git checkout $branch; )
    else
    	cd $dir
    	remote="$(git config --get remote.origin.url)"
		cd ..
		
		if [ "$remote" = "$gitrepo" ]; then
	        ( cd $dir;
				git clean -d -f -x
				git reset --hard
				git checkout $branch
				git pull --rebase
				git tag -l | xargs git tag -d
				git fetch --tags )
		else
			echo "*** Remote has changed ***"
			test -z "$dir" || test -d $dir && rm -fr $dir
			git clone $gitrepo $dir
        	( cd $dir; git checkout $branch; )
		fi
    fi
}

function import_gpg_key()
{
    if [ ! -e $build_dir/gpg-key.asc ]
    then
        echo "No gpg key to import. Skipping signing..."
    else
        echo "Setup gpg keys"

        #Increase ttl cache time
        cat > $HOME/.gnupg/gpg-agent.conf <<- 'EOF'
default-cache-ttl 34560000
max-cache-ttl 34560000
EOF

        tmpfile=$(mktemp /tmp/gpg-calaos.XXXXXX)
        gpg --import --batch --no-tty $build_dir/gpg-key.asc
        echo "hello world" > $tmpfile
        gpg --detach-sig --yes -v --output=/dev/null --pinentry-mode loopback --passphrase "$(cat $build_dir/passphrase.txt)" $tmpfile
        rm $tmpfile

        signing_available=1
    fi
}

#Usage: upload_pkg packages/calaos-ddns/calaos-ddns-1.0-1-x86_64.pkg.tar.zst $repo x86_64
# with $repo can be: 'calaos' or 'calaos-dev'
function upload_pkg()
{
    if [ ! -e $build_dir/upload_token ]
    then
        echo "No upload token set. Skipping upload..."
    else
        FNAME=$1
        FNAMESIG=$1.sig
        REPO=$2
        ARCH=$3
        UPPATH=${REPO}/${ARCH}

        UPLOAD_KEY=$(cat $build_dir/upload_token)

        echo "Uploading package $FNAME"
        curl -X POST \
            -H "Content-Type: multipart/form-data" \
            -F "upload_key=$UPLOAD_KEY" \
            -F "upload_folder=$UPPATH" \
            -F "upload_file_sig=@$FNAMESIG" \
            -F "upload_file=@$FNAME" \
            -F "upload_update_repo=true" \
            -F "upload_replace=true" \
            -F "upload_repo=$REPO" \
            https://arch.calaos.fr/upload
    fi
}

#Set permissions on docker mounted volume which belongs to root by default
function fix_docker_perms()
{
    #Fix permission issue for non root user calaos
    sudo chown -R calaos:docker $build_dir
}

function setup_calaos_repo()
{
    sudo pacman-key --recv-keys AEE23917D88BD96A
    sudo pacman-key --lsign-key AEE23917D88BD96A

    if ! grep arch.calaos.fr /etc/pacman.conf > /dev/null
    then
        sudo tee -a /etc/pacman.conf > /dev/null <<- 'EOF'
[calaos]
Server = https://arch.calaos.fr/$repo/$arch

[calaos-dev]
Server = https://arch.calaos.fr/$repo/$arch
EOF
    fi

    #Do not fail if our repo is not usable
    set +e
    sudo pacman -Sy --noconfirm
    set -e
}
