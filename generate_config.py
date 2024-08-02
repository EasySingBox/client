import json
import os
import re
import subprocess
from jinja2 import Environment, PackageLoader, select_autoescape
import random
import uuid

dev_dir = "/Users/zmlu/Developer/github/easy-sing-box/dist"


def get_ip():
    curl_out = subprocess.check_output(['curl', '-4', 'ip.p3terx.com'])
    data_str = curl_out.decode('utf-8')
    ipv4_pattern = r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    ipv4_match = re.search(ipv4_pattern, data_str, re.MULTILINE)
    ipv4_address = ipv4_match.group(1) if ipv4_match else None
    print(f'IPv4 address: {ipv4_address}')
    return ipv4_address


if __name__ == '__main__':
    project_dir = os.getcwd()
    config_file = f'{project_dir}/esb.config'

    if not os.path.exists(config_file):
        os.system("python3 generate_esb_config.py")

    with open(config_file, 'r') as file:
        data = json.load(file)

    server_ip = get_ip()
    print(f'server_ip: {server_ip}')
    reality_sid = data.get('reality_sid', '195a5279')
    private_key = data.get('private_key', 'YGxXYp61X9avMHFZpr-8-c1EMkpGjorM_2dT9dtCFnA')
    public_key = data.get('public_key', 'O6X2ekOXimzYUQIYAItVNup2LG0ukZHYdnhBDifvfHA')
    password = data.get('password', '1efe3c53-133f-4b2d-b70f-888a52a49a15')
    h2_port = data.get('h2_port', 17931)
    tuic_port = data.get('tuic_port', 57510)
    reality_port = data.get('reality_port', 37986)
    www_dir_random_id = data.get('www_dir_random_id', 'a66c7e')

    env = Environment(
        loader=PackageLoader("generate_config"),
        autoescape=select_autoescape()
    )

    nginx_www_dir = dev_dir + "/var/www/html/" + www_dir_random_id

    sb_json_tpl = env.get_template("sb.json.tpl")
    sb_json_content = sb_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                         reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                         tuic_port=tuic_port, www_dir_random_id=www_dir_random_id)

    sb_noad_json_tpl = env.get_template("sb-noad.json.tpl")
    sb_noad_json_content = sb_noad_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                                   reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                                   tuic_port=tuic_port, www_dir_random_id=www_dir_random_id)

    sb_server_json_tpl = env.get_template("sb-server.json.tpl")
    sb_server_json_content = sb_server_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                                       reality_sid=reality_sid, reality_private_key=private_key,
                                                       tuic_port=tuic_port)

    if not os.path.exists(nginx_www_dir):
        os.makedirs(nginx_www_dir)

    sing_box_config_dir = dev_dir + "/etc/sing-box"
    if not os.path.exists(sing_box_config_dir):
        os.makedirs(sing_box_config_dir)

    with open(nginx_www_dir + "/sb.json", 'w') as file:
        file.write(sb_json_content)

    with open(nginx_www_dir + "/sb-noad.json", 'w') as file:
        file.write(sb_noad_json_content)

    with open(sing_box_config_dir + "/config.json", 'w') as file:
        file.write(sb_server_json_content)

    os.system("cp ./templates/echemi.json " + nginx_www_dir)
    os.system("cp ./templates/mydirect.json " + nginx_www_dir)
    os.system("cp ./templates/myproxy.json " + nginx_www_dir)

    print(f'sing-box client config download url:\n http://{server_ip}/{www_dir_random_id}/sb.json')
    print(f'sing-box noad client config download url:\n http://{server_ip}/{www_dir_random_id}/sb-noad.json')
