# msync
## Aggregate multiple cloud-synchronized storages into a single mount point.

Because we massively rely on [rclone](http://rclone.com), you can use any provider it supports. We
also have its limitations, please refer to its documentation.

## What msync is and is not ?

msync is not a dropbox-like on steroïd. It only synchronize data from a pool of local directories
on a Linux box to a pool of cloud storages. Only in that direction. Not more. See the
"What you should know" section for some creepy details.


## Ok, but why ?

The goal is to rely on many cheap or free cloud storages and use them together, as it was a big (and expensive) one.
In fact today big cloud accounts are not so expensive, so may be I wrote this script only for fun !

By the way, this approach has other interests. First, you can reuse accounts you have bought, or just
expand one. Second, you are not relying on just one provider, something like 
"don't put all your eggs in one basket". Another good point, if you have a very high speed connection, is the
parallelization of the transfers, so you are not limited by one cloud provider.


## How it works ?

msync is a Bash script built upon the two real tools, rclone and aufs.
aufs (a re-implementation of UnionFS) is used to present an unified view based on a pool of directories, and rclone
is used to synchronize this pool on cloud storage.  
ASCII art time :
>								   __________
>								  |          |
>								  |   your   |
>								  |   data   |
>								  |__________|
>										|  
>							  ________aufs________
>							 |      |      |      |
>							_V_    _V_    _V_    _V_
>				pool of    |   |  |   |  |   |  |   |
>			  directories  |___|  |___|  |___|  |___|
>							 |      |      |      |
>						  rclone rclone rclone rclone
>							 |      |      |      |
>							_V_    _V_    _V_    _V_
>				pool of    |   |  |   |  |   |  |   |
>			cloud storages |___|  |___|  |___|  |___|
>		
>   		

<em>Please note the single direction of arrows.</em>
				 
## How to use it ?

You only need a Linux computer with rclone, aufs and inotify support.

aufs and inotify are available in all decent Linux distribution, but you may have to install
the iwatch tool. On debian-like systems, type :  
>`sudo apt-get install iwatch`

rclone is not packaged, but you can download a static binary on the homepage, and put it
in your path, or in the same directory than msync.sh.

Before using msync, you need to setup some cloud storages, in rclone. Do it with the root user,
because we need to run the service as root. Refer to [rclone documentation](http://rclone.org/docs/)
to do that.


### Syntax : 
**`msync.sh <command> <argument> <...>`**

###With command :

**`help`** 
    
 Display this help.      

 **`check <install dir>`**
    
Do simple sanity checks. If no install dir specified, check only for
base requirements (rclone, iwatch, aufs module). If `<install dir>` is
specified, check also if installation is ok.

**`install <install dir>`**

Setup cache directories in `<install dir>` using rclone confirgured cloud storages.

**`import <install dir>`**

Retrieve cloud data after a fresh (re) install, **MUST** be run before the
start command or you will overwrite all saved data on cloud. Note you
may have to fix permissions because cloud storages does not preserve
Unix perms (tool is run as root so he will own all imported files).

**`start <install dir> <mount point>`**

Start the service previously installed in `<install dir>` and mount the
agregated volume on `<mount point>`.

**`stop <install dir> <mount point>`**

Stop the service, unmount the `<mount point>` and remove it. 


## Some things you should know

* msync must be run as root because aufs create root-owned meta-data files in each
directory used as back-end, and we need to access them to synchronize.
    
* `stdout` and `stderr` of all internal commands are redirected to `<install dir>/msync.log`.
 May be useful if not working as expected.

* You should not try to mount from different places, or you will loose your
 data. It is because we synchronize only from local to cloud, except when you run the import command.
 
* You can use your cloud drive for other things as msync use its own directory. But it
is not recommended.

* For now msync is not able to handle occupied space repartition, or cloud storage
size limitation, because :
  * we can know used space on cloud storage but not remaining sapce.
  * cache directories are probably all on the same disk partition, so we cannot use the aufs mfs
 (most-free-space) policy.
 
* But as aufs is very tolerant, you can equilibrate by yourself caches directories. I recommend
to do this with service stopped, but it should be ok when running (unless you do very weird things ...)

* Last but not least, msync is very young, not very tested, so make backups ...
