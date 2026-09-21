#!/usr/bin/env bash

# Immutable download inventory for the L4D2 deployment chain.
# This file is data plus lookup helpers only; sourcing it performs no I/O.

declare -ag L4D2_ARTIFACT_KEYS=()
declare -Ag L4D2_ARTIFACT_URL=()
declare -Ag L4D2_ARTIFACT_SHA256=()
declare -Ag L4D2_ARTIFACT_FILE=()
declare -Ag L4D2_ARTIFACT_FORMAT=()
declare -Ag L4D2_ARTIFACT_VERSION=()
declare -Ag L4D2_ARTIFACT_SOURCE=()

l4d2_manifest_add() {
    local key="$1" url="$2" sha256="$3" file="$4" format="$5" version="$6" source="$7"
    L4D2_ARTIFACT_KEYS+=("$key")
    L4D2_ARTIFACT_URL["$key"]="$url"
    L4D2_ARTIFACT_SHA256["$key"]="$sha256"
    L4D2_ARTIFACT_FILE["$key"]="$file"
    L4D2_ARTIFACT_FORMAT["$key"]="$format"
    L4D2_ARTIFACT_VERSION["$key"]="$version"
    L4D2_ARTIFACT_SOURCE["$key"]="$source"
}

# Official framework releases.
l4d2_manifest_add \
    steamcmd \
    'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' \
    'cebf0046bfd08cf45da6bc094ae47aa39ebf4155e5ede41373b579b8f1071e7c' \
    steamcmd_linux.tar.gz tar.gz 'SteamCMD Linux installer snapshot' 'Valve official CDN'
l4d2_manifest_add \
    metamod \
    'https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1226-linux.tar.gz' \
    'f3ab8688885c945516c2616c3e2792451615bd8ad752ed5e0b96334b49f49077' \
    mmsource-1.12.0-git1226-linux.tar.gz tar.gz 'MetaMod:Source 1.12.0-git1226' 'AlliedModders official release'
l4d2_manifest_add \
    sourcemod \
    'https://www.sourcemod.net/smdrop/1.12/sourcemod-1.12.0-git7253-linux.tar.gz' \
    '6bbcab989cda0ada83600d0dcb0f46affd16529b2b02ed2dba1b5baeaf02fdb4' \
    sourcemod-1.12.0-git7253-linux.tar.gz tar.gz 'SourceMod 1.12.0-git7253' 'SourceMod official release'

# Fixed author releases.
l4d2_manifest_add \
    l4dtoolz \
    'https://github.com/lakwsh/l4dtoolz/releases/download/2.5.1/l4dtoolz-2.5.1-2155.zip' \
    '098ed0f0050fd770305ba697a924ccde1afd474f4776afc7a18e9c29c0180df6' \
    l4dtoolz-2.5.1-2155.zip zip 'L4DToolZ 2.5.1 build 2155' 'lakwsh official release'
l4d2_manifest_add \
    actions \
    'https://github.com/Vinillia/actions.ext/releases/download/v3.9.2/actions.ext.zip' \
    'e093ca79bf977b48fdb318b4fa4bc3ab1ce01c7ad7cf0c871354a52e5f8fdd15' \
    actions.ext-v3.9.2.zip zip 'Actions extension 3.9.2' 'Vinillia official release; Actions 4.x intentionally excluded'
l4d2_manifest_add \
    dynamic_balancer \
    'https://github.com/szGabu/L4D2_DynamicInfectedSpawnBalancer/releases/download/1.0.1/L4D2_DynamicInfectedSpawnBalancer.zip' \
    'af1ef8d95302c02d56f68854e83a9ca1dbbf19a0b360a26afbf59752245171f4' \
    L4D2_DynamicInfectedSpawnBalancer-1.0.1.zip zip 'Dynamic Infected Spawn Balancer 1.0.1' 'szGabu official release'

# Fixed source snapshots.  Each URL names an immutable commit, not a branch.
l4d2_manifest_add \
    left4dhooks \
    'https://codeload.github.com/SilvDev/Left4DHooks/tar.gz/f90ae5e62228e0b7baf12cda922e3fd40db844f4' \
    'dd5480e092f5f96c21fcf6bfe1dcea8fc31f89cde9fb164f9b826a6f699d07e3' \
    left4dhooks-1.168-f90ae5e6.tar.gz tar.gz 'Left4DHooks 1.168' 'SilvDev commit f90ae5e62228e0b7baf12cda922e3fd40db844f4'
l4d2_manifest_add \
    mutant_tanks \
    'https://codeload.github.com/Psykotikism/Mutant_Tanks/tar.gz/c7ef30eea49abce235ef9ff50587aed7cd3c4d5a' \
    '24845fd22619dcec5f0ca91952da64d6d6e56f185e45fe630aa41df2568db8ef' \
    mutant-tanks-9.3-c7ef30ee.tar.gz tar.gz 'Mutant Tanks 9.3' 'Psykotikism commit c7ef30eea49abce235ef9ff50587aed7cd3c4d5a'
l4d2_manifest_add \
    fbef_plugins \
    'https://codeload.github.com/fbef0102/L4D1_2-Plugins/tar.gz/8e67e4f659023fccb2fa65fbb74ad38547463302' \
    '7f05e1f7d5495279591b75260dbf2d3ccd5804aa5f0cd353209029e882a8be89' \
    fbef0102-8e67e4f6.tar.gz tar.gz 'fbef0102 L4D1_2-Plugins selected modules' 'fbef0102 commit 8e67e4f659023fccb2fa65fbb74ad38547463302'
l4d2_manifest_add \
    wyxls_plugins \
    'https://codeload.github.com/wyxls/SourceModPlugins-L4D2/tar.gz/c1d14e5f06368363d6800311db752ef6e6b22eda' \
    '68e941c69e352b79558407f35b24f679b2b0be615af0f3b8b0cadd2dc6b73004' \
    wyxls-SourceModPlugins-L4D2-c1d14e5f.tar.gz tar.gz 'wyxls Automatic Weapons and Gear Transfer' 'wyxls commit c1d14e5f06368363d6800311db752ef6e6b22eda'
l4d2_manifest_add \
    dual_primary \
    'https://codeload.github.com/DrStr4Nge147/L4D2-DualPrimary-Plugin/tar.gz/83e2b71c0b21e2a6291b066f903c6af18254a90c' \
    '8e36550486a9e03831849d034b7649a6f134183f6ed0511d2d97c8043f470d1d' \
    dual-primary-83e2b71c.tar.gz tar.gz 'Dual Primaries 1.5.8 source' 'DrStr4Nge147 commit 83e2b71c0b21e2a6291b066f903c6af18254a90c'
l4d2_manifest_add \
    predicaments \
    'https://codeload.github.com/janiluuk/L4D2_Predicaments/tar.gz/5c148841817f305999dd3574645f45cc6a99bf7c' \
    '603d1c77f9e9c26ff2b9e9a5ee69d9e75831147e7a6cf234a76a0518b068334d' \
    predicaments-5c148841.tar.gz tar.gz 'Predicaments 0.4 source' 'janiluuk commit 5c148841817f305999dd3574645f45cc6a99bf7c'
l4d2_manifest_add \
    votekick \
    'https://codeload.github.com/Hubfront/L4D1-L4D2-Votekick-Coop-Versus/tar.gz/8323e0aa01a8c72e52c4468b4a2bbb41976cab67' \
    '4efde606b17963d94f995e131fb2a6718fc91d07ce11fea6da8302a4deed78b6' \
    votekick-v5.3-8323e0aa.tar.gz tar.gz 'Votekick 5.3 source' 'Hubfront commit 8323e0aa01a8c72e52c4468b4a2bbb41976cab67'
l4d2_manifest_add \
    no_friendly_fire \
    'https://codeload.github.com/Psykotikism/No_Friendly-Fire/tar.gz/c4985243d77e4ba2ec58b586a45ba8f3a009821e' \
    'bc798412771a864be4a453a1a60ff0a57b43533de71576a01e6d93753943073a' \
    no-friendly-fire-c4985243.tar.gz tar.gz 'No Friendly-Fire 10.0 source' 'Psykotikism commit c4985243d77e4ba2ec58b586a45ba8f3a009821e'
l4d2_manifest_add \
    smac \
    'https://codeload.github.com/Rushaway/sm-plugin-SMAC/tar.gz/ea15f3ec0c8d9c499d0e42d7174675dd6d30780b' \
    '6410cec01a2e51981c80a183103c0375b877f23dc97079cdef15782c29b389c5' \
    smac-0.8.8.0-ea15f3ec.tar.gz tar.gz 'SMAC 0.8.8.0 source snapshot' 'Rushaway commit ea15f3ec0c8d9c499d0e42d7174675dd6d30780b'
l4d2_manifest_add \
    multicolors \
    'https://codeload.github.com/srcdslab/sm-plugin-MultiColors/tar.gz/d2f2dc9126255571c0fc4499d5729cacb57265ca' \
    'e02900f8df929481ce968f9ac0b551be59526e7d43731215f7c513da51b8c8f6' \
    multicolors-d2f2dc91.tar.gz tar.gz 'MultiColors include snapshot' 'srcdslab commit d2f2dc9126255571c0fc4499d5729cacb57265ca'

l4d2_manifest_keys() {
    printf '%s\n' "${L4D2_ARTIFACT_KEYS[@]}"
}

l4d2_manifest_validate() {
    local key
    local -i count=0
    for key in "${L4D2_ARTIFACT_KEYS[@]}"; do
        [[ "${L4D2_ARTIFACT_URL[$key]}" == https://* ]] || return 1
        [[ "${L4D2_ARTIFACT_SHA256[$key]}" =~ ^[0-9a-f]{64}$ ]] || return 1
        [[ "${L4D2_ARTIFACT_FILE[$key]}" != */* && -n "${L4D2_ARTIFACT_FILE[$key]}" ]] || return 1
        [[ "${L4D2_ARTIFACT_FORMAT[$key]}" == tar.gz || "${L4D2_ARTIFACT_FORMAT[$key]}" == zip ]] || return 1
        count+=1
    done
    (( count >= 16 ))
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -Eeuo pipefail
    l4d2_manifest_validate || exit 1
    printf 'key\tversion\tsha256\turl\tsource\n'
    for key in "${L4D2_ARTIFACT_KEYS[@]}"; do
        printf '%s\t%s\t%s\t%s\t%s\n' \
            "$key" "${L4D2_ARTIFACT_VERSION[$key]}" \
            "${L4D2_ARTIFACT_SHA256[$key]}" "${L4D2_ARTIFACT_URL[$key]}" \
            "${L4D2_ARTIFACT_SOURCE[$key]}"
    done
fi
