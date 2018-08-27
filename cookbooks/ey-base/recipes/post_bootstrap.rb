include_recipe "monit"
#TODOv6 include_recipe "collectd"
#TODOv6 include_recipe "newrelic"
include_recipe "nodejs::common"
#TODOv6 include_recipe "reboot"

file "/etc/engineyard/recipe-revision.txt" do
  action :touch
  mode 0644
end

bash "add-chef-dracul-revision-sha" do
  code "sha1sum /etc/engineyard/dracul.yml | cut -c 1-40 > /etc/engineyard/recipe-revision.txt"
end