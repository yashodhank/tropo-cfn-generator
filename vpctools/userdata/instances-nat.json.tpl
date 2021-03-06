#cloud-config

hostname: {{hostname}}
fqdn: {{hostname}}.{{zone}}.#{AWS::Region}.{{domain}}
manage_etc_hosts: true

write_files:
 - content: |
     net.ipv4.ip_forward = 1
     net.ipv4.conf.eth0.send_redirects = 0
   permissions: '0644'
   path: /etc/sysctl.d/nat.conf

bootcmd:
 - [ cloud-init-per, once, mymkfs, mkfs.ext4, /dev/xvdc ]
 - iptables -F
 - iptables -X
 - iptables -t nat -F
 - iptables -t nat -X
 - iptables -t mangle -F
 - iptables -t mangle -X
 - iptables -P INPUT ACCEPT
 - iptables -P FORWARD ACCEPT
 - iptables -P OUTPUT ACCEPT
 - iptables -t nat -A POSTROUTING -o eth0 -s "0.0.0.0/0" -j MASQUERADE
 - echo 1 >/proc/sys/net/ipv4/ip_forward
 - echo 0 >/proc/sys/net/ipv4/conf/eth0/send_redirects
 - if ! test -b "/dev/$(curl -s http://169.254.169.254/latest/meta-data/block-device-mapping/ephemeral0)" || mountpoint -q /mnt; then test -f /mnt/swap.img || /bin/dd if=/dev/zero of=/mnt/swap.img bs=1M count=2048; fi
 - test -f /mnt/swap.img && chmod 600 /mnt/swap.img
 - test -f /mnt/swap.img && (grep -q "/mnt/swap.img" /proc/swaps || /sbin/mkswap /mnt/swap.img)
 - test -f /mnt/swap.img && (grep -q "/mnt/swap.img" /proc/swaps || /sbin/swapon /mnt/swap.img)

runcmd:
 - iptables-save >/etc/sysconfig/iptables
 - test -f /mnt/swap.img || /bin/dd if=/dev/zero of=/mnt/swap.img bs=1M count=2048
 - test -f /mnt/swap.img && chmod 600 /mnt/swap.img
 - test -f /mnt/swap.img && (grep -q "/mnt/swap.img" /proc/swaps || /sbin/mkswap /mnt/swap.img)
 - test -f /mnt/swap.img && (grep -q "/mnt/swap.img" /proc/swaps || /sbin/swapon /mnt/swap.img)
 - export PATH="$PATH:/usr/local/bin:/usr/local/sbin"
 - [ /usr/local/sbin/r53.py, "#{r53_hosted_zone}}", "#{AWS::Region}", "{{zone}}" ]
 - [ cfn-init, --region, "#{AWS::Region}", -s, "#{AWS::StackName}", -r, "{{name}}" ]
 - [ cfn-signal, -e, "0", -r, "Deployment Complete.", "#{ApplicationWaitHandle}" ]

