1.Set the TVM environment value in /etc/systemd/system.conf and reboot
----------------------------------------------------------------------
```
  $echo "DefaultEnvironment=\"TVM_NUM_THREADS=1\"" >>/etc/systemd/system.conf
  $reboot
```

2.Set the aws key environment.
------------------------------
```
  $export AWS_ACCESS_KEY_ID="YOUR AWS ACCESS KEY ID"
  $export AWS_SECRET_ACCESS_KEY="YOUR AWS SECRET ACCESS KEY"
  $export AWS_SESSION_TOKEN="YOUR AWS SESSION TOKEN"
  $export AWS_REGION="us-west-2"  #replace with your aws region
```

3.(OPTIONAL)Set the permission boundary ARN if necessary, you can find the ARN in AWS management "console->IAM->Policies"
-------------------------------------------------------------------------------------------------------------------------
```
  $export PERMISSIONS_BOUNDARY=arn:aws:iam::123456789012:policy/CCoEPermissionBoundary
```

4.(OPTIONAL)Set the video source if necessary, the default is /video_source.mkv
-------------------------------------------------------------------------------
```
  $export CAMERA_DEVICE="3"
```

5.Set the PROJECT_NAME to one uniqe string with lowercase letters only.
-----------------------------------------------------------------------
```
  $export PROJECT_NAME=project
```

6.Run the setup script.
------------------------
```
  $./setup_cloud_service_and_device.sh
```

7.After testing, clean the cloud environment.
----------------------------------------------
```
  $./10_clean_up.sh
```
