wsl-vhd-mount-service
==================================================================================

Overview
----------------------------------------------------------------------------------

### Introduction of wsl-vhd-mount-service

This repository provides a shell-script(bash) to Mount/Unmount VHD(Virtual Hard Disk) on Windows to/from WSL2(Windows Subsystem for Linux version 2).

Usage
----------------------------------------------------------------------------------

### Usage

```sh
Usage: wsl-vhd-mount-service.sh [-h] [--version] [-n] [-v] [-d] [--info]
                                [--mount] [--wsl-mount] [--fs-mount]
                                [--unmount] [--wsl-unmount] [--fs-unmount]
                                [-c CONFIG_PATH]
                                [--name ID] [--uuid UUID] [--vhd VHD]
                                [--mount-point MOUNT_POINT] [--option MOUNT_OPTION]
                                [-a] [ID ...]
```

### Positional Arguments

| Argument                    | Description                                            |
|-----------------------------|--------------------------------------------------------|
| `ID`                        | Mount/Unmount/Info Target ID in Configuration          |

### Options

| Option                      | Description                                            |
|-----------------------------|--------------------------------------------------------|
| `-h, --help`                | Show this help message and exit                        |
| `--version`                 | Show version of this script                            |
| `--info`                    | Show Configuration Information                         |
| `--wsl-mount`               | Attach VHD on Windows to WSL                           |
| `--wsl-unmount`             | Detach VHD on Windows from WSL                         |
| `--fs-mount`                | Mount VHD already attached to WSL as Linux file system |
| `--fs-unmount`              | Unmount VHD that is mounted as a Linux filesystem      |
| `--mount`                   | --wsl-mount and --fs-mount                             |
| `--unmount`                 | --fs-unmount and --wsl-unmount                         |
| `-c CONFIG_PATH`            | Load Configuration File or Directory                   |
| `--config CONFIG_PATH`      | Load Configuration File or Directory                   |
| `--name ID`                 | Set ID from command line option                        |
| `--uuid UUID`               | Set UUID from command line option                      |
| `--vhd VHD`                 | Set VHD Image File from command line option            |
| `--mount-point MOUNT_POINT` | Set Mount Point from command line option               |
| `--option MOUNT_OPTION`     | Set Mount Option from command line option              |
| `-a, --all`                 | Select All target IDs in Configuration                 |
| `-v, --verbose`             | Enable verbose output                                  |

### Option arguments

| Option arguments | Description                                                       |
|------------------|-------------------------------------------------------------------|
| `ID`             | Mount/Unmount/Info Target ID in Configuration                     |
| `VHD`            | Virutal Hard Disk Image File(e.g., /mnt/d/wsl/work/ext4.vhdx)     |
| `UUID`           | UUID for file system(e.g., 7c8a93f8-3b5f-4694-a056-84b663040963)  |
| `MOUNT_POINT`    | Mount Point for Linux file system(e.g.,/mnt/work/)                |
| `MOUNT_OPTION`   | Mount Option for Linux file system                                |
| `CONFIG_PATH`    | Configuration File Name or Directory                              |

### Environment Variables

| Variable Name                       | Description                                    |
|-------------------------------------|------------------------------------------------|
| `WSL_VHD_MOUNT_SERVICE_CONFIG_PATH` | CONFIG_PATH as a list separated by ':' (e.g.,/etc/wsl-vhd-mount-service.d:~/.wsl-vhd-mount-service) |

### Configuration File Format

```ini:example.ini
[xxxx]                                     # Set ID Name (required)
VHD=/mnt/d/wsl/xxxx/ext4.vhdx              # Set VHD to ID (required)
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  # Set UUID to ID (optional)
MOUNT_POINT=/mnt/xxxx                      # Set MOUNT_POINT to ID (optional)
```

### Example 1

#### Configuration File

```ini:examples.d/00_work.ini
[work]                                     # Set ID Name
VHD=/mnt/d/wsl/work/ext4.vhdx              # Set VHD to ID (required)
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  # Set UUID to ID (optional)
MOUNT_POINT=/mnt/home/work                 # Set MOUNT_POINT to ID (optional)
```

#### Display Configuration Information

```console
shell$ wsl-vhd-mount-service.sh -c examples.d/00_work.ini --info work
[work]
NAME=work
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
VHD=/mnt/d/wsl/home/work/ext4.vhdx
MOUNT_POINT=/mnt/home/work
DESCRIPTION=Mount /mnt/d/wsl/home/work/ext4.vhdx to /mnt/home/work
```

#### Attach VHD on Windows to WSL and Mount as Linux file system

```console
shell# wsl-vhd-mount-service.sh -c examples.d/00_work.ini -v --mount work
INFO : load_config_file examples.d/00_work.ini
INFO : do_wsl_mount[work] /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe Start-Process -FilePath wsl.exe -Verb RunAs -ArgumentList "--mount","--bare","--vhd","D:\wsl\home\work\ext4.vhdx"
INFO : do_fs_mount[work] mount UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /mnt/home/work
```

#### Unmount as a Linux filesystem and Detach VHD on Windows from WSL

```console
shell# wsl-vhd-mount-service.sh -c examples.d/00_work.ini --unmount work
INFO : load_config_file examples.d/00_work.ini
INFO : do_fs_unmount[work] umount /mnt/home/work
INFO : do_wsl_unmount[work] /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe Start-Process -FilePath wsl.exe -Verb RunAs -ArgumentList "--unmount","D:\wsl\home\work\ext4.vhdx"
```

### Example 2

#### Attach VHD on Windows to WSL and Mount as Linux file system

```console
shell# wsl-vhd-mount-service.sh -v --uuid xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --vhd /mnt/d/wsl/home/work/ext4.vhdx --mount-point /mnt/home/work --mount
INFO : do_wsl_mount[___] /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe Start-Process -FilePath wsl.exe -Verb RunAs -ArgumentList "--mount","--bare","--vhd","D:\wsl\home\work\ext4.vhdx"
INFO : do_fs_mount[___] mount UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /mnt/home/work
```

#### Unmount as a Linux filesystem and Detach VHD on Windows from WSL

```console
shell# wsl-vhd-mount-service.sh -v --uuid xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --vhd /mnt/d/wsl/home/work/ext4.vhdx --mount-point /mnt/home/work --unmount
INFO : do_fs_unmount[___] umount /mnt/home/work
INFO : do_wsl_unmount[___] /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe Start-Process -FilePath wsl.exe -Verb RunAs -ArgumentList "--unmount","D:\wsl\home\work\ext4.vhdx"
```

Install
----------------------------------------------------------------------------------

### Maunal Installation

```console
shell$ sudo cp wsl-vhd-mount-service.sh /usr/local/bin/
shell$ sudo cp systemd/wsl-vhd-mount.service /etc/systemd/system/
shell$ sudo install -d /etc/wsl-vhd-mount-service.d
```

### Installation via Debian Package

```console
shell$ sudo dpkg -i wsl-vhd-mount-service_0.1-1_all.deb
Selecting previously unselected package wsl-vhd-mount-service.
(Reading database ... 67747 files and directories currently installed.)
Preparing to unpack wsl-vhd-mount-service_0.1-1_all.deb ...
Unpacking wsl-vhd-mount-service (0.1-1) ...
Setting up wsl-vhd-mount-service (0.1-1) ...
```

License
----------------------------------------------------------------------------------

This project is licensed under the BSD 2-Clause License. See the [LICENSE](./LICENSE) file for details.

