FROM quay.io/coreos-assembler/fcos-buildroot:testing-devel
LABEL com.coreos.toolbox=true
ADD *.sh /tmp
RUN /tmp/build.sh && /tmp/alltools.sh && rm -f /tmp/*.sh && yum clean all