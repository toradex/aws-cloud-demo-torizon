import json
import subprocess
import os

def cmd(command):
    return json.loads(subprocess.check_output(command,shell=True,text=True))

def execute(command):
    print(command)
    os.system(command)

print("Cancelling greengrass deployment")
output=cmd('aws greengrassv2 list-deployments')
for i in output["deployments"]:
    if ((i["deploymentStatus"]!="CANCELED")and(i["deploymentStatus"]!="FAILED")):
        execute("aws greengrassv2 cancel-deployment --deployment-id "+ i["deploymentId"])

print("Deleting greengrass components")
output=cmd('aws greengrassv2 list-components')
#print(output)
for i in output["components"]:
    execute("aws greengrassv2 delete-component --arn "+ i["latestVersion"]["arn"])

print("Detaching things certificates")
output=cmd('aws iot list-things')
for i in output["things"]:
    output1=cmd('aws iot list-thing-principals --thing-name ' + i["thingName"])
    for j in output1["principals"]:
        execute("aws iot detach-thing-principal --thing-name "+ i["thingName"] + " --principal "+ j)

print("Deactivating and Deleting iot certificates")
output=cmd('aws iot list-certificates')
for i in output["certificates"]:
    execute("aws iot update-certificate --new-status INACTIVE --certificate-id "+ i["certificateArn"].split("/")[1])
    execute("aws iot delete-certificate --force-delete --certificate-id "+ i["certificateArn"].split("/")[1])

print("Deleting greengrass thing,thing group and thing policy")
output=cmd('aws iot list-thing-groups')
for i in output["thingGroups"]:
    execute("aws iot delete-thing-group --thing-group-name "+ i["groupName"])
output=cmd('aws iot list-things')
for i in output["things"]:
    execute("aws iot delete-thing --thing-name "+ i["thingName"])
output=cmd('aws iot list-policies')
for i in output["policies"]:
    execute("aws iot delete-policy --policy-name "+ i["policyName"])

print("Deleting greengrass role alias")
output=cmd('aws iot list-role-aliases')
for i in output["roleAliases"]:
    execute("aws iot delete-role-alias --role-alias "+ i)

print("Deleting sagemaker edge device and device fleet")
output=cmd('aws sagemaker list-devices')
for i in output["DeviceSummaries"]:
    execute("aws sagemaker deregister-devices --device-fleet-name " + i["DeviceFleetName"] + " --device-names " + i["DeviceName"])
    execute("aws sagemaker delete-device-fleet --device-fleet-name " + i["DeviceFleetName"])

print("Deleting IAM role and policy")
output=cmd('aws iam list-roles')
for i in output["Roles"]:
    if( (i["RoleName"]=="AWSServiceRoleForOrganizations") or
        (i["RoleName"]=="AWSServiceRoleForServiceQuotas") or
        (i["RoleName"]=="AWSServiceRoleForSupport") or
        (i["RoleName"]=="AWSServiceRoleForTrustedAdvisor")):
        pass
    else:
        output1=cmd("aws iam list-attached-role-policies --role-name "+ i["RoleName"])
        for j in output1["AttachedPolicies"]:
            execute("aws iam detach-role-policy --role-name "+ i["RoleName"] +" --policy-arn "+j["PolicyArn"])
            execute("aws iam delete-policy --policy-arn "+j["PolicyArn"])
        execute("aws iam delete-role --role-name "+ i["RoleName"])


print("Removing s3 buckets")
output=cmd('aws s3api list-buckets')
for i in output["Buckets"]:
    execute("aws s3 rb --force s3://"+ i["Name"])
