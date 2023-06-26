# Microsoft Defender for Endpoint (MDE) Resources

## Linux

- [Ansible Playbooks for MDE](https://github.com/davi-cruz/Security/tree/main/MDE/Linux/AnsiblePlaybooks): Playbooks for installing and configuring MDE on Linux systems. As of today it also contains a playbook for policy management.

## Windows

- [`Get-MDELogs.ps1`](https://github.com/davi-cruz/Security/tree/main/MDE/Windows/Get-MDELogs.ps1): Script to collect MDE logs from a Windows system and save them in a zip file for a quick analysis when MDE Client Analyzer is too much for the job.

- [MDE Intune Evaluation Config](https://github.com/davi-cruz/Security/tree/main/MDE/Windows/IntuneEvaluationConfig): Sample Intune Policies to evaluate MDE Capabilities based on article [Evaluate Microsoft Defender Antivirus](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/evaluate-microsoft-defender-antivirus?view=o365-worldwide).
  - Usage: Download assets and run `.\Import-IntunePolicies.ps1` point to the folder where you downloaded the assets. Files must be in the folder structure used by IntuneBackupAndRestore Module.
