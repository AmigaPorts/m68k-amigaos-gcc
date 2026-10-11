#ifndef DEVICES_SANA2SPECIALSTATS_H
#define DEVICES_SANA2SPECIALSTATS_H

/*
    Copyright (C) 2005 Neil Cafferkey

    The contents of this file are subject to the AROS Public License
    Version 1.1 (the "License"); you may not use this file except in
    compliance with the License. A copy is in LICENSE.AROS-APL next to
    this file, and at http://www.aros.org/license.html.

    Software distributed under the License is distributed on an "AS IS"
    basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
    the License for the specific language governing rights and
    limitations under the License.

    $Id$

    Desc: Special statistics definitions for SANA-II devices
    Lang: english
*/

#include <devices/sana2.h>


/* Constants */
/* ========= */

/* Ethernet */

#define S2SS_ETHERNET_BADMULTICAST   (S2WireType_Ethernet << 16 | 0)
#define S2SS_ETHERNET_RETRIES        (S2WireType_Ethernet << 16 | 1)
#define S2SS_ETHERNET_FIFO_UNDERRUNS (S2WireType_Ethernet << 16 | 2)

#endif
