#!/usr/bin/env python3
"""Write the single-page Finder layout used by the MenuSlim installer.

DS_Store serialization and relative alias format adapted from go-macos/dsstore.
Copyright (c) 2026, the go-macos/dsstore authors. BSD-3-Clause;
see docs/licenses/dsstore-BSD-3-Clause.txt. No third-party runtime packages.
"""
import plistlib
import struct
import sys
from pathlib import Path


def u32(*values):
    return struct.pack('>' + 'I' * len(values), *values)


def background_alias(volume):
    path = '/.background/installer.png'
    header = bytearray(150)
    struct.pack_into('>HH', header, 6, 2, 0)
    for offset, limit, text in [(10, 27, volume), (50, 63, 'installer.png')]:
        raw = text.encode('utf-8')[:limit]
        header[offset] = len(raw)
        header[offset+1:offset+1+len(raw)] = raw
    header[42:44] = b'H+'
    struct.pack_into('>H', header, 44, 5)
    struct.pack_into('>hh', header, 130, -1, -1)
    def unicode(text):
        raw = text.encode('utf-16be')
        return struct.pack('>H', len(raw)//2) + raw
    tags = [(0,b'.background'), (1,u32(0)), (2,(volume+':.background:\0installer.png').encode()),
            (14,unicode('installer.png')), (15,unicode(volume)),
            (18,path.encode()), (19,('/Volumes/'+volume).encode())]
    for tag, data in tags:
        header.extend(struct.pack('>hH',tag,len(data))+data+b'\0'*(len(data)%2))
    header.extend(struct.pack('>hH',-1,0))
    struct.pack_into('>H',header,4,len(header))
    return bytes(header)


def write_layout(destination, volume):
    options = dict(viewOptionsVersion=1, arrangeBy='none', backgroundType=2,
        backgroundImageAlias=background_alias(volume), backgroundColorRed=0.95,
        backgroundColorGreen=0.96, backgroundColorBlue=0.98, iconSize=100.0,
        textSize=13.0, gridSpacing=100.0, gridOffsetX=0.0, gridOffsetY=0.0,
        labelOnBottom=True, showIconPreview=True, showItemInfo=False,
        scrollPositionX=0.0, scrollPositionY=0.0)
    window = dict(ContainerShowSidebar=False,ShowSidebar=False,ShowStatusBar=False,
        ShowTabView=False,ShowToolbar=False,ShowPathbar=False,
        WindowBounds='{{300, 240}, {720, 528}}')
    plist = lambda value: plistlib.dumps(value,fmt=plistlib.FMT_BINARY)
    records = [('.', 'bwsp', b'blob', plist(window)), ('.','icvp',b'blob',plist(options)),
        ('.','vSrn',b'long',u32(1)), ('.','vstl',b'type',b'icnv')]
    for name,x in [('MenuSlim.app',180),('Applications',540)]:
        records.append((name,'Iloc',b'blob',u32(x,220)+bytes.fromhex('ffffffffffff0000')))
    leaf = u32(0,len(records))
    for name,code,kind,data in sorted(records,key=lambda r:(r[0].lower(),r[1])):
        raw = name.encode('utf-16be')
        leaf += u32(len(raw)//2)+raw+code.encode()+kind
        leaf += (u32(len(data)) if kind==b'blob' else b'')+data
    if len(leaf)>4096:
        raise ValueError('Installer layout exceeds one Finder page')
    leaf=leaf.ljust(4096,b'\0')
    free = [[] for _ in range(32)]
    free[31]=[0]
    end=0
    def allocate(length):
        nonlocal end
        width=max(5,(length-1).bit_length())
        source=next(i for i in range(width,32) if free[i])
        offset=free[source].pop(0)
        while source>width:
            source-=1
            free[source].append(offset+(1<<source));free[source].sort()
        end=max(end,offset+(1<<width))
        return offset,width
    allocate(64)
    master=u32(2,0,len(records),1,4096)
    master_offset,master_width=allocate(len(master))
    node_offset,node_width=allocate(len(leaf))
    addresses=[0,master_offset|master_width,node_offset|node_width]
    def bookkeeping():
        table=u32(3,0,*addresses)+b'\0'*(253*4)+u32(1)+b'\x04DSDB'+u32(1)
        return table+b''.join(u32(len(blocks),*blocks) for blocks in free)
    info_offset,info_width=allocate(len(bookkeeping()))
    addresses[0]=info_offset|info_width
    image=bytearray(end+4)
    image[:20]=u32(1)+b'Bud1'+u32(info_offset,1<<info_width,info_offset)
    for offset,data in [(master_offset,master),(node_offset,leaf),(info_offset,bookkeeping())]:
        image[offset+4:offset+4+len(data)]=data
    Path(destination).write_bytes(image)


if __name__=='__main__':
    write_layout(sys.argv[1],sys.argv[2])
