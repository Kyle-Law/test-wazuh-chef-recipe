default['wazuh-agent']['user'] = 'root'
default['wazuh-agent']['group'] = 'root'
#Will reauth agents to "new" ip address!
default['wazuh-agent']['reauth'] = false
#local IP address or remote if non VPC
default['wazuh-agent']['ipaddress'] = "10.0.2.233"
