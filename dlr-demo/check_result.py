import pexpect
import os,sys
import time


def check_result():
    print("Greengrass service initializing...")
    while (not os.path.exists("/greengrass/v2/logs/greengrass.log")):
        time.sleep(0.1)

    cmd = pexpect.spawn("tail -F /greengrass/v2/logs/greengrass.log")
    index = cmd.expect(["Successfully connected to AWS IoT Core", pexpect.TIMEOUT], timeout=600)
    if (index == 0):
        print("Successfully connected to AWS IoT Core.")
    else:
        print("Failed to connect to AWS IoT Core.")
        return index


    print("Edge manager camera component initializing...")
    camera_log_path="/greengrass/v2/logs/aws.sagemaker." + sys.argv[1] + "_edgeManagerClientCameraIntegration.log"
    while (not os.path.exists(camera_log_path)):
        time.sleep(10)
    cmd = pexpect.spawn("tail -F " + camera_log_path)
    index = cmd.expect(["'index': '.*', 'confidence'", "Prediction failed"], timeout=6000)
    if (index == 0):
        print("Successfully get inference result.")
    else:
        print("Failed to get inference result.")

    return index

index = check_result()
if (index == 0):
    exit(0)

print("Restarting greengrass core...")
os.system("rm /greengrass/v2/config/*;rm /greengrass/v2/logs/*;cp config.yaml /greengrass/v2/config/")
os.system("systemctl restart greengrass")
index = check_result()
