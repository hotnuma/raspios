
## Raspi OS

Bare minimum Raspi OS post-install script to make it usable.

#### Manual configuration

* Install wl-clip-persist
    
    ```
    wget https://github.com/hotnuma/sysconfig/raw/refs/heads/master/labwc/wl-clip-persist-aarch64.zip
    sudo unzip -d /usr/local/bin/ wl-clip-persist-aarch64.zip
    nano ~/.config/custom-labwc/autostart
    ```

* Set prefered mpv resolution
	
	create a mpv.conf file and add the following :
	
	`ytdl-format=bestvideo[height<=?480]+bestaudio/best`


