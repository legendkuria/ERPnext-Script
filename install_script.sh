ADMIN_PWD="$1"
SITE_NAME="$2"
COMPANY="$3"
ABBR="$4"
COUNTRY_FIRST_NAME="$5"
COUNTRY_SECOND_NAME="$6"
DEFAULT_CURRENCY="$7"
USER_PWD="$8"
USERNAME="$9"
FIRST_NAME="$10"
TIME_ZONE="$11"
LANGUAGE_NAME="$12"
NUMBER_OF_EMPLOYEES=$13
NUMBER_OF_USERS=$14
ROLES='[{"role":"Stock Manager"},{"role":"Stock User"},{"role":"Accounts Manager"},{"role":"Accounts User"},{"role":"Sales Manager"},{"role":"Sales Master Manager"},{"role":"Sales User"},{"role":"Item Manager"},{"role":"Site User"}]'
SITE_USER_ROLES='[{"role":"System Manager"},{"role":"Stock User"}]'
LANGUAGE="en-US"
COUNTRY="$COUNTRY_FIRST_NAME $COUNTRY_SECOND_NAME"

# Get user specifics
FRAPPE_PWD="saas2024SAAS"
SITE_PWD=$ADMIN_PWD
MYSQL_PASS="RKulPbrQ6M9QizR"
SITE_URL=$SITE_NAME
ROOT_PWD="A,s6WaGMkZ!2B._n"

# Set default settings
TIMEZONE="Europe/Berlin"
FRAPPE_USR='frappe'
FRAPPE_BRANCH='version-14'
ERPNEXT_BRANCH='version-14'

SRVR_ADDR=$(curl -s -4 ifconfig.co)
SITE_ADDR=$(dig +short $SITE_URL)
SERVER_OS=$(/usr/bin/lsb_release -ds | awk '{print $1}')
SERVER_VER=$(/usr/bin/lsb_release -ds | awk '{print $2}' | cut -d. -f1,2)

# Create the site with earlier provided name
echo -e "\033[0;33m \n>\n> Creating new site ${SITE_URL} \n>\n\033[0m"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench new-site ${SITE_URL} --mariadb-root-password $MYSQL_PASS --admin-password $SITE_PWD --db-name "rirelovesatoi""
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_URL} install-app erpnext"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_URL} install-app hrms"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench setup nginx --yes"
systemctl reload nginx

# Deploy for production
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_URL} enable-scheduler"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_URL} set-maintenance-mode off"


# Get all the sites from the bench
FRAPPE_BENCH_PATH="/home/${FRAPPE_USR}/frappe-bench"
SITES_FOLDER="${FRAPPE_BENCH_PATH}/sites"

echo -e "\033[0;33m \n>\n> Setting SSL certificate and key for each site \n>\n\033[0m"

# Set SSL certificate and key for each site
for site in $(ls ${SITES_FOLDER})
do
    if [ -d "${SITES_FOLDER}/${site}" ] && [ "${site}" != "assets" ]; then
        echo -e "\033[0;33m \n>\n> Setting SSL certificate and key for ${site} \n>\n\033[0m"
        su ${FRAPPE_USR} -c "cd ${FRAPPE_BENCH_PATH}; yes | bench set-ssl-certificate ${site} /etc/nginx/conf.d/ssl/mtmm_sa_bundle.crt < /dev/null"
        su ${FRAPPE_USR} -c "cd ${FRAPPE_BENCH_PATH}; yes | bench set-ssl-key ${site} /etc/nginx/conf.d/ssl/mtmm_sa_privkey.key < /dev/null"
        sudo systemctl reload nginx
    fi
done


# Acquire SSL certificate for each site
echo -e "\033[0;33m \n>\n> Creating SSL certificate for each site \n>\n\033[0m"

for site in $(ls ${SITES_FOLDER})
do
    if [ -d "${SITES_FOLDER}/${site}" ] && [ "${site}" != "assets" ]; then
        sudo certbot --non-interactive --nginx -d ${site}
    fi
done

echo -e "\033[0;33m \n>\n> SSL certificates for all sites have been created \n>\n\033[0m"

yes | su ${FRAPPE_USR} -c "jq -S '. + {\"skip_setup_wizard\": 1}' \"/home/frappe/frappe-bench/sites/${SITE_URL}/site_config.json\" > \"/home/frappe/frappe-bench/sites/${SITE_URL}/site_config.json.temp\" &&
mv \"/home/frappe/frappe-bench/sites/${SITE_URL}/site_config.json.temp\" \"/home/frappe/frappe-bench/sites/${SITE_URL}/site_config.json\""
cd "/home/frappe/frappe-bench";
   
bench use $SITE_URL

bench --site $SITE_URL reinstall --yes --db-root-password=$MYSQL_PASS --admin-password=$SITE_PWD;

    
echo "
    import frappe
    frappe.local.lang = '$LANGUAGE'

    warehouse_type = frappe.get_doc({'doctype': 'Warehouse Type','name': 'Transit'})
    warehouse_type.insert(ignore_permissions=True)

    company = frappe.get_doc({
    'doctype': 'Company',
    'company_name': '$COMPANY',
    'abbr': '$ABBR',
    'country': '$COUNTRY',
    'default_currency': '$DEFAULT_CURRENCY',
    'currency': '$DEFAULT_CURRENCY'
    })
    company.insert(ignore_permissions=True)

    user = frappe.get_doc({
    'doctype': 'User',
    'email': '$USERNAME',
    'first_name': '$FIRST_NAME',
    'new_password': '$USER_PWD',
    'roles': $ROLES
    })
    user.insert(ignore_permissions=True)

    system_manager = frappe.get_doc({
    'doctype': 'User',
    'email': 'upeosoft@gmail.com',
    'first_name': 'Upeosoft',
    'new_password': '$USER_PWD',
    'roles': $SITE_USER_ROLES
    })
    system_manager.insert(ignore_permissions=True)

    global_defaults = frappe.get_doc({
    'doctype': 'Global Defaults',
    'default_company': '$COMPANY',
    'country': '$COUNTRY',
    'default_currency': '$DEFAULT_CURRENCY'
    })
    global_defaults.insert(ignore_permissions=True)


    site_user_role = frappe.get_doc({
    'doctype': 'Custom DocPerm',
    'parent': 'Site User',
    'role': 'Site User',
    'if_owner': 0,
    'permlevel':0,
    'select':0,
    'read':1,
    'write':1,
    'create':1,
    'delete':0,
    'submit':0,
    'cancel':0,
    'amend':0,
    'report':1,
    'export':1,
    'import':1,cd 
    'set_user_permissions':0,
    'share':1,
    'print':1,
    'email':1
    })
    site_user_role.insert(ignore_permissions=True)

    system_settings = frappe.get_doc({
    'doctype': 'System Settings',
    'country': '$COUNTRY',
    'time_zone': '$TIME_ZONE',
    'language':'$LANGUAGE',
    'enable_onboarding':1,
    'setup_complete':1
    })
    system_settings.insert(ignore_permissions=True)


    cliet_details = frappe.get_doc({
    'doctype': 'premiumClientsDetails',
    'site_name': '$SITE_NAME',
    'email': '$USERNAME',
    'number_of_users': '$NUMBER_OF_USERS',
    'number_of_employees': '$NUMBER_OF_EMPLOYEES'
    })
    cliet_details.insert(ignore_permissions=True)

    frappe.db.commit()
" | bench --site "${SITE_URL}" console

# Congratulations
echo -e "\033[0;33m \n>\n> Installation successful! CHEERS!!! \n>\n\033[0m"
echo -e "\033[0;33m \n>\n> Wishing you all the best from CODEWITHKARANI.COM \n>\n\033[0m"
echo "Compilation complete."
