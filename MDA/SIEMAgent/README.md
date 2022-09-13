# MDCA SIEM Agent Service Configuration

Configuring MDCA (Microsoft Defender for Cloud Apps - Formerly MCAS) SIEM Agent as a daemon/service

## Linux

- Prepare folders and permissions

  ```bash
  sudo mkdir /opt/mdca-cef
  sudo mkdir /var/log/mdca
  sudo chown -R <yourusername:yourgroup> /opt/mdca-cef
  sudo chown -R <yourusername:yourgroup> /var/log/mdca
  ```

- Place the file `mdca-cef-connector.sh` in `/opt/mdca-cef`.

- Also create a file `mdca-cef.service` at `/lib/systemd/system/` from the example in this repository.

- Defines the account name to execute service in `mcas-cef.service` (replace the `DACRUZ` from the example).

- Create a file called `settings.json` under `/opt/mcas-cef` with the following syntax and adjust the settings accordingly (eg. Remove proxy configuration if not required.)

  ```json
  {
      "jarName": "mcas-siemagent-0.111.126-signed.jar",
      "token": "S05ZAAAAAAAAAAA...",
      "logDir": "/var/log/mdca",
      "proxy": "server:port"
  }
  ```

- Enable and start service

  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable mcas-cef.service
  sudo systemctl start mcas-cef.service
  ```

## Windows

TBA
