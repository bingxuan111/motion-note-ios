#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd "${script_dir}/.." && pwd)"
readonly target_file="${project_root}/MotionNote/ViewControllers/RecordViewController.m"

is_valid_ipv4() {
    local candidate="$1"
    local first second third fourth
    if [[ ! "${candidate}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    IFS='.' read -r first second third fourth <<< "${candidate}"
    for octet in "${first}" "${second}" "${third}" "${fourth}"; do
        if ((10#${octet} > 255)); then
            return 1
        fi
    done
    if ((10#${first} == 0 || 10#${first} == 127 || (10#${first} == 169 && 10#${second} == 254))); then
        return 1
    fi
}

default_interface=""
if command -v route >/dev/null 2>&1; then
    default_interface="$({ route -n get default 2>/dev/null || true; } | awk '/interface:/{print $2; exit}')"
fi

local_ip=""
for interface in "${default_interface}" en0 en1; do
    [[ -n "${interface}" ]] || continue
    candidate="$(ipconfig getifaddr "${interface}" 2>/dev/null || true)"
    if [[ -n "${candidate}" ]] && is_valid_ipv4 "${candidate}"; then
        local_ip="${candidate}"
        break
    fi
done

if [[ -z "${local_ip}" ]] && command -v ifconfig >/dev/null 2>&1; then
    while IFS= read -r candidate; do
        if is_valid_ipv4 "${candidate}"; then
            local_ip="${candidate}"
            break
        fi
    done < <({ ifconfig 2>/dev/null || true; } | awk '/^[[:space:]]*inet /{print $2}')
fi

if [[ -z "${local_ip}" ]]; then
    echo "错误：未找到可用的本机局域网 IPv4 地址。" >&2
    exit 1
fi

if [[ ! -f "${target_file}" ]]; then
    echo "错误：找不到 ${target_file}" >&2
    exit 1
fi

match_count="$(grep -Ec '^NSString \* const IPAdress = @"[^"]+";$' "${target_file}" || true)"
if [[ "${match_count}" != "1" ]]; then
    echo "错误：IPAdress 定义数量应为 1，实际为 ${match_count}；未修改文件。" >&2
    exit 1
fi

old_address="$(grep -E '^NSString \* const IPAdress = @"[^"]+";$' "${target_file}")"
MOTION_NOTE_LOCAL_IP="${local_ip}" perl -i -pe '
    if (/^NSString \* const IPAdress = @"[^"]+";$/) {
        $_ = qq{NSString * const IPAdress = @"http://$ENV{MOTION_NOTE_LOCAL_IP}:3000";\n};
    }
' "${target_file}"

expected_address="NSString * const IPAdress = @\"http://${local_ip}:3000\";"
if ! grep -Fqx "${expected_address}" "${target_file}"; then
    echo "错误：IPAdress 写入校验失败。" >&2
    exit 1
fi

echo "已获取本机 IP：${local_ip}"
echo "修改前：${old_address}"
echo "修改后：${expected_address}"
