import sys
import os

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
    file_name = file_name.rstrip()
    # print(file_name)
    if len(file_name) > 0:
      try:
        f= open(os.path.join("TestFolder", file_name),"w+")
        f.close()
        count+=1
      except:
        pass
fp.close()
print("%d file were created on TestFolder" % (count))