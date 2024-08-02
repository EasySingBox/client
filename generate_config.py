import os
import random
import re
import subprocess
import uuid
from jinja2 import Environment, PackageLoader, select_autoescape

dev_dir = ""


def generate_reality_keys():
    xray_out = subprocess.check_output(['xray', 'x25519'])
    data_str = xray_out.decode('utf-8')
    print(f'xray_out: {xray_out}')
    private_key_pattern = r'Private key: ([\w-]+)'
    public_key_pattern = r'Public key: ([\w-]+)'
    private_key_match = re.search(private_key_pattern, data_str)
    public_key_match = re.search(public_key_pattern, data_str)
    private_key = private_key_match.group(1) if private_key_match else 'wKpQJg3pYNmHIdYNfcgkOpkuDRjBu_HtT5AILoKIlnA'
    public_key = public_key_match.group(1) if public_key_match else 'IBFZzGV6xrzrXPCzFMNN3L6paUDNJNoXUbXSKjYEFG4'
    return private_key, public_key


def generate_reality_sid():
    openssl_out = subprocess.check_output(['openssl', 'rand', '-hex', '4'])
    data_str = openssl_out.decode('utf-8')
    data_str = ''.join(data_str.splitlines())
    return data_str


def generate_port():
    min_value = 9000
    max_value = 65535
    random_numbers = random.sample(range(min_value, max_value + 1), 3)
    h2_port = random_numbers[0]
    tuic_port = random_numbers[1]
    reality_port = random_numbers[2]
    return h2_port, tuic_port, reality_port


def get_ip():
    curl_out = subprocess.check_output(['curl', '-4', 'ip.p3terx.com'])
    data_str = curl_out.decode('utf-8')
    ipv4_pattern = r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    ipv4_match = re.search(ipv4_pattern, data_str, re.MULTILINE)
    ipv4_address = ipv4_match.group(1) if ipv4_match else None
    print(f'IPv4 address: {ipv4_address}')
    return ipv4_address


if __name__ == '__main__':
    server_ip = get_ip()
    private_key, public_key = generate_reality_keys()
    reality_sid = generate_reality_sid()
    h2_port, tuic_port, reality_port = generate_port()
    password = uuid.uuid4()

    # print(f'server_ip: {server_ip}')
    # print(f'password: {password}')
    # print(f'h2_port: {h2_port}')
    # print(f'tuic_port: {tuic_port}')
    # print(f'reality_port: {reality_port}')
    # print(f'reality_pbk: {public_key}')
    # print(f'reality_private_key: {private_key}')
    # print(f'reality_sid: {reality_sid}')

    env = Environment(
        loader=PackageLoader("generate_config"),
        autoescape=select_autoescape()
    )

    www_dir_random_id = ''.join(random.sample(uuid.uuid4().hex, 6))
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
