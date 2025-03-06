######################################################################
#               _            _
#            __| | _____   _| |__   _____  __
#           / _` |/ _ \ \ / | '_ \ / _ \ \/ /
#          | (_| |  __/\ V /| |_) | (_) >  <
#           \__,_|\___| \_/ |_.__/ \___/_/\_\
#
######################################################################



FROM ubuntu:latest

ARG SSHINFO
RUN echo $SSHINFO
# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装基础工具并清理缓存
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    tar \
    git \
    openssh-server \
    unzip \
    vim \
    curl \
    wget \
    golang \
    iputils-ping \
    ca-certificates \
    gnupg \
    lsb-release \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # 设置SSH服务
    && mkdir /var/run/sshd \
    && echo 'root:chen1234' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 安装Miniconda、配置环境变量和镜像
RUN wget --no-check-certificate https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh \
    && /opt/conda/bin/conda clean -afy \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc \
    && echo "conda activate base" >> ~/.bashrc \
    # 配置pip镜像
    && mkdir -p ~/.pip \
    && echo "[global]" > ~/.pip/pip.conf \
    && echo "index-url = https://pypi.tuna.tsinghua.edu.cn/simple" >> ~/.pip/pip.conf \
    && echo "trusted-host = pypi.tuna.tsinghua.edu.cn" >> ~/.pip/pip.conf

# 设置Conda环境变量
ENV PATH="/opt/conda/bin:$PATH"

# 配置golang环境变量
RUN echo "export GOPROXY=\"https://goproxy.cn,direct\"" >> /root/.bashrc

# 安装Node.js并配置npm镜像
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm config set registry https://registry.npmmirror.com \
    # 初始化Git配置
    && git config --global user.name "devbox" \
    && git config --global user.email "719565847@qq.com"

# 创建SSH目录
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
# 创建工作目录
WORKDIR /workspace

# 暴露SSH端口
EXPOSE 22

# 创建启动脚本
RUN echo '#!/bin/bash\n\
if [ ! -z "$SSHINFO" ]; then\n\
  echo "$SSHINFO" > /root/.ssh/authorized_keys\n\
  chmod 600 /root/.ssh/authorized_keys\n\
  echo "SSH authorized_keys已更新"\n\
fi\n\
/usr/sbin/sshd -D' > /start.sh && chmod +x /start.sh

# 启动SSH服务
CMD ["/start.sh"]

# 启动SSH服务
#CMD ["/usr/sbin/sshd", "-D"]
