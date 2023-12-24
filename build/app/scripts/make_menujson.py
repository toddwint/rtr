#!/usr/bin/env python3
"""Create a menu.json needed to run menu script"""

__version__ = '0.0.1'
__date__ = '2023-12-22'
__author__ = 'Todd Wintermute'

import argparse
import json
import os
import pathlib

def parse_arguments():
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog='Have a great day!',
        )
    parser.add_argument(
        '-v', '--version',
        help='show the version number and exit',
        action='version',
        version=f'Version: %(prog)s  {__version__}  ({__date__})',
        )
    parser.add_argument(
        'outfile',
        nargs='?',
        type=pathlib.Path,
        default='./menu.json',
        help=(
            'Optional location where to write the json file. '
            'Default is `./menu.json`'
            ),
        )
    return parser

def dump_json(menulist, output):
    if not output.exists():
        output.touch()
    with open(output, 'w') as f:
        json.dump(menulist, f, indent=1)

if __name__ == '__main__':
    appname = os.environ['APPNAME']
    tailcmd = "tail -F -n +1"
    #fzfcmd = "fzf --tac --reverse --no-sort"
    fzfcmd = "fzf --tac --no-sort"
    fzfcmd2 = "fzf --reverse --no-sort"
    logsdir = f"/opt/{appname}/logs"
    debugdir = f"/opt/{appname}/debug"
    menu_log_fzf = [
        (f"{appname} log", f"{tailcmd} {logsdir}/{appname}.log | {fzfcmd}"),
        ]
    menu_log = [
        (f"{appname} log", f"more {logsdir}/{appname}.log"),
        ]
    menu_configuration = [
        ("addrs.csv", f"column.py /opt/{appname}/upload/addrs.csv | more"),
        ("routes.csv", f"column.py /opt/{appname}/upload/routes.csv | more"),
        ("IP addresses", "ip addr show | more"),
        ("Routing table", "ip route show | more"),
        ("ARP or NDISC cache", "ip neighbor show | more"),
        ("Network devices", "ip link show | more"),
        ]
    menu_debug = [
        ("Add addresses from addrs.csv", "ip-addrs-add"),
        ("Add routes from routes.csv", "ip-routes-add"),
        ("Show processes", "ps ax | more"),
        ("Show sockets", "ss --all --numeric --processes | more"),
        #("ttyd log", f"more {logsdir}/ttyd.log"),
        ("ttyd1 log", f"more {logsdir}/ttyd1.log"),
        ("ttyd2 log", f"more {logsdir}/ttyd2.log"),
        ("frontail log", f"more {logsdir}/frontail.log"),
        ("tailon log", f"more {logsdir}/tailon.log"),
        ]
    menu = [
        ("Launch tmux", f"/opt/{appname}/scripts/tmux.sh"),
        ("Search logs", menu_log_fzf),
        ("View logs", menu_log),
        ("View configuration", menu_configuration),
        ("Debug scripts", menu_debug),
        ]
    parser = parse_arguments()
    args = parser.parse_args()
    dump_json(menu, args.outfile)
