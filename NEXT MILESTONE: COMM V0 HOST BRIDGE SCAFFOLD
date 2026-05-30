============================================================
NEXT MILESTONE: COMM V0 HOST BRIDGE SCAFFOLD
============================================================

Goal:

    Give ZIGN01D a communication command layer that can later support:

        internet requests
        SMS
        modem status
        call control

    But start honestly with placeholders.

Commands:

    comm
    bridge status
    net status
    net get <url>
    sms inbox
    sms send <number> <text>
    modem status

COMM V0 output must be honest:

    bridge=not-connected
    net_backend=none
    sms_backend=none
    modem_backend=none
    real_internet=not-implemented
    real_sms=not-implemented
    real_modem=not-attached

COMM V1:

    fake bridge responses inside QEMU

COMM V2:

    real QEMU-to-host bridge, fake target

COMM V3:

    real internet through host bridge

COMM V4:

    fake SMS through host bridge

COMM V5:

    real modem status through Linux bridge

COMM V6:

    real SMS receive

COMM V7:

    real SMS send

COMM V8:

    two-way texting showcase
============================================================
