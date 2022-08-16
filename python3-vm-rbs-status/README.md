# python3-vm-rbs-status

## Simple script to dump RBS Status for VMs

### Setup .creds
```
{
	"cluster1": {
        	"servers":["IP","IP","IP","IP"],
        	"username": "user",
        	"password": "pw"
	}
}
```

### Help TXT
```
> python .\rbs_check.py -h

usage: rbs_check.py [-h] -c {poc01,devops1,se3,isilon,sql,toVCenter,fromVCenter}

optional arguments:
  -h, --help            show this help message and exit
  -c {poc01,devops1,se3,isilon,sql,toVCenter,fromVCenter}, --cluster {poc01,devops1,se3,isilon,sql,toVCenter,fromVCenter}
                        Choose a cluster in .creds
```

### Running it
```
> python .\rbs_check.py -c devops1

Running initial query for IDs
Running 1087 sub requests asyncronously
VM Name, Agent Status
poc-mass-win2016-023, False
DEMO-IMG-2, False
SE-VTHAKKAR-LINUX GUI, False
poc-mass-centos7-021, False
poc-mass-centos7-256, False
SE-DSWIFT-LINUX, False
SE-SASANO-LINUX2-VC, False
SE-DTRINUGR-LINUX, False
poc-mass-centos7-300, False
SE-AABREGO-WIN, False
SE-SNEKAVA-LINUX, False
poc-mass-win2016-275, False
HyTrust-Poore, False
SE-JBAILLEY-CENTOS7, False
DEMO-QAS-1, False
poc-mass-centos7-266, False
poc-mass-win2016-146, False
MF-rubrik-va-4.0.6-p3-846, False
cbolt-centos-2, False
SE-TBAUM-LINUX, False
SE-NWRIGHT-LINUX, False
msf-sql2017, True
devops-kube02, False
...

```
