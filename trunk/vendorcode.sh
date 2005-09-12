#!/bin/sh
# File: vendorcode.sh
# By: Eugene Lee, 1995
# Modified: EAL 10/21/03 Changed directory Vendor to 3rdParty
#           EAL 1/28/04 Code in V1,V2,V3 in directory 3rdParty moved to its
#                       own directories under directory Examples
echo "This script will create source code in directories Examples/Local-1.0",
echo "Examples/3rdPartyV1, Examples/3rdPartyV2, & Examples/3rdPartyV3 to be" 
echo "used to demonstrate merging of vendor code into a local version of"
echo "the code as described in file vendor5readme.txt"
echo ""
echo "Continue? (y/n):"
read answer
case "$answer" in
  y) ;;
  Y) ;;
  *) exit
esac

if test -d Examples
then
  echo directory Examples exists already
else
  mkdir Examples
  echo created directory Examples
fi

cd Examples
if test -d Local-1.0
then 
  echo directory Local-1.0 already exists
  cd Local-1.0
  rm -f *
else
  mkdir Local-1.0
  echo created directory Local-1.0
  cd Local-1.0
fi

# Create files for module Local-1.0
cat > main <<END
program Main
Release 1.0
 .
 . (my code) 
 ..
Get
 ...
end
END
echo " created file main"
cat > get <<END
Proc Get
Release 1.0
 ..
 ..
end
END
echo " created file get"
cd ..
########################################

# Create files for 3rdParty, release 1.0
if test -d 3rdPartyV1
then 
  echo directory 3rdPartyV1 already exists
  cd 3rdPartyV1
  rm -f *
else
  mkdir 3rdPartyV1
  echo created directory 3rdPartyV1
  cd 3rdPartyV1
fi

cat > main <<END
program Main
Release 1.0
 .
 ..
Get
 ...
end
END
echo " create file main"
cat > get <<END
Proc Get
Release 1.0
 ..
 ..
end
END
echo " created file get"
cd ..
########################################

# Create files for 3rdParty, release 1.1
if test -d 3rdPartyV2
then 
  echo directory 3rdPartyV2 already exists
  cd 3rdPartyV2
  rm -f *
else
  mkdir 3rdPartyV2
  echo created directory 3rdPartyV2
  cd 3rdPartyV2
fi

cat > main <<END
program Main
Release 1.1
 .
 ..
Get
 ...
Sort
Printout
end
END
echo " created file main"
cat > get <<END
Proc Get
Release 1.1
 ..
 ..
 (new code)
end
END
echo " created file get"
cat > sort <<END
Proc Sort
Release 1.1
 ..
end
END
echo " created file sort"
cd ..
########################################

# Create files for 3rdParty, release 2.0
if test -d 3rdPartyV3
then 
  echo directory 3rdPartyV3 already exists
  cd 3rdPartyV3
  rm -f *
else
  mkdir 3rdPartyV3
  echo created directory 3rdPartyV3
  cd 3rdPartyV3
fi

cat > main <<END
program Main
Release 2.0
 .
 ..
GetSort
Printout
end
END
echo " created file main"
cat > getsort <<END
Proc GetSort
Release 2.0
 ..
 ..
end
END
echo " created file getsort"
cd ..
