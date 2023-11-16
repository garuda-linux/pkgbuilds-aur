FROM archlinux:latest

# Set up a basic Arch container with Chaotic-AUR enabled
RUN curl -o /etc/pacman.d/mirrorlist "https://archlinux.org/mirrorlist/?country=DE&protocol=https&use_mirror_status=on" && \
    sed -i 's/^#//' /etc/pacman.d/mirrorlist
RUN pacman-key --init && pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && pacman-key --lsign-key 3056513887B78AEB
RUN pacman --noconfirm -U 'https://geo-mirror.chaotic.cx/chaotic-aur/chaotic-'{keyring,mirrorlist}'.pkg.tar.zst'
RUN echo -e "[multilib]\\nInclude = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf && \
    echo "" >>/etc/pacman.conf && \
    echo -e "[chaotic-aur]\\nInclude = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf && \
    echo "" >>/etc/pacman.conf
RUN pacman -Syu --noconfirm base-devel namcap
RUN pacman -Scc --noconfirm

RUN useradd -m builder

COPY ./entry_point.sh /entry_point.sh
RUN chmod +x /entry_point.sh

ENTRYPOINT ["/entry_point.sh"]