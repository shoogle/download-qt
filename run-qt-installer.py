#!/usr/bin/env python

import ldtp, ooldtp
import sys
import os

def wait_for_object(gui, obj, timeout=5.0, delay=0.5):
    while (timeout > 0.0):
        ldtp.wait(delay)
        if gui.objectexist(obj) and gui.stateenabled(obj):
            print timeout
            return True
        timeout-=delay
    return False

qt_installer = os.path.abspath(sys.argv[1])
print qt_installer
ldtp.launchapp(qt_installer)

print ldtp.getwindowlist()

frm = ooldtp.context('dlgQtSetup') # MaintenanceTool: 'dlgMaintainQt'
ldtp.waittillguiexist(frm._window_name) # ooldtp BUG: should be able to do frm.waittillguiexist()

print frm.getobjectlist()

wait_for_object(frm, 'btnNext')
frm.click('btnNext')
wait_for_object(frm, 'btnSkip')
frm.click('btnSkip')
wait_for_object(frm, 'btnNext>')
frm.click('btnNext>')
wait_for_object(frm, 'btnNext>', 60, 1)
frm.settextvalue('txt7', '/tmp/kjfojgo/Qt') # Qt install path
wait_for_object(frm, 'btnNext>')
frm.click('btnNext>')
wait_for_object(frm, 'btnNext>')
frm.doubleclickrow('tree0', 'Qt')
ldtp.wait(0.1)
frm.doubleclickrow('tree0', 'Qt 5.10.0') # select Qt version
ldtp.wait(0.1)
frm.doubleclickrow('tree0', '*gcc*')
ldtp.wait(0.1)
#ldtp.generatekeyevent('<space>')
ldtp.wait(0.1)
frm.doubleclickrow('tree0', 'Qt WebEngine')
ldtp.wait(0.1)
#ldtp.generatekeyevent('<space>')
ldtp.wait(0.1)
frm.click('btnNext>')
ldtp.wait(0.1)
ldtp.generatekeyevent('<tab><tab><up><space>') # agree to terms
frm.click('btnNext>')
wait_for_object(frm, 'btnInstall')
frm.click('btnInstall')
wait_for_object(frm, 'btnFinish', 10*60, 5)
ldtp.wait(0.1)
ldtp.generatekeyevent('<tab><space>') # Don't launch Qt Creator
ldtp.wait(0.1)
frm.click('btnFinish')
