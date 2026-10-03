## About

Setup scripts to use Debian's [netboot](https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64/) to PXE boot and [install](https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_13_Trixie) Proxmox on a simple single LVM drive setup.

## How to use

### Intro

To prepare a PXE boot using the output of these scripts, you'll need to prepare a DHCP, TFTP, and HTTP server--the combination of which make for a PXE server. Setting up those are beyond the scope of this project, but notes and example configurations to help give you an idea are available [here](example.configuration.and.notes.txt); I have used those myself.

In the example implementation, I used OpenWRT on my router to host all of these services with the preinstalled services--`dnsmasq` for DHCP and DNS and `uHTTPd` for http. All of the following collected files are put into the same directory`/srv/tftp`.

> [!CAUTION]
> By default, the `preseed.cfg` here is configured to delete the first disk it finds and overwrite it with a Proxmox install

### Collect Debian Kernel and initrd

Collect `initrd.gz` and `linux` from [here](https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64/)

- Put those in your tftp folder.

### Compile and collect ipxe as snponly.efi

Run `git clone https://github.com/ipxe/ipxe.git`

`cd` into the ipxe project folder

- Run `make bin-x86_64-efi/snponly.efi EMBED=${autoboot.ipxe} -j "$(nproc)"` where `${autoboot.ipxe}` is the one included here or of your choice.
  
  - Included in [autoboot.ipxe](ipxe.make.config/autoboot.ipxe):
    
    - ```
      #!ipxe
      
      dhcp
      chain ${128}
      ```
      
      - This tells the system to run the ipxe instructions in the URL of DHCP code 128

Pick out `snponly.efi` and place it in your shared tftp folder.

### Configure `authorized_keys` and `setup.sh` then run it

Edit the configurations to suit your system in `authorized_keys` and `setup.sh`

Run `chmod +x setup.sh` if it isn't already an executable, and then execute it

- Configurations include the output folder of the customized scripts, host/domain name, and network settings

`setup.sh` will ask you to create a root password for your new host and again to confirm it

- Your input is hashed using `openssl`, and that hash is placed in `preseed.cfg` where it'll later be used to configure the initial Debian install; the Proxmox install that immediately follows on top of it will inherit it.

### What files should be in your serve folder

You should have these files prepared and placed in your http & tftp folder(s):

```
authorized_keys
autoexec.ipxe
preseed.cfg
proxmoxinstall.sh


linux
initrd.gz
```

### Final touches

After Proxmox boots:

> [!WARNING]
> 
> Careful when making changes to the network section or you may lock yourself out and then require physical terminal access

- Login  to the WebGUI with the password that you supplied in the `preseed.cfg` file; look to the left and click the hostname you set that is listed under `Datacenter`; then look under `System` for `Network`
  
  - There, carefully make the following changes as making a mistake can lock you out of network access, and then you may have to physically access the system's terminal; do not hit apply until you have completed all of the changes
    
    - Remove IP/Gateway from interface, and remember the name of the interface.
      
      - Leave it as active with `Autostart` enabled
    
    - Click create and create virtual switch
      
      - I'm currently using Linux Bridge on a test bench, but OVS Bridge may be superior
      
      - Set the IP and Gateway, turn on `Autostart`, and very importantly, set `Bridge Ports` to the name of the remembered interface of the preceding instruction
      
      - You may want to use `VLAN aware` if you're going to be setting up different services on different 'broadcast domains'/VLANs
    
    - Carefully review changes to avoid being locked out, and click `Apply Configuration` when ready
    
    - You should be able to refresh the page after a second or two
      
      - If you cannot access the page, something went wrong, and you'll likely have to physically access its terminal and make changes to `/etc/network/interfaces`
        
        - See for more help: https://pve.proxmox.com/wiki/Network_Configuration

- If you don't have a subscription, enable the `pve-no-subscription` repo under `Updates` > `Repositories`