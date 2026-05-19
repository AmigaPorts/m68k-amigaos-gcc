#ifndef	_SYS_STATVFS_H
#define	_SYS_STATVFS_H	1

typedef unsigned long long __fsblkcnt64_t;
typedef unsigned long long __fsfilcnt64_t;

struct statvfs {
    unsigned long int f_bsize;
    unsigned long int f_frsize;
    __fsblkcnt64_t f_blocks;
    __fsblkcnt64_t f_bfree;
    __fsblkcnt64_t f_bavail;
    __fsfilcnt64_t f_files;
    __fsfilcnt64_t f_ffree;
    __fsfilcnt64_t f_favail;
	
    unsigned long int f_fsid;
    unsigned long int f_flag;
    unsigned long int f_namemax;
    unsigned int f_type;
    int __f_spare[5];	
};

extern __stdargs int statvfs (const char *__restrict __file,
		    struct statvfs *__restrict __buf);


#endif	/* sys/statvfs.h */
