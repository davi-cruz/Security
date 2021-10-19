# MCAS SIEM Agent Service Configuration

Configuring MCAS SIEM Agent as a Service

## Linux

- Prepare folders and permissions

  ```bash
  sudo mkdir /opt/mcas-cef
  sudo mkdir /var/log/mcas
  sudo chown -R <yourusername:yourgroup> /opt/mcas-cef
  sudo chown -R <yourusername:yourgroup> /var/log/mcas
  ```

- Place the file `mcas-cef-connector.sh` in `/opt/mcas-cef`

- Also create a file `mcas-cef.service` at `/lib/systemd/system/`

- Defines the account name to execute service in `mcas-cef.service`

- Create a file called `settings.json` under `/opt/mcas-cef` with the following syntax

  ```json
  {
      "jarName": "mcas-siemagent-0.111.126-signed.jar",
      "token": "S05ZAAAAAAAAAAA",
      "logDir": "/var/log/mcas",
      "proxy": "server:port"
  }
  ```

  - Keep proxy empty if no proxy should be used.

- Enable and start service 

  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable mcas-cef.service
  sudo systemctl start mcas-cef.service
  ```

## Windows

TBA