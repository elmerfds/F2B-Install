#!/bin/bash -e
#F2B Installer
#author: elmerfdz
version=v2.2.3-3

#Org Requirements
f2breqname=('Fail2ban' 'cURL')
f2breq=('fail2ban' 'curl')


#config variables
WEB_DIR='/var/www'
SED=`which sed`
CURRENT_DIR=`dirname $0`

F2B_LOC='/etc/fail2ban'
F2B_ACTION_LOC='/etc/fail2ban/action.d'
F2B_FILTER_LOC='/etc/fail2ban/filter.d'
WAN_IP=$(curl ipinfo.io/ip)
INT_IP=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
SCRIPT_USER=$(whoami)

#Modules
#Organizr Requirement Module
f2binstall_mod() 
	{ 
        echo
        echo -e "\e[1;36m> Updating apt repositories...\e[0m"
		echo
		apt-get update	    
        echo
		for ((i=0; i < "${#f2breqname[@]}"; i++)) 
		do
		    echo -e "\e[1;36m> Installing ${f2breqname[$i]}...\e[0m"
		    echo
		    apt-get -y install ${f2breq[$i]}
		    echo
		done
		echo
    }

f2bconfig_mod() 
	{ 
        echo
        echo -e "\e[1;36m> Configuring Fail2ban...\e[0m"
		echo
        cp $CURRENT_DIR/config/jail.local $F2B_LOC
        $SED -i "s/WANIP/$WAN_IP/g" $F2B_LOC/jail.local
        $SED -i "s/INTIP/$INT_IP/g" $F2B_LOC/jail.local
		echo
		echo "1. Enter number of seconds a host will be banned, default = 600"
		read -r BAN_TIME
		BAN_TIME=${BAN_TIME:-600}

		echo "2. Enter a max retry value before a host is banned, default = 4"
		read -r MAX_RETRY
		MAX_RETRY=${MAX_RETRY:-4}

		echo "3. Enter find time value in seconds i.e. A host is banned if it has generated "maxretry" during the last "findtime", default = 3600"
		read -r FIND_TIME
		FIND_TIME=${FIND_TIME:-3600}

		$SED -i "s/BAN_TIME/$BAN_TIME/g" $F2B_LOC/jail.local
        $SED -i "s/MAX_RETRY/$MAX_RETRY/g" $F2B_LOC/jail.local
		$SED -i "s/FIND_TIME/$FIND_TIME/g" $F2B_LOC/jail.local

		echo

        chmod 644 $F2B_LOC/jail.local
        cp $CURRENT_DIR/config/action.d/cloudflare-v4.conf $F2B_ACTION_LOC
        chmod 644 $F2B_ACTION_LOC
        cp $CURRENT_DIR/config/filter.d/* $F2B_FILTER_LOC   
        chmod 644 $F2B_FILTER_LOC/*
        echo "- Done"        
    }

 f2bconfig_cf_mod() 
	{ 
        echo
        echo -e "\e[1;36m> Adding Organizr v2 Jail...\e[0m"
		echo
        echo
		echo -e "\e[1;36m> Please enter the full path to your Organizr login log path?\e[0m" 
        echo "- e.g /var/www/organizr_folder_name/db/organizrLoginLog.json"
        read -r ORGLOGPATH
        echo
		echo "If you're using CloudFlare, you can use the API to utilise their firewall to block IPs, Do you want to set this up? [y/n]"
		read -r cf_action_setup
		cf_action_setup=${cf_action_setup:-n}
		if [ $cf_action_setup = "y" ]
		then 
				
			echo -e "\e[1;36m> Enter your Cloudflare email.\e[0m"
        	read -r cfuser_f2bi
        	echo
			echo -e "\e[1;36m> Enter your Cloudflare API.\e[0m" 
			echo "- You can get your Cloudflare API from here: https://dash.cloudflare.com/profile"        
        	read -r cftoken_f2bi
        	echo
        	$SED -i "s/cfuser_f2bi/$cfuser_f2bi/g" $F2B_ACTION_LOC/cloudflare-v4.conf
        	$SED -i "s/cftoken_f2bi/$cftoken_f2bi/g" $F2B_ACTION_LOC/cloudflare-v4.conf     
			echo

			echo "
## Organizr Jails

[organizr-auth]
enabled  = true
port     = http,https
filter   = organizr-auth-v2
logpath  = $ORGLOGPATH
maxretry = 3

[organizr-auth-cf]
enabled  = true
port     = http,https
filter   = organizr-auth-v2
action   = cloudflare-v4    
logpath  = $ORGLOGPATH
maxretry = 3" >> $F2B_LOC/jail.local
			
		elif [ $cf_action_setup = "n" ]
		then 
		echo "
## Organizr Jails

[organizr-auth]
enabled  = true
port     = http,https
filter   = organizr-auth-v2
maxretry = 3" >> $F2B_LOC/jail.local
		fi


		echo -e "\e[1;36m> Config Done.\e[0m" 
		echo
		echo -e "\e[1;36m> Reloading and Restarting F2B.\e[0m" 

        fail2ban-client reload
        systemctl restart fail2ban
        fail2ban-client reload
   }   


 # Show status of all fail2ban jails.
 # Credit https://gist.github.com/ahmadawais/840098791653a4973a84e27b8451469e
f2bstall_mod() 
    {
        JAILS=($(fail2ban-client status | grep "Jail list" | sed -E 's/^[^:]+:[ \t]+//' | sed 's/,//g'))
        for JAIL in ${JAILS[@]}
        do
			echo
            echo "--------------- JAIL STATUS: $JAIL ---------------"
            echo
            fail2ban-client status $JAIL
            echo
        done
}

f2Rconfig1_mod() 
	{ 
		if [ `whoami` = root ]; then
    		echo To use this option, please do not run script as root or using sudo
    		exit
		fi
        echo
        echo -e "\e[1;36m> Installing & Configuring Fail2Rest...\e[0m"
		sudo touch ./inst_5_temp
		echo
		echo "Downloading script to install Golang tools"
		sudo wget https://raw.githubusercontent.com/canha/golang-tools-install-script/master/goinstall.sh
		echo
		echo "Installing Golang tools"
		bash goinstall.sh --64
		sudo apt-get update
		sudo apt-get install git gcc -y
		#shell_reload
		sudo rm -rf ./goinstall.sh
		echo
		echo -e "\e[1;36m> Press enter to exit script and reload shell\e[0m"
		echo -e "\e[1;36m> Don't forget to re-launch the script without sudo or as root to complete the install: bash f2b.sh\e[0m"
		read
		sudo -u $SCRIPT_USER bash --login
	}

f2Rconfig2_mod() 
	{ 	
		if [ `whoami` = root ]; then
  			echo To use this option, please do not run script as root or using sudo
    		exit
		fi
		
		##debug
		#echo "$GOPATH"
		#go version
		#echo "pausing to check if go is installed"
		#read
		#echo
		##debug end

		go get -v github.com/Sean-Der/fail2rest
		go install -v github.com/Sean-Der/fail2rest
		sudo cp $CURRENT_DIR/fail2rest/config/config.json /tmp
		#sudo wget -P /tmp/ https://raw.githubusercontent.com/Sean-Der/fail2rest/master/config.json #should be changed
		echo
		echo -e "\e[1;36m> Which port number do you want to run the Fail2rest service on? Enter to use Default (5050)\e[0m"
		read -r PORT
		PORT=${PORT:-5050}
		sudo $SED -i "s/PORT/$PORT/g" /tmp/config.json
		sudo mv /tmp/config.json /etc/fail2rest.json

		sudo ln -s $GOPATH/bin/fail2rest /usr/bin/
		sudo cp -a $GOPATH/src/github.com/Sean-Der/fail2rest/init-scripts/systemd /etc/systemd/system/fail2rest.service
		sudo systemctl enable fail2rest.service
		sudo systemctl start fail2rest.service
		sudo rm -rf ./inst_5_temp
		echo
        echo "- Done"
		echo
		echo "Downloading Fail2web & Configuring permissions"        
		sudo git clone --depth=1 https://github.com/Sean-Der/fail2web.git /var/www/fail2web
		echo
		sudo chown -R www-data:$SUDO_USER /var/www/fail2web
		sudo chmod -R 775 /var/www/fail2web
        echo "- Done"
		echo
		echo 
		echo "Create a new nginx server block and add in the following config for your Fail2Web/Fail2Rest setup"
		echo "
    			location / {
        			root /var/www/fail2web/web;	#Fail2Web folder location
    			}
    			location /api/ {
        			proxy_pass		http://127.0.0.1:$PORT/; #Fail2Rest URL
        			proxy_redirect	off;
    			}
   			"
		echo "Make sure you've got some authentication setup to prevent unauthorized access"
		echo
		echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
		read	   

    }


#script Updater
gh_updater_mod()
	{
		echo
		echo "Which branch do you want to pull?"
		echo "- [1] = Master [2] = Dev [3] = Exp"
		read -r gh_branch_no
		echo

		if [ $gh_branch_no = "1" ]
		then 
		gh_branch_name=master
				
		elif [ $gh_branch_no = "2" ]
		then 
		gh_branch_name=dev
	
		elif [ $gh_branch_no = "3" ]
		then 
		gh_branch_name=exp
		fi

		git fetch --all
		git reset --hard origin/$gh_branch_name
		git pull origin $gh_branch_name
		echo
        echo -e "\e[1;36mScript updated, reloading now...\e[0m"
        shell_reload
	}

 shell_reload()
	{
        sleep 1s
		chmod +x $BASH_SOURCE
		exec ./f2b.sh
    } 



show_menus() 
	{
        if [ -e "./inst_5_temp" ]; then
			f2Rconfig2_mod
            clear
		fi

		echo
		echo -e " 	  \e[1;36m|F2B - INSTALLER $version|  \e[0m"
		echo
		echo "| 1.| F2B Install  " 
		echo "| 2.| F2B CloudFlare Action Setup for Organizr "
		echo "| 3.| F2B Complete Install [Install + Config + Organizr Jail + CF Action] "
		echo "| 4.| Show All Jail Status"
		echo "| 5.| Fail2Web Install (F2B frontend) [Do not run script as sudo for this option]"		
		echo "| u.| Script updater   "                  
		echo "| x.| Quit 					  "
		echo
		echo
		printf "\e[1;36m> Enter your choice: \e[0m"
	}
read_options(){
		read -r options

		case $options in
	 	"1")
			echo "- Your choice: 1. Fail2ban Install"
			f2binstall_mod
			f2bconfig_mod
			unset DOMAIN
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;;

	 	"2")
			echo "- Your choice: 2. Fail2ban Install"
            f2bconfig_cf_mod
			echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;; 


		"3")
        	echo "- Your choice 3: F2B Complete Install [Install + Config + Organizr Jail + CF Action]"
			f2binstall_mod
			f2bconfig_mod
            f2bconfig_cf_mod
    		echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read	
		;;

		"4")
        	echo "- Your choice 4: Show All Jails Status"
            f2bstall_mod
    		echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read	
		;;        

		"5")
        	echo "- Your choice 5: Fail2Web/Fail2Rest Install"
            f2Rconfig1_mod
    		echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read	
		;;   

		"u")
        	echo "- Update Script"
            gh_updater_mod
    		echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read	
		;;   

		"x")
			exit 0
		;;


	      	esac
	     }

while true 
do
	clear
	show_menus
	read_options
done