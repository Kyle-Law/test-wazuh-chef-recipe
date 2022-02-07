wazuh = node['wazuh-agent']

if File.exist?('/etc/engineyard/.ey-wazuh')
  if wazuh['reauth']
    execute 'reinstall_wazuh' do
      command "/etc/init.d/wazuh-agent stop && /var/ossec/bin/agent-auth -m #{ipaddress} && /etc/init.d/wazuh-agent start"
      user wazuh['user']
      group wazuh['group']
    end
  end
else


group wazuh['group'] do
end

execute 'install_needed_packages' do
  command "apt-get -y install curl apt-transport-https lsb-release"
end

execute 'curl_agent' do
  command "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -"
end

execute 'curl_agent' do
  command "echo 'deb https://packages.wazuh.com/3.x/apt/ stable main' | tee /etc/apt/sources.list.d/wazuh.list && apt-get update"
end

ipaddress = wazuh['ipaddress']
execute 'install_wazuh' do
  command 'WAZUH_MANAGER_IP="#{ipaddress}" apt-get install wazuh-agent'
end

template "/data/ossec.conf" do
  source 'ossec.erb'
  mode '0755'
  variables(
    :ip => wazuh['ipaddress']
  )
end

link "/var/ossec/etc/ossec.conf" do
  to "/data/ossec.conf"
end

execute 'auth_agent' do
  command "/var/ossec/bin/agent-auth -m #{ipaddress}"
end

execute 'start_agent' do
  command "/etc/init.d/wazuh-agent start"
end

execute 'create_install_file' do
  command "echo > /etc/engineyard/.ey-wazuh"
end

end
