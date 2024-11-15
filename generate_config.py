import json
import os
import random
import re
import subprocess
import sys
import uuid
from jinja2 import Environment, PackageLoader, select_autoescape
from generate_esb_config import generate_port, generate_reality_keys, generate_reality_sid, generate_password, \
    get_ip_info

config_file = f'/root/esb.config'
env = Environment(
    loader=PackageLoader("generate_config"),
    autoescape=select_autoescape()
)


def check_config_file():
    if not os.path.exists(config_file):
        os.system("python3 generate_esb_config.py")

    with open(config_file, 'r') as file:
        data = json.load(file)

    server_ip_gen, vps_org_gen, country = get_ip_info()
    server_ip = data.get('server_ip', server_ip_gen)
    vps_org = data.get('vps_org', vps_org_gen)
    reality_sid = data.get('reality_sid', generate_reality_sid())
    private_key_gen, public_key_gen = generate_reality_keys()
    private_key = data.get('private_key', private_key_gen)
    public_key = data.get('public_key', public_key_gen)
    password_gen = generate_password()
    password = data.get('password', password_gen)
    h2_port_gen, tuic_port_gen, reality_port_gen = generate_port()
    h2_port = data.get('h2_port', h2_port_gen)
    tuic_port = data.get('tuic_port', tuic_port_gen)
    reality_port = data.get('reality_port', reality_port_gen)
    www_dir_random_id = data.get('www_dir_random_id', ''.join(random.sample(uuid.uuid4().hex, 6)))

    client_sb_remote_dns = "https://cloudflare-dns.com/dns-query"
    if country == "DE":
        client_sb_remote_dns = "https://doh-de.blahdns.com/dns-query"

    esb_config = {}
    esb_config['server_ip'] = server_ip
    esb_config['vps_org'] = vps_org
    esb_config['www_dir_random_id'] = www_dir_random_id
    esb_config['password'] = password
    esb_config['h2_port'] = h2_port
    esb_config['tuic_port'] = tuic_port
    esb_config['reality_port'] = reality_port
    esb_config['reality_sid'] = reality_sid
    esb_config['public_key'] = public_key
    esb_config['private_key'] = private_key
    esb_config['client_sb_remote_dns'] = client_sb_remote_dns

    with open(config_file, 'w') as write_f:
        write_f.write(json.dumps(esb_config, indent=2, ensure_ascii=False))

    return server_ip, vps_org, reality_sid, private_key, public_key, password, h2_port, tuic_port, reality_port, www_dir_random_id, client_sb_remote_dns


def generate_singbox_server():
    server_ip, vps_org, reality_sid, private_key, public_key, password, h2_port, tuic_port, reality_port, www_dir_random_id, client_sb_remote_dns = check_config_file()

    sing_box_config_dir = "/etc/sing-box"
    if not os.path.exists(sing_box_config_dir):
        os.makedirs(sing_box_config_dir)

    is_warp = False
    if len(sys.argv) > 1:
        is_warp = sys.argv[1] == "warp"

    is_wg = False
    if len(sys.argv) > 1:
        is_wg = sys.argv[1] == "wg"

    with open(sing_box_config_dir + "/config.json", 'w') as file:
        if is_warp:
            sb_server_warp_json_content = env.get_template("/sing-box/sb-server-warp.json.tpl").render(
                password=password,
                h2_port=h2_port,
                reality_port=reality_port,
                reality_sid=reality_sid,
                reality_private_key=private_key,
                tuic_port=tuic_port)
            file.write(json.dumps(json.loads(sb_server_warp_json_content), indent=2, ensure_ascii=False))
        if is_wg:
            sb_server_wg_json_content = env.get_template("/sing-box/sb-server-wg.json.tpl").render(
                password=password,
                h2_port=h2_port,
                reality_port=reality_port,
                reality_sid=reality_sid,
                reality_private_key=private_key,
                tuic_port=tuic_port)
            file.write(json.dumps(json.loads(sb_server_wg_json_content), indent=2, ensure_ascii=False))
        if not is_warp and not is_wg:
            sb_server_json_content = env.get_template("/sing-box/sb-server.json.tpl").render(password=password,
                                                                                             h2_port=h2_port,
                                                                                             reality_port=reality_port,
                                                                                             reality_sid=reality_sid,
                                                                                             reality_private_key=private_key,
                                                                                             tuic_port=tuic_port)
            file.write(json.dumps(json.loads(sb_server_json_content), indent=2, ensure_ascii=False))

    os.system("cp /opt/easy-sing-box/cert/cert.pem /etc/sing-box/cert.pem")
    os.system("cp /opt/easy-sing-box/cert/private.key /etc/sing-box/private.key")


def generate_singbox():
    server_ip, vps_org, reality_sid, private_key, public_key, password, h2_port, tuic_port, reality_port, www_dir_random_id, client_sb_remote_dns = check_config_file()

    random_suffix = ''.join(random.sample(uuid.uuid4().hex, 6))
    ad_dns_rule = env.get_template("/sing-box/ad_dns_rule.json").render(random_suffix=random_suffix) + ","
    ad_route_rule = env.get_template("/sing-box/ad_route_rule.json").render(random_suffix=random_suffix) + ","
    ad_rule_set = env.get_template("/sing-box/ad_rule_set.json").render(random_suffix=random_suffix) + ","
    exclude_package = env.get_template("/sing-box/exclude_package.tpl").render() + ","
    exclude_package = re.sub(r'#.*', '', exclude_package)
    sb_json_tpl = env.get_template("/sing-box/sb.json.tpl")
    sb_json_content = sb_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                         reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                         vps_org=vps_org, tuic_port=tuic_port, www_dir_random_id=www_dir_random_id,
                                         exclude_package=exclude_package, random_suffix=random_suffix,
                                         client_sb_remote_dns=client_sb_remote_dns)
    sb_noad_json_content = sb_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                              reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                              vps_org=vps_org, tuic_port=tuic_port, www_dir_random_id=www_dir_random_id,
                                              ad_dns_rule=ad_dns_rule, ad_route_rule=ad_route_rule,
                                              ad_rule_set=ad_rule_set, exclude_package=exclude_package,
                                              random_suffix=random_suffix, client_sb_remote_dns=client_sb_remote_dns)

    nginx_www_dir = "/var/www/html/" + www_dir_random_id
    if not os.path.exists(nginx_www_dir):
        os.makedirs(nginx_www_dir)

    with open(nginx_www_dir + "/sb.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_json_content), indent=2, ensure_ascii=False))

    with open(nginx_www_dir + "/sb-noad.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_noad_json_content), indent=2, ensure_ascii=False))

    os.system("cp ./templates/sing-box/my/sb_echemi.json " + nginx_www_dir)
    os.system("cp ./templates/sing-box/my/sb_mydirect.json " + nginx_www_dir)
    os.system("cp ./templates/sing-box/my/sb_myproxy.json " + nginx_www_dir)


def generate_stash():
    server_ip, vps_org, reality_sid, private_key, public_key, password, h2_port, tuic_port, reality_port, www_dir_random_id, client_sb_remote_dns = check_config_file()
    stash_yaml_tpl = env.get_template("/stash/stash.yaml.tpl")
    stash_yaml_content = stash_yaml_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                               reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                               vps_org=vps_org, tuic_port=tuic_port,
                                               www_dir_random_id=www_dir_random_id)

    nginx_www_dir = "/var/www/html/" + www_dir_random_id
    if not os.path.exists(nginx_www_dir):
        os.makedirs(nginx_www_dir)

    with open(nginx_www_dir + "/st.yaml", 'w') as file:
        file.write(stash_yaml_content)

    os.system("cp ./templates/stash/my/st_echemi.list " + nginx_www_dir)
    os.system("cp ./templates/stash/my/st_apple.list " + nginx_www_dir)
    os.system("cp ./templates/stash/my/st_mydirect.list " + nginx_www_dir)
    os.system("cp ./templates/stash/my/st_myproxy.list " + nginx_www_dir)

if __name__ == '__main__':
    server_ip, vps_org, reality_sid, private_key, public_key, password, h2_port, tuic_port, reality_port, www_dir_random_id, client_sb_remote_dns = check_config_file()

    generate_singbox_server()
    generate_singbox()
    generate_stash()

    os.system('echo "重启 sing-box..."')
    os.system('systemctl start sing-box')
    os.system('systemctl restart sing-box')
    os.system('systemctl enable sing-box')
    os.system('echo "重启 nginx..."')
    os.system('systemctl start nginx')
    os.system('systemctl restart nginx')
    os.system('systemctl enable nginx')
    os.system('clear')

    os.system(f'echo "\\e[1;33msing-box 客户端文件下载地址\\033[0m"')
    os.system(f'echo "\\e[1;32mhttp://{server_ip}/{www_dir_random_id}/sb.json\\033[0m"')
    os.system(f'echo ""')

    os.system(f'echo "\\e[1;33msing-box 去广告版 客户端文件下载地址\\033[0m"')
    os.system(f'echo "\\e[1;32mhttp://{server_ip}/{www_dir_random_id}/sb-noad.json\\033[0m"')
    os.system(f'echo ""')

    os.system(f'echo "\\e[1;33mstash 客户端文件下载地址\\033[0m"')
    os.system(f'echo "\\e[1;32mhttp://{server_ip}/{www_dir_random_id}/st.yaml\\033[0m"')
    os.system(f'echo ""')
