#!/bin/bash
#
# This shell-script for wsl-vhd-mount-service
# wsl-vhd-mount-service :
#    * WSL2(Windows Subsystem for Linux version 2)
#    * VHD(Virtual Hard Disk)
#    * Mount Service
#
__copyright__='Copyright (C) 2025 ikwzm'
__version__='0.1'
__license__='BSD-2-Clause'
__author__='ikwzm'
__author_email__='ichiro_k@ca2.so-net.ne.jp'
__url__='https://github.com/ikwzm/wsl-vhd-mount-service'
__description__='Mount/Unmount VHD(Virtual Hard Disk) on Windows to/from WSL'

set -e

script_name=$0
PowerShell="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
#
# Run Command: Execute an external command.
# 
dry_run=0
run_command()
{
    if [[ $dry_run -ne 0 ]]; then
        echo "$1"
    fi
    if [[ $dry_run -eq 0 ]]; then
        eval "$1"
    fi
}
#
# Checkpoint: Used to report the status of each phase of this script.
#             Each checkpoint has an assigned severity level,
#             and checkpoints are reported according to the configured severity level.
#
error_count=0
warning_count=0
checkpoint_severity_error=7
checkpoint_severity_warning=6
checkpoint_severity_note=5
checkpoint_severity_verbose=3
checkpoint_severity_phase=2
checkpoint_severity_debug=1
report_severity_level="${checkpoint_severity_warning}"
declare -A checkpoint_serverty_level=(
    [invalid_options]="${checkpoint_severity_error}"
    [run_command_phase]="${checkpoint_severity_verbose}"
    [load_config_file_phase]="${checkpoint_severity_phase}"
    [load_config_file_debug]="${checkpoint_severity_debug}"
    [load_config_file_verbose]="${checkpoint_severity_verbose}"
    [set_config_info_phase]="${checkpoint_severity_phase}"
    [set_config_info_debug]="${checkpoint_severity_debug}"
    [set_config_multipul_id]="${checkpoint_severity_error}"
    [load_config_file_not_found]="${checkpoint_severity_error}"
    [wsl_mount_phase]="${checkpoint_severity_phase}"
    [wsl_mount_no_uuid]="${checkpoint_severity_warning}"
    [wsl_mount_no_vhd]="${checkpoint_severity_warning}"
    [wsl_mount_multipul]="${checkpoint_severity_note}"
    [wsl_mount_run_command]="${checkpoint_severity_verbose}"
    [fs_mount_phase]="${checkpoint_severity_phase}"
    [fs_mount_debug]="${checkpoint_severity_debug}"
    [fs_mount_no_mount_point]="${checkpoint_severity_note}"
    [fs_mount_not_directory]="${checkpoint_severity_warning}"
    [fs_mount_already_mounted]="${checkpoint_severity_warning}"
    [fs_mount_no_uuid]="${checkpoint_severity_warning}"
    [fs_mount_not_found_disk]="${checkpoint_severity_warning}"
    [fs_mount_run_command]="${checkpoint_severity_verbose}"
    [show_config_info_phase]="${checkpoint_severity_phase}"
    [wsl_unmount_phase]="${checkpoint_severity_phase}"
    [wsl_unmount_no_vhd]="${checkpoint_severity_warning}"
    [wsl_unmount_run_command]="${checkpoint_severity_verbose}"
    [fs_unmount_phase]="${checkpoint_severity_phase}"
    [fs_unmount_no_mount_point]="${checkpoint_severity_note}"
    [fs_unmount_not_mounted]="${checkpoint_severity_warning}"
    [fs_unmount_run_command]="${checkpoint_severity_verbose}"
)
check_point()
{
    local level="${checkpoint_serverty_level[$1]:-0}"
    local message="$2"
    local tag=""
    if   [[ "${level}" -eq 0 ]]; then
        return
    fi
    if   [[ "${level}" -ge "${checkpoint_severity_error}"   ]]; then
        tag="ERROR: "
        error_count=$(expr "${error_count}" + 1)
    elif [[ "${level}" -ge "${checkpoint_severity_warning}" ]]; then
        tag="WARN : "
        warning_count=$(expr "${warning_count}" + 1)
    elif [[ "${level}" -ge "${checkpoint_severity_note}"    ]]; then
        tag="NOTE : "
    elif [[ "${level}" -ge "${checkpoint_severity_verbose}" ]]; then
        tag="INFO : "
    elif [[ "${level}" -ge "${checkpoint_severity_debug}"   ]]; then
        tag="DEBUG: "
    fi
    if   [[ "${level}" -ge "${report_severity_level}" ]]; then
        echo "${tag}${message}" 1>&2
    fi
}
#
# CONFIG: Stores the information required for mounting, organized by ID.
# 
declare -a CONFIG_KEYS=("NAME" "UUID" "PARTUUID" "VHD" "PARTITION" "MOUNT_POINT" "OPTIONS" "DESCRIPTION")
declare -a CONFIG_ID_LIST=()
declare -A CONFIG_INFO=()
declare -A CONFIG_PARAMS=()

set_config_info() {
    local id="${1}"
    local config_file="${2}"
    check_point set_config_info_phase "## set_config_info[${id}] start"
    if [[ -n "${CONFIG_INFO[${id},NAME]}" ]]; then
        check_point set_config_multipul_id "## ${config_file}[${id}] is multipul defined"
    else
        CONFIG_ID_LIST+=("${id}")
        for key in "${CONFIG_KEYS[@]}"; do
            local value="${CONFIG_PARAMS[$key]}"
            check_point set_config_info_debug "## set_config_info[${id}]   ${key}=${value}"
            if [[ -n "${value}" ]]; then
                CONFIG_INFO["${id},${key}"]="${value}"
            fi
        done
        if [[ -z "${CONFIG_INFO[${id},NAME]}" ]]; then
            check_point set_config_info_phase "## set_config_info[${id}]   NAME=${id}"
            CONFIG_INFO["${id},NAME"]="${id}"
        fi
        if [[ -z "${CONFIG_INFO[${id},DESCRIPTION]}" ]]; then
            local uuid="${CONFIG_INFO[${id},UUID]}"
            local vhd="${CONFIG_INFO[${id},VHD]}"
            local mount_point="${CONFIG_INFO[${id},MOUNT_POINT]}"
            local description="Mount"
            if [[ -n "${vhd}" ]]; then
                description="${description} ${vhd}"
            else
                description="${description} UUID=${uuid}"
            fi
            if [[ -n "${mount_point}" ]]; then
                description="${description} to ${mount_point}"
            fi
            check_point set_config_info_phase "## set_config_info[${id}]   DESCRIPTION=${description}"
            CONFIG_INFO["${id},DESCRIPTION"]="${description}"
        fi
    fi
    check_point set_config_info_phase "## set_config_info[${id}] done"
}

load_config_file() {
    local config_file="${1}"
    local new_id=""
    CONFIG_PARAMS=()

    check_point load_config_file_phase   "load_config_file(${config_file}) start"
    check_point load_config_file_verbose "load_config_file ${config_file}"

    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        check_point load_config_file_debug "## line: ${line}"
        if [[ "${line}" =~ ^[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
            if [[ -n "${new_id}" ]]; then
                set_config_info "${new_id}" "${config_file}"
            fi
            new_id="${BASH_REMATCH[1]}"
            CONFIG_PARAMS=()
            check_point load_config_file_debug "## [${new_id}]"
            continue
        fi
        if [[ "${line}" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            CONFIG_PARAMS["${key}"]="${value}"
            check_point load_config_file_debug "## ${key}=${value}"
            continue
        fi
    done < "${config_file}"
    if [[ -n "${new_id}" ]]; then
        set_config_info "${new_id}" "${config_file}"
    fi
    check_point load_config_file_phase "load_config_file(${config_file}) done"
}

load_config_files() {
    check_point load_config_file_phase "load_config_files($*) start"
    local config_file_list=()
    for config_path in "$@"; do
        if [[ -d "${config_path}" ]]; then
            for config_file in "${config_path}"/*; do
                [[ -f "$config_file" ]] || continue
                config_file_list+=("${config_file}")
            done
            continue
        fi
        if [[ -f "${config_path}" ]]; then
            config_file_list+=("${config_path}")
            continue
        fi
        check_point load_config_file_not_found "Not found ${config_path}"
    done
    if [[ "${error_count}" -eq 0 ]]; then
        for config_file in "${config_file_list[@]}"; do
            load_config_file "${config_file}"
        done
    fi
    check_point load_config_file_phase "load_config_files($*) done"
}

show_config_info() {
    check_point show_config_info_phase "show_config_info($*) start"
    for id in "$@"; do
        echo "[${id}]"
        for key in "${CONFIG_KEYS[@]}"; do
            if [[ -n "${CONFIG_INFO[${id},${key}]}" ]]; then
                echo "${key}=${CONFIG_INFO[${id},${key}]}"
            fi
        done
    done
    check_point show_config_info_phase "show_config_info($*) done"
}
#
# check_disk_by_uuid:
#
check_disk_by_uuid() {
    local uuid="${1}"
    [[ -z "${uuid}" ]] && echo "error"
    local devfile="/dev/disk/by-uuid/${uuid}"
    if [[ -e "${devfile}" ]]; then
        echo "yes"
    else
        echo "no"
    fi
}
#
# wsl_mount: Attach VHD(Virtual Hard Disk) on Windows to WSL.
#
run_wsl_mount() {
    local id="$1"
    local phase_tag="do_wsl_mount[${id}]"
    local vhd="${CONFIG_INFO[${id},VHD]}"
    check_point wsl_mount_phase "${phase_tag} VHD=${vhd}"
    local wsl_vhd_path=$(wslpath -w "${vhd}")
    local partition="${CONFIG_INFO[${id},PARTITION]}"
    local command="${PowerShell} Start-Process -FilePath wsl.exe"
    local argment_list="\"--mount\""
    argment_list+=",\"--bare\""
    argment_list+=",\"--vhd\",\"${wsl_vhd_path}\""
    command+=" -Verb RunAs"
    command+=" -ArgumentList ${argment_list}"
    check_point wsl_mount_run_command "${phase_tag} $command"
    run_command "${command}"
}
do_wsl_mount() {
    check_point wsl_mount_phase "do_wsl_mount($*) start"
    for id in "$@"; do
        local phase_tag="do_wsl_mount[${id}]"

        local vhd="${CONFIG_INFO[${id},VHD]}"
        if [[ -z "${vhd}" ]]; then
            check_point wsl_mount_no_vhd       "[${id}] has no VHD"
            continue
        fi
        
        local uuid="${CONFIG_INFO[${id},UUID]}"
        if [[ -z "${uuid}" ]]; then
            check_point wsl_mount_no_uuid      "[${id}] has no UUID"
            continue
        fi

        check_point wsl_mount_phase "${phase_tag} uuid=${uuid}"
        local status=$(check_disk_by_uuid "${uuid}")
        case "${status}" in
             "yes")
                check_point wsl_mount_multipul "[${id}](UUID=${uuid}) already mounted"
                 ;;
             "no")
                 run_wsl_mount "${id}"
                 ;;
         esac
    done

    check_point wsl_mount_phase "do_wsl_mount($*) done"
}
#
# fs_mount: Mount VHD(Virtual Hard Disk) already attached to WSL as Linux file system.
#
run_fs_mount() {
    local id="$1"
    local phase_tag="do_fs_mount[${id}]"
    local uuid="${CONFIG_INFO[${id},UUID]}"
    local mount_point="${CONFIG_INFO[${id},MOUNT_POINT]}"
    local command="mount UUID=${uuid} ${mount_point}"
    local options="${CONFIG_INFO[${id},OPTIONS]}"
    if [[ -n "${options}" ]]; then
        command="${command} -o ${options}"
    fi
    check_point fs_mount_run_command "${phase_tag} ${command}"
    run_command "${command}"
}
do_fs_mount() {
    check_point fs_mount_phase "do_fs_mount($*) start"
    local check_list=()

    for id in "$@"; do
        local phase_tag="do_fs_mount[${id}]"
        check_point fs_mount_phase "${phase_tag}"

        local mount_point="${CONFIG_INFO[${id},MOUNT_POINT]}"
        if [[ -z "$mount_point" ]]; then
            check_point fs_mount_no_mount_point   "[${id}] has no MOUNT_POINT"
            continue
        fi
        check_point fs_mount_phase "${phase_tag} mount_point=${mount_point}"
    
        if [[ ! -d "$mount_point" ]]; then
            check_point fs_mount_not_directory   "[${id}] ${mount_point} is not directory"
            continue
        fi
        if mountpoint -q "${mount_point}"; then
            check_point fs_mount_already_mounted "[${id}] ${mount_point} is already mounted"
            continue
        fi
        check_list+=("${id}")
    done

    for check_count in {1..5}; do
        local next_check_list=()
        for id in "${check_list[@]}"; do
            local phase_tag="do_fs_mount[${id}]"
            local uuid="${CONFIG_INFO[${id},UUID]}"
            if [[ -z "${uuid}" ]]; then
                check_point fs_mount_no_uuid "[${id}] has no UUID"
                continue
            fi
            check_point fs_mount_phase "${phase_tag} uuid=${uuid})(${check_count})"
            local status=$(check_disk_by_uuid "${uuid}")
            case "${status}" in
                "yes")
                    run_fs_mount "${id}"
                     ;;
                "no")
                    next_check_list+=("${id}")
                     ;;
            esac
        done
        check_list=("${next_check_list[@]}")
        if [[ "${#check_list[@]}" -eq 0 ]]; then
           break
        fi
        sleep 1
    done

    for id in "${check_list[@]}"; do
        local uuid="${CONFIG_INFO[${id},UUID]}"
        check_point fs_mount_not_found_disk "[${id}] $uuid not found in disk"
    done
          
    check_point fs_mount_phase "do_fs_mount($*) done"
}
#
# wsl_unmount: Detach VHD(Virtual Hard Disk) on Windows from WSL.
#
run_wsl_unmount() {
    local id="$1"
    local phase_tag="do_wsl_unmount[${id}]"
    local vhd="${CONFIG_INFO[${id},VHD]}"
    check_point wsl_unmount_phase "${phase_tag} VHD=${vhd}"
    local wsl_vhd_path=$(wslpath -w "${vhd}")
    local command="${PowerShell} Start-Process -FilePath wsl.exe"
    local argment_list="\"--unmount\",\"${wsl_vhd_path}\""
    command+=" -Verb RunAs"
    command+=" -ArgumentList ${argment_list}"
    check_point wsl_unmount_run_command "${phase_tag} $command"
    run_command "${command}"
}
do_wsl_unmount() {
    check_point wsl_unmount_phase "do_wsl_unmount($*) start"
    for id in "$@"; do
        local phase_tag="do_wsl_unmount[${id}]"
        check_point wsl_unmount_phase "${phase_tag}"

        local vhd="${CONFIG_INFO[${id},VHD]}"
        if [[ -z "${vhd}" ]]; then
            check_point wsl_unmount_no_vhd     "[${id}] has no VHD"
            continue
        fi
        run_wsl_unmount "${id}"
    done
    check_point wsl_unmount_phase "do_wsl_unmount($*) done"
}
#
# fs_unmount: Unmount VHD(Virtual Hard Disk) that is mounted as a Linux filesystem
#
do_fs_unmount() {
    check_point fs_unmount_phase "do_fs_unmount($*) start"
    for id in "$@"; do
        local phase_tag="do_fs_unmount[${id}]"
        check_point fs_unmount_phase "${phase_tag}"
        
        local mount_point="${CONFIG_INFO[${id},MOUNT_POINT]}"
        if [[ -z "$mount_point" ]]; then
            check_point fs_unmount_no_mount_point   "[${id}] has no MOUNT_POINT"
            continue
        fi
        check_point fs_unmount_phase "${phase_tag} mount_point=${mount_point}"
    
        if ! mountpoint -q "${mount_point}"; then
            check_point fs_unmount_not_mounted "[${id}] ${mount_point} not mounted"
            continue
        fi

        local command="umount ${mount_point}"
        check_point fs_unmount_run_command "${phase_tag} ${command}"
        run_command "${command}"
    done
    check_point fs_unmount_phase "do_fs_unmount($*) done"
}
#
# Other comand functions
# 
do_version() {
    local script_base_name="${script_name##*/}"
    echo "${script_base_name} ${__version__}"
    echo "${__copyright__}"
    echo "License ${__license__}"
}
do_help() {
    local script_base_name="${script_name##*/}"
    echo "${script_base_name} ${__version__}"
    local usage_title_="Usage: ${script_base_name}"
    local usage_indent=$(printf '%*s' "${#usage_title_}" '')
    echo "${usage_title_} [-h] [--version] [-n] [-v] [-d] [--info]"
    echo "${usage_indent} [--mount] [--wsl-mount] [--fs-mount]"
    echo "${usage_indent} [--unmount] [--wsl-unmount] [--fs-unmount]"
    echo "${usage_indent} [-c CONFIG_PATH]"
    echo "${usage_indent} [--name ID] [--uuid UUID] [--vhd VHD]"
    echo "${usage_indent} [--mount-point MOUNT_POINT] [--option MOUNT_OPTION]"
    echo "${usage_indent} [-a] [ID ...]"
    echo ""
    echo "${script_base_name} -- ${__description__}"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message and exit"
    echo "  --version      Show version of this script"
    echo "  --info         Show Configuration Information"
    echo "  --wsl-mount    Attach  VHD on Windows to WSL"
    echo "  --wsl-unmount  Detach  VHD on Windows from WSL"
    echo "  --fs-mount     Mount   VHD already attached to WSL as Linux file system"
    echo "  --fs-unmount   Unmount VHD that is mounted as a Linux filesystem"
    echo "  --mount        --wsl-mount and --fs-mount"
    echo "  --unmount      --fs-unmount and --wsl-unmount"
    echo "  -c CONFIG_PATH, --config CONFIG_PATH"
    echo "                 Load Configuration File or Directory"
    echo "  --name ID      Set ID from command line option"
    echo "  --uuid UUID    Set UUID from command line option"
    echo "  --vhd VHD      Set VHD Image File from command line option"
    echo "  --mount-point MOUNT_POINT"
    echo "                 Set Mount Point from command line option"
    echo "  --option MOUNT_OPTION"
    echo "                 Set Mount Option from command line option"
    echo "  -a, --all      Select All target IDs in Configuration"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -d, --debug    Enable debug output"
    echo ""
    echo "Option arguments:"
    echo "  ID             Mount/Unmount/Info Target ID in Configuration"
    echo "  VHD            Virutal Hard Disk Image File(e.g., /mnt/d/wsl/work/ext4.vhdx)"
    echo "  UUID           UUID for file system(e.g., 7c8a93f8-3b5f-4694-a056-84b663040963)"
    echo "  MOUNT_POINT    Mount Point for Linux file system(e.g.,/mnt/work/)"
    echo "  MOUNT_OPTION   Mount Option for Linux file system"
    echo "  CONFIG_PATH    Configuration File Name or Directory"
    echo ""
    echo "Positional arguments:"
    echo "  ID             Target ID in Configuration"
    echo ""
    echo "Environment Variables:"
    echo "  WSL_VHD_MOUNT_SERVICE_CONFIG_PATH"
    echo "                 CONFIG_PATH as a list separated by ':'"
    echo "                 (e.g.,/etc/wsl-vhd-mount-service.d:~/.wsl-vhd-mount-service)"
    echo ""
    echo "Configuration File Format:"
    echo "[xxxx]                                     # Set ID Name (required)"
    echo "VHD=/mnt/d/wsl/xxxx/ext4.vhdx              # Set VHD to ID (required)"
    echo "UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  # Set UUID to ID (optional)"
    echo "MOUNT_POINT=/mnt/xxxx                      # Set MOUNT_POINT to ID (optional)"
    echo ""
}
#
# Main process
# 
declare -a command_list=()
declare -a config_path_list_from_options=()
declare -a config_path_list_from_environment=(${WSL_VHD_MOUNT_SERVICE_CONFIG_PATH//:/ })
declare -a target_list=()
declare -a invalid_option_list=()
declare -A config_params_from_options=()
target_all=0

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            report_severity_level="${checkpoint_severity_verbose}"
            shift
            ;;
        -d|--debug)
            report_severity_level="${checkpoint_severity_debug}"
            shift
            ;;
        -n|--dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            command_list+=("help")
            shift
            ;;
        --version)
            command_list+=("version")
            shift
            ;;
        -a|--all)
            target_all=1
            shift
            ;;
        -c|--config)
            shift
            config_path_list_from_options+=("${1}")
            shift
            ;;
        --mount)
            command_list+=("wsl-mount" "fs-mount")
            shift
            ;;
        --wsl-mount)
            command_list+=("wsl-mount")
            shift
            ;;
        --fs-mount)
            command_list+=("fs-mount")
            shift
            ;;
        --unmount)
            command_list+=("fs-unmount" "wsl-unmount")
            shift
            ;;
        --wsl-unmount)
            command_list+=("wsl-unmount")
            shift
            ;;
        --fs-unmount)
            command_list+=("fs-unmount")
            shift
            ;;
        --info)
            command_list+=("config-info")
            shift
            ;;
        --name)
            shift
            config_params_from_options[NAME]="${1}"
            shift
            ;;
        --uuid)
            shift
            config_params_from_options[UUID]="${1}"
            shift
            ;;
        --partuuid)
            shift
            config_params_from_options[PARTUUID]="${1}"
            shift
            ;;
        --vhd)
            shift
            config_params_from_options[VHD]="${1}"
            shift
            ;;
        --partition)
            shift
            config_params_from_options[PARTITION]="${1}"
            shift
            ;;
        --mount-point)
            shift
            config_params_from_options[MOUNT_POINT]="${1}"
            shift
            ;;
        --option)
            shift
            config_params_from_options[OPTIONS]="${1}"
            shift
            ;;
        --description)
            shift
            config_params_from_options[DESCRIPTION]="${1}"
            shift
            ;;
        -*)
            invalid_option_list+=("${1}")
            shift
            ;;
        *)
            target_list+=("${1}")
            shift
            ;;
    esac
done

if [[ "${#invalid_option_list[*]}" -ne 0 ]]; then
    check_point invalid_options "Invalid options ${invalid_option_list[*]}"
    do_help 
    exit 1
fi

if [[ "${#config_path_list_from_environment[*]}" -ne 0 ]]; then
    check_point load_config_file_phase "load_config_file from WSL_VHD_MOUNT_SERVICE_CONFIG_PATH start"
    for config_path in "${config_path_list_from_environment[@]}"; do
        if [[ -f "${config_path}" ]] || [[ -d "${config_path}" ]]; then
            load_config_files "${config_path}"
        fi
    done
    check_point load_config_file_phase "load_config_file from WSL_VHD_MOUNT_SERVICE_CONFIG_PATH done"
    if [[ "$error_count" -ne 0 ]]; then
        exit 1
    fi
fi

if [[ "${#config_path_list_from_options[*]}" -ne 0 ]]; then
    load_config_files "${config_path_list_from_options[@]}"
    if [[ "$error_count" -ne 0 ]]; then
        exit 1
    fi
fi

if [[ "${#config_params_from_options[*]}" -ne 0 ]]; then
    if [[ -n "${config_params_from_options[NAME]}" ]]; then
        new_id="${config_params_from_options[NAME]}"
    else
        new_id="___"
    fi
    CONFIG_PARAMS=()
    for key in "${!config_params_from_options[@]}"; do
        CONFIG_PARAMS["${key}"]="${config_params_from_options[${key}]}"
    done        
    set_config_info "${new_id}" ""
    target_list+=("${new_id}")
fi

if [[ "${#target_list[*]}" -eq 0 ]]; then
    target_all=1
fi

if [[ "$target_all" -gt 0 ]]; then
    target_list=()
    for id in "${CONFIG_ID_LIST[@]}"; do
        target_list+=("${id}")
    done
fi    

if [[ "${#command_list[*]}" -eq 0 ]]; then
    command_list+=("help")
fi

for command in "${command_list[@]}"; do
    case "$command" in
        "help"        ) do_help ;;
        "version"     ) do_version ;;
        "wsl-mount"   ) do_wsl_mount    "${target_list[@]}" ;;
        "wsl-unmount" ) do_wsl_unmount  "${target_list[@]}" ;;
        "fs-mount"    ) do_fs_mount     "${target_list[@]}" ;;
        "fs-unmount"  ) do_fs_unmount   "${target_list[@]}" ;;
        "config-info") show_config_info "${target_list[@]}" ;;
    esac
    if [[ "$error_count" -ne 0 ]]; then
        exit 1
    fi
done

exit 0
