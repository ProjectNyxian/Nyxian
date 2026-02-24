
#ifndef _PROCINFO_H_
#define _PROCINFO_H_

#define PROX_FDTYPE_VNODE       1
#define PROC_PIDFDVNODEPATHINFO         2
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

#endif
