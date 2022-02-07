remote_file "/tmp/wazuh-manager.zip" do
  source "https://github.com/wazuh/wazuh-docker/archive/master.zip"
  mode "0644"
  action :create_if_missing
end
