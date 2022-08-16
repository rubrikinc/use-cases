#! python
# Cluster IP Address and Credentials

import time,datetime
import base64
import pprint
import asyncio
import aiohttp 
import requests
import json
import sys
import random
import argparse
import os


pp = pprint.PrettyPrinter(indent=4)
d = (datetime.datetime.utcnow())
timestamp_from=(d.strftime('%a %b %d 00:00:00 UTC %Y'))
timestamp_to=(d.strftime('%a %b %d 24:00:00 UTC %Y'))


__location__ = os.path.realpath(os.path.join(os.getcwd(), os.path.dirname(__file__)))

with open(os.path.join(__location__, '.creds')) as f:
    creds = json.load(f)


parser = argparse.ArgumentParser()
parser.add_argument('-c', '--cluster', choices=creds, required='True', help='Choose a cluster in .creds')
args = parser.parse_args()

creds=creds[args.cluster]

NODE_IP_LIST = creds['servers']
USERNAME = creds['username']
PASSWORD = creds['password']

# ignore certificate verification messages
requests.packages.urllib3.disable_warnings()

# Generic Rubrik API Functions
def basic_auth_header():
    """Takes a username and password and returns a value suitable for
    using as value of an Authorization header to do basic auth.
    """
    credentials = '{}:{}'.format(USERNAME, PASSWORD)
    # Encode the Username:Password as base64
    authorization = base64.b64encode(credentials.encode())
    # Convert to String for API Call
    authorization = authorization.decode()
    return authorization

def rubrik_get(api_version, api_endpoint):
    """ Connect to a Rubrik Cluster and perform a syncronous GET operation """
    AUTHORIZATION_HEADER = {'Content-Type': 'application/json',
                            'Accept': 'application/json',
                            'Authorization': 'Basic ' + basic_auth_header()
                            }
    request_url = "https://{}/api/{}{}".format(random.choice(NODE_IP_LIST), api_version, api_endpoint)
    try:
        api_request = requests.get(request_url, verify=False, headers=AUTHORIZATION_HEADER)
        # Raise an error if they request was not successful
        api_request.raise_for_status()
    except requests.exceptions.RequestException as error_message:
        print(error_message)
        sys.exit(1)
    response_body = api_request.json()
    return response_body

async def rubrik_get_async(url):
    """ Connect to a Rubrik Cluster and perform an async GET operation """

    AUTHORIZATION_HEADER = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Basic ' + basic_auth_header()
    }

    connector = aiohttp.TCPConnector(limit=10)
    async with aiohttp.ClientSession(headers=AUTHORIZATION_HEADER, connector=connector) as session:
        async with session.get(url,headers=AUTHORIZATION_HEADER,verify_ssl=False) as response:
            response_body = await response.read()
            try:
                r = json.loads(response_body)
                OUT_DATA.append({'name':r['name'],'agent':r['isAgentRegistered']})
            except:
                print(response.message)
                return

start = time.time()
# Here we just run the initial call to get event IDs. We set the timeframe for today and query only for failures.
print("Running initial query for IDs")
RETURN1 = rubrik_get("v1","/vmware/vm?limit=9999&primary_cluster_id=local")

tasks = []
OUT_DATA = []

# Here we assemble our request loop to run async, randomizing the node we use.
if sys.platform == 'win32':
    loop = asyncio.ProactorEventLoop()
    asyncio.set_event_loop(loop)

loop = asyncio.get_event_loop()

print("Running {} sub requests asyncronously".format(len(RETURN1['data'])))
for item in RETURN1['data']:
    api_endpoint = "/vmware/vm/{}".format(item['id'])
    node_ip = random.choice(NODE_IP_LIST)
    task = asyncio.ensure_future(rubrik_get_async("https://{}/api/{}{}".format(node_ip, 'v1', api_endpoint)))
    tasks.append(task)

# Here we run the async tasks 
loop.run_until_complete(asyncio.wait(tasks))
end = time.time()
elapsed_async = end-start
print("VM Name, Agent Status")
for vm in OUT_DATA:
   print("{}, {}".format(vm['name'],vm['agent']))

print("Items reported : {}".format(len(OUT_DATA)))
print("Elapsed : {}".format(elapsed_async))
