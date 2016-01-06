#!/usr/bin/python
# Copyright (c) 2013 Quanta Research Cambridge, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from __future__ import print_function
import argparse, json, sys
from collections import OrderedDict
import copy

bindings = {
    #'pins': 'pins',
    'pin_name': 'pins' # legacy
    }
errorDetected = False

def newArgparser():
    argparser = argparse.ArgumentParser("Generate constraints file for board.")
    argparser.add_argument('--boardfile', help='Board description file (json)')
    argparser.add_argument('--pinoutfile', default=[], help='Project description file (json)', action='append')
    argparser.add_argument('-b', '--bind', default=[], help='Bind signal group to pin group', action='append')
    argparser.add_argument('-o', '--output', default=None, help='Write output to file')
    argparser.add_argument('-f', '--fpga', default="xilinx", help='Target FPGA Vendor')
    return argparser


if __name__=='__main__':
    argparser=newArgparser()
    options = argparser.parse_args()

    for binding in options.bind:
        split = binding.split(':')
        bindings[split[0]] = split[1]

    boardInfo = json.loads(open(options.boardfile).read())

    if options.fpga == "xilinx":
        template='''\
    set_property LOC "%(LOC)s" [get_ports "%(name)s"]
    set_property IOSTANDARD "%(IOSTANDARD)s" [get_ports "%(name)s"]
    set_property PIO_DIRECTION "%(PIO_DIRECTION)s" [get_ports "%(name)s"]
        '''
        setPropertyTemplate='''\
        set_property %(prop)s "%(val)s" [get_ports "%(name)s"]
        '''
    elif options.fpga == "altera":
        template='''\
    set_instance_assignment -name IO_STANDARD "%(IOSTANDARD)s" -to "%(name)s"
    set_location_assignment "%(LOC)s" -to "%(name)s"
    '''
        setPropertyTemplate='''\
    set_instance_assignment -name %(prop)s "%(val)s" -to "%(name)s"
    '''

    out = sys.stdout
    if options.output:
        out = open(options.output, 'w')

    for filename in options.pinoutfile:
        print('generate-constraints: processing file "' + filename + '"')
        pinstr = open(filename).read()
        pinout = json.loads(pinstr, object_pairs_hook=OrderedDict)
        for pin in pinout:
            projectPinInfo = pinout[pin]
            loc = 'TBD'
            iostandard = 'TBD'
            iodir = 'TBD'
            used = []
            boardGroupInfo = {}
            pinName = ''
            #print('PPP', projectPinInfo)
            for key in bindings:
                if projectPinInfo.has_key(key):
                    used.append(key)
                    pinName = projectPinInfo[key]
                    #print('LLL', key, pinName, bindings[key])
                    boardGroupInfo = boardInfo[bindings[key]]
                    break
            if pinName == '':
                for key in projectPinInfo:
                    #print('JJJJ', key)
                    if boardInfo.get(key):
                        used.append(key)
                        pinName = projectPinInfo[key]
                        boardGroupInfo = boardInfo[key]
                        #print('FFF', key, pinName, boardGroupInfo, boardGroupInfo.has_key(pinName), boardGroupInfo.get(pinName))
                        break
            if boardGroupInfo == {}:
                print('Missing group description for', pinName, projectPinInfo, file=sys.stderr)
                errorDetected = True
            pinInfo = {}
            if boardGroupInfo.has_key(pinName):
                pinInfo = copy.copy(boardGroupInfo[pinName])
            else:
                print('Missing pin description for', pinName, projectPinInfo, file=sys.stderr)
                pinInfo['LOC'] = 'fmc.%s' % (pinName)
                errorDetected = True
            pinInfo['name'] = pin
            for prop in projectPinInfo:
                if projectPinInfo.has_key(prop):
                    pinInfo[prop] = projectPinInfo[prop]
            out.write(template % pinInfo)
            for k in pinInfo:
                if k in used+['name', 'IOSTANDARD', 'PIO_DIRECTION']: continue
                out.write(setPropertyTemplate % {
                        'name': pin,
                        'prop': k,
                        'val': pinInfo[k],
                        })
    if errorDetected:
        sys.exit(-1);
