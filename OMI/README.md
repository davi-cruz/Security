# OMI Management on Linux

This folder contains some resources I've been working with customers on updating OMI after OMIGOD CVE publishing.

Feel free to reuse some of the code here shared and any feedback is very welcome!

The script and Ansible playbooks were created based on same purpose folder for MDE in this same repo.

Ansible playbook usage sample. You'll also need to adjust your `ansible.cfg` pointing to your inventory file.

``` bash
# Configures bash and ssh-key to be used as authentication method
ssh-agent bash
ssh-add /path/to/key/id_rsa

# Verification:
ansible-playbook ./playbooks/omi_install.yml --check

# Install/Update:
ansible-playbook ./playbooks/omi_install.yml
```

HTH
