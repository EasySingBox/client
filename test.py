import json
import subprocess


def get_ipinfo():
    curl_out = subprocess.check_output(['curl', '-s', '-4', 'ip.network/more'])
    data_str = curl_out.decode('utf-8')
    ip_infp = json.loads(data_str)
    ip = ip_infp.get('ip')
    country = ip_infp.get('country')
    asOrganization = ip_infp.get('asOrganization')
    return ip, country, asOrganization


if __name__ == '__main__':
    ip, country, asOrganization = get_ipinfo()
    print(ip, asOrganization)
    print(country)
    print(asOrganization)
