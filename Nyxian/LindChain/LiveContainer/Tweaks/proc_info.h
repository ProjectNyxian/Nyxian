
#ifndef _PROCINFO_H_
#define _PROCINFO_H_

#define PROX_FDTYPE_VNODE       1
#define PROC_PIDFDVNODEPATHINFO         2
#define PROC_PIDFDSOCKETINFO            3
#define PROC_PIDFDPIPEINFO              6

#define PROC_PIDLISTFDS                 1

struct proc_fdinfo {
    int32_t                 proc_fd;
    uint32_t                proc_fdtype;
};


struct proc_fileinfo {
    uint32_t                fi_openflags;
    uint32_t                fi_status;
    off_t                   fi_offset;
    int32_t                 fi_type;
    uint32_t                fi_guardflags;
};

struct vinfo_stat {
    uint32_t        vst_dev;        /* [XSI] ID of device containing file */
    uint16_t        vst_mode;       /* [XSI] Mode of file (see below) */
    uint16_t        vst_nlink;      /* [XSI] Number of hard links */
    uint64_t        vst_ino;        /* [XSI] File serial number */
    uid_t           vst_uid;        /* [XSI] User ID of the file */
    gid_t           vst_gid;        /* [XSI] Group ID of the file */
    int64_t         vst_atime;      /* [XSI] Time of last access */
    int64_t         vst_atimensec;  /* nsec of last access */
    int64_t         vst_mtime;      /* [XSI] Last data modification time */
    int64_t         vst_mtimensec;  /* last data modification nsec */
    int64_t         vst_ctime;      /* [XSI] Time of last status change */
    int64_t         vst_ctimensec;  /* nsec of last status change */
    int64_t         vst_birthtime;  /*  File creation time(birth)  */
    int64_t         vst_birthtimensec;      /* nsec of File creation time */
    off_t           vst_size;       /* [XSI] file size, in bytes */
    int64_t         vst_blocks;     /* [XSI] blocks allocated for file */
    int32_t         vst_blksize;    /* [XSI] optimal blocksize for I/O */
    uint32_t        vst_flags;      /* user defined flags for file */
    uint32_t        vst_gen;        /* file generation number */
    uint32_t        vst_rdev;       /* [XSI] Device ID */
    int64_t         vst_qspare[2];  /* RESERVED: DO NOT USE! */
};

struct vnode_info {
    struct vinfo_stat       vi_stat;
    int                     vi_type;
    int                     vi_pad;
    fsid_t                  vi_fsid;
};

struct vnode_info_path {
    struct vnode_info       vip_vi;
    char                    vip_path[MAXPATHLEN];   /* tail end of it  */
};


struct vnode_fdinfowithpath {
    struct proc_fileinfo    pfi;
    struct vnode_info_path  pvip;
};

struct pipe_info {
    struct vinfo_stat       pipe_stat;
    uint64_t                pipe_handle;
    uint64_t                pipe_peerhandle;
    int                     pipe_status;
    int                     rfu_1;
};

struct pipe_fdinfo {
    struct proc_fileinfo    pfi;
    struct pipe_info        pipeinfo;
};

/* https://github.com/apple/darwin-xnu/blob/2ff845c2e033bd0ff64b5b6aa6063a1f8f65aa32/bsd/sys/proc_info.h */

#include <sys/ioctl.h>
#include <sys/un.h>

#define MAX_KCTL_NAME   96

typedef struct in6_addr {
    union {
        __uint8_t   __u6_addr8[16];
        __uint16_t  __u6_addr16[8];
        __uint32_t  __u6_addr32[4];
    } __u6_addr;                    /* 128-bit IP6 address */
} in6_addr_t;


struct in_addr {
    in_addr_t s_addr;
};

#define INI_IPV4        0x1
#define INI_IPV6        0x2

struct in4in6_addr {
    u_int32_t               i46a_pad32[3];
    struct in_addr          i46a_addr4;
};

struct in_sockinfo {
    int                                     insi_fport;             /* foreign port */
    int                                     insi_lport;             /* local port */
    uint64_t                                insi_gencnt;            /* generation count of this instance */
    uint32_t                                insi_flags;             /* generic IP/datagram flags */
    uint32_t                                insi_flow;

    uint8_t                                 insi_vflag;             /* ini_IPV4 or ini_IPV6 */
    uint8_t                                 insi_ip_ttl;            /* time to live proto */
    uint32_t                                rfu_1;                  /* reserved */
    /* protocol dependent part */
    union {
        struct in4in6_addr      ina_46;
        struct in6_addr         ina_6;
    }                                       insi_faddr;             /* foreign host table entry */
    union {
        struct in4in6_addr      ina_46;
        struct in6_addr         ina_6;
    }                                       insi_laddr;             /* local host table entry */
    struct {
        u_char                  in4_tos;                        /* type of service */
    }                                       insi_v4;
    struct {
        uint8_t                 in6_hlim;
        int                     in6_cksum;
        u_short                 in6_ifindex;
        short                   in6_hops;
    }                                       insi_v6;
};

#define TSI_T_REXMT             0       /* retransmit */
#define TSI_T_PERSIST           1       /* retransmit persistence */
#define TSI_T_KEEP              2       /* keep alive */
#define TSI_T_2MSL              3       /* 2*msl quiet time timer */
#define TSI_T_NTIMERS           4

#define TSI_S_CLOSED            0       /* closed */
#define TSI_S_LISTEN            1       /* listening for connection */
#define TSI_S_SYN_SENT          2       /* active, have sent syn */
#define TSI_S_SYN_RECEIVED      3       /* have send and received syn */
#define TSI_S_ESTABLISHED       4       /* established */
#define TSI_S__CLOSE_WAIT       5       /* rcvd fin, waiting for close */
#define TSI_S_FIN_WAIT_1        6       /* have closed, sent fin */
#define TSI_S_CLOSING           7       /* closed xchd FIN; await FIN ACK */
#define TSI_S_LAST_ACK          8       /* had fin and close; await FIN ACK */
#define TSI_S_FIN_WAIT_2        9       /* have closed, fin is acked */
#define TSI_S_TIME_WAIT         10      /* in 2*msl quiet wait after close */
#define TSI_S_RESERVED          11      /* pseudo state: reserved */

struct tcp_sockinfo {
    struct in_sockinfo              tcpsi_ini;
    int                             tcpsi_state;
    int                             tcpsi_timer[TSI_T_NTIMERS];
    int                             tcpsi_mss;
    uint32_t                        tcpsi_flags;
    uint32_t                        rfu_1;          /* reserved */
    uint64_t                        tcpsi_tp;       /* opaque handle of TCP protocol control block */
};

struct un_sockinfo {
    uint64_t                                unsi_conn_so;   /* opaque handle of connected socket */
    uint64_t                                unsi_conn_pcb;  /* opaque handle of connected protocol control block */
    union {
        struct sockaddr_un      ua_sun;
        char                    ua_dummy[SOCK_MAXADDRLEN];
    }                                       unsi_addr;      /* bound address */
    union {
        struct sockaddr_un      ua_sun;
        char                    ua_dummy[SOCK_MAXADDRLEN];
    }                                       unsi_caddr;     /* address of socket connected to */
};

struct ndrv_info {
    uint32_t        ndrvsi_if_family;
    uint32_t        ndrvsi_if_unit;
    char            ndrvsi_if_name[IF_NAMESIZE];
};

struct kern_event_info {
    uint32_t        kesi_vendor_code_filter;
    uint32_t        kesi_class_filter;
    uint32_t        kesi_subclass_filter;
};

struct kern_ctl_info {
    uint32_t        kcsi_id;
    uint32_t        kcsi_reg_unit;
    uint32_t        kcsi_flags;                     /* support flags */
    uint32_t        kcsi_recvbufsize;               /* request more than the default buffer size */
    uint32_t        kcsi_sendbufsize;               /* request more than the default buffer size */
    uint32_t        kcsi_unit;
    char            kcsi_name[MAX_KCTL_NAME];       /* unique nke identifier, provided by DTS */
};

struct vsock_sockinfo {
    uint32_t        local_cid;
    uint32_t        local_port;
    uint32_t        remote_cid;
    uint32_t        remote_port;
};

struct sockbuf_info {
    uint32_t                sbi_cc;
    uint32_t                sbi_hiwat;                      /* SO_RCVBUF, SO_SNDBUF */
    uint32_t                sbi_mbcnt;
    uint32_t                sbi_mbmax;
    uint32_t                sbi_lowat;
    short                   sbi_flags;
    short                   sbi_timeo;
};

enum {
    SOCKINFO_GENERIC        = 0,
    SOCKINFO_IN             = 1,
    SOCKINFO_TCP            = 2,
    SOCKINFO_UN             = 3,
    SOCKINFO_NDRV           = 4,
    SOCKINFO_KERN_EVENT     = 5,
    SOCKINFO_KERN_CTL       = 6,
    SOCKINFO_VSOCK          = 7,
};

struct socket_info {
    struct vinfo_stat                       soi_stat;
    uint64_t                                soi_so;         /* opaque handle of socket */
    uint64_t                                soi_pcb;        /* opaque handle of protocol control block */
    int                                     soi_type;
    int                                     soi_protocol;
    int                                     soi_family;
    short                                   soi_options;
    short                                   soi_linger;
    short                                   soi_state;
    short                                   soi_qlen;
    short                                   soi_incqlen;
    short                                   soi_qlimit;
    short                                   soi_timeo;
    u_short                                 soi_error;
    uint32_t                                soi_oobmark;
    struct sockbuf_info                     soi_rcv;
    struct sockbuf_info                     soi_snd;
    int                                     soi_kind;
    uint32_t                                rfu_1;          /* reserved */
    union {
        struct in_sockinfo      pri_in;                 /* SOCKINFO_IN */
        struct tcp_sockinfo     pri_tcp;                /* SOCKINFO_TCP */
        struct un_sockinfo      pri_un;                 /* SOCKINFO_UN */
        struct ndrv_info        pri_ndrv;               /* SOCKINFO_NDRV */
        struct kern_event_info  pri_kern_event;         /* SOCKINFO_KERN_EVENT */
        struct kern_ctl_info    pri_kern_ctl;           /* SOCKINFO_KERN_CTL */
        struct vsock_sockinfo   pri_vsock;              /* SOCKINFO_VSOCK */
    }                                       soi_proto;
};

struct socket_fdinfo {
    struct proc_fileinfo    pfi;
    struct socket_info      psi;
};

#endif // !_PROCINFO_H_
