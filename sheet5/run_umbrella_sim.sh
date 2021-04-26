#!/bin/bash

# Make directory to save all simulation data in, if it doesn't exist yet.
UMBRELLA_DIR="umbrella_runs"
! [ -d $UMBRELLA_DIR ] && mkdir $UMBRELLA_DIR

# Clean up results of previous runs.
cd $UMBRELLA_DIR
[ -f tpr-files.dat ] && rm tpr-files.dat
[ -f pullf-files.dat ] && rm pullf-files.dat
[ -f histo.xvg ] && rm histo.xvg
[ -f profile.xvg ] && rm profile.xvg
cd ..

START_DIST=0
for i in $(seq 0 100)
do
    # Calculate distance value for the current frame $i.
    gmx distance -s pull.tpr -f stretch_run/frames/conf$i.pdb -n index.ndx -oall dist_temp.xvg -xvg none -select 'com of group "chain_A" plus com of group "chain_B"' &> /dev/null

    # Get only the distance value from the generated dist_temp.xvg file (omit time).
    DIST=$(cat dist_temp.xvg | tr -s " " | cut -d " " -f 3)
    # Remove temp file.
    rm dist_temp.xvg

    # Perform MD if difference in distance between current and last simulated frame is greater than $DISTANCE_DIFF nm 
    if [ $i -gt 0 ] && (( $(bc -l <<< "($DIST - $START_DIST) > $DISTANCE_DIFF") ))
    then
        # Perform MD on the frame one before $i, hence the last one with a distance below the threshold of $DISTANCE_DIFF nm.
        START_DIST=$LAST_DIST
        j=$((i - 1))

        cd $UMBRELLA_DIR
            
        echo frame_$j/umbrella$j.tpr >> tpr-files.dat
        echo frame_$j/pullf-umbrella$j.xvg >> pullf-files.dat

        # Only run simulation if it has not been run yet for frame number $j.
        if [ ! -d frame_$j ]
        then
            mkdir frame_$j

            gmx grompp -f ../md_umbrella.mdp -c ../stretch_run/frames/conf$j.pdb -r ../stretch_run/frames/conf$j.pdb -p ../topol.top -n ../index.ndx -o frame_$j/umbrella$j.tpr
            cd frame_$j
            gmx mdrun -v -deffnm umbrella$j -pf pullf-umbrella$j.xvg -px pullx-umbrella$j.xvg
            cd ..
        fi

        cd ..
    fi

    LAST_DIST=$DIST
done


# Make directory to save all results in, if it doesn't exist yet.
RESULTS_DIR="results/${DISTANCE_DIFF}nm"
! [ -d $RESULTS_DIR ] && mkdir $RESULTS_DIR

cd $UMBRELLA_DIR

# Generate PMF and histograms.
gmx wham -it tpr-files.dat -if pullf-files.dat -o -hist -unit kCal

# Export result figures as PNGs.
xmgrace -nxy histo.xvg -hdevice PNG -hardcopy -printfile histo.png
xmgrace -nxy profile.xvg -hdevice PNG -hardcopy -printfile profile.png

# Move all important files into results dir.
mv tpr-files.dat pullf-files.dat histo.* profile.*  ../$RESULTS_DIR

cd ..