# Setup Kali Linux

- Run pimpmykali from https://github.com/Dewalt-arch/pimpmykali and use New VM Setup option.
-  Install fonts: 
    ```bash
    git clone https://github.com/powerline/fonts.git
    cd fonts
    ./install.sh
    ```
- Install Brave from https://brave.com/linux/#release-channel-installation
- Install required tools
    ```bash
    sudo apt install -y fish terminator gedit python3-pip vim-gtk3 alien
    ```
- Install VS Code
- Install rust from https://rustp.rs
    ```bash
    source "$HOME/.cargo/env"
    cargo install rustscan
    cargo install feroxbuster
    ```

## Additional Steps for fish
```bash
curl -kL https://get.oh-my.fish |fish
fish -c "omf install bobthefish"
echo "set -x PATH \$PATH $HOME/.cargo/bin" >> ~/.config/fish/config.fish
chsh -s /usr/bin/fish
```