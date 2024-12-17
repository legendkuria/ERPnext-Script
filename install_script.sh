#!/bin/bash
ADMIN_PWD=$1
SITE_URL=$2
COMPANY=$3
ABBR=$4
COUNTRY=$5
DEFAULT_CURRENCY=$6
USER_PWD=$7
USERNAME=$8
FIRST_NAME=$9
TIME_ZONE=${10}
LANGUAGE_NAME=${11}
LANGUAGE="en-US"
FRAPPE_PWD="saas2024SAAS"
MYSQL_PASS="RKulPbrQ6M9QizR"
FRAPPE_USR='frappe'
FRAPPE_BENCH_PATH="/home/${FRAPPE_USR}/frappe-bench"
SSL_CERT="/etc/nginx/conf.d/ssl/mtmm_sa_bundle.crt"
SSL_KEY="/etc/nginx/conf.d/ssl/mtmm_sa_privkey.key"
SITE_PWD=$ADMIN_PWD
SITE_NAME=$SITE_URL
SYSTEM_MANAGER_ROLE='[{"role":"System Manager"}]'
API_KEY="14353d90b5995a6"
API_SECRET="7165202111f241f"

# API Endpoints
SUBSCRIBED_MODULE_AND_ROLES_API="https://endpoint.mtmm.sa/api/method/datacollection.service.rest.get_subscribed_role_and_modules"
SYSTEM_MODULES_API="https://endpoint.mtmm.sa/api/method/datacollection.service.rest.get_system_modules"

# Fetch subscribed modules and roles from API without authentication
response=$(curl -s -X GET "$SUBSCRIBED_MODULE_AND_ROLES_API" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$USERNAME\"}")

# Check if the response contains the "message" key
if [[ $(echo "$response" | jq '.message') == "null" ]]; then
  echo "Error: Invalid or unauthorized response from the API. Check endpoint permissions."
  exit 1
fi

# Extract subscribed roles as key-value pairs (combining roles from both arrays inside message)
subscribed_roles=$(echo "$response" | jq -r '[.message[0][] | .roles[] | {role: .}]')

# Extract subscribed modules
subscribed_modules=$(echo "$response" | jq -r '[.message[1][] | {module: .module}]')

# Fetch all system modules from API without authentication
system_modules_response=$(curl -s -X GET "$SYSTEM_MODULES_API" \
  -H "Content-Type: application/json")

# Check if the system modules response contains the "message" key
if [[ $(echo "$system_modules_response" | jq '.message') == "null" ]]; then
  echo "Error: Invalid response from system modules API."
  exit 1
fi


# Extract system modules
system_modules=$(echo "$system_modules_response" | jq -r '[.message.all_module[] | {module: .module}]')

# Calculate blocked modules by excluding subscribed modules from system modules
blocked_modules=$(echo "$system_modules" | jq --argjson subscribed_modules "$subscribed_modules" \
  '[.[] | select(.module as $m | $subscribed_modules | map(.module) | index($m) | not)]')


 # Escape the JSON string for Python
USER_SUBSCRIBED_ROLES=$(echo "$subscribed_roles" | jq -c .) 
USER_SUBSCRIBED_MODULES=$(echo "$blocked_modules" | jq -c .)

echo "USER_SUBSCRIBED_ROLES: $USER_SUBSCRIBED_ROLES"
echo "USER_SUBSCRIBED_MODULES: $USER_SUBSCRIBED_MODULES"

# Function to send progress updates
post_progress_update() {
    local title="$1"
    local description="$2"
    curl -X POST "https://endpoint.mtmm.sa/api/method/datacollection.service.rest.post_progress_update" \
        -H "Content-Type: application/json" \
        -d "{\"progress_update_infor\": {\"email\": \"${USERNAME}\", \"title\": \"${title}\", \"description\": \"${description}\"}}"
}

# Function to Send Client Welcome Email
send_client_welcome_email() {
    curl -X POST "https://endpoint.mtmm.sa/api/method/datacollection.service.rest.send_client_welcome_email" \
        -H "Content-Type: application/json" \
        -d "{\"email_infor\": {\"client_email\": \"${USERNAME}\", \"user_pwd\": \"${USER_PWD}\"}}"
}


# Create the site with dynamically passed name
echo -e "\033[0;33m \n>\n> Creating new site ${SITE_NAME} \n>\n\033[0m"
post_progress_update "Creating New Site" "Creation of site ${SITE_NAME} in progress...."
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench new-site ${SITE_NAME} --mariadb-root-password $MYSQL_PASS --admin-password $SITE_PWD --db-name "finallyamprounfhswowyas""

# Install ERPNext and HRMS Apps
post_progress_update "Installing System Instance Apps" "Installation of System Apps for site ${SITE_NAME} in progress...."
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app erpnext"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app hrms"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app ksa"
# Check if 'Healthcare' is in subscribed modules and install the app if it is
if echo "$subscribed_modules" | jq -e 'any(.module == "Healthcare")'; then
    su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app healthcare"
fi

# Check if 'Education' is in subscribed modules and install the app if it is
if echo "$subscribed_modules" | jq -e 'any(.module == "Education")'; then
    su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app education"
fi
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench setup nginx --yes"
systemctl reload nginx

# Enable Scheduler and Set Maintenance Mode Off
post_progress_update "Scheduler Enabled" "Scheduler enabled for site ${SITE_NAME}"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} enable-scheduler"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} set-maintenance-mode off"

# Set SSL certificate and key
echo -e "\033[0;33m \n>\n> Setting SSL certificate and key for ${SITE_NAME} \n>\n\033[0m"
post_progress_update "Setting SSL" "Setting SSL certificate and key for ${SITE_NAME}"
su ${FRAPPE_USR} -c "cd ${FRAPPE_BENCH_PATH}; yes | bench set-ssl-certificate ${SITE_NAME} ${SSL_CERT} < /dev/null"
su ${FRAPPE_USR} -c "cd ${FRAPPE_BENCH_PATH}; yes | bench set-ssl-key ${SITE_NAME} ${SSL_KEY} < /dev/null"
sudo systemctl reload nginx
echo -e "\033[0;33m \n>\n> SSL setup complete for ${SITE_NAME} \n>\n\033[0m"

# Skip the setup wizard
post_progress_update "Skipping Wizard" "Skipping wizard for site ${SITE_NAME}."
yes | su ${FRAPPE_USR} -c "jq -S '. + {\"skip_setup_wizard\": 1}' \"/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json\" > \"/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json.temp\" &&
mv \"/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json.temp\" \"/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json\""
cd "/home/frappe/frappe-bench";

bench use $SITE_NAME
bench --site $SITE_NAME reinstall --yes --db-root-password=$MYSQL_PASS --admin-password=$SITE_PWD;
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_NAME} install-app datacollection"

# Migrate the site
post_progress_update "Migrating the Site" "Migrating and Restarting site ${SITE_NAME}"
bench --site $SITE_NAME migrate

# Post progress update for setting up system data
post_progress_update "Setting up Default System Data" "Configuring default system data for site ${SITE_NAME}"
CURRENT_YEAR=$(date +%Y)

# Setting Default Data
echo "
import json
import frappe

# Load language settings and input data
frappe.local.lang = '$LANGUAGE'
user_roles = json.loads('$USER_SUBSCRIBED_ROLES')
user_blocked_modules = json.loads('$USER_SUBSCRIBED_MODULES')

# Function to check and insert a document if it does not exist
def create_if_not_exists(doctype, filters, data):
    if not frappe.db.exists(doctype, filters):
        doc = frappe.get_doc(data)
        doc.insert(ignore_permissions=True)

# 1. Create 'Transit' Warehouse Type if it doesn't exist
create_if_not_exists('Warehouse Type', 'Transit', {
    'doctype': 'Warehouse Type',
    'name': 'Transit'
})

# 2. Company Setup
create_if_not_exists('Company', '$COMPANY', {
    'doctype': 'Company',
    'company_name': '$COMPANY',
    'abbr': '$ABBR',
    'country': '$COUNTRY',
    'default_currency': '$DEFAULT_CURRENCY',
    'currency': '$DEFAULT_CURRENCY',
    'create_chart_of_accounts_based_on': 'Standard Template',
    'chart_of_accounts': 'Standard with Numbers'
})

# 3. Create Default User with Subscribed Roles and Blocked Modules
create_if_not_exists('User', '$USERNAME', {
    'doctype': 'User',
    'email': '$USERNAME',
    'first_name': '$FIRST_NAME',
    'new_password': '$USER_PWD',
    'roles': user_roles,
    'block_modules': user_blocked_modules
})

# 4. Create System Manager User
create_if_not_exists('User', 'upeosoft@gmail.com', {
    'doctype': 'User',
    'email': 'upeosoft@gmail.com',
    'first_name': 'Upeosoft',
    'new_password': '$USER_PWD',
    'roles': $SYSTEM_MANAGER_ROLE
})

# 5. Update System Settings
system_settings = frappe.get_doc('System Settings')
system_settings.update({
    'country': '$COUNTRY',
    'time_zone': '$TIME_ZONE',
    'language': '$LANGUAGE',
    'enable_onboarding': 1,
    'setup_complete': 1
})
system_settings.save(ignore_permissions=True)

# 6. Update Global Defaults
global_defaults = frappe.get_doc('Global Defaults')
global_defaults.update({
    'default_company': '$COMPANY',
    'country': '$COUNTRY',
    'default_currency': '$DEFAULT_CURRENCY'
})
global_defaults.save(ignore_permissions=True)

# 7. Setup Fiscal Year
create_if_not_exists('Fiscal Year', '$CURRENT_YEAR', {
    'doctype': 'Fiscal Year',
    'year': '$CURRENT_YEAR',
    'year_start_date': f'$CURRENT_YEAR-01-01',
    'year_end_date': f'$CURRENT_YEAR-12-31'
})

# 8. Insert Premium Client Details
create_if_not_exists('premiumClientsDetails', '$SITE_NAME', {
    'doctype': 'premiumClientsDetails',
    'site_name': '$SITE_NAME',
    'email': '$USERNAME'
})

# Commit the database changes
frappe.db.commit()
" | bench --site "${SITE_URL}" console

# Post progress after email is successfully sent
send_client_welcome_email
post_progress_update "Email Sent" "Email sent successfully to ${USERNAME}"

# Final step
echo -e "\033[0;33m \n>\n> Installation successful! CHEERS!!! \n>\n\033[0m"
post_progress_update "Installation Complete" "Site installation completed successfully for ${SITE_NAME}"
echo -e "\033[0;33m \n>\n> Wishing you all the best from CODEWITHKARANI.COM \n>\n\033[0m"
