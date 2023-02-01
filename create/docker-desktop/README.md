# Desktop Configuration Instructions

### Docker Desktop - Windows

> **WARNING**: _This is all quite memory intensive, an 8GB Windows laptop won't even be able to start a kubernetes cluster in a satisfactory way, let alone applications on top of it, 16GB will be tight, as by default WSL2 sets the maximum memory available to the virtual machine to 50% of the host capacity. 32GB is mostly painless. If you don't have the capacity, consider using a cloud provider to run a cluster._

1. Have WSL2 installed and confirmed working, do first login etc.
1. Have Docker Desktop installed, and confirm the `docker ps` command is working correctly from a WSL shell session.
1. Enable the kubernetes service option in Docker Desktop settings.
   ![docker-desktop-windows](../../docs/windows-docker-desktop.png)

### Docker Desktop - MacOS

> **WARNING**: _Similar warnings to Windows above, but MacOS requires a step to define the resources available. Don't skip it as the defaults are very conservative._

1. Have Docker Desktop installed, with a confirmation `docker ps` command is working correctly in the MacOS terminal session.
1. Enable the VirtIO option on storage, the default option is extremely slow for host mounted volumes (applies more to docker than kubernetes but solid advice regardless).
   ![virtio](../../docs/macos-docker-desktop-general.png)
1. Enable the kubernetes service option in Docker Desktop settings.
   ![docker-desktop-macos](../../docs/macos-docker-desktop-kubernetes.png)
1. Configure the VM resources for Docker/Kubernetes.
   ![resources](../../docs/macos-docker-desktop-resources.png)
   * In this example there's 32GB of system ram to play with, I appreciate that'll be rare, but try to at least provision 10GB. 
   * Storage should also be set to a decent percentage of your host disk space, if only because a lot of these projects move larger files around persistent and ephemeral volumes.
    More CPU cores is better, but total-2 is a decent starting point so your host remains responsive.