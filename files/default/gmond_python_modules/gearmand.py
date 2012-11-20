#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import traceback
import os
import threading
import time
import socket
import select
import re 

tracked_queues = dict()
descriptors = list()
Desc_Skel   = {}
_Worker_Thread = None
_Lock = threading.Lock() # synchronization lock
Debug = False

def dprint(f, *v):
    if Debug:
        print >>sys.stderr, "DEBUG: "+f % v

def floatable(str):
    try:
        float(str)
        return True
    except:
        return False

class UpdateMetricThread(threading.Thread):

    def __init__(self, params):
        threading.Thread.__init__(self)
        self.running      = False
        self.shuttingdown = False
        self.refresh_rate = 15
        if "refresh_rate" in params:
            self.refresh_rate = int(params["refresh_rate"])
        self.metric       = {}
        self.last_metric       = {}
        self.timeout      = 2

        self.host         = "localhost"
        self.port         = 4730
        if "host" in params:
            self.host = params["host"]
        if "port" in params:
            self.port = int(params["port"])
        self.type    = params["type"]
        self.mp      = params["metrix_prefix"]

    def shutdown(self):
        self.shuttingdown = True
        if not self.running:
            return
        self.join()

    def run(self):
        self.running = True

        while not self.shuttingdown:
            _Lock.acquire()
            self.update_metric()
            _Lock.release()
            time.sleep(self.refresh_rate)

        self.running = False

    def update_metric(self):
        global tracked_queues, descriptors, Desc_Skel
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        msg  = ""
        self.last_metric = self.metric.copy()
        try:
            dprint("connect %s:%d", self.host, self.port)
            sock.connect((self.host, self.port))
            sock.send("status\n")

            while True:
                rfd, wfd, xfd = select.select([sock], [], [], self.timeout)
                if not rfd:
                    print >>sys.stderr, "ERROR: select timeout"
                    break

                for fd in rfd:
                    if fd == sock:
                        data = fd.recv(8192)
                        msg += data

                if msg.find("^.$"):
                    break

            sock.close()
        except socket.error, e:
            print >>sys.stderr, "ERROR: %s" % e
        
        try: 
            for m in msg.split("\n"):
                if m != "." and m != "":
                    (jobname, enqueued, running, workercount) = re.split('\s+', m)

                    self.metric[self.mp+"_"+jobname+"_enqueued"] = float(enqueued)
                    self.metric[self.mp+"_"+jobname+"_running"] = float(running)
                    self.metric[self.mp+"_"+jobname+"_workers"] = float(workercount)
                    
                    if (not tracked_queues.has_key(jobname)):
                        dprint("Tracking job: %s" % (jobname))
                        tracked_queues[jobname] = 1

                        descriptors.append(create_desc(Desc_Skel, {
                            "name"       : self.mp+"_" + jobname + "_enqueued",
                            "units"      : "items",
                            "slope"      : "both",
                            "description": "Current number of jobs queued for" + jobname,
                        }))

                        descriptors.append(create_desc(Desc_Skel, {
                            "name"       : self.mp+"_" + jobname + "_running",
                            "units"      : "items",
                            "slope"      : "both",
                            "description": "Current number of jobs currently running for" + jobname,
                        }))

                        descriptors.append(create_desc(Desc_Skel, {
                            "name"       : self.mp+"_" + jobname + "_workers",
                            "units"      : "workers",
                            "slope"      : "both",
                            "description": "Current number of workers able to handle " + jobname,
                        }))

        except: 
            print >>sys.stderr, "Oops!"
            traceback.print_exc(file=sys.stderr)


    def metric_of(self, name):
        val = 0
        mp = name.split("_")[0]
        if name.rsplit("_",1)[1] == "rate" and name.rsplit("_",1)[0] in self.metric:
            _Lock.acquire()
            name = name.rsplit("_",1)[0]
            if name in self.last_metric:
                num = self.metric[name]-self.last_metric[name]
                period = self.metric[mp+"_time"]-self.last_metric[mp+"_time"]
                try:
                    val = num/period
                except ZeroDivisionError:
                    val = 0
            _Lock.release()
        elif name in self.metric:
            _Lock.acquire()
            val = self.metric[name]
            _Lock.release()
        return val

def metric_init(params):
    global descriptors, Desc_Skel, _Worker_Thread, Debug

    print '[gearmand] gearmand protocol "status"'
    if "type" not in params:
        params["type"] = "gearmand"

    if "metrix_prefix" not in params:
        params["metrix_prefix"] = "gm"

    print params

    # initialize skeleton of descriptors
    Desc_Skel = {
        'name'        : 'XXX',
        'call_back'   : metric_of,
        'time_max'    : 60,
        'value_type'  : 'float',
        'format'      : '%.0f',
        'units'       : 'XXX',
        'slope'       : 'XXX', # zero|positive|negative|both
        'description' : 'XXX',
        'groups'      : params["type"],
        }

    if "refresh_rate" not in params:
        params["refresh_rate"] = 15
    if "debug" in params:
        Debug = params["debug"]
    dprint("%s", "Debug mode on")

    _Worker_Thread = UpdateMetricThread(params)
    _Worker_Thread.start()

    # IP:HOSTNAME
    if "spoof_host" in params:
        Desc_Skel["spoof_host"] = params["spoof_host"]

    mp = params["metrix_prefix"]
    
    return descriptors

def create_desc(skel, prop):
    d = skel.copy()
    for k,v in prop.iteritems():
        d[k] = v
    return d

def metric_of(name):
    return _Worker_Thread.metric_of(name)

def metric_cleanup():
    _Worker_Thread.shutdown()

if __name__ == '__main__':
    try:
        params = {
            "host"  : "localhost",
            "port"  : 4730,
            # "host"  : "tt101",
            # "port"  : 1978,
            # "type"  : "Tokyo Tyrant",
            # "metrix_prefix" : "tt101",
            "debug" : True,
            }
        metric_init(params)

        while True:
            for d in descriptors:
                v = d['call_back'](d['name'])
                print ('value for %s is '+d['format']) % (d['name'],  v)
            time.sleep(5)
    except KeyboardInterrupt:
        time.sleep(0.2)
        os._exit(1)
    except:
        traceback.print_exc()
        os._exit(1)
