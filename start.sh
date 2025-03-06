#!/bin/bash
# 检查是否存在挂载的authorized_keys文件
if [ -f /tmp/ssh/authorized_keys ]; then
    # 复制authorized_keys到容器内
    mkdir -p /root/.ssh
    cp /tmp/ssh/authorized_keys /root/.ssh/
    chmod 600 /root/.ssh/authorized_keys
    echo "SSH authorized_keys已复制"
fi

# 启动SSH服务
/usr/sbin/sshd -D