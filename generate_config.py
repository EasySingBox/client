import json
import os
import random
import re
import subprocess
import uuid
from jinja2 import Environment, PackageLoader, select_autoescape
from generate_esb_config import generate_port, generate_reality_keys, generate_reality_sid


def get_ip():
    curl_out = subprocess.check_output(['curl', '-s', '-4', 'ip.p3terx.com'])
    data_str = curl_out.decode('utf-8')
    ipv4_pattern = r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
    ipv4_match = re.search(ipv4_pattern, data_str, re.MULTILINE)
    ipv4_address = ipv4_match.group(1) if ipv4_match else None
    return ipv4_address


if __name__ == '__main__':
    config_file = f'/root/esb.config'

    if not os.path.exists(config_file):
        os.system("python3 generate_esb_config.py")

    with open(config_file, 'r') as file:
        data = json.load(file)

    server_ip = get_ip()
    reality_sid = data.get('reality_sid', generate_reality_sid())
    private_key_gen, public_key_gen = generate_reality_keys()
    private_key = data.get('private_key', private_key_gen)
    public_key = data.get('public_key', public_key_gen)
    password = data.get('password', str(uuid.uuid4()))
    h2_port_gen, tuic_port_gen, reality_port_gen = generate_port()
    h2_port = data.get('h2_port', h2_port_gen)
    tuic_port = data.get('tuic_port', tuic_port_gen)
    reality_port = data.get('reality_port', reality_port_gen)
    www_dir_random_id = data.get('www_dir_random_id', ''.join(random.sample(uuid.uuid4().hex, 6)))

    esb_config = {}
    esb_config['www_dir_random_id'] = www_dir_random_id
    esb_config['password'] = password
    esb_config['h2_port'] = h2_port
    esb_config['tuic_port'] = tuic_port
    esb_config['reality_port'] = reality_port
    esb_config['reality_sid'] = reality_sid
    esb_config['public_key'] = public_key
    esb_config['private_key'] = private_key

    with open(config_file, 'w') as write_f:
        write_f.write(json.dumps(esb_config, indent=2, ensure_ascii=False))

    env = Environment(
        loader=PackageLoader("generate_config"),
        autoescape=select_autoescape()
    )

    nginx_www_dir = "/var/www/html/" + www_dir_random_id

    ad_dns_rule = env.get_template("ad_dns_rule.json").render() + ","
    ad_route_rule = env.get_template("ad_route_rule.json").render() + ","
    ad_rule_set = env.get_template("ad_rule_set.json").render() + ","
    exclude_package = env.get_template("exclude_package.tpl").render() + ","
    exclude_package = re.sub(r'#.*', '', exclude_package)  # 删除注释

    sb_json_tpl = env.get_template("sb.json.tpl")
    sb_json_content = sb_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                         reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                         tuic_port=tuic_port, www_dir_random_id=www_dir_random_id,
                                         exclude_package=exclude_package)

    sb_noad_json_content = sb_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                              reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                              tuic_port=tuic_port, www_dir_random_id=www_dir_random_id,
                                              ad_dns_rule=ad_dns_rule, ad_route_rule=ad_route_rule,
                                              ad_rule_set=ad_rule_set, exclude_package=exclude_package)

    sb_cn_json_tpl = env.get_template("sb-cn.json.tpl")
    sb_cn_json_content = sb_cn_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                               reality_sid=reality_sid, reality_pbk=public_key, server_ip=server_ip,
                                               tuic_port=tuic_port, exclude_package=exclude_package)

    # sb_server_json_tpl = env.get_template("sb-server.json.tpl")
    # sb_server_json_content = sb_server_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
    #                                                    reality_sid=reality_sid, reality_private_key=private_key,
    #                                                    tuic_port=tuic_port)

    sb_server_warp_json_tpl = env.get_template("sb-server-warp.json.tpl")
    sb_server_warp_json_content = sb_server_warp_json_tpl.render(password=password, h2_port=h2_port, reality_port=reality_port,
                                                       reality_sid=reality_sid, reality_private_key=private_key,
                                                       tuic_port=tuic_port)

    if not os.path.exists(nginx_www_dir):
        os.makedirs(nginx_www_dir)

    sing_box_config_dir = "/etc/sing-box"
    if not os.path.exists(sing_box_config_dir):
        os.makedirs(sing_box_config_dir)

    with open(nginx_www_dir + "/sb.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_json_content), indent=2, ensure_ascii=False))

    with open(nginx_www_dir + "/sb-noad.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_noad_json_content), indent=2, ensure_ascii=False))

    with open(nginx_www_dir + "/sb-cn.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_cn_json_content), indent=2, ensure_ascii=False))

    with open(sing_box_config_dir + "/config.json", 'w') as file:
        file.write(json.dumps(json.loads(sb_server_warp_json_content), indent=2, ensure_ascii=False))

    os.system("cp ./templates/echemi.json " + nginx_www_dir)
    os.system("cp ./templates/mydirect.json " + nginx_www_dir)
    os.system("cp ./templates/myproxy.json " + nginx_www_dir)

    os.system("cp /opt/easy-sing-box/cert/cert.pem /etc/sing-box/cert.pem")
    os.system("cp /opt/easy-sing-box/cert/private.key /etc/sing-box/private.key")
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

    os.system(f'echo "\\e[1;33msing-box 国内版 客户端文件下载地址\\033[0m"')
    os.system(f'echo "\\e[1;32mhttp://{server_ip}/{www_dir_random_id}/sb-cn.json\\033[0m"')
    os.system(f'echo ""')
