ARG VPP_VERSION=v22.06
ARG UBUNTU_VERSION=20.04

FROM ubuntu:${UBUNTU_VERSION} as vppbuild
ARG VPP_VERSION
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive TZ=US/Central apt-get install -y git make python3 sudo asciidoc
RUN git clone https://github.com/FDio/vpp.git
WORKDIR /vpp
RUN git checkout ${VPP_VERSION}
COPY patch/ patch/
RUN test -x "patch/patch.sh" && ./patch/patch.sh || exit 1
RUN DEBIAN_FRONTEND=noninteractive TZ=US/Central UNATTENDED=y make install-dep
RUN make pkg-deb
RUN ./src/scripts/version > /vpp/VPP_VERSION

FROM vppbuild as version
CMD cat /vpp/VPP_VERSION

FROM ubuntu:${UBUNTU_VERSION} as vppinstall
COPY --from=vppbuild /var/lib/apt/lists/* /var/lib/apt/lists/
COPY --from=vppbuild [ "/vpp/build-root/libvppinfra_*_amd64.deb", "/vpp/build-root/vpp_*_amd64.deb", "/vpp/build-root/vpp-plugin-core_*_amd64.deb", "/vpp/build-root/vpp-plugin-dpdk_*_amd64.deb", "/pkg/"]
RUN VPP_INSTALL_SKIP_SYSCTL=false apt install -f -y --no-install-recommends /pkg/*.deb ca-certificates iputils-ping iproute2 tcpdump iptables; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /pkg

FROM ubuntu:${UBUNTU_VERSION} as vpp
COPY --from=vppinstall / /

FROM vpp as vpp-dbg
WORKDIR /pkg/
COPY --from=vppbuild ["/vpp/build-root/libvppinfra-dev_*_amd64.deb", "/vpp/build-root/vpp-dbg_*_amd64.deb", "/vpp/build-root/vpp-dev_*_amd64.deb", "./" ]
RUN VPP_INSTALL_SKIP_SYSCTL=false apt install -f -y --no-install-recommends ./*.deb
