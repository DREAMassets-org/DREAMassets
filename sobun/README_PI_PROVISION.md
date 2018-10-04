# Configure Redis

We need to set `vm.overcommit_memory=1` so redis won't fail on snapshot the data:

Modify /etc/sysctl.conf and add:

```
vm.overcommit_memory=1
```

Then restart sysctl with:
```
sudo sysctl -p /etc/sysctl.conf
```

https://stackoverflow.com/a/49839193/177298
