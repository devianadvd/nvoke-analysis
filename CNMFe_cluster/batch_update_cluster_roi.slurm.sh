#!/bin/bash
#SBATCH -p compute
#SBATCH -t 1-0
#SBATCH --mem=256G
#SBATCH -c 32

# Load matlab
module load matlab 

# matlab program with options for batch processing
# mlab_cmd="matlab -nosplash -nodisplay -nojvm -nodesktop"
mlab_cmd="matlab -nosplash -nodisplay -nodesktop"

# Creat a temporary directory for this job and save the name
# 'mktemp -d' creates a directory with a guaranteed unique name. It will replace the 'XXXXXX' with a random string.
# tempdir=$(mktemp -d /flash/UusisaariU/GD/data_folder.XXXXXX) 

# set inputs
folder_to_process=/flash/UusisaariU/GD/data_folder.xKs2rn/
# Fs=20 # sampling frequency. default is 20 Hz 

# enter the code directory on flash
cd /flash/UusisaariU/GD/code/

# Copy files to be processed into the tempdir
# cp -r $folder_to_process/* $tempdir

# Copy codes to temp folder
# bash /flash/UusisaariU/GD/update_code_from_bucket.sh

# Run code for CNMFe process
${mlab_cmd} -r "folder='${folder_to_process}'; cnmfe_series_delete_rois_update('folder', folder);"

# # Sync temp dir with cnmfe output to data folder in the bucket
# rsync -av --no-group --no-perms $tempdir/ deigo:$folder_to_process/

# # Clean up by removing our temporary directory
# rm -r $tempdir