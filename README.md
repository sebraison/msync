# msync
## Aggregate multiple cloud-synchronized storages into a single mount point.

Because we massively rely on [rclone](http://rclone.com), you can use any provider it supports. We
also have its limitations, please refer to its documentation. The biggest one
is that you should not try to mount from different places, or you will loose
data.

This tool **MUST** be run as root because aufs create root-owned meta-data files in
each directory used as back-end, and we need to access them to synchronize.

### Syntax : 
>**`msync.sh <command> <argument> <...>`**

###With command :

>**`help`** 
    
>> Display this help.      

> **`check <install dir>`**
    
>>Do simple sanity checks. If no install dir specified, check only for
base requirements (rclone, iwatch, aufs module). If <install dir> is
specified, check also if installation is ok.

>**`install <install dir>`**

>>Setup cache directory in <install dir> using rclone confirgured
storages.

>**`import <install dir>`**

>>Retrieve cloud data after a fresh (re) install, **MUST** be run before the
start command or you will overwrite all saved data on cloud. Note you
may have to fix permissions because cloud storages does not preserve
Unix perms (tool is run as root so he will own all imported files).

>**`start <install dir> <mount point>`**

>>Start the service previously installed in <install dir> and mount the
agregated volume on <mount point>.

>**`stop <install dir> <mount point>`**

>>Stop the service, unmount the `<mount point>` and remove it. 

  
### Some things you should know

* `stdout` and `stderr` of all internal commands are redirected to `<install dir>/msync.log`.
 May be useful if not working as expected.

* You should not try to mount from different places, or you will loose your
 data. It is because we synchronize from local to cloud, except when you run the import command.

* For now msync is not able to handle occupied space repartition, or cloud storage
size limitation, because :
  * we can know used space on cloud storage but not remaining sapce.
  * cache directories are probably all on the same disk partition, so we cannot use the aufs mfs
 (most-free-space) policy.
 
* But as aufs is very tolerant, you can equilibrate by yourself caches directories. I recommend
to do this with service stopped, but it should be ok when running (unless you do very weird things ...)

* Last but not least, msync is very young, not very tested, so make backups ...
