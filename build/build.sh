#!/bin/bash

# build.sh
#
# This script builds the project by using Drush make and symbolic linking.
#
# FLAG OPTIONS
#
# -dev
#   Sets the script to run in development mode. Currently this means that the
#   script will use the development version of the Drush Make file, and will
#   include .git directory.
#
# -webroot somevalue
#   The default webroot is 'www' but you can specifiy a different directory if
#   desired.
#
# -y
#   Skips all promts and assumes a 'confirm' action.
#

#
# VARIABLES
#

site_name="tpv"

# Grab the command flags passed as arguments
options=$@
arguments=($options)
index=0

# Set flag defaults
webroot="www"
development=0
force=0

# Set passed flags
for argument in $options
  do
    # Incrementing index
    index=`expr $index + 1`

    # The conditions
    case $argument in
      -webroot)
        webroot=${arguments[index]} ;;
      -dev)
        development=1
        echo "- Script is running in development mode." ;;
      -y)
        force=1 ;;
    esac
done

# Include Functions in build_functions.sh
. $(git rev-parse --show-toplevel)/scripts/build_functions.sh
cd ${base_dir}

#
# Main Script
#

echo ""
echo "--- Preparing to build ---"
echo "- Webroot is set to: ${webroot}."

# If the given webroot already exists, remove it.
if [[ -d "${base_dir}/${webroot}" ]] ; then
  # If user forced yes, skip the prompt.
  if [ "$force" == '1' ];
    then
      echo "- Webroot ${webroot} already exists, removing it."
      remove_site
    # Otherwise ask for permission to remove the webroot.
    else
      echo ""
      echo "- Webroot ${webroot} already exists, remove it?"
      select yn in "Yes" "No"; do
        case $yn in
          Yes )
            remove_site
            break ;;
          No )
            echo ""
            echo "- Build process aborted by user."
            echo ""
            exit ;;
        esac
      done
  fi
fi

echo ""
echo "--- Building ${site_name} ---"

# Download Drupal core, contrib and custom packages. This need to be aware of the -dev flag
echo "- Downloading Drupal core, contrib, and custom via Drush Make."

# Download custom packages.
if [ "$development" == '1' ];
  then
    echo "- Downloading custom modules/themes in development mode."
    echo ""
    # Run the MAKEFILE with the --working-copy flag to grab the .git directory
    drush make ${base_dir}/build/${site_name}.custom.make ${webroot} --working-copy
  else
    echo "- Downloading custom modules/themes in production mode."
    echo ""
    drush make ${base_dir}/build/${site_name}.custom.make ${webroot}
fi

echo ""

# Create the symbolic link to the custom modules directory
components_symlink modules ${modules_dir}

# Create the symbolic link to the custom features directory
components_symlink features ${features_dir}

# Create the symbolic link to the custom themes directory
components_symlink themes ${themes_dir}

# Copying any libraries that couldn't be included via Drush Make.
components_copy libraries ${libraries_dir}

# Now bring the settings.php and files directory back, restoring the site.
restore_site

# Recursively touch all files to update the modified time.
# Note: The motified date is preserved by Drush Make which causes issues with APC
#       on the dev servers. This results in PHP thinking that it has loaded all
#       of its includes but they aren't actually in the cache. Touching all of
#       the files updates their modified date, which gets them recached, resolving
#       this issue.
echo "- Touching all files to update modified time."
find ${base_dir}/${webroot} -exec touch {} \;

# Now compile any SASS Compass based themes
compile_sass

echo ""
