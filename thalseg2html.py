#!/usr/bin/python3.6
# -*- coding: utf-8 -*-

"""
Created on Sat Jun 20 11:06:24 2020

@author: Chris Vriend
"""

from nilearn import plotting
import argparse
import base64
import os



parser = argparse.ArgumentParser('create html for thalamic subsegmentation QC')

# required arguments
parser.add_argument('--thal', action="store", dest="thal", required=True,
                    help='full path to thalamic segmentation')
parser.add_argument('--brain', action="store", dest="brain", required=True,
                    help='full path to MRI brain as background image')
parser.add_argument('--output', action="store", dest="output", required=True,
                    help='full path to output html file')
# parse arguments
args = parser.parse_args()
thal=args.thal
brain=args.brain
output=args.output


# test input
#thal='ThalamicNuclei.v12.T1.FSvoxelSpace_noLMGN.nii.gz'
#brain='brain.nii.gz'
#output='test'


# overlay thalamic segmentation on T1 brainThalamicNuclei.v12.T1.FSvoxelSpace_noLMGN.nii
view=plotting.view_img(thal,
                       bg_img=brain,symmetric_cmap=False,
                       resampling_interpolation='nearest',
                       colorbar=False,opacity=0.6,annotate=True,
                       cmap='CMRmap')
#view.save_as_html(output + '.html')
html1=view.get_standalone()
html1=html1.replace('width="600"','width="2400"')
html1=html1.replace('height="240"','width="960"')
                     
# make figure of thalamic contours
display = plotting.plot_anat(brain, display_mode='tiled',draw_cross=False,)                           
display.add_contours(thal,alpha=0.5,levels=[0.5],colors='r',linewidths=0.5)

display.savefig(output + '.png',dpi=300)

# convert to html code
data_uri = base64.b64encode(open(output + '.png', 'rb').read()).decode('utf-8')
img_tag = '<img src="data:image/png;base64,{0}">'.format(data_uri)

# clean up
os.remove(output + '.png')


htmlbase='<!DOCTYPE html> <html lang="en"> <head> <title>Slice viewer</title>  <meta charset="UTF-8" /> </head> <body>'
htmlend='</body> </html>'


htmlfull=htmlbase + html1 + img_tag + htmlend

# Write HTML String to file.html
with open(output + ".html", "w") as file:
    file.write(htmlfull)
    




