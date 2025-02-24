######################################################################
#               _            _
#            __| | _____   _| |__   _____  __
#           / _` |/ _ \ \ / | '_ \ / _ \ \/ /
#          | (_| |  __/\ V /| |_) | (_) >  <
#           \__,_|\___| \_/ |_.__/ \___/_/\_\
#
######################################################################

FROM ubuntu:noble-20241118.1

ENV USERNAME="zhilong"
ENV NEOVIM_RELEASE_VERSION="0.10.1"
ENV NEOVIM_SHA256="4867de01a17f6083f902f8aa5215b40b0ed3a36e83cc0293de3f11708f1f9793"
ENV LAZYGIT_VERSION="0.44.1"
ENV YAZI_VERSION="0.4.1"
ENV GIT_USERNAME="zhilong_devbox"
ENV GIT_EMAIL="719565847@qq.com"
ENV GIT_DEFAULT_BRANCH="main"
ENV TZ="America/Los_Angeles"

######################################################################
#                               PACKAGES
######################################################################

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y \
  clang \
  curl \
  fd-find \
  fontconfig \
  git \
  luarocks \
  make \
  pip \
  golang \
  openssh-server \
  python3 \
  python3.12-venv \
  npm \
  nodejs \
  ripgrep \
  sudo \
  tar \
  unzip \
  wget \
  vim \
  zsh

RUN chsh -s $(which zsh)

# Set empty password by default
RUN useradd -ms /bin/zsh ${USERNAME} && passwd -d ${USERNAME}

RUN usermod -aG sudo ${USERNAME}
USER ${USERNAME}

RUN mkdir -p ~/.local/share/fonts
WORKDIR /home/${USERNAME}/.local/share/fonts
RUN curl -L "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip" -o JetBrainsMono.zip && \
  unzip JetBrainsMono.zip && \
  rm JetBrainsMono.zip && \
  fc-cache -fv

######################################################################
#                               ZSH
######################################################################

# TODO: this seems odd that I have to specifically run this as root
USER root
COPY .config/.zshrc /home/${USERNAME}/.zshrc
RUN chmod a+rwx /home/${USERNAME}/.zshrc
COPY .config/.p10k.zsh /home/${USERNAME}/.p10k.zsh
RUN chmod a+rwx /home/${USERNAME}/.p10k.zsh
USER ${USERNAME}

RUN echo 'export SHELL="/bin/zsh"' >> /home/${USERNAME}/.zshrc
RUN git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k

######################################################################
#                             openssh
######################################################################

RUN sudo echo -e '\nPermitRootLogin yes' >> /etc/ssh/sshd_config
RUN sudo service ssh enable

######################################################################
#                              conda
######################################################################

RUN cd ~
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash ./Miniconda3-latest-Linux-x86_64.sh -b
RUN echo -e '\nPATH="/home/'${USERNAME}'/miniconda3/bin:$PATH"' >> ~/.bashrc
RUN source ~/.bashrc
######################################################################
#                               RUST
######################################################################

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN ~/.cargo/bin/cargo install \
  cargo-nextest \
  ripgrep
RUN ~/.cargo/bin/rustup component add rustfmt

######################################################################
#                               PYTHON
######################################################################

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN ~/.local/bin/uv tool install ruff

######################################################################
#                               LAZYGIT
######################################################################

RUN mkdir -p /tmp/lazygit
WORKDIR /tmp/lazygit
RUN curl -L "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" -o lazygit.tar.gz && \
  tar -xzf lazygit.tar.gz && \
  mkdir -p ~/.bin && \
  mv lazygit ~/.bin/lazygit
ENV PATH="$PATH:~/.bin"
RUN echo 'export PATH="$PATH:/home/'"${USERNAME}"'/bin"' >> ~/.zshrc
RUN mkdir -p ~/.config/lazygit && \
  echo "disableStartupPopups: true" >> ~/.config/lazygit/config.yml
RUN git config --global user.name ${GIT_USERNAME} && \
  git config --global user.email ${GIT_EMAIL} && \
  git config --global init.defaultbranch ${GIT_DEFAULT_BRANCH} && \
  git config --global core.editor "nvim"

######################################################################
#                               YAZI
######################################################################

RUN mkdir -p /tmp/yazi
WORKDIR /tmp/yazi
RUN curl -L "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" -o yazi.zip && \
  unzip yazi.zip && \
  mv yazi-x86_64-unknown-linux-gnu ~/.bin/yazi
ENV PATH="$PATH:~/.bin/yazi"
RUN echo 'export PATH="$PATH:/home/'"${USERNAME}"'/.bin/yazi"' >> ~/.zshrc
COPY --chown=${USERNAME}:${USERNAME} scripts/yazi-cd.sh /tmp/yazi/
RUN cat yazi-cd.sh >> ~/.zshrc

######################################################################
#                               NEOVIM
######################################################################

RUN mkdir -p /tmp/neovim
WORKDIR /tmp/neovim
# For some reason -O is not passing the checksum
RUN curl -L "https://github.com/neovim/neovim/releases/download/v${NEOVIM_RELEASE_VERSION}/nvim-linux64.tar.gz" -o nvim-linux64.tar.gz && \
  echo "${NEOVIM_SHA256} nvim-linux64.tar.gz" | sha256sum -c - && \
  tar -xzf nvim-linux64.tar.gz && \
  mv nvim-linux64 ~/.bin/nvim
ENV PATH="$PATH:~/.bin/nvim/bin"
RUN echo 'export PATH="$PATH:/home/'"${USERNAME}"'/.bin/nvim/bin"' >> ~/.zshrc

COPY --chown=${USERNAME}:${USERNAME} .config/nvim /home/${USERNAME}/.config/nvim

# TODO: even though this is on the path, it can't find it?
# TODO: why is MasonInstallAll not working correctly?
RUN ~/.bin/nvim/bin/nvim --headless +Lazy sync +qall
RUN ~/.bin/nvim/bin/nvim --headless -c "MasonInstallAll" +qall
RUN ~/.bin/nvim/bin/nvim --headless -c "MasonInstall rust-analyzer ruff ruff-lsp codelldb debugpy pyright" +qall
RUN ~/.bin/nvim/bin/nvim --headless "+TSInstallSync! rust python" +qa

# For some reason Treesitter sync above isn't actually doing anything,
# so instead let's open a file that treesitter would highlight and have it do stuff.
# We do an arbitrary long 15s wait because actually quering treesitter using their
# functions does not seem to work.
RUN ~/.bin/nvim/bin/nvim --headless -c "edit tmp.py" -c "lua vim.wait(15000)" -c "quit"

######################################################################
#                               FINISH
######################################################################
WORKDIR /home/${USERNAME}
#ENTRYPOINT ["/bin/zsh", "-c", "set -e; echo 'Please set a password:'; passwd $USER; exec /bin/zsh"]
ENTRYPOINT [ "/bin/zsh" ]
