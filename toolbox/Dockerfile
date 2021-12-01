FROM quay.io/coreos-assembler/fcos-buildroot:testing-devel
LABEL com.coreos.toolbox=true
ADD build.sh /tmp
RUN /tmp/build.sh && rm -f /tmp/build.sh
