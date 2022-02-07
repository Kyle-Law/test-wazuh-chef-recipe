# Include your desired recipe(s) to run after the completion of the main execution phase
#
include_recipe "custom-redis"
include_recipe "custom-wazuh-agent"
include_recipe "custom-wazuh-manager"
