import sys
import os
import zipfile

if len(sys.argv) < 2 :
  print("Missing input file argument")
  exit()

filepath=sys.argv[1]
if not os.path.isfile(filepath):
  print("File path {} does not exist. Exiting...".format(filepath))
  sys.exit()

directory = "TestFolder"
if not os.path.exists(directory):
    os.makedirs(directory)

count = 0
with open(filepath) as fp:
  for file_name in fp:
    file_name = directory + "/" +file_name.rstrip() + ".zip"
    zf = zipfile.ZipFile(file_name, mode='w')
    zf.close()
    count+=1
fp.close()
print("%d file were created on TestFolder" % (count))
