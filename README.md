# D.R.E.A.M.

## Raspberry Pi Setup

Here are some basic steps for setting up a Raspberry Pi from the CanaKit box.

1. put the SD card in
1. hook up a monitor, keyboard and mouse
1. Follow the steps to install Raspberrian
1. run `rasPi-config` to hook the Pi up to the wireless network
1. run `rasPi-config` to change the hostname to something that is not `raspberryPi`
1. update the password for the Pi account

At this point you should be able to disconnect the Pi from everything except power and it should be accessible.
Make sure you are on the same wireless network as it will only be availble within that subnet.

We need a few extra packages for the Pi to be a BLE sniffer.  Run the following commands to add these dependencies.

```
sudo apt-get install libdbus-1-dev libdbus-glib-1-dev libglib2.0-dev libical-dev libreadline-dev libudev-dev libusb-dev make glib2.0 libdbus-1-dev libudev-dev bluez bluez-hcidump
```

This should provide `hcitool` and `hcidump` which are the main tools we (probably) will be using.

To start sniffing, open 2 consoles on the Pi.  In one, start up a scanner

```
sudo hciconfig hc0 up
sudo hcitool lescan -v
```

In the other, start up the data dumper
```
sudo hcidump --raw
```

At this point you should see a spew of data coming out of the `hcidump` terminal.
